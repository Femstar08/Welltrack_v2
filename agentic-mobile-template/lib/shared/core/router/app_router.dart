import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth screens
import '../../../features/auth/presentation/login_screen.dart'
    as auth_login;
import '../../../features/auth/presentation/signup_screen.dart'
    as auth_signup;

// Profile & onboarding
import '../../../features/profile/presentation/onboarding/onboarding_flow_screen.dart'
    as profile_onboarding;
import '../../../features/profile/presentation/profile_screen.dart'
    as profile_screen;

// Dashboard & daily view
import '../../../features/dashboard/presentation/dashboard_screen.dart'
    as dashboard_screen;
import '../../../features/daily_view/presentation/daily_view_screen.dart'
    as daily_view;

// Workouts (branch root)
import '../../../features/workouts/presentation/workouts_screen.dart'
    as workouts_screen;

// Freemium
import '../../../features/freemium/data/freemium_repository.dart';
import '../../../features/freemium/domain/plan_tier.dart';
import '../../../features/freemium/presentation/paywall_screen.dart'
    as paywall_screen;

import '../router/route_guards.dart';
import '../router/scaffold_with_bottom_nav.dart';
import '../../../features/auth/presentation/auth_provider.dart'
    show isAuthenticatedProvider;

// Extracted route definitions
import 'routes/dashboard_routes.dart';
import 'routes/workout_routes.dart';

/// Splash screen shown during app initialization
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Auth state provider — reactively tracks whether the user is authenticated.
final authStateProvider = Provider<bool>((ref) {
  return ref.watch(isAuthenticatedProvider);
});

/// Onboarding state provider — placeholder, connect to actual user prefs
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

/// Active profile ID provider — set after login/profile selection
final activeProfileIdProvider = StateProvider<String?>((ref) => null);

/// Active display name provider
final activeDisplayNameProvider = StateProvider<String>((ref) => 'User');

/// Converts a Supabase auth state stream into a [ChangeNotifier] that
/// triggers GoRouter's redirect re-evaluation on auth changes (ARCH-001).
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider exposing the GoRouter instance for use in app.dart and elsewhere.
final goRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.createRouter(ref);
});

/// GoRouter configuration with authentication and onboarding guards
class AppRouter {
  AppRouter._();

  static GoRouter createRouter(Ref ref) {
    final authRefresh = GoRouterAuthRefresh();

    return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      refreshListenable: authRefresh,
      redirect: (context, state) {
        final isAuthenticated = ref.read(authStateProvider);
        final isOnboardingComplete = ref.read(onboardingCompleteProvider);
        final requestedPath = state.matchedLocation;

        // Check all guards
        final guardResult = RouteGuards.checkAll(
          isAuthenticated: isAuthenticated,
          isOnboardingComplete: isOnboardingComplete,
          requestedPath: requestedPath,
        );

        if (!guardResult.canNavigate) {
          return guardResult.redirectTo;
        }

        // Freemium tier check for Pro-only routes (SEC-005)
        const proOnlyPrefixes = ['/insights', '/recovery-detail'];
        final isProRoute = proOnlyPrefixes.any(
          (prefix) => requestedPath.startsWith(prefix),
        );
        if (isProRoute && isAuthenticated) {
          final tier = ref.read(currentPlanTierProvider).valueOrNull;
          if (tier != null && tier != PlanTier.pro) {
            return '/paywall';
          }
        }

        // Handle splash screen redirect based on auth/onboarding state
        if (requestedPath == '/splash') {
          if (!isAuthenticated) {
            return '/login';
          }
          if (!isOnboardingComplete) {
            return '/onboarding';
          }
          return '/';
        }

        // Prevent navigating to dashboard with no profile loaded
        final profileId = ref.read(activeProfileIdProvider);
        final needsProfile = requestedPath == '/' ||
            requestedPath.startsWith('/pantry') ||
            requestedPath.startsWith('/recipes') ||
            requestedPath.startsWith('/shopping') ||
            requestedPath.startsWith('/meals/') ||
            requestedPath.startsWith('/health/') ||
            requestedPath.startsWith('/insights') ||
            requestedPath.startsWith('/goals') ||
            requestedPath.startsWith('/supplements') ||
            requestedPath.startsWith('/workouts') ||
            requestedPath.startsWith('/daily-view') ||
            requestedPath.startsWith('/daily-coach/') ||
            requestedPath == '/bloodwork' ||
            requestedPath.startsWith('/bloodwork/') ||
            requestedPath == '/habits' ||
            requestedPath == '/habits/kegel-timer';
        if (needsProfile &&
            (profileId == null || profileId.isEmpty) &&
            isAuthenticated) {
          return '/onboarding';
        }

        return null;
      },
      routes: [
        // ── Auth & onboarding (outside shell — no bottom nav) ──────
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const _SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const auth_login.LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) => const auth_signup.SignupScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) =>
              const profile_onboarding.OnboardingFlowScreen(),
        ),
        GoRoute(
          path: '/paywall',
          name: 'paywall',
          builder: (context, state) =>
              const paywall_screen.PaywallScreen(),
        ),

        // ── Main shell — persistent bottom nav across 4 tabs ───────
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: [
            // ── Branch 0: Home / Dashboard ────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  name: 'dashboard',
                  builder: (context, state) {
                    final profileId =
                        ref.read(activeProfileIdProvider) ?? '';
                    final displayName =
                        ref.read(activeDisplayNameProvider);
                    return dashboard_screen.DashboardScreen(
                      profileId: profileId,
                      displayName: displayName,
                    );
                  },
                  routes: dashboardChildRoutes(ref),
                ),
              ],
            ),

            // ── Branch 1: Log (Daily View) ────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/daily-view',
                  name: 'dailyView',
                  builder: (context, state) {
                    final profileId =
                        ref.read(activeProfileIdProvider) ?? '';
                    return daily_view.DailyViewScreen(
                        profileId: profileId);
                  },
                ),
              ],
            ),

            // ── Branch 2: Workouts ────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/workouts',
                  name: 'workouts',
                  builder: (context, state) {
                    final profileId =
                        ref.read(activeProfileIdProvider) ?? '';
                    return workouts_screen.WorkoutsScreen(
                      profileId: profileId,
                    );
                  },
                  routes: workoutChildRoutes(ref),
                ),
              ],
            ),

            // ── Branch 3: Profile ─────────────────────────────────
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  name: 'profile',
                  builder: (context, state) =>
                      const profile_screen.ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.matchedLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
