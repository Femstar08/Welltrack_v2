
/// Route guard result
class RouteGuardResult {

  const RouteGuardResult({
    required this.canNavigate,
    this.redirectTo,
    this.message,
  });

  factory RouteGuardResult.allow() => const RouteGuardResult(canNavigate: true);

  factory RouteGuardResult.deny({String? redirectTo, String? message}) {
    return RouteGuardResult(
      canNavigate: false,
      redirectTo: redirectTo,
      message: message,
    );
  }
  final bool canNavigate;
  final String? redirectTo;
  final String? message;
}

/// Authentication guard
class AuthGuard {
  AuthGuard._();

  /// Check if user is authenticated
  static RouteGuardResult checkAuth({
    required bool isAuthenticated,
    required String requestedPath,
  }) {
    // Public routes that don't require authentication
    const publicRoutes = ['/login', '/signup', '/splash'];

    // If requesting a public route, allow
    if (publicRoutes.contains(requestedPath)) {
      return RouteGuardResult.allow();
    }

    // If not authenticated and requesting protected route, redirect to login
    if (!isAuthenticated) {
      return RouteGuardResult.deny(
        redirectTo: '/login',
        message: 'Please sign in to continue',
      );
    }

    return RouteGuardResult.allow();
  }
}

/// Onboarding guard
class OnboardingGuard {
  OnboardingGuard._();

  /// Check if user has completed onboarding
  static RouteGuardResult checkOnboarding({
    required bool isOnboardingComplete,
    required String requestedPath,
  }) {
    // Routes that skip onboarding check
    const skipOnboardingRoutes = [
      '/login',
      '/signup',
      '/splash',
      '/onboarding',
    ];

    // If requesting a route that skips onboarding, allow
    if (skipOnboardingRoutes.contains(requestedPath)) {
      return RouteGuardResult.allow();
    }

    // If onboarding not complete, redirect to onboarding
    if (!isOnboardingComplete) {
      return RouteGuardResult.deny(
        redirectTo: '/onboarding',
        message: 'Please complete onboarding to continue',
      );
    }

    return RouteGuardResult.allow();
  }
}

/// Combined guard that checks all requirements
class RouteGuards {
  RouteGuards._();

  /// Check all guards for a route
  static RouteGuardResult checkAll({
    required bool isAuthenticated,
    required bool isOnboardingComplete,
    required String requestedPath,
  }) {
    // Check authentication first
    final authResult = AuthGuard.checkAuth(
      isAuthenticated: isAuthenticated,
      requestedPath: requestedPath,
    );

    if (!authResult.canNavigate) {
      return authResult;
    }

    // If authenticated, check onboarding
    final onboardingResult = OnboardingGuard.checkOnboarding(
      isOnboardingComplete: isOnboardingComplete,
      requestedPath: requestedPath,
    );

    if (!onboardingResult.canNavigate) {
      return onboardingResult;
    }

    return RouteGuardResult.allow();
  }
}
