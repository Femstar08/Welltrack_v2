# PRP: Pantry → Recipes → Prep Feature

## Context

### Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Local Storage**: Isar (encrypted)
- **HTTP Client**: Dio
- **Architecture**: Clean Architecture (domain/data/presentation)

### Related Patterns
- Entity-Repository-Provider pattern (see profile feature)
- AsyncValue for async state management
- ConsumerWidget for UI with Riverpod
- copyWith pattern for immutable updates
- Snake case for Supabase column names, camelCase for Dart

### Known Issues
- Must use `wt_` prefix for all table names (not WP_)
- All dates must use ISO8601 format for Supabase
- Offline-first: all writes must queue if offline
- Profile-scoped data: all queries must filter by profile_id
- Never call AI directly from client; use Edge Function orchestrator

## Implementation Plan

### Phase 1: Pantry Domain Layer
**What**: Create pantry item entity and data models
**How**:
1. Create `PantryItemEntity` with all fields
2. Create `PantryItemModel` with JSON serialization
3. Follow existing profile entity pattern

**Validation**: Dart analyzer passes, no errors
**Success Criteria**:
- [ ] Entity has all required fields
- [ ] toJson/fromJson methods work
- [ ] copyWith method for updates

### Phase 2: Pantry Data Layer
**What**: Create repository for pantry CRUD operations
**How**:
1. Create `PantryRepository` with Supabase client
2. Implement getItems, addItem, updateItem, deleteItem
3. Filter by category (fridge/cupboard/freezer)
4. Sort by expiry date

**Validation**: Repository methods compile
**Success Criteria**:
- [ ] CRUD operations defined
- [ ] Proper error handling
- [ ] Riverpod provider created

### Phase 3: Pantry Presentation Layer
**What**: Create UI for managing pantry items
**How**:
1. Create `PantryProvider` StateNotifier
2. Create `PantryScreen` with category tabs
3. Create `AddPantryItemSheet` bottom sheet
4. Add "Cook with these" FAB

**Validation**: UI renders without errors
**Success Criteria**:
- [ ] Category filtering works
- [ ] Add/edit/delete items
- [ ] Search functionality
- [ ] Material Design compliance

### Phase 4: Recipes Domain & Data Layer
**What**: Create recipe entities and repository
**How**:
1. Create `RecipeEntity`, `RecipeStep`, `RecipeIngredient`
2. Create `RecipeRepository` with transaction support
3. Support saving recipe + steps + ingredients atomically

**Validation**: Repository methods compile
**Success Criteria**:
- [ ] Recipe with nested steps/ingredients
- [ ] Transaction-based saves
- [ ] Toggle favorite feature

### Phase 5: Recipe Generation Flow
**What**: AI recipe generation from pantry items
**How**:
1. Create `RecipeGenerationProvider` StateNotifier
2. Call AI orchestrator Edge Function
3. Parse response into recipe suggestions
4. Handle loading/error states

**Validation**: Provider state transitions work
**Success Criteria**:
- [ ] Sends pantry items to AI
- [ ] Parses recipe suggestions
- [ ] Generates detailed steps
- [ ] Saves to database

### Phase 6: Recipe UI
**What**: Recipe suggestion and detail screens
**How**:
1. Create `RecipeSuggestionsScreen` with card list
2. Create `RecipeDetailScreen` with full recipe
3. Create `PrepWalkthroughScreen` with step-by-step
4. Add timer and checklist features

**Validation**: UI flows work end-to-end
**Success Criteria**:
- [ ] Recipe cards display correctly
- [ ] Navigation flows work
- [ ] Timers countdown properly
- [ ] Step progression works

### Phase 7: Meals Domain & Data Layer
**What**: Meal logging entity and repository
**How**:
1. Create `MealEntity` with nutrition info
2. Create `MealRepository` with CRUD
3. Link to recipes when logging from prep

**Validation**: Repository compiles
**Success Criteria**:
- [ ] Meal logging works
- [ ] Recipe linking works
- [ ] Nutrition auto-extraction

### Phase 8: Meal Logging UI
**What**: Quick meal logging screen
**How**:
1. Create `LogMealScreen` with form
2. Auto-fill from recipe if available
3. Rating and notes capture
4. Photo placeholder

**Validation**: Form submission works
**Success Criteria**:
- [ ] Meal type selector
- [ ] Auto-fill from recipe
- [ ] Servings tracking
- [ ] Saves to database

### Phase 9: Integration & Routing
**What**: Wire up navigation and module registration
**How**:
1. Add pantry/recipes routes to router
2. Register in module system
3. Add dashboard tiles

**Validation**: Navigation works
**Success Criteria**:
- [ ] Routes accessible
- [ ] Module toggles work
- [ ] Dashboard tiles appear

### Phase 10: Testing & Polish
**What**: Unit tests and error handling
**How**:
1. Test repository methods
2. Test state transitions
3. Test error scenarios
4. Add loading states

