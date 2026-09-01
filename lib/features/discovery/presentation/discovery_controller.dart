import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/geo.dart';
import '../../businesses/domain/business.dart';
import '../../businesses/domain/business_repository.dart';

/// Everything the discovery screen renders.
class DiscoveryState {
  const DiscoveryState({
    this.center,
    this.locationFailure,
    this.isLocating = false,
    this.searchTerm = '',
    this.radiusKm = AppConfig.defaultSearchRadiusKm,
    this.openNowOnly = false,
    this.isLoading = false,
    this.failure,
    this.results,
  });

  /// The customer's position, once known.
  final GeoPoint? center;

  /// Why there is no position. Held separately from [failure] because a missing
  /// location degrades the experience without breaking it — results are still
  /// listed, just not sorted by distance.
  final LocationFailure? locationFailure;

  final bool isLocating;

  final String searchTerm;
  final double radiusKm;
  final bool openNowOnly;

  final bool isLoading;

  /// A failure that stopped results from loading at all.
  final AppFailure? failure;

  /// Null means "not loaded yet"; empty means "loaded, nothing matched". The
  /// two need different screens, so they are distinct states.
  final List<NearbyBusiness>? results;

  bool get hasLocation => center != null;
  bool get hasResults => results != null && results!.isNotEmpty;

  /// True when a filter is narrowing the results, which changes the wording of
  /// the empty state from "none nearby" to "none match".
  bool get isFiltered => searchTerm.trim().isNotEmpty || openNowOnly;

  DiscoveryState copyWith({
    GeoPoint? center,
    LocationFailure? locationFailure,
    bool clearLocationFailure = false,
    bool? isLocating,
    String? searchTerm,
    double? radiusKm,
    bool? openNowOnly,
    bool? isLoading,
    AppFailure? failure,
    bool clearFailure = false,
    List<NearbyBusiness>? results,
  }) => DiscoveryState(
    center: center ?? this.center,
    locationFailure: clearLocationFailure
        ? null
        : (locationFailure ?? this.locationFailure),
    isLocating: isLocating ?? this.isLocating,
    searchTerm: searchTerm ?? this.searchTerm,
    radiusKm: radiusKm ?? this.radiusKm,
    openNowOnly: openNowOnly ?? this.openNowOnly,
    isLoading: isLoading ?? this.isLoading,
    failure: clearFailure ? null : (failure ?? this.failure),
    results: results ?? this.results,
  );
}

/// Drives the nearby search.
///
/// Location and results are fetched separately and on purpose: a position
/// arrives in two stages (a cached fix immediately, a fresh one shortly after),
/// and the screen shows results from the first without waiting for the second.
class DiscoveryController extends Notifier<DiscoveryState> {
  Timer? _searchDebounce;

  @override
  DiscoveryState build() {
    ref.onDispose(() => _searchDebounce?.cancel());
    // Kicked off after the first frame so the screen paints its skeleton
    // immediately rather than after the location round trip.
    Future.microtask(initialise);
    return const DiscoveryState(isLocating: true, isLoading: true);
  }

  Future<void> initialise() async {
    final locationService = ref.read(locationServiceProvider);

    // A cached position renders the list at once.
    //
    // Design guideline — Loading: "Show something as soon as possible."
    final cached = await locationService.getLastKnownPosition();
    if (cached != null) {
      state = state.copyWith(center: cached, clearLocationFailure: true);
      await _load();
    }

    // Then a fresh fix, which may move the results.
    try {
      final fresh = await locationService.getCurrentPosition();
      state = state.copyWith(
        center: fresh,
        isLocating: false,
        clearLocationFailure: true,
      );
      await _load();
    } on LocationFailure catch (failure) {
      state = state.copyWith(isLocating: false, locationFailure: failure);
      // Still load: without a position the repository lists by rating instead
      // of distance, which is far better than an empty screen.
      if (cached == null) await _load();
    } catch (error) {
      state = state.copyWith(
        isLocating: false,
        locationFailure: LocationFailure.unavailable(cause: error),
      );
      if (cached == null) await _load();
    }
  }

  /// Re-asks for permission and reloads. Wired to the recovery action on the
  /// location notice.
  Future<void> retryLocation() async {
    state = state.copyWith(isLocating: true, clearLocationFailure: true);
    await initialise();
  }

  Future<void> openLocationSettings() =>
      ref.read(locationServiceProvider).openAppSettings();

  /// Debounced, so typing does not fire a query per keystroke.
  void setSearchTerm(String term) {
    state = state.copyWith(searchTerm: term);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _load());
  }

  Future<void> setRadius(double radiusKm) async {
    state = state.copyWith(radiusKm: radiusKm);
    await _load();
  }

  Future<void> toggleOpenNow() async {
    state = state.copyWith(openNowOnly: !state.openNowOnly);
    await _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    try {
      final results = await ref
          .read(businessRepositoryProvider)
          .findNearby(
            NearbyQuery(
              center: state.center,
              radiusKm: state.radiusKm,
              searchTerm: state.searchTerm,
              openNowOnly: state.openNowOnly,
            ),
          );

      state = state.copyWith(isLoading: false, results: results);
    } catch (error) {
      state = state.copyWith(isLoading: false, failure: toAppFailure(error));
    }
  }
}

final discoveryControllerProvider =
    NotifierProvider<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );
