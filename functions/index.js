/**
 * Nearby — Cloud Functions.
 *
 * Deliberately small. Only three things genuinely cannot be done on the client:
 *
 *   1. Maintaining a business's aggregate rating. A client that can write its
 *      own rating can inflate it, so the security rules deny those fields to
 *      clients entirely and this owns them instead.
 *   2. Sending push notifications. FCM sends require server credentials.
 *   3. Housekeeping the slot-lock collection, which no user action would clear.
 *
 * Everything else — slot generation, booking validation, state transitions —
 * lives in the app and the security rules, where it is easier to test and
 * cheaper to run.
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');

initializeApp();

const db = getFirestore();

// Keep functions close to the data. Change this to match where the Firestore
// database and the majority of users are.
const REGION = 'asia-south1';

// -----------------------------------------------------------------------------
// 1. Aggregate ratings
// -----------------------------------------------------------------------------

/**
 * Folds a new review into its business's aggregate rating.
 *
 * Incremental rather than a recount: adding one review should not cost a read
 * of every existing review. The transaction is what keeps the counter honest
 * when two reviews land at once.
 */
exports.onReviewCreated = onDocumentCreated(
  { document: 'reviews/{reviewId}', region: REGION },
  async (event) => {
    const review = event.data?.data();
    if (!review) return;

    const { businessId, rating } = review;
    if (!businessId || typeof rating !== 'number') {
      logger.warn('Review missing businessId or rating', { reviewId: event.params.reviewId });
      return;
    }

    const businessRef = db.collection('businesses').doc(businessId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(businessRef);
      if (!snapshot.exists) {
        logger.warn('Review for a business that no longer exists', { businessId });
        return;
      }

      const data = snapshot.data();
      const currentAverage = Number(data.ratingAverage) || 0;
      const currentCount = Number(data.ratingCount) || 0;

      const newCount = currentCount + 1;
      const newAverage = (currentAverage * currentCount + rating) / newCount;

      transaction.update(businessRef, {
        // Rounded to three places: the extra precision is meaningless and it
        // keeps the stored value stable across recalculation.
        ratingAverage: Math.round(newAverage * 1000) / 1000,
        ratingCount: newCount,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    logger.info('Rating updated', { businessId, rating });
  },
);

// -----------------------------------------------------------------------------
// 2. Notifications
// -----------------------------------------------------------------------------

/**
 * Collects a user's registered device tokens.
 */
async function tokensFor(userId) {
  const snapshot = await db
    .collection('users')
    .doc(userId)
    .collection('deviceTokens')
    .get();

  return snapshot.docs.map((doc) => doc.get('token')).filter(Boolean);
}

/**
 * Sends a notification and prunes tokens the device no longer accepts.
 *
 * Stale tokens accumulate every time an app is reinstalled; clearing them on
 * failure keeps later sends from being mostly wasted work.
 */
async function notify(userId, { title, body, data = {} }) {
  const tokens = await tokensFor(userId);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    ),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  const stale = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      stale.push(tokens[index]);
    }
  });

  await Promise.all(
    stale.map((token) =>
      db
        .collection('users')
        .doc(userId)
        .collection('deviceTokens')
        .doc(token)
        .delete()
        .catch(() => {}),
    ),
  );
}

/** The owner of a business, or null. */
async function ownerIdOf(businessId) {
  const snapshot = await db.collection('businesses').doc(businessId).get();
  return snapshot.exists ? snapshot.get('ownerId') : null;
}

function formatWhen(startTime) {
  if (!(startTime instanceof Timestamp)) return 'soon';
  return startTime.toDate().toLocaleString('en-IN', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: 'Asia/Kolkata',
  });
}

/**
 * Tells the tailor a new appointment has been requested.
 *
 * This is the notification the product depends on: a request nobody sees is a
 * customer lost.
 */
exports.onBookingCreated = onDocumentCreated(
  { document: 'bookings/{bookingId}', region: REGION },
  async (event) => {
    const booking = event.data?.data();
    if (!booking) return;

    const ownerId = await ownerIdOf(booking.businessId);
    if (!ownerId) return;

    await notify(ownerId, {
      title: 'New appointment request',
      body: `${booking.customerName || 'A customer'} requested ${booking.serviceName} on ${formatWhen(booking.startTime)}.`,
      data: { type: 'booking_created', bookingId: event.params.bookingId },
    });
  },
);

