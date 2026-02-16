import { SafetyFlag, DBWrite } from './types.ts'

// Medical claim keywords that should trigger flags
const MEDICAL_CLAIM_KEYWORDS = [
  'diagnose',
  'diagnosis',
  'cure',
  'treat',
  'treatment for',
  'prescribe',
  'prescription',
  'you have',
  'you are suffering from',
  'medical condition',
  'disease',
  'illness',
]

// Unsafe numeric value ranges for common metrics
const SAFE_RANGES: Record<string, { min: number; max: number; unit: string }> = {
  weight_kg: { min: 30, max: 300, unit: 'kg' },
  height_cm: { min: 100, max: 250, unit: 'cm' },
  calories: { min: 0, max: 10000, unit: 'kcal' },
  steps: { min: 0, max: 100000, unit: 'steps' },
  sleep_hours: { min: 0, max: 24, unit: 'hours' },
  heart_rate: { min: 30, max: 220, unit: 'bpm' },
  stress_score: { min: 0, max: 100, unit: 'score' },
  vo2_max: { min: 10, max: 100, unit: 'ml/kg/min' },
}

export function validateSafety(
  assistantMessage: string,
  dbWrites: DBWrite[]
): SafetyFlag[] {
  const flags: SafetyFlag[] = []

  // Check for medical claims in assistant message
  const lowerMessage = assistantMessage.toLowerCase()
  for (const keyword of MEDICAL_CLAIM_KEYWORDS) {
    if (lowerMessage.includes(keyword)) {
      flags.push({
        type: 'medical_claim',
        message: `Detected potential medical claim: "${keyword}". Response may need review.`,
        blocked: false, // Log but don't block by default
      })
      break // Only flag once per message
    }
  }

  // Validate numeric values in db_writes
  for (const write of dbWrites) {
    const table = write.table
    const data = write.data

    // Check weight values
    if (data.weight_kg && typeof data.weight_kg === 'number') {
      if (!isInRange(data.weight_kg, SAFE_RANGES.weight_kg)) {
        flags.push({
          type: 'unsafe_value',
          message: `Weight value ${data.weight_kg}kg is outside safe range (${SAFE_RANGES.weight_kg.min}-${SAFE_RANGES.weight_kg.max}kg)`,
          blocked: true,
        })
      }
    }

    // Check height values
    if (data.height_cm && typeof data.height_cm === 'number') {
      if (!isInRange(data.height_cm, SAFE_RANGES.height_cm)) {
        flags.push({
          type: 'unsafe_value',
          message: `Height value ${data.height_cm}cm is outside safe range (${SAFE_RANGES.height_cm.min}-${SAFE_RANGES.height_cm.max}cm)`,
          blocked: true,
        })
      }
    }

    // Check calories
    if (data.calories && typeof data.calories === 'number') {
      if (!isInRange(data.calories, SAFE_RANGES.calories)) {
        flags.push({
          type: 'unsafe_value',
          message: `Calorie value ${data.calories} is outside safe range (${SAFE_RANGES.calories.min}-${SAFE_RANGES.calories.max})`,
          blocked: true,
        })
      }
    }

    // Check health metrics if writing to wt_health_metrics
    if (table === 'wt_health_metrics' && data.value_num && typeof data.value_num === 'number') {
      const metricType = data.metric_type as string
      if (metricType && SAFE_RANGES[metricType]) {
        if (!isInRange(data.value_num, SAFE_RANGES[metricType])) {
          flags.push({
            type: 'unsafe_value',
            message: `${metricType} value ${data.value_num} is outside safe range`,
            blocked: true,
          })
        }
      }
    }

    // Validate table names are wt_ prefixed
    if (!table.startsWith('wt_')) {
      flags.push({
        type: 'unsafe_value',
        message: `Invalid table name "${table}". All tables must be prefixed with "wt_"`,
        blocked: true,
      })
    }
  }

  return flags
}

function isInRange(
  value: number,
  range: { min: number; max: number }
): boolean {
  return value >= range.min && value <= range.max
}

export function hasBlockingFlags(flags: SafetyFlag[]): boolean {
  return flags.some((f) => f.blocked)
}
