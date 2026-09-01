/**
 * Nearby — Firestore security rules tests.
 *
 * These are the authoritative check on authorisation. The Dart tests in
 * test/integration cover the same rules at the repository layer, but a client
 * check is only a convenience — a hostile client talks to Firestore directly,
 * so what the rules permit is what is actually true.
 *
 * Run with:  cd test/security && npm install && npm test
 * (which starts the Firestore emulator, runs these, and shuts it down)
 */

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  getDocs,
  setLogLevel,
} from 'firebase/firestore';

setLogLevel('error');

// --- Fixtures ----------------------------------------------------------------

const CUSTOMER = 'customer-1';
const OTHER_CUSTOMER = 'customer-2';
const OWNER = 'owner-1';
const OTHER_OWNER = 'owner-2';

const BUSINESS = 'business-1';
const OTHER_BUSINESS = 'business-2';
const SERVICE = 'service-1';

/** One hour from now, so bookings are validly in the future. */
const soon = () => new Date(Date.now() + 60 * 60 * 1000);
const soonPlus = (minutes) =>
  new Date(soon().getTime() + minutes * 60 * 1000);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'nearby-rules-test',
    firestore: {
      rules: readFileSync('../../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

/**
 * Resets the database and seeds it with two customers, two owners and two
 * shops, bypassing the rules so the fixtures themselves are not under test.
 */
beforeEach(async () => {
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, 'users', CUSTOMER), {
      email: 'c1@example.com',
      role: 'customer',
      displayName: 'Customer One',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users', OTHER_CUSTOMER), {
      email: 'c2@example.com',
      role: 'customer',
      displayName: 'Customer Two',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users', OWNER), {
      email: 'o1@example.com',
      role: 'businessOwner',
      displayName: 'Owner One',
      businessId: BUSINESS,
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'users', OTHER_OWNER), {
      email: 'o2@example.com',
      role: 'businessOwner',
      displayName: 'Owner Two',
      businessId: OTHER_BUSINESS,
      createdAt: new Date(),
    });

    for (const [id, ownerId] of [
      [BUSINESS, OWNER],
      [OTHER_BUSINESS, OTHER_OWNER],
    ]) {
      await setDoc(doc(db, 'businesses', id), {
        ownerId,
        name: `Shop ${id}`,
        nameLower: `shop ${id}`,
        category: 'tailoring',
        address: '1 Test Street',
        latitude: 12.9716,
        longitude: 77.5946,
        geohash: 'tdr1v9qtj',
        isAcceptingBookings: true,
        ratingAverage: 4.5,
        ratingCount: 10,
        openingHours: { slotDurationMinutes: 30, days: {}, blockedDates: [] },
        createdAt: new Date(),
      });
    }

    await setDoc(doc(db, 'businesses', BUSINESS, 'services', SERVICE), {
      name: 'Shirt stitching',
      price: 350,
      durationMinutes: 30,
      isActive: true,
    });
  });
});

/** A Firestore handle authenticated as [uid]. */
const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const asAnonymous = () => testEnv.unauthenticatedContext().firestore();

/** A well-formed booking payload. */
const bookingPayload = (overrides = {}) => ({
  customerId: CUSTOMER,
  businessId: BUSINESS,
  serviceId: SERVICE,
  startTime: soon(),
  endTime: soonPlus(30),
  status: 'pending',
  serviceName: 'Shirt stitching',
  servicePrice: 350,
  businessName: `Shop ${BUSINESS}`,
  hasReview: false,
  slotLockIds: [`${BUSINESS}_${soon().getTime()}`],
  createdAt: new Date(),
});

/** Seeds a booking directly, for tests about reading or updating one. */
async function seedBooking(id, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'bookings', id),
      { ...bookingPayload(), ...overrides },
    );
  });
}

// --- Tests -------------------------------------------------------------------

describe('unauthenticated access', () => {
  it('cannot read a business listing', async () => {
    await assertFails(getDoc(doc(asAnonymous(), 'businesses', BUSINESS)));
  });

  it('cannot read a user profile', async () => {
    await assertFails(getDoc(doc(asAnonymous(), 'users', CUSTOMER)));
  });

  it('cannot read bookings', async () => {
    await seedBooking('b1');
    await assertFails(getDoc(doc(asAnonymous(), 'bookings', 'b1')));
  });

  it('cannot write anything', async () => {
    await assertFails(
      setDoc(doc(asAnonymous(), 'businesses', 'injected'), { name: 'Nope' }),
    );
  });
});

describe('users', () => {
  it('can read their own profile', async () => {
    await assertSucceeds(getDoc(doc(as(CUSTOMER), 'users', CUSTOMER)));
  });

  it("cannot read another user's profile", async () => {
    await assertFails(getDoc(doc(as(CUSTOMER), 'users', OTHER_CUSTOMER)));
  });

  it('cannot enumerate accounts', async () => {
    await assertFails(getDocs(collection(as(CUSTOMER), 'users')));
  });

  it('can edit their own name and phone', async () => {
    await assertSucceeds(
      updateDoc(doc(as(CUSTOMER), 'users', CUSTOMER), {
        displayName: 'Renamed',
        phone: '+91 9800000000',
      }),
    );
  });

  it('cannot promote themselves to a business owner', async () => {
    // The critical privilege-escalation path: role is fixed at creation.
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'users', CUSTOMER), {
        role: 'businessOwner',
      }),
    );
  });

  it('cannot change their email', async () => {
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'users', CUSTOMER), {
        email: 'someone.else@example.com',
      }),
    );
  });

  it("cannot edit another user's profile", async () => {
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'users', OTHER_CUSTOMER), {
        displayName: 'Hijacked',
      }),
    );
  });

  it('cannot delete an account from the client', async () => {
    await assertFails(deleteDoc(doc(as(CUSTOMER), 'users', CUSTOMER)));
  });
});

describe('businesses', () => {
  it('any signed-in user can read listings', async () => {
    await assertSucceeds(getDoc(doc(as(CUSTOMER), 'businesses', BUSINESS)));
  });

  it('the owner can edit their own listing', async () => {
    await assertSucceeds(
      updateDoc(doc(as(OWNER), 'businesses', BUSINESS), {
        name: 'Renamed Shop',
        tagline: 'Now with more tailoring',
      }),
    );
  });

  it("an owner cannot edit another owner's listing", async () => {
    await assertFails(
      updateDoc(doc(as(OWNER), 'businesses', OTHER_BUSINESS), {
        name: 'Hijacked Shop',
      }),
    );
  });

  it('a customer cannot edit a listing', async () => {
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'businesses', BUSINESS), {
        name: 'Customer Edited',
      }),
    );
  });

  it('an owner cannot inflate their own rating', async () => {
    // Ratings belong to the Cloud Function. This is the whole reason those
    // fields are denied to clients.
    await assertFails(
      updateDoc(doc(as(OWNER), 'businesses', BUSINESS), {
        ratingAverage: 5,
        ratingCount: 9999,
      }),
    );
  });

  it('an owner cannot transfer ownership of their listing', async () => {
    await assertFails(
      updateDoc(doc(as(OWNER), 'businesses', BUSINESS), {
        ownerId: OTHER_OWNER,
      }),
    );
  });

  it('an owner cannot delete a listing', async () => {
    await assertFails(deleteDoc(doc(as(OWNER), 'businesses', BUSINESS)));
  });

  it('a customer cannot create a listing', async () => {
    await assertFails(
      setDoc(doc(as(CUSTOMER), 'businesses', 'new-shop'), {
        ownerId: CUSTOMER,
        name: 'Customer Shop',
        latitude: 12.9,
        longitude: 77.5,
        geohash: 'tdr1v9qtj',
        ratingAverage: 0,
        ratingCount: 0,
      }),
    );
  });

  it('an owner who already has a listing cannot create a second', async () => {
    await assertFails(
      setDoc(doc(as(OWNER), 'businesses', 'second-shop'), {
        ownerId: OWNER,
        name: 'Second Shop',
        latitude: 12.9,
        longitude: 77.5,
        geohash: 'tdr1v9qtj',
        ratingAverage: 0,
        ratingCount: 0,
      }),
    );
  });

  it('a listing cannot be created with a non-zero rating', async () => {
    // A fresh owner with no businessId yet.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'fresh-owner'), {
        email: 'fresh@example.com',
        role: 'businessOwner',
        createdAt: new Date(),
      });
    });

    await assertFails(
      setDoc(doc(as('fresh-owner'), 'businesses', 'fresh-shop'), {
        ownerId: 'fresh-owner',
        name: 'Fresh Shop',
        latitude: 12.9,
        longitude: 77.5,
        geohash: 'tdr1v9qtj',
        ratingAverage: 5,
        ratingCount: 100,
      }),
    );
  });

  it('a fresh owner can create their first listing', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'fresh-owner'), {
        email: 'fresh@example.com',
        role: 'businessOwner',
        createdAt: new Date(),
      });
    });

    await assertSucceeds(
      setDoc(doc(as('fresh-owner'), 'businesses', 'fresh-shop'), {
        ownerId: 'fresh-owner',
        name: 'Fresh Shop',
        latitude: 12.9,
        longitude: 77.5,
        geohash: 'tdr1v9qtj',
        ratingAverage: 0,
        ratingCount: 0,
      }),
    );
  });
});