**Validation**: All tests pass
**Success Criteria**:
- [ ] Repository tests pass
- [ ] Provider tests pass
- [ ] Error handling robust
- [ ] Loading states smooth

## Failure Prevention

### Pattern 1: Offline Queue Not Used
**Description**: Direct Supabase writes fail when offline
**Prevention**:
- Use offline queue for all writes
- Show pending indicator
- Sync when connection restored

### Pattern 2: Nested Transactions Fail
**Description**: Saving recipe + steps + ingredients can partially fail
**Prevention**:
- Use Supabase RPC with transaction
- Validate all data before write
- Rollback on any error

### Pattern 3: AI Response Parsing Errors
**Description**: AI might return malformed JSON
**Prevention**:
- Validate JSON schema
- Provide default values
- Show user-friendly error
- Log for debugging

### Pattern 4: Date Format Mismatches
**Description**: Dart DateTime vs ISO8601 string issues
**Prevention**:
- Always use toIso8601String() for Supabase
- Parse with DateTime.parse()
- Handle null dates gracefully

### Pattern 5: Missing Profile Context
**Description**: Queries without profile_id can leak data
**Prevention**:
- Always include profile_id in where clause
- RLS enforces at DB level
- Double-check all queries

## Success Criteria

- [ ] User can add pantry items by category
- [ ] User can view items by fridge/cupboard/freezer
- [ ] User can search and filter pantry
- [ ] User can delete pantry items
- [ ] "Cook with these" triggers AI recipe generation
- [ ] AI returns 5-10 recipe suggestions
- [ ] Recipe cards show time, difficulty, nutrition score
- [ ] User can select recipe for detailed view
- [ ] Recipe detail shows ingredients and steps
- [ ] "Start Cooking" begins step-by-step walkthrough
- [ ] Timers work for timed steps
- [ ] User can mark steps complete
- [ ] On completion, meal logging screen appears
- [ ] Meal is logged with recipe link
- [ ] Nutrients are auto-extracted from recipe
- [ ] All data syncs when offline
- [ ] No data leaks between profiles
- [ ] Navigation flows are smooth
- [ ] Error states are user-friendly
- [ ] Loading states show progress

## Confidence Score

**8/10** - High confidence

**Reasoning**:
- Clear requirements
- Existing patterns to follow (profile feature)
- Known tech stack (Flutter + Supabase + Riverpod)
- Clean architecture structure in place
- Minor unknowns: AI orchestrator contract (will stub for now)

**Risks**:
- AI orchestrator endpoint not yet built (will create mock for testing)
- Recipe step generation complexity (mitigated with clear JSON schema)
- Timer state management during app backgrounding (will handle with lifecycle)

## Documentation References

- Flutter Riverpod: https://riverpod.dev/docs/introduction/getting_started
- Supabase Flutter: https://supabase.com/docs/reference/dart/introduction
- Material Design: https://m3.material.io/
- Clean Architecture: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

## File Structure

```
lib/features/
├── pantry/
│   ├── domain/
│   │   └── pantry_item_entity.dart
│   ├── data/
│   │   ├── pantry_item_model.dart
│   │   └── pantry_repository.dart
│   └── presentation/
│       ├── pantry_provider.dart
│       ├── pantry_screen.dart
│       └── add_pantry_item_sheet.dart
├── recipes/
│   ├── domain/
│   │   ├── recipe_entity.dart
│   │   ├── recipe_step.dart
│   │   └── recipe_ingredient.dart
│   ├── data/
│   │   ├── recipe_model.dart
│   │   └── recipe_repository.dart
│   └── presentation/
│       ├── recipe_generation_provider.dart
│       ├── recipe_suggestions_screen.dart
│       ├── recipe_detail_screen.dart
│       └── prep_walkthrough_screen.dart
└── meals/
    ├── domain/
    │   └── meal_entity.dart
    ├── data/
    │   ├── meal_model.dart
    │   └── meal_repository.dart
    └── presentation/
        ├── meal_provider.dart
        └── log_meal_screen.dart
```

## Implementation Notes

- Use `package:welltrack/...` imports
- Follow snake_case for file names (Dart convention)
- Use ConsumerWidget for all UI components with Riverpod
- Add proper error boundaries with try-catch
- Include loading states with AsyncValue
- Maintain < 500 lines per file
- Add TODO comments for AI orchestrator stubs
- Use Material 3 components
- Ensure accessibility (semantic labels, contrast)

## Next Steps After Implementation

1. Create AI orchestrator Edge Function
2. Define JSON schema for recipe generation
3. Add unit tests for repositories
4. Add widget tests for screens
5. Test offline sync behavior
6. Add integration tests for full flow
7. Performance test with large pantry lists
8. Accessibility audit
9. Update router with new routes
10. Register module in dashboard
