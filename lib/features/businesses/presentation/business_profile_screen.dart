import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/indicators.dart';
import '../../../core/widgets/nearby_card.dart';
import '../../../core/widgets/primary_cta.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/star_rating.dart';
import '../../discovery/presentation/discovery_controller.dart';
import '../../reviews/domain/review.dart';
import '../domain/business.dart';
import '../domain/service_offering.dart';
import 'business_providers.dart';
import 'opening_hours_list.dart';

/// A tailor's full listing, ending in the one action that matters.
///
/// Design guideline — Layout > Visual hierarchy: information is ordered by what
/// a customer needs to decide. Imagery and identity come first and stay put;
/// under them a segmented control holds the three answers that follow — what
/// they can buy, when and where they are, what other customers said. The
/// booking action is pinned so it never scrolls out of reach.
class BusinessProfileScreen extends ConsumerWidget {
  const BusinessProfileScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final businessAsync = ref.watch(businessProvider(businessId));

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: businessAsync.when(
        loading: () => const _ProfileSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(businessProvider(businessId)),
          ),
        ),
        data: (business) {
          if (business == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const ErrorView(failure: NotFoundFailure(what: 'tailor')),
            );
          }
          return _ProfileBody(business: business);
        },
      ),
      bottomNavigationBar: businessAsync.value == null
          ? null
          : _BookingCta(business: businessAsync.value!),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.business});

  final Business business;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  /// The page answers three separate questions — what can I book, when and
  /// where are they, what do others say — and answering all three in one scroll
  /// ran to three screenfuls with the reviews stranded at the bottom.
  /// Segmenting is the reference profile's own move: the identity block stays
  /// put and only the answer beneath it changes.
  static const List<String> _segmentLabels = ['Booking', 'Hours', 'Reviews'];

  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final business = widget.business;
    final servicesAsync = ref.watch(businessServicesProvider(business.id));
    final reviewsAsync = ref.watch(businessReviewsProvider(business.id));

    // Distance is a property of the *viewer*, not the business, so it comes
    // from the discovery state rather than the listing.
    final center = ref.watch(discoveryControllerProvider).center;
    final distanceKm = center == null
        ? null
        : GeoDistance.kmBetween(center, business.location);

    final isOpen = business.isOpenAt(DateTime.now());

    return CustomScrollView(
      slivers: [
        _ProfileHeader(business: business),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.xl,
              AppSpacing.screenMargin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No open-dot here: the trading state lives once, as the
                    // gold OPEN NOW in the metadata line below. Repeating it on
                    // the avatar would double the screen's gold budget for no
                    // new information.
                    BusinessAvatar(
                      businessId: business.id,
                      name: business.name,
                      photoUrl: business.photoUrl,
                      size: 56,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business.name,
                            style: context.type.title2.copyWith(
                              color: colors.label,
                            ),
                          ),
                          if (business.tagline != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              business.tagline!,
                              style: context.type.subhead.copyWith(
                                color: colors.labelSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // One metadata line — reputation, then distance, then trading
                // state — in the reference's "4.9 (120) · 1.2 km · OPEN NOW"
                // manner. Gold discipline: the star and OPEN NOW are the only
                // hue here, so distance stays quiet grey rather than the
                // emphasised primary it used on the old layout. A Wrap, not a
                // Row, so the line flows to a second run at accessibility text
                // sizes instead of clipping.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _dotSeparated(context, [
                    RatingBadge(
                      average: business.ratingAverage,
                      count: business.ratingCount,
                    ),
                    // DistanceLabel hides itself when there is no fix, which
                    // would strand its interpunct — so it is only listed when
                    // it will actually render.
                    if (distanceKm != null)
                      DistanceLabel(distanceKm: distanceKm),
                    StatusPill.openState(isOpen: isOpen, context: context),
                  ]),
                ),
                // The pause and the description belong to the whole listing
                // rather than to one segment, so they stay above the control.
                if (!business.isAcceptingBookings) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const _PausedNotice(),
                ],
                if (business.description != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    business.description!,
                    style: context.type.body.copyWith(
                      color: colors.labelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.xxl,
              AppSpacing.screenMargin,
              0,
            ),
            child: SegmentedPills(
              segments: _segmentLabels,
              selectedIndex: _segment,
              onChanged: (index) => setState(() => _segment = index),
            ),
          ),
        ),

        // No cross-fade between segments: a tap on a segment is a navigation,
        // and the content is a whole screenful — animating it would be motion
        // for its own sake, which is also one less reduce-motion guard to get
        // wrong.
        ...switch (_segment) {
          0 => _bookingSlivers(context, business, servicesAsync),
          1 => _hoursSlivers(context, business, distanceKm),
          _ => _reviewSlivers(context, business, reviewsAsync),
        },

        // Clearance so the pinned action bar never crowds the last row.
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  /// Booking — the services, which is the reason the page was opened, so it is
  /// the segment the page lands on.
  List<Widget> _bookingSlivers(
    BuildContext context,
    Business business,
    AsyncValue<List<ServiceOffering>> servicesAsync,
  ) {
    return [
      const SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Services',
          subtitle: 'Tap a service to start booking',
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: servicesAsync.when(
            loading: () => const _ServicesSkeleton(),
            error: (error, _) => ErrorView(
              failure: toAppFailure(error),
              compact: true,
              onRetry: () =>
                  ref.invalidate(businessServicesProvider(business.id)),
            ),
            data: (services) => services.isEmpty
                ? const _NoServicesNotice()
                : NearbyCardList(
                    children: [
                      for (final service in services)
                        _ServiceRow(
                          service: service,
                          enabled: business.isAcceptingBookings,
                          onTap: () =>
                              _startBooking(context, business.id, service.id),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    ];
  }

  /// Hours and address share a segment: "when" and "where" are the same
  /// question asked twice, and neither fills a screen on its own.
  List<Widget> _hoursSlivers(
    BuildContext context,
    Business business,
    double? distanceKm,
  ) {
    final colors = context.colors;

    return [
      const SliverToBoxAdapter(child: SectionHeader(title: 'Opening hours')),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: NearbyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpeningHoursList(hours: business.openingHours),
                // Space rather than a rule: the slot length is a footnote under
                // the table, not a peer row, and this scheme separates by
                // negative space wherever a hairline is not doing real work.
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Icon(
                      Icons.timelapse_rounded,
                      size: AppSizing.iconSm,
                      color: colors.labelSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Expanded so the sentence wraps at accessibility text
                    // sizes instead of running past the card's edge.
                    Expanded(
                      child: Text(
                        '${business.openingHours.slotDurationMinutes}-minute appointments',
                        style: context.type.footnote.copyWith(
                          color: colors.labelSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: SectionHeader(title: 'Where to find them'),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: NearbyCardList(
            children: [
              _DetailRow(
                icon: Icons.place_rounded,
                label: business.address,
                trailing: distanceKm == null
                    ? null
                    : Fmt.distanceAway(distanceKm),
              ),
              if (business.phone != null)
                _DetailRow(icon: Icons.phone_rounded, label: business.phone!),
            ],
          ),
        ),
      ),
    ];
  }

  /// Reviews. The header keeps the average as its subtitle — the segment label
  /// can only say "Reviews", so the number still needs somewhere to live.
  List<Widget> _reviewSlivers(
    BuildContext context,
    Business business,
    AsyncValue<List<Review>> reviewsAsync,
  ) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Reviews',
          subtitle: business.hasRating
              ? '${Fmt.rating(business.ratingAverage)} average from ${Fmt.reviewCount(business.ratingCount)}'
              : null,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: reviewsAsync.when(
            loading: () => const _ReviewsSkeleton(),
            error: (error, _) => ErrorView(
              failure: toAppFailure(error),
              compact: true,
              onRetry: () =>
                  ref.invalidate(businessReviewsProvider(business.id)),
            ),
            data: (reviews) => reviews.isEmpty
                ? const _NoReviewsNotice()
                : Column(
                    children: [
                      for (final review in reviews) ...[
                        _ReviewCard(review: review),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    ];
  }

  /// Interleaves the metadata items with interpunct separators.
  ///
  /// The dots are pure decoration — the items each carry their own semantics —
  /// so they are hidden from the screen reader rather than announced between
  /// every value.
  ///
  /// Each dot travels with the item *after* it rather than being its own Wrap
  /// child, so when the line breaks at large text sizes the new run starts
  /// "· OPEN NOW" instead of leaving a dangling separator at the end of the
  /// previous one.
  static List<Widget> _dotSeparated(BuildContext context, List<Widget> items) {
    final dot = ExcludeSemantics(
      child: Text(
        '·',
        style: context.type.subhead.copyWith(
          color: context.colors.labelTertiary,
        ),
      ),
    );
    return [
      for (var i = 0; i < items.length; i++)
        if (i == 0)
          items[i]
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              const SizedBox(width: AppSpacing.sm),
              items[i],
            ],
          ),
    ];
  }

  static void _startBooking(
    BuildContext context,
    String businessId,
    String? serviceId,
  ) {
    context.pushNamed(
      AppRoutes.bookingFlow,
      pathParameters: {'businessId': businessId},
      queryParameters: serviceId == null ? {} : {'serviceId': serviceId},
    );
  }
}

/// The media header, with the back button floated over it.
///
/// Design guideline — Layout > Best practices: "Make sure backgrounds and
/// full-screen artwork extend to the edges of the display." The image runs under
/// the status bar; the back button sits inside the safe area with a scrim behind
/// it so it stays legible over any photo.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gallery = [
      if (business.photoUrl != null) business.photoUrl!,
      ...business.galleryUrls,
    ];

    return SliverAppBar(
      // A photograph earns the full height; a generated banner is decoration,
      // and spending 220pt of the first screenful on it pushes the services —
      // the reason the customer opened this page — below the fold.
      expandedHeight: gallery.isEmpty
          ? AppSizing.profileHeaderHeight * 0.62
          : AppSizing.profileHeaderHeight,
      pinned: true,
      backgroundColor: colors.bgBase,
      surfaceTintColor: Colors.transparent,
      leading: const _ScrimmedBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (gallery.isEmpty)
              BusinessBanner(
                businessId: business.id,
                name: business.name,
                photoUrl: null,
              )
            else
              _HeaderGallery(
                urls: gallery,
                businessId: business.id,
                name: business.name,
              ),
            // A scrim under the toolbar so the back button stays legible over
            // any photograph.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header photos, swipeable when there is more than one.
class _HeaderGallery extends StatefulWidget {
  const _HeaderGallery({
    required this.urls,
    required this.businessId,
    required this.name,
  });

  /// Used to build the per-shop identity a page falls back to when its photo
  /// cannot be loaded. Without it, an unreachable gallery leaves the header as
  /// an empty void behind a generic placeholder glyph — which is exactly how a
  /// broken screen looks.
  final String businessId;
  final String name;

  final List<String> urls;

  @override
  State<_HeaderGallery> createState() => _HeaderGalleryState();
}

class _HeaderGalleryState extends State<_HeaderGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;

    final fallback = BusinessBanner(
      businessId: widget.businessId,
      name: widget.name,
    );

    if (urls.length == 1) {
      return RemoteImage(
        url: urls.first,
        radius: 0,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: 'Shop photo',
        fallback: fallback,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: urls.length,
          onPageChanged: (index) => setState(() => _page = index),
          itemBuilder: (context, index) => RemoteImage(
            url: urls[index],
            radius: 0,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: 'Shop photo ${index + 1} of ${urls.length}',
            fallback: fallback,
          ),
        ),
        // Without dots there is nothing to say a second photo exists. Literal
        // white rather than a theme colour, for the same reason as the scrimmed
        // back button: over a photograph nothing is known about the value
        // behind the mark. Hidden from the screen reader — each photo already
        // announces "photo 2 of 3".
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.md,
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs + 1,
                    ),
                    // Unanimated: the swipe the customer just made is the
                    // motion, and a 6pt dot cross-fading adds nothing that
                    // would survive a reduce-motion setting anyway.
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A back button that stays visible over a photograph.
class _ScrimmedBackButton extends StatelessWidget {
  const _ScrimmedBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// One service row: name, optional description, duration and price.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onTap,
    this.enabled = true,
  });

  final ServiceOffering service;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: enabled,
      label:
          '${service.name}, '
          '${service.price == 0 ? 'free' : 'from ${Fmt.price(service.price)}'}, '
          '${Fmt.duration(service.durationMinutes)}'
          '${enabled ? '' : ', unavailable'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: context.type.headline.copyWith(
                        color: enabled ? colors.label : colors.labelTertiary,
                      ),
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        service.description!,
                        style: context.type.footnote.copyWith(
                          color: colors.labelSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs + 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: AppSizing.iconSm - 2,
                          color: colors.labelSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          Fmt.duration(service.durationMinutes),
                          style: context.type.footnote.copyWith(
                            color: colors.labelSecondary,
                            fontFeatures: AppTypography.tabular,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Price and chevron on one trailing line, centred against the
              // whole row: stacked, the chevron read as though it belonged to
              // nothing.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PriceLabel(amount: service.price),
                  if (enabled) ...[
                    const SizedBox(width: AppSpacing.xs),
                    // Secondary, not tertiary: the chevron is the row's only
                    // hint that it navigates, so it must clear the 4.5:1 bar
                    // that labelSecondary guarantees.
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppSizing.iconMd,
                      color: colors.labelSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final value = trailing == null
        ? null
        : Text(
            trailing!,
            style: context.type.footnote.copyWith(
              color: colors.labelSecondary,
              fontFeatures: AppTypography.tabular,
            ),
          );

    final text = Text(
      label,
      style: context.type.subhead.copyWith(color: colors.label),
    );

    // Past about 1.3x the address and the distance can no longer share a line
    // without the address breaking mid-word, so the value drops underneath it.
    //
    // Design guideline — Typography > Best practices: "make sure your app's
    // layout adapts to all font sizes."
    final stacked = value != null && context.type.scale > 1.3;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grey, not primary: in this palette primary means *tappable*, and
          // these rows are plain facts. Monochrome discipline — a supporting
          // glyph is metadata, so it takes the metadata grey.
          Icon(icon, size: AppSizing.iconMd, color: colors.labelSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text,
                      const SizedBox(height: AppSpacing.xs),
                      value,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: text),
                      if (value != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        value,
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return NearbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                initials: _initialsOf(review.customerName),
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  review.customerName ?? 'Nearby customer',
                  style: context.type.subheadEmphasis.copyWith(
                    color: colors.label,
                  ),
                ),
              ),
              // Tertiary: the timestamp is the quietest thing on the card so
              // the name, stars and comment keep the hierarchy.
              Text(
                Fmt.relative(review.createdAt),
                style: context.type.caption.copyWith(
                  color: colors.labelTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StarRatingDisplay(rating: review.rating),
          if (review.comment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: context.type.subhead.copyWith(
                color: colors.labelSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initialsOf(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The pinned booking action.
///
/// Disabled with a reason rather than hidden: a missing button leaves the
/// customer wondering where it went.
class _BookingCta extends ConsumerWidget {
  const _BookingCta({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(businessServicesProvider(business.id)).value;
    final hasServices = services != null && services.isNotEmpty;
    final canBook = business.isAcceptingBookings && hasServices;

    return PrimaryCtaBar(
      label: 'Book appointment',
      icon: Icons.event_available_rounded,
      supportingText: _supportingText(
        isAcceptingBookings: business.isAcceptingBookings,
        servicesLoaded: services != null,
        hasServices: hasServices,
      ),
      onPressed: canBook
          ? () => context.pushNamed(
              AppRoutes.bookingFlow,
              pathParameters: {'businessId': business.id},
            )
          : null,
    );
  }

  /// Says why the button is disabled, rather than leaving the customer to guess.
  static String? _supportingText({
    required bool isAcceptingBookings,
    required bool servicesLoaded,
    required bool hasServices,
  }) {
    if (!isAcceptingBookings) return 'This tailor has paused bookings';
    if (!servicesLoaded) return null;
    if (!hasServices) return 'No services listed yet';
    return 'Choose a service, date and time';
  }
}

class _PausedNotice extends StatelessWidget {
  const _PausedNotice();

  @override
  Widget build(BuildContext context) {
    return const InlineNotice(
      // Info (a monochrome wash), not warning: gold is reserved for ratings,
      // OPEN NOW and the pending-booking badge, and a paused shop is a fact to
      // note, not an alarm. The pause glyph and the copy carry the meaning.
      tone: NoticeTone.info,
      icon: Icons.pause_circle_outline_rounded,
      message:
          'This tailor is not taking appointments at the moment. Their details '
          'are still here for when they reopen.',
    );
  }
}

class _NoServicesNotice extends StatelessWidget {
  const _NoServicesNotice();

  @override
  Widget build(BuildContext context) {
    return const InlineNotice(
      tone: NoticeTone.info,
      message: 'This tailor has not listed their services yet.',
    );
  }
}

class _NoReviewsNotice extends StatelessWidget {
  const _NoReviewsNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return NearbyCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          const Illustration(kind: NearbyIllustration.noReviews, size: 96),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No reviews yet',
            style: context.type.headline.copyWith(color: colors.label),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Be the first to review them after your appointment.',
            textAlign: TextAlign.center,
            style: context.type.footnote.copyWith(color: colors.labelSecondary),
          ),
        ],
      ),
    );
  }
}

// --- Skeletons ---------------------------------------------------------------

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            const Skeleton(height: AppSizing.profileHeaderHeight, radius: 0),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.text(width: 220, fontSize: 28),
                  const SizedBox(height: AppSpacing.md),
                  Skeleton.text(width: 150, fontSize: 17),
                  const SizedBox(height: AppSpacing.xl),
                  // Placeholders mirror the loaded layout — a pill-shaped track
                  // where the segments land, then the services card — so the
                  // page does not rearrange itself under the customer's eye.
                  const Skeleton(
                    height: AppSizing.minTouchTarget + AppSpacing.sm,
                    radius: AppRadius.pill,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _ServicesSkeleton(),
                ],
              ),
            ),
          ],
        ),
        // The way back has to exist while the listing loads too: a slow
        // response must not be a dead end.
        const Positioned(
          top: 0,
          left: 0,
          child: SafeArea(child: _ScrimmedBackButton()),
        ),
      ],
    );
  }
}

class _ServicesSkeleton extends StatelessWidget {
  const _ServicesSkeleton();

  @override
  Widget build(BuildContext context) {
    return NearbyCard(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.text(width: 140, fontSize: 17),
                      const SizedBox(height: AppSpacing.sm),
                      Skeleton.text(width: 70, fontSize: 13),
                    ],
                  ),
                ),
                Skeleton.text(width: 56, fontSize: 17),
              ],
            ),
            if (i != 2) const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          NearbyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton.square(32, radius: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Skeleton.text(width: 100, fontSize: 15),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Skeleton.text(width: double.infinity, fontSize: 15),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