describe('services', () => {
  it('any signed-in user can read a shop’s services', async () => {
    await assertSucceeds(
      getDocs(collection(as(CUSTOMER), 'businesses', BUSINESS, 'services')),
    );
  });

  it('the owner can add a service', async () => {
    await assertSucceeds(
      setDoc(doc(as(OWNER), 'businesses', BUSINESS, 'services', 'new-service'), {
        name: 'Blouse stitching',
        price: 500,
        durationMinutes: 45,
        isActive: true,
      }),
    );
  });

  it("an owner cannot add a service to another owner's shop", async () => {
    await assertFails(
      setDoc(
        doc(as(OWNER), 'businesses', OTHER_BUSINESS, 'services', 'injected'),
        { name: 'Injected', price: 1, durationMinutes: 15, isActive: true },
      ),
    );
  });

  it('a customer cannot add a service', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'businesses', BUSINESS, 'services', 'free-service'),
        { name: 'Free', price: 0, durationMinutes: 15, isActive: true },
      ),
    );
  });

  it('rejects a negative price', async () => {
    await assertFails(
      setDoc(doc(as(OWNER), 'businesses', BUSINESS, 'services', 'bad-price'), {
        name: 'Bad',
        price: -100,
        durationMinutes: 30,
        isActive: true,
      }),
    );
  });

  it('rejects an absurd duration', async () => {
    await assertFails(
      setDoc(doc(as(OWNER), 'businesses', BUSINESS, 'services', 'bad-time'), {
        name: 'Bad',
        price: 100,
        durationMinutes: 10000,
        isActive: true,
      }),
    );
  });

  it('services cannot be deleted, only deactivated', async () => {
    await assertFails(
      deleteDoc(doc(as(OWNER), 'businesses', BUSINESS, 'services', SERVICE)),
    );
    await assertSucceeds(
      updateDoc(doc(as(OWNER), 'businesses', BUSINESS, 'services', SERVICE), {
        name: 'Shirt stitching',
        price: 350,
        durationMinutes: 30,
        isActive: false,
      }),
    );
  });
});

describe('bookings', () => {
  it('a customer can create a valid booking for themselves', async () => {
    await assertSucceeds(
      setDoc(doc(as(CUSTOMER), 'bookings', 'new-booking'), bookingPayload()),
    );
  });

  it('a customer cannot create a booking in someone else’s name', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'bookings', 'impersonated'),
        bookingPayload({ customerId: OTHER_CUSTOMER }),
      ),
    );
  });

  it('a booking cannot be created already confirmed', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'bookings', 'self-confirmed'),
        bookingPayload({ status: 'confirmed' }),
      ),
    );
  });

  it('a booking cannot claim a price the service does not have', async () => {
    // The tampered-price path: the rules check against the stored service.
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'bookings', 'cheap'),
        bookingPayload({ servicePrice: 1 }),
      ),
    );
  });

  it('a booking cannot claim a longer slot than the service takes', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'bookings', 'long'),
        bookingPayload({ endTime: soonPlus(180) }),
      ),
    );
  });

  it('a booking cannot be placed in the past', async () => {
    const past = new Date(Date.now() - 60 * 60 * 1000);
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'bookings', 'past'),
        bookingPayload({
          startTime: past,
          endTime: new Date(past.getTime() + 30 * 60 * 1000),
        }),
      ),
    );
  });

  it('a booking cannot be made against a shop that paused bookings', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'businesses', BUSINESS), {
        isAcceptingBookings: false,
      });
    });

    await assertFails(
      setDoc(doc(as(CUSTOMER), 'bookings', 'paused'), bookingPayload()),
    );
  });

  it('a booking cannot be made against a deactivated service', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), 'businesses', BUSINESS, 'services', SERVICE),
        { isActive: false },
      );
    });

    await assertFails(
      setDoc(doc(as(CUSTOMER), 'bookings', 'retired'), bookingPayload()),
    );
  });

  it('a business owner cannot create a booking', async () => {
    await assertFails(
      setDoc(
        doc(as(OWNER), 'bookings', 'owner-made'),
        bookingPayload({ customerId: OWNER }),
      ),
    );
  });

  it('a customer can read their own booking', async () => {
    await seedBooking('mine');
    await assertSucceeds(getDoc(doc(as(CUSTOMER), 'bookings', 'mine')));
  });

  it("a customer cannot read another customer's booking", async () => {
    await seedBooking('theirs', { customerId: OTHER_CUSTOMER });
    await assertFails(getDoc(doc(as(CUSTOMER), 'bookings', 'theirs')));
  });

  it('the shop owner can read a booking made against their shop', async () => {
    await seedBooking('at-my-shop');
    await assertSucceeds(getDoc(doc(as(OWNER), 'bookings', 'at-my-shop')));
  });

  it("an owner cannot read a booking at another owner's shop", async () => {
    await seedBooking('elsewhere', { businessId: OTHER_BUSINESS });
    await assertFails(getDoc(doc(as(OWNER), 'bookings', 'elsewhere')));
  });

  it('the whole bookings collection cannot be listed', async () => {
    await seedBooking('mine');
    await assertFails(getDocs(collection(as(CUSTOMER), 'bookings')));
  });

  it('a customer can query their own bookings', async () => {
    await seedBooking('mine');
    await assertSucceeds(
      getDocs(
        query(
          collection(as(CUSTOMER), 'bookings'),
          where('customerId', '==', CUSTOMER),
        ),
      ),
    );
  });

  it("a customer cannot query another customer's bookings", async () => {
    await seedBooking('theirs', { customerId: OTHER_CUSTOMER });
    await assertFails(
      getDocs(
        query(
          collection(as(CUSTOMER), 'bookings'),
          where('customerId', '==', OTHER_CUSTOMER),
        ),
      ),
    );
  });

  it('an owner can query bookings for their own shop', async () => {
    await seedBooking('mine');
    await assertSucceeds(
      getDocs(
        query(
          collection(as(OWNER), 'bookings'),
          where('businessId', '==', BUSINESS),
        ),
      ),
    );
  });

  it("an owner cannot query another shop's bookings", async () => {
    await assertFails(
      getDocs(
        query(
          collection(as(OWNER), 'bookings'),
          where('businessId', '==', OTHER_BUSINESS),
        ),
      ),
    );
  });

  it('a customer can cancel their own booking', async () => {
    await seedBooking('mine');
    await assertSucceeds(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'mine'), {
        status: 'cancelled',
        cancelledBy: 'customer',
        cancelledAt: new Date(),
      }),
    );
  });

  it('a customer cannot confirm their own booking', async () => {
    // Confirmation is the shop's decision, not the customer's.
    await seedBooking('mine');
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'mine'), { status: 'confirmed' }),
    );
  });

  it('a customer cannot mark their own booking completed', async () => {
    await seedBooking('mine');
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'mine'), { status: 'completed' }),
    );
  });

  it("a customer cannot cancel another customer's booking", async () => {
    await seedBooking('theirs', { customerId: OTHER_CUSTOMER });
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'theirs'), {
        status: 'cancelled',
        cancelledBy: 'customer',
        cancelledAt: new Date(),
      }),
    );
  });

  it('a customer cannot change the price of an existing booking', async () => {
    await seedBooking('mine');
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'mine'), { servicePrice: 1 }),
    );
  });

  it('a customer cannot move an existing booking to a different time', async () => {
    await seedBooking('mine');
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'bookings', 'mine'), {
        startTime: soonPlus(120),
      }),
    );
  });

  it('the shop owner can confirm a booking', async () => {
    await seedBooking('mine');
    await assertSucceeds(
      updateDoc(doc(as(OWNER), 'bookings', 'mine'), { status: 'confirmed' }),
    );
  });

  it('the shop owner can complete a confirmed booking', async () => {
    await seedBooking('mine', { status: 'confirmed' });
    await assertSucceeds(
      updateDoc(doc(as(OWNER), 'bookings', 'mine'), {
        status: 'completed',
        completedAt: new Date(),
      }),
    );
  });

  it("an owner cannot touch a booking at another shop", async () => {
    await seedBooking('elsewhere', { businessId: OTHER_BUSINESS });
    await assertFails(
      updateDoc(doc(as(OWNER), 'bookings', 'elsewhere'), {
        status: 'confirmed',
      }),
    );
  });

  it('a cancelled booking cannot be revived', async () => {
    await seedBooking('dead', { status: 'cancelled', cancelledBy: 'customer' });
    await assertFails(
      updateDoc(doc(as(OWNER), 'bookings', 'dead'), { status: 'confirmed' }),
    );
  });

  it('a completed booking cannot be changed', async () => {
    await seedBooking('done', { status: 'completed' });
    await assertFails(
      updateDoc(doc(as(OWNER), 'bookings', 'done'), { status: 'confirmed' }),
    );
  });

  it('bookings cannot be deleted', async () => {
    await seedBooking('mine');
    await assertFails(deleteDoc(doc(as(CUSTOMER), 'bookings', 'mine')));
    await assertFails(deleteDoc(doc(as(OWNER), 'bookings', 'mine')));
  });
});

