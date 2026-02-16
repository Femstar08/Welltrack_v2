# Performance Engine Design

**Version**: 1.0
**Last Updated**: 2026-02-15
**Status**: Draft

---

## Overview

The Performance Engine is the **core differentiator** of WellTrack. It provides deterministic, reproducible calculations for recovery scoring, training load analysis, and performance forecasting. All calculations are based on **SQL and mathematical formulas** — AI is used only for narrative generation, never for scoring or predictions.

### Key Principles

1. **Deterministic**: Same inputs → same outputs, always
2. **Transparent**: All formulas documented and auditable
3. **Privacy-first**: Calculations run server-side on user's own data
4. **Science-based**: Formulas grounded in exercise physiology and recovery science
5. **Baseline-calibrated**: Personalized to each user's starting point

---

## 1. Baseline Calibration (14-Day Capture)

### Purpose

Before showing any performance scores or forecasts, we establish a personalized baseline. The first 14 days of data after connecting a health source capture the user's starting point across all key metrics.

### Database Schema

#### Table: `wt_baselines`

```sql
CREATE TABLE wt_baselines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  metric_type TEXT NOT NULL, -- sleep_duration, sleep_quality, resting_hr, hrv, stress_avg, vo2max, daily_steps
  calibration_status TEXT NOT NULL DEFAULT 'pending', -- pending | in_progress | complete
  capture_start_date DATE,
  capture_end_date DATE,
  baseline_value NUMERIC,
  data_points_count INT DEFAULT 0,
  raw_values JSONB, -- array of {date, value} for transparency
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, metric_type)
);

-- RLS policy: users can only see their own baselines
ALTER TABLE wt_baselines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own baselines"
  ON wt_baselines FOR SELECT
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));
```

### Baseline Metrics Tracked

| Metric Type | Source | Unit | Purpose |
|------------|--------|------|---------|
| sleep_duration | Health Connect, HealthKit, Garmin | minutes | Sleep component in recovery score |
| sleep_quality | Garmin (sleep score) | 0-100 | Optional enhancement to sleep scoring |
| resting_hr | Health Connect, HealthKit, Garmin | bpm | HR component in recovery score |
| hrv | Garmin, HealthKit | ms | Future: Advanced recovery indicator |
| stress_avg | Garmin (stress score) | 0-100 | Stress component in recovery score |
| vo2max | Garmin, Strava, Health Connect, HealthKit | mL/kg/min | Cardio fitness forecasting |
| daily_steps | Health Connect, HealthKit, Garmin | steps | Activity baseline |

### Capture Process

#### Trigger
Baseline capture starts automatically when the first health metric data point arrives for a profile.

#### Completion Threshold
- **Duration**: 14 consecutive days
- **Minimum data points**: 10 per metric (allows up to 4 gap days)
- **Status progression**:
  - `pending`: No data received yet
  - `in_progress`: First data point received, capture window active
  - `complete`: 14 days elapsed AND minimum 10 data points collected

#### Baseline Calculation Logic

```sql
-- Run this nightly or on-demand to check baseline completion
WITH metric_summary AS (
  SELECT
    metric_type,
    COUNT(*) as data_points,
    AVG(value_num) as baseline_value,
    MIN(start_time)::date as capture_start,
    MAX(start_time)::date as capture_end,
    ARRAY_AGG(jsonb_build_object('date', start_time::date, 'value', value_num) ORDER BY start_time) as raw_values,
    (MAX(start_time)::date - MIN(start_time)::date) >= 13 as span_complete,
    COUNT(*) >= 10 as points_sufficient
  FROM wt_health_metrics
  WHERE profile_id = $1
    AND metric_type = $2
    AND start_time >= (
      SELECT COALESCE(capture_start_date, MIN(start_time)::date)
      FROM wt_baselines
      WHERE profile_id = $1 AND metric_type = $2
    )
    AND start_time < (
      SELECT COALESCE(capture_start_date, MIN(start_time)::date) + interval '14 days'
      FROM wt_baselines
      WHERE profile_id = $1 AND metric_type = $2
    )
  GROUP BY metric_type
)
UPDATE wt_baselines
SET
  calibration_status = CASE
    WHEN ms.span_complete AND ms.points_sufficient THEN 'complete'
    WHEN ms.data_points > 0 THEN 'in_progress'
    ELSE 'pending'
  END,
  capture_start_date = ms.capture_start,
  capture_end_date = ms.capture_end,
  baseline_value = ms.baseline_value,
  data_points_count = ms.data_points,
  raw_values = ms.raw_values,
  updated_at = NOW()
FROM metric_summary ms
WHERE wt_baselines.profile_id = $1
  AND wt_baselines.metric_type = ms.metric_type;
```

#### UI During Calibration

```
Status: in_progress, 8/14 days collected
Message: "Calibrating your baseline... 8/14 days. We need 14 days of data to establish your personalized baseline and unlock performance forecasts."

Progress bar: 8/14 (57%)
```

#### Post-Calibration

Once `calibration_status = 'complete'`:
- Baseline value is **locked** (not recalculated unless user explicitly resets)
- Recovery scores and forecasts become available
- Dashboard shows "Baseline established" badge

---

## 2. Training Load Formula

### Definition

**Training Load** quantifies the physiological stress imposed by a workout session.

```
Training Load = Duration (minutes) × Intensity Factor
```

### Database Schema

#### Table: `wt_training_loads`

```sql
CREATE TABLE wt_training_loads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  workout_id UUID REFERENCES wt_workouts(id) ON DELETE CASCADE,
  activity_id UUID REFERENCES wt_health_metrics(id) ON DELETE SET NULL, -- from external source
  load_date DATE NOT NULL,
  duration_minutes INT NOT NULL,
  intensity_factor NUMERIC(3,2) NOT NULL, -- 0.50 to 1.50
  training_load NUMERIC(6,1) GENERATED ALWAYS AS (duration_minutes * intensity_factor) STORED,
  avg_hr INT, -- if available
  activity_type TEXT, -- e.g., 'cardio', 'strength', 'yoga'
  hr_zone TEXT, -- e.g., 'zone_3', 'zone_4'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_training_loads_profile_date ON wt_training_loads(profile_id, load_date DESC);

-- RLS
ALTER TABLE wt_training_loads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own training loads"
  ON wt_training_loads FOR SELECT
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));
```

### Intensity Factor Mapping

#### Activity Type-Based Mapping

| Activity Type | Intensity Factor | Notes |
|--------------|-----------------|-------|
| Easy walk | 0.5 | Low impact, conversational pace |
| Yoga / stretching | 0.5 | Flexibility and mobility |
| Light cardio (zone 1-2) | 0.7 | 50-70% max HR, easy breathing |
| Moderate cardio (zone 3) | 1.0 | 70-80% max HR, steady state |
| Hard cardio (zone 4) | 1.3 | 80-90% max HR, threshold |
| Very hard / HIIT (zone 5) | 1.5 | 90-100% max HR, maximal effort |
| Strength (light) | 0.6 | Bodyweight, high reps |
| Strength (moderate) | 0.9 | Free weights, 8-12 reps |
| Strength (heavy) | 1.2 | Powerlifting, 1-5 reps |
| Sports (recreational) | 0.8 | Basketball, soccer, tennis |
| Sports (competitive) | 1.2 | Tournament play, high intensity |

#### Heart Rate-Based Calculation

If average HR during workout is available, calculate intensity factor dynamically:

```sql
-- Calculate intensity factor from HR data
WITH hr_params AS (
  SELECT
    COALESCE(
      (SELECT baseline_value FROM wt_baselines
       WHERE profile_id = $1 AND metric_type = 'resting_hr' AND calibration_status = 'complete'),
      60 -- default if no baseline
    ) as resting_hr,
    (220 - (SELECT EXTRACT(YEAR FROM AGE(date_of_birth)) FROM wt_profiles WHERE id = $1)) as max_hr
)
SELECT
  CASE
    WHEN avg_hr IS NOT NULL AND avg_hr > resting_hr THEN
      -- Heart Rate Reserve method
      LEAST(
        0.5 + (
          (avg_hr - resting_hr)::NUMERIC / NULLIF(max_hr - resting_hr, 0)
        ),
        1.5
      )
    ELSE
      -- Fallback to activity type mapping
      CASE activity_type
        WHEN 'yoga' THEN 0.5
        WHEN 'light_cardio' THEN 0.7
        WHEN 'moderate_cardio' THEN 1.0
        WHEN 'hard_cardio' THEN 1.3
        WHEN 'hiit' THEN 1.5
        WHEN 'strength_light' THEN 0.6
        WHEN 'strength_moderate' THEN 0.9
        WHEN 'strength_heavy' THEN 1.2
        ELSE 1.0 -- default
      END
  END as intensity_factor
FROM wt_workouts
CROSS JOIN hr_params
WHERE id = $workout_id;
```

### 7-Day Rolling Training Load

```sql
-- Calculate weekly training load (acute load)
SELECT
  profile_id,
  SUM(training_load) as weekly_load,
  AVG(training_load) as daily_avg_load,
  COUNT(*) as session_count
FROM wt_training_loads
WHERE profile_id = $1
  AND load_date >= CURRENT_DATE - interval '7 days'
  AND load_date <= CURRENT_DATE
GROUP BY profile_id;
```

### Chronic Training Load (28-Day Average)

```sql
-- Calculate chronic training load (fitness baseline)
SELECT
  profile_id,
  SUM(training_load) / 28.0 as chronic_daily_avg
FROM wt_training_loads
WHERE profile_id = $1
  AND load_date >= CURRENT_DATE - interval '28 days'
  AND load_date <= CURRENT_DATE
GROUP BY profile_id;
```

### Acute-to-Chronic Workload Ratio (ACWR)

```sql
-- Calculate ACWR for overtraining detection
WITH acute AS (
  SELECT SUM(training_load) / 7.0 as acute_daily_avg
  FROM wt_training_loads
  WHERE profile_id = $1
    AND load_date >= CURRENT_DATE - interval '7 days'
),
chronic AS (
  SELECT SUM(training_load) / 28.0 as chronic_daily_avg
  FROM wt_training_loads
  WHERE profile_id = $1
    AND load_date >= CURRENT_DATE - interval '28 days'
)
SELECT
  acute.acute_daily_avg,
  chronic.chronic_daily_avg,
  CASE
    WHEN chronic.chronic_daily_avg > 0 THEN
      acute.acute_daily_avg / chronic.chronic_daily_avg
    ELSE NULL
  END as acwr
FROM acute, chronic;
```

