import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/entrance.dart';
import '../../../core/widgets/illustrations.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/presentation/business_providers.dart';
import 'business_card.dart';
import 'discovery_controller.dart';

/// The customer's home: tailors near you, searchable and filterable.
///
/// Design guideline — Layout > Visual hierarchy: the most important item sits at
/// the top and leading side. Here that is the location, because it is the
/// premise of everything below it — and the large title scrolls away while the
/// search field stays pinned, so filtering is always one tap from anywhere in
/// the list.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBusiness(String businessId) {
    context.pushNamed(
      AppRoutes.businessProfile,
      pathParameters: {'businessId': businessId},
    );
  }

  Future<void> _handleLocationRecovery(LocationFailure failure) async {
    final controller = ref.read(discoveryControllerProvider.notifier);

    if (failure.canOpenSettings) {
      await controller.openLocationSettings();
    } else {
      await controller.retryLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          color: colors.primary,
          backgroundColor: colors.surface,
          child: CustomScrollView(
            slivers: [
              // --- Wordmark, orientation line, location -------------------
              SliverToBoxAdapter(
                child: _DiscoveryHeader(
                  state: state,
                  onLocationTap: state.locationFailure == null
                      ? null
                      : () => _handleLocationRecovery(state.locationFailure!),
                ),
              ),

              // --- Pinned search + filters --------------------------------
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  // Height is measured from the current text scale rather than
                  // hard-coded, so the header still fits when someone raises
                  // their text size.
                  metrics: _SearchHeaderMetrics.of(context),
                  child: _SearchAndFilters(
                    metrics: _SearchHeaderMetrics.of(context),
                    controller: _searchController,
                    state: state,
                    onSearchChanged: controller.setSearchTerm,
                    onRadiusChanged: controller.setRadius,
                    onOpenNowToggled: controller.toggleOpenNow,
                    onClearSearch: () {
                      _searchController.clear();
                      controller.setSearchTerm('');
                    },
                  ),
                ),
              ),

              // --- Location notice ----------------------------------------
              if (state.locationFailure != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenMargin,
                      AppSpacing.sm,
                      AppSpacing.screenMargin,
                      AppSpacing.xs,
                    ),
                    child: _LocationNotice(
                      failure: state.locationFailure!,
                      onAction: () =>
                          _handleLocationRecovery(state.locationFailure!),
                    ),
                  ),
                ),

              // --- Results -------------------------------------------------
              ..._buildResults(context, state, controller),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResults(
    BuildContext context,
    DiscoveryState state,
    DiscoveryController controller,
  ) {
    final failure = state.failure;
    if (failure != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(failure: failure, onRetry: controller.refresh),
        ),
      ];
    }

    final results = state.results;

    // Nothing yet: skeleton cards shaped like the real ones, so the layout does
    // not jump when they arrive.
    if (results == null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            0,
          ),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, __) => const BusinessCardSkeleton(),
          ),
        ),
      ];
    }

    if (results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: state.isFiltered
              ? EmptyView(
                  illustration: NearbyIllustration.noSearchResults,
                  icon: Icons.search_off_rounded,
                  title: 'No tailors match',
                  message:
                      'Try a different search, widen the distance, or turn off the open-now filter.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _searchController.clear();
                    controller.setSearchTerm('');
                    if (state.openNowOnly) controller.toggleOpenNow();
                  },
                )
              : EmptyView(
                  illustration: state.hasLocation
                      ? NearbyIllustration.noTailorsNearby
                      : NearbyIllustration.locationOff,
                  icon: Icons.storefront_outlined,
                  title: 'No tailors nearby yet',
                  message: state.hasLocation
                      ? 'Nearby has not reached your area yet. Try widening the search distance.'
                      : 'Turn on location to find tailors close to you.',
                  actionLabel:
                      state.radiusKm < AppConfig.searchRadiusOptionsKm.last
                      ? 'Search a wider area'
                      : null,
                  onAction:
                      state.radiusKm < AppConfig.searchRadiusOptionsKm.last
                      ? () => controller.setRadius(
                          AppConfig.searchRadiusOptionsKm.last,
                        )
                      : null,
                ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                // The count as a micro-label in the reference's manner — the
                // SectionHeader uppercases the display itself and keeps the
                // spoken label in natural case.
                child: SectionHeader(
                  title: _resultCountLabel(results.length, state),
                  padding: EdgeInsets.zero,
                ),
              ),
              // A quiet in-place indicator while a filter change reloads, so
              // the existing list stays put instead of being replaced by a
              // spinner.
              if (state.isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: context.colors.labelSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
        ),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final entry = results[index];

            // The first result is the nearest, and only earns the badge when
            // distance actually ordered the list — without a location fix
            // "closest to you" would be a lie.
            final isClosest = index == 0 && state.hasLocation;

            return EntranceTransition(
              index: index,
              child: _ResultTile(
                entry: entry,
                isClosest: isClosest,
                onTap: () => _openBusiness(entry.business.id),
              ),
            );
          },
        ),
      ),
    ];
  }

  static String _resultCountLabel(int count, DiscoveryState state) {
    final noun = count == 1 ? 'tailor' : 'tailors';
    if (!state.hasLocation) return '$count $noun';
    return '$count $noun within ${state.radiusKm.round()} km';
  }
}

