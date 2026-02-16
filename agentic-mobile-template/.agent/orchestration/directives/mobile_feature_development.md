# Directive: Mobile Feature Development

## Purpose
Implement a new feature in a React Native/Expo mobile application following best practices and project conventions.

## Inputs
- `INITIAL.md` with feature requirements
- `PROJECT_CONTEXT.md` with tech stack and patterns
- `examples/` directory with code patterns
- Relevant failure patterns from knowledge base

## Process

### 1. Research Phase
**Goal:** Understand what needs to be built and how it fits into the existing codebase.

**Steps:**
1. Read `INITIAL.md` completely
2. Review `PROJECT_CONTEXT.md` for tech stack and patterns
3. Check `examples/` for similar implementations
4. Query knowledge base for relevant failure patterns
5. Search for official documentation URLs provided
6. Identify integration points with existing code

**Output:** Mental model of the feature and implementation approach.

---

### 2. Generate PRP
**Goal:** Create a comprehensive Product Requirements Prompt with all necessary context.

**Steps:**
1. Extract tech stack choices from `INITIAL.md`
2. Load relevant failure patterns for chosen libraries
3. Fetch success metrics for similar feature types
4. Compile documentation URLs
5. Create step-by-step implementation plan
6. Add validation gates for each step
7. Define success criteria
8. Calculate confidence score (1-10)

**PRP Structure:**
```markdown
# PRP: [Feature Name]

## Context
- Tech Stack: [from INITIAL.md]
- Related Patterns: [from examples/]
- Known Issues: [from failure patterns]

## Implementation Plan
### Step 1: [Task]
- What: [description]
- How: [approach]
- Validation: [test command]
- Success Criteria: [checklist]

[Repeat for each step]

## Failure Prevention
- Pattern 1: [description and prevention]
- Pattern 2: [description and prevention]

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Confidence Score
[1-10 based on complexity and available context]
```

**Output:** `PRPs/[feature-name].md`

---

### 3. Pre-Execution Validation
**Goal:** Ensure all context is in place before starting implementation.

**Steps:**
1. Verify all file references exist
2. Check URL accessibility
3. Validate environment variables
4. Ensure dependencies are installed
5. Run existing tests to establish baseline

**Validation Levels:**
- **Level 1:** File references valid
- **Level 2:** Dependencies available
- **Level 3:** Environment configured
- **Level 4:** Pattern-aware checks

**Output:** Validation report with pass/fail status.

---

### 4. Implementation
**Goal:** Build the feature following the PRP.

**Steps:**
1. Create necessary files based on project structure
2. Implement each step from the PRP
3. Follow code patterns from `examples/`
4. Apply failure prevention strategies
5. Handle edge cases listed in `INITIAL.md`
6. Write tests alongside code
7. Run validation after each major step

**Code Standards:**
- Follow `GLOBAL_RULES.md`
- Match patterns in `PROJECT_CONTEXT.md`
- Use naming conventions from project
- Apply design system from theme config

**Error Handling:**
- Catch and handle all async errors
- Provide user-friendly error messages
- Log errors for debugging
- Implement retry logic where appropriate

**Output:** Working implementation with tests.

---

### 5. Testing
**Goal:** Ensure the feature works correctly and doesn't break existing functionality.

**Steps:**
1. Run unit tests: `npm test`
2. Run linter: `npm run lint`
3. Run type checker: `npm run type-check`
4. Test on iOS simulator
5. Test on Android emulator
6. Test edge cases from `INITIAL.md`
7. Verify success criteria from PRP

**Required Tests:**
- Unit tests for business logic
- Integration tests for API calls
- Component tests for UI
- E2E tests for critical flows (if applicable)

**Output:** All tests passing, no lint errors.

---

### 6. Post-Implementation Analysis
**Goal:** Learn from this implementation to improve future ones.

**Steps:**
1. Record success metrics:
   - Feature type
   - Implementation time
   - Lines of code
   - Test coverage
   - Success rate (pass/fail)
