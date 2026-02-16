import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/shared/core/modules/module_metadata.dart';

void main() {
  group('WellTrackModule', () {
    test('should have correct number of modules', () {
      expect(WellTrackModule.values.length, 9);
    });

    test('should convert to database value', () {
      expect(WellTrackModule.meals.toDatabaseValue(), 'meals');
      expect(WellTrackModule.workouts.toDatabaseValue(), 'workouts');
      expect(WellTrackModule.dailyView.toDatabaseValue(), 'dailyview');
    });

    test('should parse from database value', () {
      expect(
        WellTrackModule.fromDatabaseValue('meals'),
        WellTrackModule.meals,
      );
      expect(
        WellTrackModule.fromDatabaseValue('workouts'),
        WellTrackModule.workouts,
      );
    });

    test('should return null for invalid database value', () {
      expect(WellTrackModule.fromDatabaseValue('invalid'), isNull);
    });

    test('should have accent color for all modules', () {
      for (final module in WellTrackModule.values) {
        final color = module.getAccentColor();
        expect(color.value, isNonZero);
      }
    });

    test('should have display name for all modules', () {
      for (final module in WellTrackModule.values) {
        expect(module.displayName, isNotEmpty);
      }
    });

    test('should have icon for all modules', () {
      for (final module in WellTrackModule.values) {
        expect(module.icon, isNotNull);
      }
    });
  });

  group('ModuleConfig', () {
    test('should create with default values', () {
      final config = ModuleConfig(module: WellTrackModule.meals);
      expect(config.module, WellTrackModule.meals);
      expect(config.enabled, true);
      expect(config.tileOrder, 0);
      expect(config.tileConfig, isEmpty);
    });

    test('should create with custom values', () {
      final config = ModuleConfig(
        module: WellTrackModule.workouts,
        enabled: false,
        tileOrder: 5,
        tileConfig: {'showGraph': true},
      );

      expect(config.module, WellTrackModule.workouts);
      expect(config.enabled, false);
      expect(config.tileOrder, 5);
      expect(config.tileConfig['showGraph'], true);
    });

    test('should copy with updated values', () {
      final original = ModuleConfig(
        module: WellTrackModule.meals,
        enabled: true,
        tileOrder: 2,
      );

      final updated = original.copyWith(enabled: false, tileOrder: 5);

      expect(updated.module, WellTrackModule.meals);
      expect(updated.enabled, false);
      expect(updated.tileOrder, 5);
    });

    test('should convert to JSON', () {
      final config = ModuleConfig(
        module: WellTrackModule.meals,
        enabled: true,
        tileOrder: 3,
        tileConfig: {'test': 'value'},
      );

      final json = config.toJson();

      expect(json['module_name'], 'meals');
      expect(json['enabled'], true);
      expect(json['tile_order'], 3);
      expect(json['tile_config'], {'test': 'value'});
    });

    test('should create from JSON', () {
      final json = {
        'module_name': 'workouts',
        'enabled': false,
        'tile_order': 7,
        'tile_config': {'showStats': true},
      };

      final config = ModuleConfig.fromJson(json);

      expect(config.module, WellTrackModule.workouts);
      expect(config.enabled, false);
      expect(config.tileOrder, 7);
      expect(config.tileConfig['showStats'], true);
    });

    test('should throw error for invalid module name in JSON', () {
      final json = {
        'module_name': 'invalid_module',
        'enabled': true,
        'tile_order': 0,
      };

      expect(() => ModuleConfig.fromJson(json), throwsArgumentError);
    });

    test('should use default values for missing JSON fields', () {
      final json = {
        'module_name': 'meals',
      };

      final config = ModuleConfig.fromJson(json);

      expect(config.module, WellTrackModule.meals);
      expect(config.enabled, true);
      expect(config.tileOrder, 0);
      expect(config.tileConfig, isEmpty);
    });

    test('should implement equality correctly', () {
      final config1 = ModuleConfig(
        module: WellTrackModule.meals,
        enabled: true,
        tileOrder: 2,
      );

      final config2 = ModuleConfig(
        module: WellTrackModule.meals,
        enabled: true,
        tileOrder: 2,
      );

      final config3 = ModuleConfig(
        module: WellTrackModule.meals,
        enabled: false,
        tileOrder: 2,
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });
}