describe('slot locks', () => {
  const lockId = `${BUSINESS}_1800000000000`;

  const lockPayload = (overrides = {}) => ({
    bookingId: 'some-booking',
    businessId: BUSINESS,
    customerId: CUSTOMER,
    slotStart: soon(),
    createdAt: new Date(),
    ...overrides,
  });

  it('a customer can claim a free slot', async () => {
    await assertSucceeds(
      setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload()),
    );
  });

  it('a claimed slot cannot be claimed again', async () => {
    // The concurrency guarantee, at the level that actually enforces it:
    // `create` on an existing document fails, so of two racing customers only
    // one write can land.
    await setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload());

    await assertFails(
      setDoc(
        doc(as(OTHER_CUSTOMER), 'slotLocks', lockId),
        lockPayload({ customerId: OTHER_CUSTOMER }),
      ),
    );
  });

  it('a lock cannot be created in another customer’s name', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'slotLocks', lockId),
        lockPayload({ customerId: OTHER_CUSTOMER }),
      ),
    );
  });

  it('a lock cannot be edited to steal a slot', async () => {
    await setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload());
    await assertFails(
      updateDoc(doc(as(OTHER_CUSTOMER), 'slotLocks', lockId), {
        customerId: OTHER_CUSTOMER,
      }),
    );
  });

  it('the claiming customer can release their lock', async () => {
    await setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload());
    await assertSucceeds(deleteDoc(doc(as(CUSTOMER), 'slotLocks', lockId)));
  });

  it('the shop owner can release a lock on their own shop', async () => {
    await setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload());
    await assertSucceeds(deleteDoc(doc(as(OWNER), 'slotLocks', lockId)));
  });

  it('nobody else can release a lock', async () => {
    await setDoc(doc(as(CUSTOMER), 'slotLocks', lockId), lockPayload());
    await assertFails(deleteDoc(doc(as(OTHER_CUSTOMER), 'slotLocks', lockId)));
    await assertFails(deleteDoc(doc(as(OTHER_OWNER), 'slotLocks', lockId)));
  });

  it('locks cannot be listed, which would leak every shop’s schedule', async () => {
    await assertFails(getDocs(collection(as(CUSTOMER), 'slotLocks')));
  });
});