### Overtraining Detection

| ACWR Range | Status | Risk Level | AI Narrative Guidance |
|-----------|--------|-----------|----------------------|
| 0.8 - 1.3 | Optimal | Low | "Your training load is well-balanced. You're building fitness while managing fatigue." |
| 1.3 - 1.5 | Moderate Increase | Medium | "Your training load has increased. Monitor recovery closely over the next few days." |
| > 1.5 | Rapid Increase | High | "Your training load has spiked. Consider reducing intensity or adding rest days to prevent overtraining." |
| < 0.8 | Detraining | Low-Medium | "Your training load has decreased significantly. This might impact fitness if sustained." |

---

## 3. Recovery Score (Composite)

### Formula

The Recovery Score is a weighted composite of four physiological indicators, normalized to a 0-100 scale.

```
Recovery Score = (stress_norm × 0.25) + (sleep_norm × 0.30) + (hr_norm × 0.20) + (load_norm × 0.25)

Where:
  stress_norm = normalized stress component (0-100)
  sleep_norm = normalized sleep component (0-100)
  hr_norm = normalized heart rate component (0-100)
  load_norm = normalized training load component (0-100)
```

### Component Calculations

#### 1. Stress Component (Weight: 0.25)

**Input**: Garmin stress score (0-100, where 100 = maximum stress)

**Normalization**:
```sql
-- Invert stress: low stress = high recovery
stress_norm = 100 - stress_avg

-- If stress unavailable, redistribute weight to other components
IF stress_avg IS NULL THEN
  stress_norm = NULL
  -- Effective weights become: sleep=0.40, hr=0.267, load=0.333
END IF
```

#### 2. Sleep Component (Weight: 0.30)

**Input**: sleep_duration (minutes), optional sleep_quality (0-100)

**Target Range**: 7-9 hours (420-540 minutes)

**Normalization**:
```sql
WITH sleep_data AS (
  SELECT
    value_num as duration_minutes,
    -- Extract quality if available from raw_payload_json
    (raw_payload_json->>'sleepScore')::INT as quality_score
  FROM wt_health_metrics
  WHERE profile_id = $1
    AND metric_type = 'sleep'
    AND start_time::date = CURRENT_DATE - 1 -- previous night
  ORDER BY start_time DESC
  LIMIT 1
),
sleep_score AS (
  SELECT
    CASE
      WHEN duration_minutes >= 420 AND duration_minutes <= 540 THEN 100
      WHEN duration_minutes < 420 THEN (duration_minutes / 420.0) * 100
      ELSE GREATEST(100 - ((duration_minutes - 540) / 60.0 * 10), 60)
    END as duration_score,
    quality_score
  FROM sleep_data
)
SELECT
  CASE
    WHEN quality_score IS NOT NULL THEN
      (duration_score * 0.6) + (quality_score * 0.4)
    ELSE
      duration_score
  END as sleep_norm
FROM sleep_score;
```

**Scoring Breakdown**:
- **420-540 min** (7-9 hrs): 100 points
- **< 420 min**: Linear penalty (e.g., 6 hrs = 85.7, 5 hrs = 71.4)
- **> 540 min**: Slight penalty (e.g., 10 hrs = 90, 11 hrs = 80)
- **Quality blend**: If Garmin sleep score available, 60% duration + 40% quality

#### 3. Heart Rate Component (Weight: 0.20)

**Input**: resting_hr (bpm) from morning measurement

**Baseline Comparison**: Current vs. baseline resting HR

**Normalization**:
```sql
WITH baseline AS (
  SELECT baseline_value as baseline_hr
  FROM wt_baselines
  WHERE profile_id = $1
    AND metric_type = 'resting_hr'
    AND calibration_status = 'complete'
),
current AS (
  SELECT value_num as current_hr
  FROM wt_health_metrics
  WHERE profile_id = $1
    AND metric_type = 'resting_hr'
    AND start_time::date = CURRENT_DATE
  ORDER BY start_time DESC
  LIMIT 1
)
SELECT
  CASE
    WHEN baseline.baseline_hr IS NOT NULL THEN
      -- Baseline-calibrated scoring
      CASE
        WHEN current.current_hr <= baseline.baseline_hr THEN 100
        ELSE GREATEST(
          100 - (((current.current_hr - baseline.baseline_hr) / baseline.baseline_hr) * 500),
          0
        )
      END
    ELSE
      -- Absolute scale fallback (60 bpm = 100, 100 bpm = 0)
      GREATEST(
        ((100 - current.current_hr) / 40.0) * 100,
        0
      )
  END as hr_norm
FROM baseline, current;
```

**Interpretation**:
- **At or below baseline**: 100 points (excellent recovery)
- **+5% above baseline**: ~75 points
- **+10% above baseline**: ~50 points (fatigue indicator)
- **+20% above baseline**: 0 points (severe fatigue)

#### 4. Training Load Component (Weight: 0.25)

**Input**: 7-day rolling load vs. previous 7-day load