2. Extract patterns:
   - What worked well?
   - What was challenging?
   - Any new failure patterns discovered?
3. Update knowledge base:
   - Add new failure patterns
   - Record success metrics
   - Update library gotchas
4. Suggest template improvements:
   - Missing context that would have helped
   - Better validation checks
   - Improved directive steps

**Output:** Updated knowledge base, analytics recorded.

---

## Tools

### Execution Scripts
- `npm test` - Run tests
- `npm run lint` - Lint code
- `npm run type-check` - TypeScript validation
- `npm run build` - Build app
- `npm start` - Start dev server

### Validation Scripts
Located in `.agent/execution/scripts/`:
- `validate_dependencies.py` - Check dependencies
- `validate_env.py` - Check environment variables
- `validate_structure.py` - Check file structure

### Knowledge Base
```python
from context_engineering_utils import ContextEngineeringUtils

utils = ContextEngineeringUtils()

# Get failure patterns
patterns = utils.get_failure_patterns(['react-native', 'expo'])

# Get success metrics
metrics = utils.get_relevant_success_metrics(['authentication', 'navigation'])

# Add new pattern
utils.add_failure_pattern({
    'description': 'New pattern discovered',
    'prevention': ['How to avoid it'],
    'related_libraries': ['library-name']
})
```

---

## Edge Cases

### Missing Context
**Problem:** INITIAL.md lacks tech stack details  
**Solution:** Ask user for clarification before generating PRP

### Conflicting Patterns
**Problem:** Multiple valid approaches exist  
**Solution:** Present options to user, let them choose

### Breaking Changes
**Problem:** Implementation requires changing existing code  
**Solution:** Get user approval before making breaking changes

### Third-Party API Issues
**Problem:** External API down or rate limited  
**Solution:** Implement exponential backoff, inform user

### Platform-Specific Issues
**Problem:** Feature works on iOS but not Android  
**Solution:** Research platform-specific requirements, add to gotchas

---

## Success Criteria

Implementation is complete when:

- [ ] All steps in PRP executed successfully
- [ ] All success criteria from INITIAL.md met
- [ ] All tests passing (unit, integration, E2E)
- [ ] No linting errors
- [ ] No TypeScript errors
- [ ] Code follows project conventions
- [ ] Documentation updated (if needed)
- [ ] Builds successfully on both platforms
- [ ] Knowledge base updated with learnings

---

## Failure Recovery

If implementation fails:

1. **Analyze:** Understand root cause
2. **Pattern Check:** Is this a known failure pattern?
3. **Fix:** Implement solution
4. **Test:** Verify fix works
5. **Learn:** Add pattern to knowledge base
6. **Retry:** Resume implementation

**Never:** Give up on first failure. The system self-anneals.

---

## Confidence Scoring

Rate implementation difficulty (1-10):

**High Confidence (8-10):**
- Clear requirements
- Similar examples exist
- All dependencies available
- No known failure patterns
- Standard feature type

**Medium Confidence (5-7):**
- Some ambiguity in requirements
- Partial examples exist
- Some dependencies unfamiliar
- Few known failure patterns
- Moderate complexity

**Low Confidence (1-4):**
- Unclear requirements
- No similar examples
- Many unknowns
- Multiple failure patterns
- High complexity

If confidence < 5, ask user for more context before proceeding.

---

## Validation Commands

```bash
# Full validation suite
npm run validate

# Individual checks
npm test                    # Unit tests
npm run lint               # ESLint
npm run type-check         # TypeScript
npm run test:integration   # Integration tests
npm run test:e2e           # E2E tests (if configured)

# Platform-specific
npm run ios                # Test on iOS
npm run android            # Test on Android
```

---

## Notes

- This directive evolves. When you discover a better approach, update it.
- Confidence scores improve as the knowledge base grows.
- Every implementation makes the next one easier.
- Trust the process. The system self-anneals.

---

**Last Updated:** [Auto-updated by system]  
**Success Rate:** [Tracked by ML system]  
**Avg Implementation Time:** [Tracked by ML system]
