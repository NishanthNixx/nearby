# Nearby

Discover and book local services. The first vertical is **tailoring**.

A customer opens the app, allows location, sees registered tailors near them,
picks a service, date and time, and books. A tailor signs in, lists their shop
and services, sets their hours, and manages the appointments that arrive.

---

## Running it

```bash
flutter pub get
flutter run
```

**Firebase is optional to run.** If no Firebase configuration is present the app
falls back to an in-memory backend seeded with six sample tailors — with demo
photography, so the listing screens look like the real thing. Sample
credentials:

| Role     | Email                    | Password      |
|----------|--------------------------|---------------|
| Customer | `customer@example.com`   | `password123` |
| Tailor   | `lakshmi@example.com`    | `password123` |

This is not a mock layer bolted on for demos — it is a second real
implementation of every repository interface, which is what proves those
interfaces carry no Firebase concepts. It is also what the tests run against.

### Connecting a Firebase project

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # writes ios/…/GoogleService-Info.plist etc.

firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions
```

The app switches to Firebase automatically once `Firebase.initializeApp()`
succeeds. Nothing above the data layer changes.

---

## Architecture

```
UI  →  Riverpod controller  →  Repository interface  →  FirebaseXRepository  →  Firebase
```

Firebase is an implementation detail. The rule that keeps it that way: no
widget, controller or domain model imports a Firebase package. Firestore types
(`DocumentSnapshot`, `Timestamp`, `FirebaseException`) stop at the data layer —
mappers convert them to domain models, and `FirebaseErrorMapper` converts
exceptions to `AppFailure`.

Replacing Firebase with REST + PostgreSQL means writing `ApiXRepository`
against the same interfaces and adding a branch in `lib/core/di/providers.dart`.
The UI does not move.

```
lib/
├── core/
│   ├── config/      AppConfig, Firestore collection names
│   ├── data/        Firebase error mapping; the in-memory backend
│   ├── di/          providers.dart — the composition root
│   ├── errors/      AppFailure hierarchy (what the user is actually shown)
│   ├── routing/     GoRouter, role-based redirects
│   ├── theme/       colour, type, spacing tokens
│   ├── utils/       geohash, haversine, formatters
│   └── widgets/     the design system
└── features/
    ├── auth/  discovery/  businesses/  bookings/  reviews/
    ├── profile/  notifications/  owner/  shell/  splash/
    └── each: data/ (mappers, repositories) · domain/ (models, interfaces) · presentation/