**Load Ratio Calculation**:
```sql
WITH current_week AS (
  SELECT SUM(training_load) as current_load
  FROM wt_training_loads
  WHERE profile_id = $1
    AND load_date >= CURRENT_DATE - interval '7 days'
),
previous_week AS (
  SELECT SUM(training_load) as previous_load
  FROM wt_training_loads
  WHERE profile_id = $1
    AND load_date >= CURRENT_DATE - interval '14 days'
    AND load_date < CURRENT_DATE - interval '7 days'
)
SELECT
  CASE
    WHEN previous_week.previous_load > 0 THEN
      current_week.current_load / previous_week.previous_load
    ELSE 1.0 -- no previous data = neutral
  END as load_ratio
FROM current_week, previous_week;
```

**Normalization**:
```sql
load_norm = CASE
  WHEN load_ratio <= 0.8 THEN 100  -- decreasing load = recovering
  WHEN load_ratio <= 1.0 THEN 80   -- stable load
  WHEN load_ratio <= 1.3 THEN 60   -- moderate increase
  WHEN load_ratio <= 1.5 THEN 40   -- significant increase
  ELSE 20                          -- overtraining territory
END
```

### Composite Score Calculation

```sql
-- Full recovery score calculation
WITH components AS (
  SELECT
    -- Stress component
    CASE WHEN stress_avg IS NOT NULL THEN (100 - stress_avg) ELSE NULL END as stress_norm,

    -- Sleep component (from sleep scoring logic above)
    sleep_norm,

    -- HR component (from HR scoring logic above)
    hr_norm,

    -- Load component (from load ratio logic above)
    load_norm
  FROM ... -- joined data sources
),
weighted AS (
  SELECT
    stress_norm,
    sleep_norm,
    hr_norm,
    load_norm,
    -- Count available components
    (CASE WHEN stress_norm IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN sleep_norm IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN hr_norm IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN load_norm IS NOT NULL THEN 1 ELSE 0 END) as available_count
  FROM components
)
SELECT
  CASE
    WHEN available_count = 4 THEN
      -- All components available
      (stress_norm * 0.25) + (sleep_norm * 0.30) + (hr_norm * 0.20) + (load_norm * 0.25)
    WHEN available_count >= 2 THEN
      -- Redistribute weights proportionally
      (COALESCE(stress_norm * 0.25, 0) +
       COALESCE(sleep_norm * 0.30, 0) +
       COALESCE(hr_norm * 0.20, 0) +
       COALESCE(load_norm * 0.25, 0)) /
      (COALESCE(CASE WHEN stress_norm IS NOT NULL THEN 0.25 ELSE 0 END, 0) +
       COALESCE(CASE WHEN sleep_norm IS NOT NULL THEN 0.30 ELSE 0 END, 0) +
       COALESCE(CASE WHEN hr_norm IS NOT NULL THEN 0.20 ELSE 0 END, 0) +
       COALESCE(CASE WHEN load_norm IS NOT NULL THEN 0.25 ELSE 0 END, 0))
    ELSE NULL -- not enough data
  END as recovery_score
FROM weighted;
```

### Recovery Score Interpretation