/// The pinned search field and filter row.
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.metrics,
    required this.controller,
    required this.state,
    required this.onSearchChanged,
    required this.onRadiusChanged,
    required this.onOpenNowToggled,
    required this.onClearSearch,
  });

  final _SearchHeaderMetrics metrics;
  final TextEditingController controller;
  final DiscoveryState state;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onOpenNowToggled;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
            ),
            child: SizedBox(
              height: metrics.fieldHeight,
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: context.type.body.copyWith(color: colors.label),
                decoration: InputDecoration(
                  // Design guideline — Searching: "Use placeholder text to
                  // indicate what content is searchable."
                  hintText: 'Search tailors or services',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: state.searchTerm.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: AppSizing.iconMd,
                          ),
                          onPressed: onClearSearch,
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: metrics.chipHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              children: [
                _FilterChip(
                  label: 'Open now',
                  icon: Icons.schedule_rounded,
                  isSelected: state.openNowOnly,
                  onTap: onOpenNowToggled,
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final radius in AppConfig.searchRadiusOptionsKm) ...[
                  _FilterChip(
                    label: 'Within ${radius.round()} km',
                    icon: Icons.near_me_rounded,
                    isSelected: state.radiusKm == radius,
                    onTap: () => onRadiusChanged(radius),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: AppSizing.separator, color: colors.separator),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          // No height of its own: the chip fills the row, whose height is
          // measured from the text scale and never falls below the 44pt
          // minimum control size.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Selection inverts to the ground's opposite value — the same rule
            // as the primary button, a selected date cell and a chosen time
            // slot. One rule for "chosen", everywhere.
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isSelected || colors.brightness == Brightness.light
                ? Border.all(
                    color: isSelected ? colors.primary : colors.separator,
                    width: isSelected ? 1.5 : 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                // A selected chip swaps to a filled check as well as changing
                // colour, so selection survives greyscale.
                isSelected ? Icons.check_rounded : icon,
                size: AppSizing.iconSm,
                color: isSelected ? colors.onPrimary : colors.labelSecondary,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: context.type.footnoteEmphasis.copyWith(
                  color: isSelected ? colors.onPrimary : colors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains a missing location without blocking the results below it.
///
/// Design guideline — Privacy: explain why you need access at the moment you
/// ask, and keep working without it where you can.
class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.failure, required this.onAction});

  final LocationFailure failure;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      // Opaque fill plus a full-strength hairline. The alpha wash this
      // replaces composited to #EDE2D2 over the bone ground — 1.15:1, which
      // is no panel at all. The fill alone is only 1.09:1, so the hairline is
      // what makes the shape findable; the ink carries the meaning at 6.53:1.
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: AppSizing.iconMd,
            color: colors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.title,
                  style: context.type.footnoteEmphasis.copyWith(
                    color: colors.label,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  failure.message,
                  style: context.type.footnote.copyWith(
                    color: colors.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onAction,
            child: Text(failure.recovery ?? 'Retry'),
          ),
        ],
      ),
    );
  }
}

/// Height of the pinned header, derived from the current text scale.
///
/// Design guideline — Typography > Supporting scalable text: "Make sure your
/// app's layout adapts to all font sizes." A `SliverPersistentHeader` has to
/// declare its extent before it lays out its child, so the extent is computed
/// from the type metrics rather than assumed — otherwise the header clips its
/// own contents the moment someone raises their text size.
@immutable
class _SearchHeaderMetrics {
  const _SearchHeaderMetrics({
    required this.fieldHeight,
    required this.chipHeight,
  });

  factory _SearchHeaderMetrics.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);

    // One line of body text plus the field's vertical padding.
    final bodyLine =
        scaler.scale(AppTypography.body.fontSize!) * AppTypography.body.height!;
    final fieldHeight = math.max(
      AppSizing.searchFieldHeight,
      bodyLine + AppSpacing.md * 2,
    );

    // One line of footnote text plus padding, floored at the minimum control
    // size so a filter chip stays comfortably tappable.
    final footnoteLine =
        scaler.scale(AppTypography.footnoteEmphasis.fontSize!) *
        AppTypography.footnoteEmphasis.height!;
    final chipHeight = math.max(
      AppSizing.minTouchTarget,
      footnoteLine + AppSpacing.sm * 2 + 4,
    );

    return _SearchHeaderMetrics(
      fieldHeight: fieldHeight,
      chipHeight: chipHeight,
    );
  }

  final double fieldHeight;
  final double chipHeight;

  /// Field, gap, chip row, gap, hairline.
  double get total =>
      fieldHeight +
      AppSpacing.md +
      chipHeight +
      AppSpacing.md +
      AppSizing.separator;

  @override
  bool operator ==(Object other) =>
      other is _SearchHeaderMetrics &&
      other.fieldHeight == fieldHeight &&
      other.chipHeight == chipHeight;

  @override
  int get hashCode => Object.hash(fieldHeight, chipHeight);
}