```

Domain vocabulary is `Business`, `ServiceOffering`, `Booking`, `Review`,
`BusinessCategory` — not `Tailor*`. The first implementation is tailoring; the
concepts are not tailoring-specific. No abstraction exists for a vertical that
does not exist yet.

---

## Two decisions worth knowing about

### Booking concurrency

Two customers must never get the same slot, and the client's availability list
is only ever a hint. The authority is a Firestore transaction that creates
`slotLocks/{businessId}_{startEpochMs}` documents — `create` only succeeds when
the document does not exist, so of two racing writes exactly one lands.

One lock per *start time* is not enough. With a 30-minute cadence and a
60-minute service, bookings at 9:00 and 9:30 have different start times but
overlap. So an appointment claims a lock for **every cadence slot it spans**,
and the lock IDs are stored on the booking so cancelling releases exactly those.

The transaction also re-reads the business and service, so price and duration
come from stored records rather than the request — and the security rules check
the same thing independently.

### Nearby search

Each business stores `latitude`, `longitude` and a `geohash`. A search computes
the geohash cells covering the requested radius (the centre cell plus its eight
neighbours, at a precision whose cell is at least as large as the radius), runs
one indexed range query per cell, then filters by exact haversine distance.

No geospatial service, no extra dependency, ~150 lines of hand-written geohash.
The `geohash` field is equally meaningful to a future PostgreSQL schema, where
PostGIS would replace it.

---

## Design

The UI is built against Apple's Human Interface Guidelines, adapted for
Flutter/Material 3. The decisions that shaped it:

- **One typeface** — the platform system font. HIG: *minimise the number of
  typefaces*, and *don't embed system fonts*. Identity comes from the type
  ladder, spacing and colour, not a novelty face. It also means scalable text
  and Bold Text work for free. The wordmark is the one exception that does *not*
  scale — a logo is identity, not content.
- **A generated identity per business.** Most local tailors will never upload a
  photo, and without this every listing renders the same grey placeholder — six
  results become six identical rows. It is also the fallback when a photo *fails*
  to load, so offline or a dead URL looks identical to "no photo yet" rather than
  looking broken. Each shop gets a deterministic gradient and
  monogram derived from its id, so it looks the same on every device and a
  customer starts to recognise it. The palette is ten curated hues rather than
  algorithmic HSL, because an algorithmic ramp produces a rainbow and fails
  contrast in the yellow-green band. Generic words are skipped when building the
  monogram, so "Sri Lakshmi Tailors" reads as **LA**.
- **Drawn illustrations** for empty, error and location states, painted with
  `CustomPaint` rather than shipped as assets — they recolour with the theme,
  stay sharp at any size, and add nothing to the bundle. A stock icon in a grey
  circle is what makes an empty state look unfinished, and empty states are
  where someone decides whether the app works.
- **A prices band on each card.** Two cheapest services with prices, so "what
  will this cost" does not require a tap.
- **The nearest open shop gets a larger card** — but only when a location fix
  actually ordered the list, because "closest to you" would otherwise be a claim
  the app cannot support.
- **An 11-step type ladder** mirroring the platform text styles. 17pt body,
  nothing below 11pt (the mobile minimum). No weight lighter than regular.
- **Indigo & Brass on a warm neutral ground.** Two decisions carry the palette.
  The neutrals are *warm* — cool grey reads as utility software, warm ivory reads
  as considered. And the primary is muted: 33% saturation, down from 77%. High
  saturation signals urgency; low saturation signals restraint, and restraint is
  what reads as expensive. Brass appears only as trim — stars, small highlights,
  never a surface. Indigo is not arbitrary here: it is the oldest textile dye
  there is, which makes it the one hue that means something to a tailoring app.
- **Verified contrast.** Four palettes — light, dark, and an increased-contrast
  variant of each. Every foreground/background pair was measured: text roles
  clear 4.5:1 in the standard palettes and 7:1 in the high-contrast ones.
- **Status is never colour alone.** Open/closed, booking state, selection and
  unavailable slots each carry a glyph or a shape change *and* a text label, so
  meaning survives colour blindness and a greyscale screenshot.
- **44pt minimum touch target**, asserted in a widget test rather than assumed.
- **CTAs are inset from the screen edge**, not full-bleed. HIG: *avoid
  full-width buttons*.
- **No in-app appearance switch.** HIG: *avoid offering an app-specific
  appearance setting* — Nearby follows the system.
- **Every async screen has four states.** Loading (a skeleton shaped like the
  result, not a bare spinner), empty, error and success. No screen goes blank.
- **Errors are sentences, not exceptions.** Every failure the user can hit has a
  title, an explanation and a recovery action, chosen from the `AppFailure`
  hierarchy. A raw `FirebaseException` cannot reach the UI.
- **Permission asked when the value is clear.** Notifications are requested
  right after a booking, where "we'll tell you when the tailor confirms" is
  self-evident — not on first launch.

---

## Tests

```bash
flutter test          # 103 tests
```

- **`test/unit/`** — slot generation (the fiddliest logic in the product, and
  pure), geohash encoding and cell adjacency, distance, formatters.
- **`test/integration/`** — auth, discovery and booking flows against the
  in-memory backend, including five simultaneous booking attempts on one slot
  resolving to exactly one winner.
- **`test/widget/`** — the discovery screen reaching each of its four states,
  plus touch-target and 2× text-scale checks.
- **`test/security/`** — Firestore rules, via the emulator.
- **`test/golden/`** — renders the main screens to PNGs for visual review:

  ```bash
  flutter test --update-goldens --run-skipped test/golden
  ```

  Tagged `golden` and **skipped by `flutter test` on purpose.** A golden fails on
  every deliberate visual change, so gating on them turns each design decision
  into a chore and trains people to regenerate without looking. The behavioural
  guarantees live in `test/widget`, which asserts the 44pt touch floor and that
  the layout survives 2× text scaling — and those run every time.

  Reviewing these renders is how five real bugs were found that the behavioural
  tests missed: full-width slot chips, a "Step 0 of 3" label, a clipped avatar,
  an unreadable status pill on dark artwork, and a patch of mine that had
  silently failed to apply.

The contrast guarantees are enforced in code, not just asserted in comments:
`test/unit/identity_palette_test.dart` computes WCAG contrast for every
generated gradient in both appearances and fails if a monogram would be
illegible.

### Security rules

```bash
cd test/security && npm install && npm test
```

Requires a JRE (the Firestore emulator runs on the JVM). **This suite has not
been executed** — the development machine has no Java runtime installed.

The rules themselves enforce: nothing readable while signed out; a user writes
only their own records; role is immutable after creation; ratings are denied to
clients entirely (a Cloud Function owns them); booking price and duration are
validated against the stored service; booking state transitions are restricted
to the permitted ones by the party entitled to make them; and reviews are
one-per-booking by document identity.

---

## Cloud Functions

Three things genuinely cannot be done on the client, and nothing else is there:

1. **Aggregate ratings** — a client that can write its own rating can inflate
   it, so those fields are denied to clients and a function owns them.
2. **Push notifications** — sends need server credentials.
3. **Pruning slot locks** — no user action would ever clear them.

Slot generation, booking validation and state transitions live in the app and
the rules, where they are cheaper to run and easier to test.

---

## Not built

Payments, chat, coupons, loyalty, staff management, multi-currency,
multi-country, recommendations, analytics dashboards, and any second vertical.
The MVP is: a customer finds and books a tailor, and a tailor manages the
appointment.
