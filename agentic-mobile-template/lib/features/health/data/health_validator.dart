import '../domain/health_metric_entity.dart';

/// Validates health metric values against safe/expected ranges
class HealthValidator {
  /// Validate a health metric and return its validation status
  static ValidationStatus validateMetric(HealthMetricEntity metric) {
    if (metric.valueNum == null) {
      return ValidationStatus.rejected;
    }

    final value = metric.valueNum!;

    switch (metric.metricType) {
      case MetricType.sleep:
        return _validateSleep(value);
      case MetricType.steps:
        return _validateSteps(value);
      case MetricType.hr:
        return _validateHeartRate(value);
      case MetricType.hrv:
        return _validateHRV(value);
      case MetricType.stress:
        return _validateStress(value);
      case MetricType.vo2max:
        return _validateVO2Max(value);
      case MetricType.spo2:
        return _validateSpO2(value);
      case MetricType.weight:
        return _validateWeight(value);
      case MetricType.bodyFat:
        return _validateBodyFat(value);
      case MetricType.calories:
        return _validateCalories(value);
      case MetricType.distance:
        return _validateDistance(value);
      case MetricType.activeMinutes:
        return _validateActiveMinutes(value);
      case MetricType.bloodPressure:
        return _validateBloodPressure(value);
    }
  }

  /// Validate sleep duration (0-1440 minutes = 0-24 hours per session)
  static ValidationStatus _validateSleep(double minutes) {
    if (minutes < 0 || minutes > 1440) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate daily step count (0-100,000 steps)
  static ValidationStatus _validateSteps(double steps) {
    if (steps < 0 || steps > 100000) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate heart rate (30-250 bpm)
  static ValidationStatus _validateHeartRate(double bpm) {
    if (bpm < 30 || bpm > 250) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate HRV (0-300 ms)
  static ValidationStatus _validateHRV(double hrv) {
    if (hrv < 0 || hrv > 300) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate stress score (0-100)
  static ValidationStatus _validateStress(double stress) {
    if (stress < 0 || stress > 100) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate VO2 max (10-90 ml/kg/min)
  static ValidationStatus _validateVO2Max(double vo2max) {
    if (vo2max < 10 || vo2max > 90) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate SpO2 (70-100%)
  static ValidationStatus _validateSpO2(double spo2) {
    if (spo2 < 70 || spo2 > 100) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate weight (20-500 kg)
  static ValidationStatus _validateWeight(double weight) {
    if (weight < 20 || weight > 500) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate body fat percentage (3-70%)
  static ValidationStatus _validateBodyFat(double bodyFat) {
    if (bodyFat < 3 || bodyFat > 70) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate daily calories (0-15000)
  static ValidationStatus _validateCalories(double calories) {
    if (calories < 0 || calories > 15000) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate distance (0-200 km per day)
  static ValidationStatus _validateDistance(double distance) {
    if (distance < 0 || distance > 200000) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate active minutes (0-1440 minutes = 0-24 hours)
  static ValidationStatus _validateActiveMinutes(double minutes) {
    if (minutes < 0 || minutes > 1440) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }

  /// Validate blood pressure (systolic: 50-250, diastolic: 30-150)
  /// Value should be systolic for this validation
  static ValidationStatus _validateBloodPressure(double pressure) {
    if (pressure < 30 || pressure > 250) {
      return ValidationStatus.rejected;
    }
    return ValidationStatus.validated;
  }
}
