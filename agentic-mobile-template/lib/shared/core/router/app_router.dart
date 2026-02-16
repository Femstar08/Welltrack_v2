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

// Settings
import '../../../features/settings/presentation/settings_screen.dart'
    as settings_screen;
import '../../../features/settings/presentation/health_settings_screen.dart'
    as health_settings;

// Pantry & recipes
import '../../../features/pantry/presentation/pantry_screen.dart'
    as pantry_screen;
import '../../../features/recipes/presentation/recipe_suggestions_screen.dart'
    as recipe_suggestions;
import '../../../features/recipes/presentation/recipe_detail_screen.dart'
    as recipe_detail;
import '../../../features/recipes/presentation/url_import_screen.dart'
    as url_import;
import '../../../features/recipes/presentation/ocr_import_screen.dart'
    as ocr_import;

// Meals
import '../../../features/meals/presentation/log_meal_screen.dart'
    as log_meal;

// Health
import '../../../features/health/presentation/health_connection_screen.dart'
    as health_connection;

// Insights
import '../../../features/insights/presentation/insights_dashboard_screen.dart'
    as insights_screen;

// Supplements & workouts
import '../../../features/supplements/presentation/supplements_screen.dart'
    as supplements_screen;
import '../../../features/workouts/presentation/workouts_screen.dart'
    as workouts_screen;

// Reminders
import '../../../features/reminders/presentation/reminders_screen.dart'
    as reminders_screen;

// Freemium
import '../../../features/freemium/presentation/paywall_screen.dart'
    as paywall_screen;

import '../router/route_guards.dart';

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

/// Auth state provider — tracks whether the current Supabase session is valid
final authStateProvider = Provider<bool>((ref) {
  return Supabase.instance.client.auth.currentSession != null;
});

/// Onboarding state provider — placeholder, connect to actual user prefs
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

/// Active profile ID provider — set after login/profile selection
final activeProfileIdProvider = StateProvider<String?>((ref) => null);

/// Active display name provider
final activeDisplayNameProvider = StateProvider<String>((ref) => 'User');

/// GoRouter configuration with authentication and onboarding guards
class AppRouter {
  AppRouter._();

  static GoRouter createRouter(Ref ref) {
    return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
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
            requestedPath == '/daily-view' ||
            requestedPath == '/health/connections' ||
            requestedPath == '/insights' ||
            requestedPath == '/supplements' ||
            requestedPath == '/workouts';
        if (needsProfile &&
            (profileId == null || profileId.isEmpty) &&
            isAuthenticated) {
          // No profile found — redirect to onboarding to create one
          return '/onboarding';
        }

        return null;
      },
      routes: [
        // ── Auth & onboarding ──────────────────────────────
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

        // ── Main app ───────────────────────────────────────
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            final displayName = ref.read(activeDisplayNameProvider);
            return dashboard_screen.DashboardScreen(
              profileId: profileId,
              displayName: displayName,
            );
          },
        ),
        GoRoute(
          path: '/daily-view',
          name: 'dailyView',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            return daily_view.DailyViewScreen(profileId: profileId);
          },
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) =>
              const profile_screen.ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) =>
              const settings_screen.SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/health',
          name: 'healthSettings',
          builder: (context, state) =>
              const health_settings.HealthSettingsScreen(),
        ),

        // ── Pantry & Recipes ───────────────────────────────
        GoRoute(
          path: '/pantry',
          name: 'pantry',
          builder: (context, state) =>
              const pantry_screen.PantryScreen(),
        ),
        GoRoute(
          path: '/recipes/suggestions',
          name: 'recipeSuggestions',
          builder: (context, state) =>
              const recipe_suggestions.RecipeSuggestionsScreen(),
        ),
        GoRoute(
          path: '/recipes/import-url',
          name: 'recipeImportUrl',
          builder: (context, state) =>
              const url_import.UrlImportScreen(),
        ),
        GoRoute(
          path: '/recipes/import-ocr',
          name: 'recipeImportOcr',
          builder: (context, state) =>
              const ocr_import.OcrImportScreen(),
        ),
        GoRoute(
          path: '/recipes/:id',
          name: 'recipeDetail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return recipe_detail.RecipeDetailScreen(recipeId: id);
          },
        ),

        // ── Meals ──────────────────────────────────────────
        GoRoute(
          path: '/meals/log',
          name: 'logMeal',
          builder: (context, state) =>
              const log_meal.LogMealScreen(),
        ),

        // ── Health ─────────────────────────────────────────
        GoRoute(
          path: '/health/connections',
          name: 'healthConnections',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            return health_connection.HealthConnectionScreen(
              profileId: profileId,
            );
          },
        ),

        // ── Insights ───────────────────────────────────────
        GoRoute(
          path: '/insights',
          name: 'insights',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            return insights_screen.InsightsDashboardScreen(
              profileId: profileId,
            );
          },
        ),

        // ── Supplements ────────────────────────────────────
        GoRoute(
          path: '/supplements',
          name: 'supplements',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            return supplements_screen.SupplementsScreen(
              profileId: profileId,
            );
          },
        ),

        // ── Workouts ───────────────────────────────────────
        GoRoute(
          path: '/workouts',
          name: 'workouts',
          builder: (context, state) {
            final profileId = ref.read(activeProfileIdProvider) ?? '';
            return workouts_screen.WorkoutsScreen(
              profileId: profileId,
            );
          },
        ),

        // ── Reminders ──────────────────────────────────────
        GoRoute(
          path: '/reminders',
          name: 'reminders',
          builder: (context, state) =>
              const reminders_screen.RemindersScreen(),
        ),

        // ── Freemium ───────────────────────────────────────
        GoRoute(
          path: '/paywall',
          name: 'paywall',
          builder: (context, state) =>
              const paywall_screen.PaywallScreen(),
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

/// Router provider using Riverpod
final goRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.createRouter(ref);
});
