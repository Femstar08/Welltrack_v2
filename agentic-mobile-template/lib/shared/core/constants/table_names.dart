/// Centralized Supabase table name constants.
///
/// Use these instead of hardcoded strings to prevent typos
/// and make table renames a single-line change.
class TableNames {
  const TableNames._();

  static const String users = 'wt_users';
  static const String profiles = 'wt_profiles';
  static const String healthMetrics = 'wt_health_metrics';
  static const String workouts = 'wt_workouts';
  static const String workoutLogs = 'wt_workout_logs';
  static const String workoutPlans = 'wt_workout_plans';
  static const String workoutPlanExercises = 'wt_workout_plan_exercises';
  static const String exercises = 'wt_exercises';
  static const String exerciseRecords = 'wt_exercise_records';
  static const String meals = 'wt_meals';
  static const String mealPlans = 'wt_meal_plans';
  static const String mealPlanItems = 'wt_meal_plan_items';
  static const String recipes = 'wt_recipes';
  static const String recipeSteps = 'wt_recipe_steps';
  static const String recipeIngredients = 'wt_recipe_ingredients';
  static const String pantryItems = 'wt_pantry_items';
  static const String shoppingLists = 'wt_shopping_lists';
  static const String shoppingListItems = 'wt_shopping_list_items';
  static const String goals = 'wt_goals';
  static const String reminders = 'wt_reminders';
  static const String habitStreaks = 'wt_habit_streaks';
  static const String habitLogs = 'wt_habit_logs';
  static const String bloodworkResults = 'wt_bloodwork_results';
  static const String supplements = 'wt_supplements';
  static const String supplementLogs = 'wt_supplement_logs';
  static const String dailyCheckins = 'wt_daily_checkins';
  static const String dailyPrescriptions = 'wt_daily_prescriptions';
  static const String aiUsage = 'wt_ai_usage';
  static const String aiConversations = 'wt_ai_conversations';
  static const String customMacroTargets = 'wt_custom_macro_targets';
  static const String oauthTokens = 'wt_oauth_tokens';
  static const String purchases = 'wt_purchases';
  static const String profileModules = 'wt_profile_modules';
}