describe('reviews', () => {
  const reviewPayload = (overrides = {}) => ({
    customerId: CUSTOMER,
    businessId: BUSINESS,
    bookingId: 'completed-booking',
    rating: 5,
    comment: 'Excellent work',
    customerName: 'Customer One',
    createdAt: new Date(),
    ...overrides,
  });

  beforeEach(async () => {
    await seedBooking('completed-booking', { status: 'completed' });
    await seedBooking('pending-booking', { status: 'pending' });
    await seedBooking('others-booking', {
      status: 'completed',
      customerId: OTHER_CUSTOMER,
    });
  });

  it('a customer can review their own completed booking', async () => {
    await assertSucceeds(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
        reviewPayload(),
      ),
    );
  });

  it('a review must use the booking-derived document id', async () => {
    // This is what makes a duplicate review a collision rather than a new row.
    await assertFails(
      setDoc(doc(as(CUSTOMER), 'reviews', 'arbitrary-id'), reviewPayload()),
    );
  });

  it('a second review for the same booking collides', async () => {
    await setDoc(
      doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
      reviewPayload(),
    );
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
        reviewPayload({ rating: 1 }),
      ),
    );
  });

  it('cannot review a booking that is not completed', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_pending-booking'),
        reviewPayload({ bookingId: 'pending-booking' }),
      ),
    );
  });

  it("cannot review another customer's booking", async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_others-booking'),
        reviewPayload({ bookingId: 'others-booking' }),
      ),
    );
  });

  it('cannot attribute a review to another customer', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
        reviewPayload({ customerId: OTHER_CUSTOMER }),
      ),
    );
  });

  it('cannot point a review at a different business than the booking', async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
        reviewPayload({ businessId: OTHER_BUSINESS }),
      ),
    );
  });

  it('rejects a rating outside one to five', async () => {
    for (const rating of [0, 6, -1, 100]) {
      await assertFails(
        setDoc(
          doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
          reviewPayload({ rating }),
        ),
      );
    }
  });

  it('a business owner cannot write a review for their own shop', async () => {
    await assertFails(
      setDoc(
        doc(as(OWNER), 'reviews', 'booking_completed-booking'),
        reviewPayload({ customerId: OWNER }),
      ),
    );
  });

  it('a review cannot be edited or deleted once posted', async () => {
    await setDoc(
      doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
      reviewPayload(),
    );
    await assertFails(
      updateDoc(doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'), {
        rating: 1,
      }),
    );
    await assertFails(
      deleteDoc(doc(as(CUSTOMER), 'reviews', 'booking_completed-booking')),
    );
  });

  it('reviews are readable by any signed-in user', async () => {
    await setDoc(
      doc(as(CUSTOMER), 'reviews', 'booking_completed-booking'),
      reviewPayload(),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(as(OTHER_CUSTOMER), 'reviews'),
          where('businessId', '==', BUSINESS),
        ),
      ),
    );
  });
});

describe('device tokens', () => {
  it('a user can register a token against their own account', async () => {
    await assertSucceeds(
      setDoc(doc(as(CUSTOMER), 'users', CUSTOMER, 'deviceTokens', 'token-1'), {
        token: 'token-1',
        platform: 'iOS',
      }),
    );
  });

  it("a user cannot register a token against another account", async () => {
    await assertFails(
      setDoc(
        doc(as(CUSTOMER), 'users', OTHER_CUSTOMER, 'deviceTokens', 'token-x'),
        { token: 'token-x' },
      ),
    );
  });
});

describe('collections with no rules', () => {
  it('an undeclared collection is denied by default', async () => {
    // Nearby ships no catch-all allow, so anything not explicitly matched is
    // closed.
    await assertFails(
      setDoc(doc(as(CUSTOMER), 'someOtherCollection', 'x'), { a: 1 }),
    );
    await assertFails(getDoc(doc(as(CUSTOMER), 'someOtherCollection', 'x')));
  });
});