| Score Range | Label | Color | AI Narrative Tone |
|------------|-------|-------|-------------------|
| 80-100 | Excellent | Green (#10B981) | "Your recovery looks strong. This could be a good day for a challenging workout." |
| 60-79 | Good | Light Green (#84CC16) | "You're recovering well. A moderate session might work well today." |
| 40-59 | Moderate | Yellow (#EAB308) | "Your recovery is moderate. You might consider a lighter session or active recovery." |
| 20-39 | Low | Orange (#F97316) | "Your body may need more recovery time. Consider rest or very light activity." |
| 0-19 | Critical | Red (#EF4444) | "Your recovery indicators suggest prioritizing rest today." |

### Database Storage

#### Table: `wt_recovery_scores`

```sql
CREATE TABLE wt_recovery_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  score_date DATE NOT NULL,
  recovery_score NUMERIC(5,2), -- 0-100
  stress_norm NUMERIC(5,2),
  sleep_norm NUMERIC(5,2),
  hr_norm NUMERIC(5,2),
  load_norm NUMERIC(5,2),
  available_components INT, -- 1-4
  score_label TEXT, -- Excellent, Good, Moderate, Low, Critical
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, score_date)
);

CREATE INDEX idx_recovery_scores_profile_date ON wt_recovery_scores(profile_id, score_date DESC);

-- RLS
ALTER TABLE wt_recovery_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recovery scores"
  ON wt_recovery_scores FOR SELECT
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));
```

---

## 4. Deterministic Forecast (Linear Regression)

### Approach

Performance forecasting uses **simple linear regression** (ordinary least squares) to project future metric values based on historical trends. This is a proven, deterministic method used in sports science.

### Requirements

- **Baseline value**: Established via 14-day calibration
- **Minimum data points**: 4 post-baseline measurements
- **Single metric focus**: One forecast per metric (e.g., VO₂ max)
- **Recalculation frequency**: Weekly or when new data arrives

### Linear Regression Formula

Given data points `(x_i, y_i)` where:
- `x = days_since_baseline`
- `y = metric_value`

**Slope** (rate of change):
```
slope = (n × Σ(x_i × y_i) - Σx_i × Σy_i) / (n × Σ(x_i²) - (Σx_i)²)
```

**Intercept** (starting value):
```
intercept = (Σy_i - slope × Σx_i) / n
```

**Projected days to target**:
```
projected_days = (target_value - intercept) / slope
projected_date = baseline_date + projected_days
```

**Confidence (R² coefficient of determination)**:
```
R² = 1 - (SS_res / SS_tot)

Where:
  SS_res = Σ(y_i - ŷ_i)²  (residual sum of squares)
  SS_tot = Σ(y_i - ȳ)²    (total sum of squares)
  ŷ_i = intercept + slope × x_i  (predicted value)
  ȳ = mean(y)  (mean of observed values)

confidence = R² × 100  (0-100 scale)
```

### SQL Implementation

```sql
-- Calculate linear regression for a single metric
WITH baseline_ref AS (
  SELECT
    baseline_value,
    capture_end_date
  FROM wt_baselines
  WHERE profile_id = $1
    AND metric_type = $2
    AND calibration_status = 'complete'
),
data_points AS (
  SELECT
    EXTRACT(EPOCH FROM (start_time::date - br.capture_end_date)) / 86400.0 as x,
    value_num as y
  FROM wt_health_metrics hm
  CROSS JOIN baseline_ref br
  WHERE hm.profile_id = $1
    AND hm.metric_type = $2
    AND hm.start_time > br.capture_end_date
    AND hm.validation_status = 'validated'
  ORDER BY hm.start_time
),
regression_stats AS (
  SELECT
    COUNT(*) as n,
    SUM(x) as sum_x,
    SUM(y) as sum_y,
    SUM(x * y) as sum_xy,
    SUM(x * x) as sum_xx,
    SUM(y * y) as sum_yy,
    AVG(y) as mean_y
  FROM data_points
),
regression_params AS (
  SELECT
    n,
    mean_y,
    (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_xx - sum_x * sum_x, 0) as slope,
    (sum_y - ((n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_xx - sum_x * sum_x, 0)) * sum_x) / NULLIF(n, 0) as intercept
  FROM regression_stats
),
predictions AS (
  SELECT
    dp.x,
    dp.y,
    rp.intercept + rp.slope * dp.x as y_pred
  FROM data_points dp
  CROSS JOIN regression_params rp
),
r_squared AS (
  SELECT
    1 - (SUM(POWER(y - y_pred, 2)) / NULLIF(SUM(POWER(y - (SELECT mean_y FROM regression_params), 2)), 0)) as r2
  FROM predictions
)
SELECT
  rp.n as data_points,
  rp.slope,
  rp.intercept,
  rs.r2,
  rs.r2 * 100 as confidence_pct,
  CASE
    WHEN rp.slope > 0 AND $target_value > rp.intercept THEN
      br.capture_end_date + INTERVAL '1 day' * (($target_value - rp.intercept) / rp.slope)
    ELSE NULL
  END as projected_date
FROM regression_params rp
CROSS JOIN r_squared rs
CROSS JOIN baseline_ref br
WHERE rp.n >= 4; -- minimum data points requirement
```

### Forecast Rules

#### 1. Insufficient Data
```
IF data_points < 4:
  message = "We need at least 4 measurements after your baseline to generate a forecast. Keep logging!"
  projected_date = NULL
  confidence = NULL
```

#### 2. Negative or Zero Slope (No Progress)
```
IF slope <= 0 AND goal_is_improvement:
  message = "Based on current trends, the target isn't being approached yet. This might indicate a need to adjust your approach."
  projected_date = NULL
  confidence = r2 * 100  -- still show confidence in trend
```

#### 3. Low Confidence
```
IF confidence < 30:
  warning = "Not enough consistent data to project reliably yet. Forecast accuracy will improve with more data."
  show_forecast = true  -- still show, but with warning badge
```

#### 4. High Confidence
```
IF confidence >= 70:
  message = "Strong trend detected. Forecast is highly reliable."
  show_forecast = true
  show_confidence_badge = "High confidence"
```

### Database Storage

#### Table: `wt_goal_forecasts`

```sql
CREATE TABLE wt_goal_forecasts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL REFERENCES wt_profiles(id) ON DELETE CASCADE,
  goal_id UUID REFERENCES wt_goals(id) ON DELETE CASCADE,
  metric_type TEXT NOT NULL,
  baseline_value NUMERIC,
  current_value NUMERIC,
  target_value NUMERIC,
  data_points_count INT,
  slope NUMERIC, -- rate of change per day
  intercept NUMERIC,
  r_squared NUMERIC(5,4), -- 0.0000 to 1.0000
  confidence_pct NUMERIC(5,2), -- 0-100
  projected_date DATE,
  projected_date_lower DATE, -- 95% confidence interval
  projected_date_upper DATE,
  forecast_status TEXT, -- active | insufficient_data | no_progress | stale
  last_calculated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, metric_type)
);

CREATE INDEX idx_goal_forecasts_profile ON wt_goal_forecasts(profile_id);

-- RLS
ALTER TABLE wt_goal_forecasts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own goal forecasts"
  ON wt_goal_forecasts FOR SELECT
  USING (profile_id IN (SELECT id FROM wt_profiles WHERE user_id = auth.uid()));
```

### Recalculation Triggers

1. **Weekly recalculation**: Cron job runs every Monday
2. **On new data**: When new health metric arrives for tracked metric_type
3. **On-demand**: User requests forecast refresh in UI

```sql
-- Scheduled function (Edge Function or pg_cron)
SELECT recalculate_forecasts_for_profile($profile_id);

-- On new health metric insert
CREATE OR REPLACE FUNCTION trigger_forecast_recalc()
RETURNS TRIGGER AS $$
BEGIN
  -- Queue forecast recalculation for this profile + metric
  INSERT INTO wt_forecast_recalc_queue (profile_id, metric_type)
  VALUES (NEW.profile_id, NEW.metric_type)
  ON CONFLICT (profile_id, metric_type) DO UPDATE
  SET queued_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER health_metric_forecast_trigger
AFTER INSERT ON wt_health_metrics
FOR EACH ROW
EXECUTE FUNCTION trigger_forecast_recalc();
```

---

## 5. VO₂ Max Improvement Data Flow

### Source Priority

WellTrack ingests VO₂ max from multiple sources with the following priority:

1. **Garmin** (primary): `userMetrics` push webhook → `vo2Max` field
2. **Strava**: Activity-level VO₂ max estimates
3. **Health Connect** (Android): `Vo2MaxRecord`
4. **HealthKit** (iOS): `HKQuantityTypeIdentifier.vo2Max`

### Normalization

All sources normalized to: **mL/kg/min** (milliliters per kilogram per minute)

### Deduplication Strategy

```sql
-- Dedup logic: same date + same source = replace
INSERT INTO wt_health_metrics (
  profile_id,
  source,
  metric_type,
  value_num,
  unit,
  start_time,
  end_time,
  recorded_at,
  raw_payload_json,
  dedupe_hash
)
VALUES (
  $profile_id,
  $source, -- 'garmin', 'strava', 'healthconnect', 'healthkit'
  'vo2max',
  $value_num,
  'mL/kg/min',
  $start_time,
  $start_time, -- VO2 max is point-in-time
  NOW(),
  $raw_payload,
  MD5($profile_id || $source || $start_time::date) -- dedupe by profile + source + date
)
ON CONFLICT (dedupe_hash) DO UPDATE
SET
  value_num = EXCLUDED.value_num,
  raw_payload_json = EXCLUDED.raw_payload_json,
  updated_at = NOW();
```

### End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Data Ingestion                                                   │
├─────────────────────────────────────────────────────────────────────┤
│ Garmin Push Webhook                                                 │
│   ↓                                                                  │
│ POST /webhooks/garmin                                               │
│   ↓                                                                  │
│ wt_webhook_events (raw storage)                                     │
│   ↓                                                                  │
│ Process webhook: extract userMetrics.vo2Max                         │
│   ↓                                                                  │
│ Normalize to mL/kg/min                                              │
│   ↓                                                                  │
│ INSERT INTO wt_health_metrics                                       │
│   - source: 'garmin'                                                │
│   - metric_type: 'vo2max'                                           │
│   - value_num: {normalized_value}                                   │
│   - dedupe_hash: MD5(profile_id || source || date)                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 2. Baseline Calibration Check                                       │
├─────────────────────────────────────────────────────────────────────┤
│ IF baseline status = 'in_progress':                                 │
│   - Include in 14-day baseline calculation                          │
│   - Check if baseline complete (14 days, 10+ points)                │
│   - If complete: SET calibration_status = 'complete'                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 3. Forecast Update (if baseline complete)                           │
├─────────────────────────────────────────────────────────────────────┤
│ Trigger: New vo2max data point inserted                             │
│   ↓                                                                  │
│ Queue forecast recalculation                                        │
│   ↓                                                                  │
│ Run linear regression:                                              │
│   - Collect all post-baseline vo2max values                         │
│   - Calculate slope (mL/kg/min per day)                             │
│   - Calculate R² (confidence)                                       │
│   ↓                                                                  │
│ IF data_points >= 4:                                                │
│   - Calculate projected_date to target                              │
│   - UPDATE wt_goal_forecasts                                        │
│ ELSE:                                                                │
│   - SET forecast_status = 'insufficient_data'                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ 4. AI Narrative Generation                                          │
├─────────────────────────────────────────────────────────────────────┤
│ POST /ai/orchestrate                                                │
│   tool: generate_vo2max_insight                                     │
│   ↓                                                                  │
│ Context passed to AI:                                               │
│   - baseline_value: {baseline_vo2max}                               │
│   - current_value: {latest_vo2max}                                  │
│   - change_absolute: {current - baseline}                           │
│   - change_percent: {(current - baseline) / baseline * 100}         │
│   - weeks_elapsed: {(now - baseline_end_date) / 7}                  │
│   - slope: {rate_of_change_per_day}                                 │
│   - projected_date: {forecast_date}                                 │
│   - confidence: {r_squared * 100}                                   │
│   ↓                                                                  │
│ AI generates narrative:                                             │
│   "Your VO₂ max has improved from 42.3 to 44.1 mL/kg/min over      │
│    6 weeks. At your current rate of improvement, you're on track   │
│    to reach your target of 48 mL/kg/min by August 15, 2026."       │
│   ↓                                                                  │
│ Store in wt_insights (insight_type: 'vo2max_progress')              │
└─────────────────────────────────────────────────────────────────────┘
```

### Dashboard Display

#### Card: VO₂ Max Progress

```
┌─────────────────────────────────────────────────┐
│ VO₂ Max                                         │
│                                                 │
│ 44.1 mL/kg/min        ↑ +1.8 (+4.3%)           │
│                                                 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ Baseline  Current                      Target  │
│   42.3     44.1                          48.0  │
│                                                 │
│ [Chart: VO₂ max over time with regression line]│
│                                                 │
│ 🎯 On track to reach 48 by Aug 15, 2026        │
│    (73% confidence)                             │
│                                                 │
│ [View Detailed Analysis] (Pro)                  │
└─────────────────────────────────────────────────┘
```

#### Chart Details

- **X-axis**: Time (days/weeks since baseline)
- **Y-axis**: VO₂ max (mL/kg/min)
- **Blue dots**: Actual measurements
- **Dashed line**: Linear regression (trend)
- **Shaded area**: 95% confidence interval
- **Target line**: Horizontal line at target value
- **Intersection marker**: Projected achievement date

#### Free vs. Pro Features

| Feature | Free | Pro |
|---------|------|-----|
| Current VO₂ max value | ✅ | ✅ |
| Baseline comparison | ✅ | ✅ |
| Simple trend arrow (↑/↓/→) | ✅ | ✅ |
| Basic chart (30 days) | ✅ | ✅ |
| Projected achievement date | ❌ | ✅ |
| Confidence percentage | ❌ | ✅ |
| Full historical chart | ❌ | ✅ |
| Confidence intervals | ❌ | ✅ |
| AI-generated insights | Limited | Unlimited |

---

## 6. Implementation Checklist

### Phase 1: Baseline System
- [ ] Create `wt_baselines` table with RLS
- [ ] Build baseline capture logic (14-day window, 10+ points)
- [ ] Create nightly cron job for baseline status checks
- [ ] Add baseline status to user profile API
- [ ] Build UI: calibration progress indicator
- [ ] Add baseline reset endpoint (admin/user-initiated)

### Phase 2: Training Load
- [ ] Create `wt_training_loads` table
- [ ] Implement intensity factor calculation (HR-based + activity-based)
- [ ] Build 7-day and 28-day rolling load queries
- [ ] Calculate ACWR (acute-to-chronic workload ratio)
- [ ] Add overtraining detection flags
- [ ] Create training load API endpoints
- [ ] Build UI: weekly load chart + ACWR indicator

### Phase 3: Recovery Score
- [ ] Create `wt_recovery_scores` table
- [ ] Implement stress normalization
- [ ] Implement sleep scoring (duration + quality blend)
- [ ] Implement HR deviation scoring
- [ ] Implement load ratio scoring
- [ ] Build composite score calculation with missing data handling
- [ ] Create recovery score API endpoint
- [ ] Build UI: daily recovery card with component breakdown

### Phase 4: Linear Regression Forecasts
- [ ] Create `wt_goal_forecasts` table
- [ ] Implement linear regression SQL function
- [ ] Add R² confidence calculation
- [ ] Build forecast recalculation trigger (on new data)
- [ ] Create weekly forecast recalc cron job
- [ ] Add forecast API endpoints (per metric)
- [ ] Build UI: forecast chart with confidence intervals (Pro)

### Phase 5: VO₂ Max Pipeline
- [ ] Garmin webhook: extract `vo2Max` from userMetrics
- [ ] Strava webhook: extract VO₂ max from activities
- [ ] Health Connect: ingest `Vo2MaxRecord`
- [ ] HealthKit: ingest `vo2Max` quantity
- [ ] Normalize all sources to mL/kg/min
- [ ] Implement dedup logic (date + source)
- [ ] Wire VO₂ max ingestion to baseline + forecast systems
- [ ] Build VO₂ max dashboard card
- [ ] Create AI narrative tool: `generate_vo2max_insight`

### Phase 6: AI Integration
- [ ] Add performance context to AI orchestrator snapshot
- [ ] Create AI tools:
  - [ ] `summarize_recovery_score`
  - [ ] `explain_training_load_change`
  - [ ] `generate_vo2max_insight`
  - [ ] `suggest_workout_intensity` (based on recovery)
- [ ] Implement freemium limits for AI narratives
- [ ] Add AI audit logging for performance insights

---

## 7. Testing Strategy

### Unit Tests

#### Baseline Calibration
- [ ] Test 14-day window calculation
- [ ] Test minimum 10 data points threshold
- [ ] Test status transitions (pending → in_progress → complete)
- [ ] Test baseline value averaging
- [ ] Test edge cases: gaps in data, duplicate dates

#### Training Load
- [ ] Test intensity factor calculation (HR-based)
- [ ] Test intensity factor fallback (activity-based)
- [ ] Test 7-day rolling sum
- [ ] Test ACWR calculation
- [ ] Test overtraining detection thresholds

#### Recovery Score
- [ ] Test stress normalization (invert scale)
- [ ] Test sleep scoring (target range, quality blend)
- [ ] Test HR deviation scoring (baseline comparison)
- [ ] Test load ratio scoring
- [ ] Test composite score with all components
- [ ] Test composite score with missing components (weight redistribution)
- [ ] Test edge cases: all nulls, single component available

#### Linear Regression
- [ ] Test slope calculation (positive, negative, zero)
- [ ] Test intercept calculation
- [ ] Test R² calculation
- [ ] Test projected date calculation
- [ ] Test minimum data points enforcement (< 4)
- [ ] Test confidence intervals
- [ ] Test edge cases: perfect fit (R²=1), no correlation (R²=0)

### Integration Tests

- [ ] End-to-end: Garmin webhook → VO₂ max storage → baseline → forecast → UI
- [ ] End-to-end: Workout log → training load → recovery score → AI narrative
- [ ] End-to-end: Sleep data → recovery score → workout recommendation
- [ ] Cross-platform: Verify identical calculations on iOS and Android

### Performance Tests

- [ ] Baseline calculation: 10,000 profiles, 14 days each
- [ ] Recovery score: 10,000 daily calculations
- [ ] Forecast recalc: 1,000 profiles, 100 data points each
- [ ] Query optimization: ensure all queries < 200ms at scale

---

## 8. API Endpoints

### Baseline

```
GET /api/v1/profiles/{profile_id}/baselines
  → Returns all baseline metrics with calibration status

GET /api/v1/profiles/{profile_id}/baselines/{metric_type}
  → Returns single baseline metric

POST /api/v1/profiles/{profile_id}/baselines/reset
  → Resets baseline for specified metric (requires confirmation)
```

### Recovery Score

```
GET /api/v1/profiles/{profile_id}/recovery/current
  → Returns today's recovery score with component breakdown

GET /api/v1/profiles/{profile_id}/recovery/history?days=30
  → Returns recovery score history (default 30 days)
```

### Training Load

```
GET /api/v1/profiles/{profile_id}/training-load/current
  → Returns current 7-day load + ACWR

GET /api/v1/profiles/{profile_id}/training-load/history?weeks=12
  → Returns weekly training load history
```

### Forecasts

```
GET /api/v1/profiles/{profile_id}/forecasts
  → Returns all active forecasts

GET /api/v1/profiles/{profile_id}/forecasts/{metric_type}
  → Returns single metric forecast with full regression data

POST /api/v1/profiles/{profile_id}/forecasts/{metric_type}/recalculate
  → Triggers on-demand forecast recalculation
```

---

## 9. Privacy & Security

### Data Minimization
- Only ingest health metrics necessary for enabled modules
- Delete raw webhook payloads after normalization (retain 7 days for debugging)
- Provide user-initiated data export and deletion

### Encryption
- All health metrics encrypted at rest (Supabase encryption)
- API communications over TLS 1.3+
- Local device storage: use `flutter_secure_storage` for tokens

### Row-Level Security (RLS)
- All tables enforce profile-scoped access
- No cross-user data leakage
- Admin access logged in `wt_audit_log`

### Compliance
- HIPAA-compliant data handling (if applicable)
- GDPR: right to access, rectification, deletion
- Store all AI interactions in audit log for transparency

---

## 10. Future Enhancements

### Advanced Forecasting
- **Polynomial regression**: For non-linear trends (e.g., strength gains plateau)
- **Seasonal decomposition**: Account for seasonal variation (e.g., outdoor running in winter)
- **Multivariate models**: Combine multiple metrics (e.g., sleep + load → VO₂ max)

### HRV-Based Recovery
- Integrate HRV (heart rate variability) as primary recovery indicator
- Replace or supplement resting HR with HRV score
- Validated: HRV is highly sensitive to fatigue and stress

### Adaptive Baselines
- Rolling baseline: recalibrate every 90 days
- Detect fitness level changes and adjust automatically
- Notify user when baseline shifts significantly

### Machine Learning Layer (Optional)
- Use regression for initial forecast
- Optionally enhance with ML (XGBoost, neural nets) for users with 6+ months data
- Always show both: deterministic (regression) + ML prediction
- ML must be explainable (SHAP values, feature importance)

### Readiness Score Enhancements
- Add HRV (0.15 weight)
- Add subjective readiness (user inputs: muscle soreness, mood, energy) (0.10 weight)
- Adjust weights dynamically based on available data quality

---

## Appendix: Formulas Reference

### Recovery Score (Full)
```
Recovery Score = (stress_norm × 0.25) + (sleep_norm × 0.30) + (hr_norm × 0.20) + (load_norm × 0.25)

stress_norm = 100 - stress_avg  (if available)

sleep_norm = CASE
  WHEN duration ∈ [420, 540] THEN 100
  WHEN duration < 420 THEN (duration / 420) × 100
  ELSE MAX(100 - ((duration - 540) / 60 × 10), 60)
END
IF sleep_quality available: (duration_score × 0.6) + (quality × 0.4)

hr_norm = CASE
  WHEN current_hr ≤ baseline_hr THEN 100
  ELSE MAX(100 - (((current_hr - baseline_hr) / baseline_hr) × 500), 0)
END

load_norm = CASE
  WHEN load_ratio ≤ 0.8 THEN 100
  WHEN load_ratio ≤ 1.0 THEN 80
  WHEN load_ratio ≤ 1.3 THEN 60
  WHEN load_ratio ≤ 1.5 THEN 40
  ELSE 20
END
```

### Training Load
```
Training Load = Duration (min) × Intensity Factor

Intensity Factor = CASE
  WHEN avg_hr available THEN 0.5 + (HR_reserve_fraction)
  ELSE activity_type_mapping
END

ACWR = (7-day avg daily load) / (28-day avg daily load)
```

### Linear Regression
```
slope = (n × Σ(x × y) - Σx × Σy) / (n × Σ(x²) - (Σx)²)
intercept = (Σy - slope × Σx) / n
R² = 1 - (SS_res / SS_tot)
projected_days = (target - intercept) / slope
```

---

**End of Document**