/// Keeps the search field visible as the list scrolls beneath it.
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchHeaderDelegate({required this.metrics, required this.child});

  final _SearchHeaderMetrics metrics;
  final Widget child;

  @override
  double get minExtent => metrics.total;

  @override
  double get maxExtent => metrics.total;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: metrics.total, child: child);

  @override
  bool shouldRebuild(_SearchHeaderDelegate oldDelegate) =>
      oldDelegate.metrics != metrics || oldDelegate.child != child;
}

/// The screen's masthead: the mark, one warm line of orientation, and the
/// location the results are anchored to.
///
/// Design guideline — Layout > Visual hierarchy: "Place items to convey their
/// relative importance." The location sits directly under the wordmark because
/// it is the premise of every result below — and it is rendered as a filled,
/// tappable pill rather than a line of grey text so it reads as the control it
/// is.
class _DiscoveryHeader extends ConsumerWidget {
  const _DiscoveryHeader({required this.state, this.onLocationTap});

  final DiscoveryState state;
  final VoidCallback? onLocationTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NearbyWordmark(fontSize: 26),
          const SizedBox(height: AppSpacing.xl),

          // Greeting first, at display size — the person, not the product, is
          // the largest thing on the screen. The wordmark above it is a
          // masthead, deliberately smaller.
          Text(
            _greeting(user?.name),
            style: context.type.title1.copyWith(color: colors.label),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            Fmt.fullDate(DateTime.now()),
            style: context.type.subhead.copyWith(color: colors.labelSecondary),
          ),

          const SizedBox(height: AppSpacing.lg),
          _LocationPill(state: state, onTap: onLocationTap),
        ],
      ),
    );
  }

  /// "Hey, Priya 👋" — first name only.
  ///
  /// A full display name would wrap on a narrow screen and reads as a form
  /// field rather than a greeting. Falls back to a nameless greeting rather
  /// than showing an email local-part at display size.
  static String _greeting(String? name) {
    final first = name?.trim().split(RegExp(r'\s+')).first;
    if (first == null || first.isEmpty) return 'Hey there 👋';
    return 'Hey, $first 👋';
  }
}

/// The current location, as a filled pill.
class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.state, this.onTap});

  final DiscoveryState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasProblem = state.locationFailure != null;

    final label = switch (state) {
      _ when hasProblem => 'Location unavailable',
      _ when state.center == null => 'Finding your location…',
      _ => 'Your location',
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isLocating)
          SizedBox(
            width: AppSizing.iconSm,
            height: AppSizing.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: colors.primary,
            ),
          )
        else
          Icon(
            hasProblem ? Icons.location_off_rounded : Icons.place_rounded,
            size: AppSizing.iconMd,
            color: hasProblem ? colors.warning : colors.primary,
          ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.subheadEmphasis.copyWith(color: colors.label),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            hasProblem ? 'Fix' : 'Change',
            style: context.type.footnoteEmphasis.copyWith(
              color: colors.primary,
            ),
          ),
        ],
      ],
    );

    final decorated = Container(
      constraints: const BoxConstraints(minHeight: AppSizing.minTouchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hasProblem ? colors.warningContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // The healthy pill is a tint of primary and needs no outline; the
        // problem pill is a near-ground peach and would vanish without one.
        border: hasProblem ? Border.all(color: colors.warning) : null,
      ),
      child: content,
    );

    if (onTap == null) {
      return Semantics(
        label: 'Location: $label',
        excludeSemantics: true,
        child: decorated,
      );
    }

    return Semantics(
      button: true,
      label: 'Location: $label. ${hasProblem ? 'Fix' : 'Change'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: decorated,
        ),
      ),
    );
  }
}

/// One result, wired to its service prices.
///
/// The prices come from a separate provider rather than the discovery query, so
/// a card renders immediately with its identity and metadata and fills in the
/// price band a moment later — rather than the whole list waiting on N service
/// reads before anything appears.
class _ResultTile extends ConsumerWidget {
  const _ResultTile({
    required this.entry,
    required this.onTap,
    this.isClosest = false,
  });

  final NearbyBusiness entry;
  final VoidCallback onTap;

  /// Whether this is the nearest, distance-ordered result. Every card shares
  /// one layout — the closest merely earns a badge on its imagery, so the
  /// list stays symmetrical.
  final bool isClosest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services =
        ref.watch(businessServicesPreviewProvider(entry.business.id)).value ??
        const [];

    return BusinessCard(
      entry: entry,
      services: services,
      showClosestBadge: isClosest,
      onTap: onTap,
    );
  }
}