/**
 * Notifies whichever party did not make the change.
 */
exports.onBookingStatusChanged = onDocumentUpdated(
  { document: 'bookings/{bookingId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only status transitions are worth a push; a note edit is not.
    if (before.status === after.status) return;

    const bookingId = event.params.bookingId;
    const when = formatWhen(after.startTime);

    if (after.status === 'confirmed') {
      await notify(after.customerId, {
        title: 'Appointment confirmed',
        body: `${after.businessName} confirmed your ${after.serviceName} on ${when}.`,
        data: { type: 'booking_confirmed', bookingId },
      });
      return;
    }

    if (after.status === 'cancelled') {
      // The party who cancelled already knows; tell the other one.
      if (after.cancelledBy === 'business') {
        await notify(after.customerId, {
          title: 'Appointment cancelled',
          body: `${after.businessName} had to cancel your ${when} appointment. You can book another time.`,
          data: { type: 'booking_cancelled', bookingId },
        });
      } else {
        const ownerId = await ownerIdOf(after.businessId);
        if (ownerId) {
          await notify(ownerId, {
            title: 'Appointment cancelled',
            body: `${after.customerName || 'A customer'} cancelled their ${when} appointment. The slot is free again.`,
            data: { type: 'booking_cancelled', bookingId },
          });
        }
      }
      return;
    }

    if (after.status === 'completed') {
      await notify(after.customerId, {
        title: 'How did it go?',
        body: `Leave a review for ${after.businessName} to help others nearby.`,
        data: { type: 'booking_completed', bookingId },
      });
    }
  },
);

/**
 * Reminds customers about appointments starting in roughly a day.
 *
 * Runs hourly and looks at a one-hour window 24 hours out, so each appointment
 * is reminded about exactly once without needing per-booking scheduled jobs.
 */
exports.sendAppointmentReminders = onSchedule(
  { schedule: 'every 1 hours', region: REGION, timeZone: 'Asia/Kolkata' },
  async () => {
    const now = Date.now();
    const windowStart = Timestamp.fromMillis(now + 24 * 60 * 60 * 1000);
    const windowEnd = Timestamp.fromMillis(now + 25 * 60 * 60 * 1000);

    const snapshot = await db
      .collection('bookings')
      .where('status', '==', 'confirmed')
      .where('startTime', '>=', windowStart)
      .where('startTime', '<', windowEnd)
      .get();

    logger.info(`Reminding about ${snapshot.size} appointments`);

    await Promise.all(
      snapshot.docs.map(async (doc) => {
        const booking = doc.data();
        await notify(booking.customerId, {
          title: 'Appointment tomorrow',
          body: `${booking.serviceName} at ${booking.businessName}, ${formatWhen(booking.startTime)}.`,
          data: { type: 'booking_reminder', bookingId: doc.id },
        });
      }),
    );
  },
);

// -----------------------------------------------------------------------------
// 3. Housekeeping
// -----------------------------------------------------------------------------

/**
 * Deletes slot locks for appointments long past.
 *
 * A lock is released when a booking is cancelled, but a completed appointment
 * keeps its lock — nothing would ever clear those, and the collection would
 * grow without bound. Locks older than the retention window can never block a
 * new booking, because bookings cannot be made in the past.
 */
exports.pruneSlotLocks = onSchedule(
  { schedule: 'every 24 hours', region: REGION, timeZone: 'Asia/Kolkata' },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);

    let deleted = 0;

    // Batched, so one run cannot exceed the write limit on a large backlog.
    for (let pass = 0; pass < 10; pass += 1) {
      const snapshot = await db
        .collection('slotLocks')
        .where('slotStart', '<', cutoff)
        .limit(400)
        .get();

      if (snapshot.empty) break;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      deleted += snapshot.size;
      if (snapshot.size < 400) break;
    }

    logger.info(`Pruned ${deleted} expired slot locks`);
  },
);
