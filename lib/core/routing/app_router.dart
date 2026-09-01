import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/bookings/presentation/booking_flow_screen.dart';
import '../../features/bookings/presentation/customer_bookings_screen.dart';
import '../../features/businesses/presentation/business_profile_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/owner/presentation/owner_bookings_screen.dart';
import '../../features/owner/presentation/owner_business_setup_screen.dart';
import '../../features/owner/presentation/owner_hours_screen.dart';
import '../../features/owner/presentation/owner_profile_screen.dart';
import '../../features/owner/presentation/owner_services_screen.dart';
import '../../features/owner/presentation/owner_shell.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/write_review_screen.dart';
import '../../features/shell/customer_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../di/providers.dart';

/// Route names, so navigation calls never embed path strings.
abstract final class AppRoutes {
  static const String splash = 'splash';
  static const String signIn = 'signIn';
  static const String signUp = 'signUp';

  // Customer
  static const String discover = 'discover';
  static const String businessProfile = 'businessProfile';
  static const String bookingFlow = 'bookingFlow';
  static const String bookings = 'bookings';
  static const String writeReview = 'writeReview';
  static const String profile = 'profile';

  // Owner
  static const String ownerSetup = 'ownerSetup';
  static const String ownerBookings = 'ownerBookings';
  static const String ownerServices = 'ownerServices';
  static const String ownerHours = 'ownerHours';
  static const String ownerProfile = 'ownerProfile';
}

final routerProvider = Provider<GoRouter>((ref) {
  // The router re-evaluates redirects whenever auth changes, so signing out
  // anywhere lands on the sign-in screen without manual navigation.
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);

      // Still restoring the session: hold on the splash screen.
      if (auth.isLoading) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final user = auth.value;
      final location = state.matchedLocation;
      final onAuthScreen = location == '/sign-in' || location == '/sign-up';
      final onSplash = location == '/';

      if (user == null) {
        // Signed out: everything except the auth screens redirects to sign-in.
        return onAuthScreen ? null : '/sign-in';
      }

      // Signed in: leaving the splash/auth screens, land on the home for the
      // user's role.
      if (onSplash || onAuthScreen) return _homeFor(user);

      // An owner with no business yet is walked through setup first.
      if (user.needsBusinessSetup && !location.startsWith('/owner/setup')) {
        return '/owner/setup';
      }

      // Role fencing: a customer cannot open owner routes and vice versa.
      final isOwnerRoute = location.startsWith('/owner');
      if (isOwnerRoute && !user.role.isBusinessOwner) return _homeFor(user);
      if (!isOwnerRoute && user.role.isBusinessOwner) return _homeFor(user);

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        name: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),

      // -----------------------------------------------------------------------
      // Customer shell: bottom navigation with three tabs.
      //
      // Design guideline — platform conventions: bottom tab bar is the standard
      // primary navigation pattern on mobile.
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: AppRoutes.discover,
                builder: (context, state) => const DiscoveryScreen(),
                routes: [
                  GoRoute(
                    path: 'business/:businessId',
                    name: AppRoutes.businessProfile,
                    builder: (context, state) => BusinessProfileScreen(
                      businessId: state.pathParameters['businessId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'book',
                        name: AppRoutes.bookingFlow,
                        // The booking flow is a focused, multi-step task, so it
                        // covers the tab bar rather than sitting inside it.
                        //
                        // Design guideline — Modality: "Consider using a
                        // full-screen modal style for... a complex task."
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => BookingFlowScreen(
                          businessId: state.pathParameters['businessId']!,
                          preselectedServiceId:
                              state.uri.queryParameters['serviceId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bookings',
                name: AppRoutes.bookings,
                builder: (context, state) => const CustomerBookingsScreen(),
                routes: [
                  GoRoute(
                    path: 'review/:bookingId',
                    name: AppRoutes.writeReview,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => WriteReviewScreen(
                      bookingId: state.pathParameters['bookingId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Owner routes
      // -----------------------------------------------------------------------
      GoRoute(
        path: '/owner/setup',
        name: AppRoutes.ownerSetup,
        builder: (context, state) => const OwnerBusinessSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OwnerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/bookings',
                name: AppRoutes.ownerBookings,
                builder: (context, state) => const OwnerBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/services',
                name: AppRoutes.ownerServices,
                builder: (context, state) => const OwnerServicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/hours',
                name: AppRoutes.ownerHours,
                builder: (context, state) => const OwnerHoursScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/owner/profile',
                name: AppRoutes.ownerProfile,
                builder: (context, state) => const OwnerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();

String _homeFor(AppUser user) {
  if (user.role.isBusinessOwner) {
    return user.needsBusinessSetup ? '/owner/setup' : '/owner/bookings';
  }
  return '/discover';
}

/// Adapts the auth stream to the [Listenable] GoRouter refreshes on.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _subscription = ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
