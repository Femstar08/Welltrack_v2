# Health Metric Mapping

This document maps every health metric in WellTrack to its source platforms, data formats, normalization rules, and storage patterns in the `wt_health_metrics` table.

## Table of Contents
- [Overview](#overview)
- [Metric Types](#metric-types)
- [Data Sources](#data-sources)
- [Metric Details](#metric-details)
- [Normalization Rules](#normalization-rules)
- [Deduplication Strategy](#deduplication-strategy)
- [Validation Fields](#validation-fields)

---

## Overview

All health metrics are stored in the `wt_health_metrics` table with the following core structure:

```sql
CREATE TABLE wt_health_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id),
  source wt_health_source NOT NULL,
  metric_type wt_metric_type NOT NULL,
  value_num NUMERIC,
  value_text TEXT,
  unit TEXT,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  raw_payload_json JSONB,
  dedupe_hash TEXT UNIQUE NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  validation_status TEXT DEFAULT 'raw',
  ingestion_source_version TEXT,
  processing_status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Metric Types

Defined in `wt_metric_type` enum:

- `sleep` — Sleep duration and stages
- `stress` — Stress score (0-100)
- `vo2max` — Cardiovascular fitness (mL/kg/min)
- `steps` — Daily step count
- `hr` — Heart rate (bpm)
- `hrv` — Heart rate variability (ms)
- `calories` — Total calories burned (kcal)
- `distance` — Distance traveled (meters/km)
- `active_minutes` — Active/exercise minutes
- `weight` — Body weight (kg/lbs)
- `body_fat` — Body fat percentage
- `blood_pressure` — Systolic/diastolic (mmHg)
- `spo2` — Blood oxygen saturation (%)

---

## Data Sources

Defined in `wt_health_source` enum:

- `healthconnect` — Android Health Connect (Android 14+)
- `healthkit` — Apple HealthKit (iOS)
- `garmin` — Garmin Connect API (OAuth + webhooks)
- `strava` — Strava API (OAuth + webhooks)
- `manual` — User-entered data

---

## Metric Details

### 1. Sleep

**Health Connect (Android)**
- **Type:** `SleepSessionRecord`
- **Fields:**
  - `startTime`, `endTime` — session boundaries
  - `stages` — array of stage records:
    - `awake` — awake during sleep session
    - `sleeping` — general sleep (unspecified)
    - `out_of_bed` — out of bed
    - `light` — light sleep
    - `deep` — deep sleep
    - `rem` — REM sleep
- **Unit:** minutes
- **Availability:** Android 14+ devices with compatible sleep tracking
- **Raw format:** Multiple stage records with timestamps

**HealthKit (iOS)**
- **Type:** `HKCategoryTypeIdentifier.sleepAnalysis`
- **Categories:**
  - `inBed` — in bed but not necessarily asleep
  - `asleepUnspecified` — asleep (no stage detail)
  - `asleepCore` — core/light sleep
  - `asleepDeep` — deep sleep
  - `asleepREM` — REM sleep
  - `awake` — awake during sleep session
- **Unit:** minutes
- **Raw format:** Multiple samples with category + start/end time

**Garmin**
- **Endpoint:** Push webhook `sleeps`
- **Fields:**
  - `sleepLevelsMap` — breakdown by level:
    - `deep` — deep sleep minutes
    - `light` — light sleep minutes
    - `rem` — REM sleep minutes
    - `awake` — awake minutes
  - `sleepStartTimestampGMT`, `sleepEndTimestampGMT`
  - `sleepTimeSeconds` — total sleep duration
  - `deepSleepSeconds`, `lightSleepSeconds`, `remSleepSeconds`, `awakeSleepSeconds`
  - Optional: `avgSpO2Value`, `lowestSpO2Value` (if device supports)
- **Unit:** seconds (convert to minutes)
- **Trigger:** Push on sleep session completion

**Strava**
- Not available

**Normalization:**
- `value_num` = total sleep duration in minutes
- `unit` = "minutes"
- `start_time` = sleep session start
- `end_time` = sleep session end
- `raw_payload_json` = full stage/level breakdown:
  ```json
  {
    "stages": [
      {"type": "deep", "duration_minutes": 90, "start": "...", "end": "..."},
      {"type": "light", "duration_minutes": 180, "start": "...", "end": "..."},
      {"type": "rem", "duration_minutes": 60, "start": "...", "end": "..."},
      {"type": "awake", "duration_minutes": 20, "start": "...", "end": "..."}
    ],
    "total_minutes": 350,
    "spo2_avg": 96,
    "spo2_low": 92
  }
  ```

**Deduplication:**
- Key: `start_time` + `end_time` + `source` + `profile_id`
- Provenance preference: most detailed stages > summary only, then newest `recorded_at`
- Example: Prefer Garmin (deep/light/REM breakdown) over HealthKit (asleepUnspecified) for same period

---

### 2. Stress

**Garmin ONLY**
- **Endpoint:** Push webhook `stressDetails`
- **Fields:**
  - `stressValuesArray` — array of 3-minute stress averages
    - Each entry: `{"startTimeGMT": "...", "endTimeGMT": "...", "stressLevel": 45}`
  - `stressLevel` values:
    - `1-25` — Low stress
    - `26-50` — Medium stress
    - `51-75` — High stress
    - `76-100` — Very high stress
    - `-1` to `-5` — Device could not calculate (insufficient data, not worn, etc.)
  - `bodyBatteryChange` — energy level change
- **Unit:** 0-100 scale (dimensionless)
- **Trigger:** Push at end of day or on demand

**Health Connect, HealthKit, Strava**
- Not available

**Manual Entry**
- User can log subjective stress rating (1-10 scale, converted to 0-100)

**Normalization:**
- `value_num` = daily average of valid stress values (exclude negatives)
- If all values negative → `value_num = NULL`, `value_text = "unavailable"`
- `unit` = "stress_score"
- `start_time` = first valid stress reading of day
- `end_time` = last valid stress reading of day
- `raw_payload_json` = full 3-minute array:
  ```json
  {
    "daily_avg": 42,
    "valid_readings": 320,
    "unavailable_readings": 160,
    "samples": [
      {"time": "2026-02-15T06:00:00Z", "value": 35},
      {"time": "2026-02-15T06:03:00Z", "value": 38},
      ...
    ],
    "body_battery_start": 85,
    "body_battery_end": 42
  }
  ```

**Display Rules:**
- If `value_num IS NULL` → show "Stress data not available from connected source"
- Never show negative stress values in UI
- Color coding: 1-25 green, 26-50 yellow, 51-75 orange, 76-100 red

---

### 3. VO2 Max

**Garmin**
- **Endpoint:** Push webhook `userMetrics`
- **Fields:**
  - `vo2Max` — running VO2 max (mL/kg/min)
  - `vo2MaxCycling` — cycling VO2 max (if available)
- **Unit:** mL/kg/min
- **Trigger:** Push when metric updates (typically after qualifying activity)

**Strava**
- **Endpoint:** Activity detail API or webhook
- **Fields:**
  - `estimated_vo2max` — calculated from activity performance
- **Unit:** mL/kg/min
- **Note:** Estimate only, less accurate than lab/device measurements

**Health Connect (Android)**
- **Type:** `Vo2MaxRecord`
- **Fields:**
  - `vo2MillilitersPerMinuteKilogram` — VO2 max value
  - `measurementMethod` — `MEASUREMENT_METHOD_METABOLIC_CART`, `MEASUREMENT_METHOD_HEART_RATE_RATIO`, `MEASUREMENT_METHOD_COOPER_TEST`, `MEASUREMENT_METHOD_MULTISTAGE_FITNESS_TEST`, `MEASUREMENT_METHOD_ROCKPORT_FITNESS_TEST`, `MEASUREMENT_METHOD_OTHER`
- **Unit:** mL/kg/min
- **Note:** Limited device support; most Android devices rely on Garmin/Strava

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.vo2Max`
- **Fields:**
  - Value in mL/(kg·min)
- **Unit:** mL/kg/min
- **Note:** Requires Apple Watch Series 3+ with specific workouts

**Normalization:**
- `value_num` = VO2 max value
- `unit` = "mL/kg/min"
- `start_time` = measurement time
- `end_time` = measurement time (instantaneous)
- `raw_payload_json`:
  ```json
  {
    "running_vo2max": 52.3,
    "cycling_vo2max": 48.7,
    "measurement_method": "device_calculated",
    "confidence": "high"
  }
  ```

**Source Priority:**
1. Garmin (most accurate, device-based)
2. Strava (activity-based estimate)
3. Health Connect / HealthKit (limited availability)
4. Manual (user-entered from lab test)

**Deduplication:**
- Keep most recent per source
- Flag primary source in `is_primary` field

---

### 4. Steps

**Health Connect (Android)**
- **Type:** `StepsRecord`
- **Fields:**
  - `count` — step count
  - `startTime`, `endTime` — period boundaries
- **Unit:** steps (count)
- **Aggregation:** Sum per day

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.stepCount`
- **Fields:**
  - Value in count
  - `startDate`, `endDate`
- **Unit:** steps (count)
- **Aggregation:** Sum per day

**Garmin**
- **Endpoint:** Push webhook `dailies`
- **Fields:**
  - `steps` — total daily steps
  - `stepGoal` — user's step goal
- **Unit:** steps (count)
- **Trigger:** Push at end of day

**Strava**
- Not typically available (activity-specific distance/pace instead)

**Normalization:**
- `value_num` = total daily steps
- `unit` = "steps"
- `start_time` = 00:00:00 of day (local timezone)
- `end_time` = 23:59:59 of day (local timezone)
- `raw_payload_json`:
  ```json
  {
    "total_steps": 8542,
    "goal": 10000,
    "goal_met": false,
    "source_breakdown": {
      "phone": 3200,
      "watch": 5342
    }
  }
  ```

**Deduplication:**
- Key: `date` + `source` + `profile_id`
- If multiple sources for same day → store all, mark Garmin as primary if available
- Avoid double-counting: don't sum Garmin + Health Connect for same day

---

### 5. Heart Rate (HR)

**Health Connect (Android)**
- **Type:** `HeartRateRecord`
- **Fields:**
  - `beatsPerMinute` — array of samples
  - `time` — timestamp per sample
- **Unit:** bpm
- **Frequency:** Can be continuous or periodic samples

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.heartRate`
- **Fields:**
  - Value in count/min
  - Timestamp
- **Unit:** bpm
- **Frequency:** Continuous or periodic samples

**Garmin**
- **Endpoint:** Push webhook `dailies`
- **Fields:**
  - `restingHeartRateInBeatsPerMinute` — daily resting HR
  - `maxHeartRateInBeatsPerMinute` — max HR for day
  - Optional: `minHeartRateInBeatsPerMinute`
- **Unit:** bpm
- **Trigger:** Push at end of day

**Normalization:**
- **For daily summary:**
  - `value_num` = resting heart rate (most clinically relevant)
  - `unit` = "bpm"
  - `start_time` = 00:00:00 of day
  - `end_time` = 23:59:59 of day
  - `raw_payload_json`:
    ```json
    {
      "resting_hr": 58,
      "min_hr": 52,
      "max_hr": 165,
      "avg_hr": 72,
      "samples_count": 1440
    }
    ```

- **For continuous monitoring (optional, separate records):**
  - Store as time-series in `raw_payload_json`
  - One record per hour with array of samples

**Use Cases:**
- **Insights:** Use resting HR (daily trend)
- **Workout analysis:** Use max HR
- **HRV correlation:** Use resting HR

---

### 6. HRV (Heart Rate Variability)

**Health Connect (Android)**
- **Type:** `HeartRateVariabilityRmssdRecord`
- **Fields:**
  - `heartRateVariabilityMillis` — RMSSD value in milliseconds
  - `time` — measurement timestamp
- **Unit:** ms (milliseconds)

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`
- **Fields:**
  - Value in milliseconds
- **Unit:** ms
- **Method:** SDNN (standard deviation of NN intervals)

**Garmin**
- **Endpoint:** `userMetrics` or embedded in sleep data
- **Fields:**
  - `hrvValue` — HRV measurement
  - May use RMSSD or SDNN depending on device
- **Unit:** ms

**Normalization:**
- `value_num` = HRV value (RMSSD preferred, SDNN acceptable)
- `unit` = "ms"
- `value_text` = method used ("RMSSD" or "SDNN")
- `start_time` = measurement time
- `end_time` = measurement time
- `raw_payload_json`:
  ```json
  {
    "hrv_value": 42.5,
    "method": "RMSSD",
    "measurement_context": "morning_resting",
    "quality": "high"
  }
  ```

**Clinical Note:**
- Higher HRV generally indicates better recovery/fitness
- Morning resting HRV is most reliable
- Use for recovery tracking and training readiness

---

### 7. Calories

**Health Connect (Android)**
- **Type:** `TotalCaloriesBurnedRecord`
- **Fields:**
  - `energy` — total calories (active + BMR)
  - `startTime`, `endTime`
- **Unit:** kilocalories (kcal)

**HealthKit (iOS)**
- **Types:**
  - `HKQuantityTypeIdentifier.activeEnergyBurned` — active calories
  - `HKQuantityTypeIdentifier.basalEnergyBurned` — BMR calories
- **Unit:** kilocalories (kcal)
- **Sum:** active + basal = total

**Garmin**
- **Endpoint:** Push webhook `dailies`
- **Fields:**
  - `activeKilocalories` — calories from activity
  - `bmrKilocalories` — basal metabolic rate calories
  - `totalKilocalories` — sum (may be pre-calculated)
- **Unit:** kcal
- **Trigger:** Push at end of day

**Normalization:**
- `value_num` = total calories (active + BMR)
- `unit` = "kcal"
- `start_time` = 00:00:00 of day
- `end_time` = 23:59:59 of day
- `raw_payload_json`:
  ```json
  {
    "total_kcal": 2450,
    "active_kcal": 750,
    "bmr_kcal": 1700,
    "activity_breakdown": {
      "workout": 450,
      "steps": 200,
      "other": 100
    }
  }
  ```

---

### 8. Distance

**Health Connect (Android)**
- **Type:** `DistanceRecord`
- **Fields:**
  - `distance` — distance in meters
  - `startTime`, `endTime`
- **Unit:** meters

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.distanceWalkingRunning`, `HKQuantityTypeIdentifier.distanceCycling`, etc.
- **Fields:**
  - Value in meters
- **Unit:** meters

**Garmin**
- **Endpoint:** Push webhook `dailies`
- **Fields:**
  - `distanceInMeters` — total distance for day
- **Unit:** meters

**Strava**
- **Endpoint:** Activity webhook
- **Fields:**
  - `distance` — activity distance in meters
- **Unit:** meters

**Normalization:**
- `value_num` = total distance
- `unit` = "meters" (convert to km/miles for display)
- `start_time` = 00:00:00 of day (for daily total) or activity start
- `end_time` = 23:59:59 of day or activity end
- `raw_payload_json`:
  ```json
  {
    "total_meters": 8540,
    "activity_breakdown": [
      {"type": "running", "distance": 5000},
      {"type": "walking", "distance": 3540}
    ]
  }
  ```

---

### 9. Active Minutes

**Health Connect (Android)**
- **Type:** `ExerciseSessionRecord`
- **Fields:**
  - `exerciseType` — type of activity
  - `startTime`, `endTime` — session boundaries
- **Unit:** minutes
- **Calculation:** Sum duration of all exercise sessions

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.appleExerciseTime`
- **Fields:**
  - Value in minutes
- **Unit:** minutes

**Garmin**
- **Endpoint:** Push webhook `dailies`
- **Fields:**
  - `moderateIntensityMinutes` — moderate activity minutes
  - `vigorousIntensityMinutes` — vigorous activity minutes
  - WHO recommendation: 150 min moderate OR 75 min vigorous per week
- **Unit:** minutes

**Normalization:**
- `value_num` = total active minutes (moderate + vigorous)
- `unit` = "minutes"
- `start_time` = 00:00:00 of day
- `end_time` = 23:59:59 of day
- `raw_payload_json`:
  ```json
  {
    "total_minutes": 45,
    "moderate_minutes": 30,
    "vigorous_minutes": 15,
    "weekly_goal": 150,
    "weekly_progress": 210
  }
  ```

---

### 10. Weight

**Health Connect (Android)**
- **Type:** `WeightRecord`
- **Fields:**
  - `weight` — weight value
  - `time` — measurement timestamp
- **Unit:** kilograms (default), pounds (optional)

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.bodyMass`
- **Fields:**
  - Value in kg or lbs
- **Unit:** kilograms (default)

**Garmin**
- **Endpoint:** Push webhook `userMetrics` or manual scale sync
- **Fields:**
  - `weight` — weight in grams (convert to kg)
- **Unit:** grams (Garmin), convert to kg

**Manual Entry**
- User input with unit selection

**Normalization:**
- `value_num` = weight in kilograms
- `unit` = "kg"
- `start_time` = measurement timestamp
- `end_time` = measurement timestamp
- `raw_payload_json`:
  ```json
  {
    "weight_kg": 75.4,
    "weight_lbs": 166.2,
    "trend_7d": -0.3,
    "trend_30d": -1.2,
    "source": "smart_scale"
  }
  ```

**Display:**
- Convert to user's preferred unit (kg or lbs)
- Show trend arrows/graphs

---

### 11. Body Fat Percentage

**Health Connect (Android)**
- **Type:** `BodyFatRecord`
- **Fields:**
  - `percentage` — body fat percentage (0-100)
  - `time` — measurement timestamp
- **Unit:** percentage (%)

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.bodyFatPercentage`
- **Fields:**
  - Value as percentage (0-1, multiply by 100)
- **Unit:** percentage (%)

**Garmin**
- **Endpoint:** Smart scale sync via `userMetrics`
- **Fields:**
  - `bodyFat` — percentage
- **Unit:** percentage (%)

**Normalization:**
- `value_num` = body fat percentage (0-100 scale)
- `unit` = "percent"
- `start_time` = measurement timestamp
- `end_time` = measurement timestamp
- `raw_payload_json`:
  ```json
  {
    "body_fat_percent": 18.5,
    "measurement_method": "bioimpedance",
    "trend_7d": -0.2,
    "category": "athlete"
  }
  ```

---

### 12. Blood Pressure

**Health Connect (Android)**
- **Type:** `BloodPressureRecord`
- **Fields:**
  - `systolic` — systolic pressure
  - `diastolic` — diastolic pressure
  - `bodyPosition` — sitting, standing, lying down
  - `measurementLocation` — left wrist, right wrist, left upper arm, right upper arm
  - `time` — measurement timestamp
- **Unit:** mmHg

**HealthKit (iOS)**
- **Types:**
  - `HKQuantityTypeIdentifier.bloodPressureSystolic` — systolic
  - `HKQuantityTypeIdentifier.bloodPressureDiastolic` — diastolic
- **Unit:** mmHg
- **Note:** Stored as two separate samples with same timestamp (correlate)

**Garmin**
- Limited support (some devices only)
- Manual entry or compatible BP monitor

**Normalization:**
- `value_num` = systolic value
- `value_text` = "systolic/diastolic" (e.g., "120/80")
- `unit` = "mmHg"
- `start_time` = measurement timestamp
- `end_time` = measurement timestamp
- `raw_payload_json`:
  ```json
  {
    "systolic": 120,
    "diastolic": 80,
    "body_position": "sitting",
    "measurement_location": "left_upper_arm",
    "category": "normal"
  }
  ```

**Categories:**
- Normal: < 120/80
- Elevated: 120-129/<80
- High Stage 1: 130-139/80-89
- High Stage 2: ≥140/≥90

---

### 13. SpO2 (Blood Oxygen Saturation)

**Health Connect (Android)**
- **Type:** `OxygenSaturationRecord`
- **Fields:**
  - `percentage` — oxygen saturation (0-100)
  - `time` — measurement timestamp
- **Unit:** percentage (%)

**HealthKit (iOS)**
- **Type:** `HKQuantityTypeIdentifier.oxygenSaturation`
- **Fields:**
  - Value as percentage (0-1, multiply by 100)
- **Unit:** percentage (%)

**Garmin**
- **Endpoint:** Embedded in sleep data or pulse ox readings
- **Fields:**
  - `avgSpO2Value` — average SpO2
  - `lowestSpO2Value` — lowest SpO2 during sleep
- **Unit:** percentage (%)
- **Note:** Requires device with pulse oximeter (e.g., recent watches)

**Normalization:**
- `value_num` = SpO2 percentage (0-100)
- `unit` = "percent"
- `start_time` = measurement start
- `end_time` = measurement end (or same as start for spot check)
- `raw_payload_json`:
  ```json
  {
    "spo2_percent": 96,
    "spo2_min": 92,
    "spo2_max": 98,
    "measurement_type": "continuous_sleep",
    "duration_minutes": 420
  }
  ```

**Clinical Note:**
- Normal: ≥95%
- Low: 90-94% (monitor)
- Critical: <90% (seek medical attention)

---

## Normalization Rules

### General Principles

1. **Single Source of Truth per Source**
   - Each (source, metric_type, time_period) combination = one record
   - Updates from same source replace previous record (using `dedupe_hash`)

2. **Primary Record Selection**
   - One `is_primary = true` record per (profile_id, metric_type, date)
   - Priority order (highest to lowest):
     1. Most detailed/accurate source (e.g., Garmin stress > manual)
     2. Device-measured > estimated > manual
     3. Newest `recorded_at` if same source quality

3. **Unit Standardization**
   - Always store in canonical units (kg not lbs, meters not km, minutes not hours)
   - Convert on ingestion, convert back on display based on user preference

4. **Time Period Alignment**
   - Daily metrics: `start_time` = 00:00:00 local, `end_time` = 23:59:59 local
   - Point measurements: `start_time` = `end_time` = measurement timestamp
   - Sessions (sleep, workout): actual start/end times preserved

5. **Value Storage Strategy**
   - `value_num` = primary numeric value (for aggregation, charts, insights)
   - `value_text` = secondary text value (for composite metrics like "120/80")
   - `raw_payload_json` = full original data (for debugging, detailed views)

6. **Null Handling**
   - `value_num = NULL` when data unavailable (e.g., Garmin stress = -1)
   - Never store negative sentinel values in `value_num`
   - Use `value_text = "unavailable"` or `validation_status = 'rejected'` for clarity

### Source-Specific Rules

#### Health Connect (Android)
- Aggregate multiple records per day into single daily summary
- Preserve individual samples in `raw_payload_json` if needed for detailed analysis
- Time zone: use device local time, convert to UTC for storage

#### HealthKit (iOS)
- Correlate related samples (e.g., systolic + diastolic BP) by timestamp
- Sum totals for additive metrics (steps, calories)
- Average for rate metrics (HR, SpO2)

#### Garmin
- Use `summaryId` to detect updates vs new data
- If `summaryId` matches existing record → update (replace)
- Webhook payload is authoritative (don't re-fetch unless missing data)
- Store `summaryId` in `raw_payload_json.garmin_summary_id`

#### Strava
- Activities are discrete events, not daily aggregates
- Store as individual records with activity start/end times
- Link to `wt_workouts` if user saved activity as workout

#### Manual
- User-entered data always marked `source = 'manual'`
- Require unit selection on entry
- Validate ranges (e.g., HR 30-250 bpm, SpO2 70-100%)

---

## Deduplication Strategy

### Dedupe Hash Calculation

```sql
dedupe_hash = SHA256(
  profile_id || '|' ||
  source || '|' ||
  metric_type || '|' ||
  COALESCE(start_time::TEXT, '') || '|' ||
  COALESCE(end_time::TEXT, '') || '|' ||
  COALESCE(value_num::TEXT, '') || '|' ||
  COALESCE(value_text, '')
)
```

- **Purpose:** Prevent duplicate ingestion of same data point
- **Uniqueness:** Unique constraint on `dedupe_hash` column
- **Conflict handling:** ON CONFLICT DO UPDATE (replace with newer data)

### Garmin-Specific Deduplication

Garmin provides `summaryId` in webhook payloads for daily summaries:

```sql
-- Store summaryId in raw_payload_json
raw_payload_json = {
  ...,
  "garmin_summary_id": "abc123xyz"
}

-- On ingestion, check for existing summaryId
SELECT id FROM wt_health_metrics
WHERE profile_id = $1
  AND source = 'garmin'
  AND metric_type = $2
  AND raw_payload_json->>'garmin_summary_id' = $3;

-- If exists → UPDATE
-- If not → INSERT
```

### Time-Based Deduplication

For metrics from multiple sources covering the same time period:

1. **Check for overlap:**
   ```sql
   SELECT * FROM wt_health_metrics
   WHERE profile_id = $1
     AND metric_type = $2
     AND source != $3
     AND start_time <= $4
     AND end_time >= $5;
   ```

2. **If overlap exists:**
   - Compare source priority (Garmin > Health Connect/HealthKit > Manual)
   - If new source is higher priority → set old record `is_primary = false`, new `is_primary = true`
   - If new source is lower priority → set new record `is_primary = false`
   - Keep both records (don't delete lower priority data)

3. **For insights/aggregations:**
   - Only use `is_primary = true` records
   - Prevents double-counting steps/calories from phone + watch

### Daily Rollup Deduplication

For metrics ingested as continuous streams (HR, steps) that need daily rollup:

```sql
-- Example: Aggregate hourly step records into daily total
INSERT INTO wt_health_metrics (
  profile_id, source, metric_type, value_num, unit,
  start_time, end_time, raw_payload_json, dedupe_hash, is_primary
)
SELECT
  profile_id,
  source,
  metric_type,
  SUM(value_num) as value_num,
  'steps' as unit,
  DATE_TRUNC('day', start_time) as start_time,
  DATE_TRUNC('day', start_time) + INTERVAL '1 day' - INTERVAL '1 second' as end_time,
  jsonb_build_object(
    'hourly_breakdown', jsonb_agg(jsonb_build_object('hour', EXTRACT(HOUR FROM start_time), 'steps', value_num))
  ) as raw_payload_json,
  SHA256(...) as dedupe_hash,
  true as is_primary
FROM wt_health_metrics
WHERE metric_type = 'steps'
  AND validation_status = 'validated'
  AND start_time >= DATE_TRUNC('day', NOW())
  AND start_time < DATE_TRUNC('day', NOW()) + INTERVAL '1 day'
GROUP BY profile_id, source, metric_type, DATE_TRUNC('day', start_time)
ON CONFLICT (dedupe_hash) DO UPDATE
SET value_num = EXCLUDED.value_num,
    raw_payload_json = EXCLUDED.raw_payload_json,
    updated_at = NOW();
```

---

## Validation Fields

Added in Phase 1b to support data quality pipeline:

### validation_status

Type: `TEXT`
Default: `'raw'`
Values:
- `raw` — Newly ingested, not yet validated
- `validated` — Passed validation rules, safe for insights
- `rejected` — Failed validation (out of range, corrupted, etc.)

**Validation Rules by Metric:**

| Metric | Range | Additional Checks |
|--------|-------|-------------------|
| sleep | 0-960 min (16 hrs) | start_time < end_time, stages sum ≤ total |
| stress | 0-100 or NULL | Reject negative values |
| vo2max | 10-90 mL/kg/min | Typical human range |
| steps | 0-100000 | Reject unrealistic spikes |
| hr | 30-250 bpm | Resting 30-100, max 100-250 |
| hrv | 10-200 ms | Typical range |
| calories | 0-10000 kcal/day | Reject extreme values |
| distance | 0-100000 m/day | ~62 miles max reasonable |
| active_minutes | 0-1440 min | Can't exceed 24 hours |
| weight | 20-300 kg | Human range |
| body_fat | 3-60% | Human range |
| blood_pressure | Systolic 70-250, Diastolic 40-150 | Systolic > diastolic |
| spo2 | 70-100% | Below 70% likely sensor error |

### ingestion_source_version

Type: `TEXT`
Default: `NULL`
Purpose: Track API version that produced the data

Examples:
- `garmin_api_v2`
- `healthconnect_v1.1`
- `healthkit_ios17`
- `strava_webhook_v3`

**Use case:** If API changes format, can re-process old data or apply version-specific parsing.

### processing_status

Type: `TEXT`
Default: `'pending'`
Values:
- `pending` — Queued for processing (rollup, insights, ML)
- `processed` — Successfully processed
- `error` — Processing failed (logged in `wt_ai_audit_log`)

**Processing Pipeline:**

```
[Webhook/Sync] → wt_health_metrics (processing_status='pending')
                       ↓
            [Validation Job] → validation_status='validated'|'rejected'
                       ↓
            [Rollup Job] → daily aggregates (if needed)
                       ↓
            [Insights Job] → wt_insights table
                       ↓
            [ML Pipeline] → embeddings, patterns (wt_ai_memory)
                       ↓
            processing_status='processed'
```

**Query Pattern:**

```sql
-- Get unprocessed metrics for daily rollup
SELECT * FROM wt_health_metrics
WHERE processing_status = 'pending'
  AND validation_status = 'validated'
  AND metric_type IN ('steps', 'calories', 'hr', 'distance', 'active_minutes')
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at ASC
LIMIT 1000;
```

---

## Example Queries

### Get Primary Sleep Data for Week

```sql
SELECT
  DATE(start_time) as sleep_date,
  value_num as total_minutes,
  raw_payload_json->'stages' as stages,
  source
FROM wt_health_metrics
WHERE profile_id = 'user-profile-uuid'
  AND metric_type = 'sleep'
  AND is_primary = true
  AND validation_status = 'validated'
  AND start_time >= NOW() - INTERVAL '7 days'
ORDER BY start_time DESC;
```

### Get Stress Trend (Garmin Only)

```sql
SELECT
  DATE(start_time) as date,
  value_num as avg_stress,
  raw_payload_json->>'body_battery_start' as bb_start,
  raw_payload_json->>'body_battery_end' as bb_end
FROM wt_health_metrics
WHERE profile_id = 'user-profile-uuid'
  AND metric_type = 'stress'
  AND source = 'garmin'
  AND validation_status = 'validated'
  AND start_time >= NOW() - INTERVAL '30 days'
ORDER BY start_time ASC;
```

### Compare Steps from Multiple Sources

```sql
SELECT
  DATE(start_time) as date,
  source,
  value_num as steps,
  is_primary
FROM wt_health_metrics
WHERE profile_id = 'user-profile-uuid'
  AND metric_type = 'steps'
  AND validation_status = 'validated'
  AND start_time >= NOW() - INTERVAL '7 days'
ORDER BY date DESC, is_primary DESC, source;
```

### Get Latest VO2 Max from All Sources

```sql
SELECT DISTINCT ON (source)
  source,
  value_num as vo2max,
  start_time as measured_at,
  raw_payload_json->>'measurement_method' as method
FROM wt_health_metrics
WHERE profile_id = 'user-profile-uuid'
  AND metric_type = 'vo2max'
  AND validation_status = 'validated'
ORDER BY source, start_time DESC;
```

---

## Integration Notes

### Webhook Ingestion Flow

1. **Receive webhook** (Garmin, Strava)
2. **Parse payload** into normalized format
3. **Calculate dedupe_hash**
4. **Insert/update** wt_health_metrics (ON CONFLICT)
5. **Set processing_status = 'pending'**
6. **Trigger validation job** (async)
7. **Return 200 OK** to webhook sender (fast response)

### Health Connect / HealthKit Sync Flow

1. **Background job** (every 1-6 hours, configurable)
2. **Query native API** for new data since last sync
3. **Parse records** into normalized format
4. **Batch insert** with dedupe checks
5. **Update last_sync_time** in `wt_health_connections`
6. **Trigger validation job**

### Manual Entry Flow

1. **User inputs value** in UI
2. **Client validates** (range checks, required fields)
3. **API call** to `/api/health-metrics/manual`
4. **Server validation** + insert
5. **Return success** with created record
6. **UI updates** immediately (optimistic + confirmed)

---

## Performance Optimizations

### Indexes

```sql
-- Primary lookups
CREATE INDEX idx_health_metrics_profile_type_time ON wt_health_metrics(profile_id, metric_type, start_time DESC);

-- Primary record queries
CREATE INDEX idx_health_metrics_primary ON wt_health_metrics(profile_id, metric_type, is_primary) WHERE is_primary = true;

-- Processing queue
CREATE INDEX idx_health_metrics_processing ON wt_health_metrics(processing_status, validation_status, created_at) WHERE processing_status = 'pending';

-- Source-specific queries
CREATE INDEX idx_health_metrics_source ON wt_health_metrics(profile_id, source, metric_type, start_time DESC);

-- Dedupe lookups (unique constraint already provides index)
-- CREATE UNIQUE INDEX idx_health_metrics_dedupe ON wt_health_metrics(dedupe_hash);
```

### Partitioning (Future)

For large datasets (1M+ records), partition by time:

```sql
-- Partition by month
CREATE TABLE wt_health_metrics_y2026m02 PARTITION OF wt_health_metrics
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- Automatic partition creation via pg_partman or scheduled job
```

### Archival Strategy

- **Active data:** Last 90 days in main table
- **Archive:** Older data moved to `wt_health_metrics_archive` (cold storage)
- **Aggregates:** Pre-computed monthly summaries in `wt_health_metrics_monthly` for fast trend queries

---

## Troubleshooting

### Duplicate Records

**Symptom:** Multiple records for same metric/time/source

**Diagnosis:**
```sql
SELECT profile_id, source, metric_type, start_time, COUNT(*)
FROM wt_health_metrics
GROUP BY profile_id, source, metric_type, start_time
HAVING COUNT(*) > 1;
```

**Fix:** Re-run deduplication logic, ensure `dedupe_hash` unique constraint is active

### Missing Primary Records

**Symptom:** No `is_primary = true` record for a day

**Diagnosis:**
```sql
SELECT DATE(start_time) as date, metric_type, COUNT(*), SUM(is_primary::int) as primary_count
FROM wt_health_metrics
WHERE profile_id = 'user-uuid'
  AND metric_type = 'steps'
  AND start_time >= NOW() - INTERVAL '7 days'
GROUP BY DATE(start_time), metric_type
HAVING SUM(is_primary::int) = 0;
```

**Fix:** Run primary selection job to re-evaluate source priorities

### Validation Failures

**Symptom:** High rejection rate for specific metric/source

**Diagnosis:**
```sql
SELECT source, metric_type, validation_status, COUNT(*)
FROM wt_health_metrics
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY source, metric_type, validation_status
ORDER BY COUNT(*) DESC;
```

**Fix:** Review validation rules, check for API changes, inspect `raw_payload_json` of rejected records

---

## References

- **Health Connect API:** https://developer.android.com/health-and-fitness/guides/health-connect
- **HealthKit Framework:** https://developer.apple.com/documentation/healthkit
- **Garmin Health API:** https://developer.garmin.com/health-api/overview/
- **Strava API:** https://developers.strava.com/docs/reference/

---

**Document Version:** 1.0
**Last Updated:** 2026-02-15
**Maintainer:** WellTrack Backend Team
