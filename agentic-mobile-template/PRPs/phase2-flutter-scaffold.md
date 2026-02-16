# PRP: Phase 2 — Flutter Scaffold + Auth + Offline Engine

## Project
WellTrack — Performance & Recovery Optimization Engine

## Phase
2 of 12 — App skeleton with auth, offline support, and module system

## Why
The app must exist before any features can be built. This phase creates the foundation that every subsequent phase builds on: project structure, authentication, local storage, offline sync, and the module registry system.

## Strategy
- Flutter Clean Architecture with feature-first organization
- Riverpod for state management
- Isar for encrypted local storage
- Supabase Auth (email/password only for MVP)
- GoRouter for navigation
- Single profile only (dependent profiles in Phase 12)

## Deliverables
1. Flutter project initialized with correct dependencies
2. Clean Architecture folder structure (lib/features/, lib/shared/core/)
3. Supabase Auth integration (sign up, sign in, sign out, session persistence)
4. Encrypted local database (Isar) with models mirroring key wt_ tables
5. Offline sync engine (queue writes, sync on reconnect, conflict resolution)
6. Module registry system (reads wt_profile_modules, renders dashboard tiles)
7. GoRouter navigation with auth guards
8. Theme system (light/dark, typography, colors)
9. Dio HTTP client with interceptors (auth token, retry, offline queue)
10. Error reporting framework (basic logging, ready for Sentry)

## Architecture

### Folder Structure
```
lib/
  app.dart                    # MaterialApp with router + providers
  main.dart                   # Entry point
  features/
    auth/
      data/
        auth_repository.dart
        supabase_auth_source.dart
      domain/
        auth_state.dart
        user_entity.dart
      presentation/
        login_screen.dart
        signup_screen.dart
        auth_provider.dart
    dashboard/
      presentation/
        dashboard_screen.dart
        module_tile_widget.dart
        dashboard_provider.dart
    profile/
      data/
        profile_repository.dart
      domain/
        profile_entity.dart
      presentation/
        profile_screen.dart
        onboarding_screen.dart
        profile_provider.dart
    settings/
      presentation/
        settings_screen.dart
  shared/
    core/
      network/
        dio_client.dart
        api_interceptor.dart
        offline_queue.dart
        connectivity_service.dart
      storage/
        isar_service.dart
        secure_storage_service.dart
      auth/
        supabase_service.dart
        session_manager.dart
      sync/
        sync_engine.dart
        conflict_resolver.dart
      theme/
        app_theme.dart
        app_colors.dart
        app_typography.dart
      router/
        app_router.dart
        route_guards.dart
      modules/
        module_registry.dart
        module_metadata.dart
      logging/
        app_logger.dart
      constants/
        api_constants.dart
        storage_keys.dart
```

## Key Design Decisions
- Riverpod over Bloc: simpler boilerplate, compile-time safety, better for this project scale
- Isar over Hive: better query support, encryption built-in, type-safe
- GoRouter: official Flutter navigation, declarative, supports deep links
- Dio: interceptor chain for auth tokens, retry logic, offline detection
- Single profile first: reduces complexity, dependent profiles layer on top later

## Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  supabase_flutter: ^2.3.0
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  path_provider: ^2.1.0
  flutter_secure_storage: ^9.0.0
  dio: ^5.4.0
  go_router: ^14.0.0
  connectivity_plus: ^6.0.0
  json_annotation: ^4.8.0
  freezed_annotation: ^2.4.0
  uuid: ^4.3.0
  intl: ^0.19.0
  fl_chart: ^0.68.0
  cached_network_image: ^3.3.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  isar_generator: ^3.1.0
  flutter_lints: ^3.0.0
  mockito: ^5.4.0
  flutter_test:
    sdk: flutter
```

## Confidence Score
8/10 — Standard Flutter scaffold with well-known packages. Offline sync adds complexity but is a known pattern.
