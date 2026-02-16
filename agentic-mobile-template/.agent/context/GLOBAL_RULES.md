# Global Agent Rules

> These rules apply to ALL projects using this template. They define universal standards the agent must follow.

## 🎯 Core Principles

### 1. Context Over Cleverness
- Read all available context before starting
- Check examples/ directory for patterns
- Review PROJECT_CONTEXT.md for project specifics
- Don't guess—ask or search when unclear

### 2. Self-Annealing
- When something breaks, fix it and learn from it
- Update directives with new learnings
- Add failure patterns to knowledge base
- Never repeat the same mistake

### 3. Deterministic Execution
- Push complexity into scripts, not prompts
- Use execution layer for API calls, file ops
- AI makes decisions; code does the work
- Prefer proven patterns over novel approaches

---

## 📝 Code Standards

### File Organization

**Size Limits:**
- Single file: < 500 lines
- Split into modules if exceeding
- Keep related code together

**Structure:**
```
src/
├── components/       # UI components
├── screens/         # Full screen views (mobile)
├── pages/           # Routes (web)
├── services/        # API clients, integrations
├── stores/          # State management
├── utils/           # Helper functions
├── types/           # TypeScript types
└── constants/       # Config, constants
```

### Naming Conventions

**Files:**
- Components: `PascalCase.tsx`
- Utilities: `camelCase.ts`
- Types: `PascalCase.types.ts`
- Constants: `SCREAMING_SNAKE_CASE.ts`

**Variables:**
- camelCase for variables and functions
- PascalCase for components and classes
- SCREAMING_SNAKE_CASE for constants

**Examples:**
```typescript
// Good
const userProfile = getUserProfile();
export const API_BASE_URL = 'https://api.example.com';
function UserAvatar() { }

// Bad
const UserProfile = getUserProfile(); // Should be camelCase
const apiBaseUrl = 'https://api.example.com'; // Should be SCREAMING_SNAKE_CASE
function user_avatar() { } // Should be PascalCase
```

---

## 🧪 Testing Requirements

### Coverage

- Unit tests: Core business logic
- Integration tests: API calls, state updates
- E2E tests: Critical user flows
- Target: 80%+ coverage on new code

### Test Structure

```typescript
describe('FeatureName', () => {
  describe('when condition', () => {
    it('should do expected behavior', () => {
      // Arrange
      // Act
      // Assert
    });
  });
});
```

### What to Test

**Always test:**
- API integrations
- State management logic
- Authentication flows
- Data transformations
- Error handling

**Don't test:**
- Third-party library internals
- Simple getters/setters
- UI styling (unless critical)

---

## 🔒 Security Standards

### Sensitive Data

**Never log:**
- Passwords, tokens, API keys
- User emails, phone numbers
- Payment information
- Session data

**Storage:**
- Mobile: Use Expo SecureStore or react-native-keychain
- Web: Use httpOnly cookies for tokens
- Never store sensitive data in localStorage/AsyncStorage

### API Security

**Authentication:**
- Always validate tokens server-side
- Implement token refresh logic
- Handle 401s gracefully
- Never expose API keys in client code

**Input Validation:**
- Validate all user inputs
- Sanitize before database operations
- Use parameterized queries
- Implement rate limiting

---

## 📖 Documentation Standards

### Code Comments

**When to comment:**
- Complex business logic
- Non-obvious algorithms
- Workarounds for bugs/limitations
- Public API methods

**When NOT to comment:**
- Self-explanatory code
- Every line (let code speak)
- Redundant descriptions

**Example:**
```typescript
// Good: Explains why
// Using setTimeout to avoid race condition with React state updates
setTimeout(() => setLoading(false), 0);

// Bad: States the obvious
// Set loading to false
setLoading(false);
```

### Function Documentation

```typescript
/**
 * Fetches user profile from API with retry logic
 * 
 * @param userId - Unique user identifier
 * @param options - Optional fetch configuration
 * @returns User profile data or null if not found
 * @throws {NetworkError} When API is unreachable after retries
 * 
 * @example
 * const profile = await getUserProfile('user-123');
 * if (profile) {
 *   console.log(profile.name);
 * }
 */
async function getUserProfile(
  userId: string,
  options?: FetchOptions
): Promise<UserProfile | null>
```

---

## 🚨 Error Handling

### General Principles

- Always handle errors explicitly
- Provide user-friendly error messages
- Log errors for debugging
- Never expose internal errors to users

### Try-Catch Usage

```typescript
// Good: Specific error handling
try {
  const data = await fetchData();
  return processData(data);
} catch (error) {
  if (error instanceof NetworkError) {
    // Handle network issues
  } else if (error instanceof ValidationError) {
    // Handle validation issues
  } else {
    // Handle unexpected errors
    logError(error);
    throw new AppError('Something went wrong');
  }
}

// Bad: Silent failure
try {
  const data = await fetchData();
} catch (error) {
  // Do nothing
}
```

### User-Facing Errors

```typescript
// Good: Helpful, actionable
throw new Error('Unable to load profile. Check your connection and try again.');

// Bad: Technical, confusing
throw new Error('HTTP 500: Internal Server Error at /api/user/profile');
```

---

## 🎨 UI/UX Standards

### Accessibility

**Required:**
- Semantic HTML elements
- ARIA labels where needed
- Keyboard navigation support
- Screen reader compatibility
- Sufficient color contrast (4.5:1)

**Mobile:**
- Touch targets: min 44x44 points
- Support system font sizes
- Handle different screen sizes

### Loading States

**Always show:**
- Spinner/skeleton for async operations
- Progress indicators for uploads
- Feedback for user actions
- Error states with retry options

### Responsive Design

**Mobile-first:**
- Design for smallest screen first
- Scale up for tablets/desktop
- Test on actual devices
- Handle different orientations

---

## 🔄 Version Control

### Commit Messages

**Format:**
```
type(scope): brief description

Detailed explanation if needed

Fixes #issue-number
```

**Types:**
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code restructuring
- test: Adding tests
- chore: Maintenance

**Examples:**
```
feat(auth): add Google sign-in support

Implements OAuth flow for Google authentication.
Users can now sign in with their Google account.

Fixes #123
```

### Branch Strategy

- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: New features
- `fix/*`: Bug fixes
- `hotfix/*`: Urgent production fixes

---

## 🚀 Performance

### Optimization Guidelines

**React Native:**
- Memoize expensive computations
- Use `React.memo` for pure components
- Implement virtualized lists for long scrolls
- Optimize images (WebP, lazy loading)
- Minimize bridge calls

**Web:**
- Code splitting by route
- Lazy load non-critical components
- Debounce search inputs
- Cache API responses
- Minimize bundle size

### Monitoring

**Track:**
- App load time
- Screen transition time
- API response times
- Error rates
- Crash reports

---

## 🧩 Integration Standards

### API Clients

**Structure:**
```typescript
class ApiClient {
  private baseUrl: string;
  private token: string | null;

  async get<T>(endpoint: string): Promise<T> {
    // Implementation with error handling
  }

  async post<T>(endpoint: string, data: unknown): Promise<T> {
    // Implementation with error handling
  }
  
  // ... other methods
}
```

**Error Handling:**
- Network errors
- Timeout errors
- Authentication errors
- Validation errors
- Rate limiting

### Third-Party Services

**Before integrating:**
- Check license compatibility
- Review security implications
- Consider bundle size impact
- Read their documentation fully
- Check maintenance status

---

## 📊 Analytics & Monitoring

### Events to Track

**User Actions:**
- Screen views
- Button clicks
- Form submissions
- Feature usage

**Errors:**
- API failures
- Crashes
- Validation errors
- Performance issues

### Privacy

- Get user consent
- Anonymize sensitive data
- Follow GDPR/CCPA guidelines
- Provide opt-out mechanisms

---

## 🛠️ Development Workflow

### Before Starting

1. Read INITIAL.md thoroughly
2. Check examples/ for patterns
3. Review PROJECT_CONTEXT.md
4. Understand tech stack choices
5. Plan implementation approach

### During Development

1. Follow TDD when applicable
2. Write tests alongside code
3. Run linter frequently
4. Test on real devices/browsers
5. Handle edge cases

### Before Committing

1. All tests pass
2. No linting errors
3. No console errors
4. Documentation updated
5. Self-review changes

---

## 🎓 Learning & Improvement

### When Things Break

1. **Analyze**: Understand root cause
2. **Fix**: Implement solution
3. **Test**: Verify fix works
4. **Document**: Update directive
5. **Learn**: Add to knowledge base

### Continuous Improvement

- Review failure patterns monthly
- Update examples with new patterns
- Refine directives based on outcomes
- Share learnings with team

---

## 🚫 Anti-Patterns to Avoid

### Code Smells

- God objects (classes doing too much)
- Deep nesting (> 3 levels)
- Long functions (> 50 lines)
- Duplicate code
- Magic numbers/strings

### Architecture Smells

- Circular dependencies
- Tight coupling
- No separation of concerns
- Inconsistent patterns
- Over-engineering

### React/React Native Specific

- Prop drilling (use state management)
- Inline function props (performance)
- Missing dependency arrays (useEffect)
- Mutating state directly
- Using index as key

---

## 📞 When to Ask for Help

**Ask the user when:**
- Requirements are unclear
- Multiple valid approaches exist
- Security implications are significant
- Breaking changes are needed
- Third-party service choices required

**Don't ask when:**
- Implementation details are clear
- Standard patterns apply
- Directive covers the scenario
- Examples show the way

---

## ✅ Definition of Done

A feature is done when:

- [ ] All success criteria met
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] No linting errors
- [ ] Code reviewed (self-review)
- [ ] Tested on target platforms
- [ ] Error handling implemented
- [ ] Accessibility checked
- [ ] Performance validated
- [ ] Ready for deployment

---

These rules are living documents. Update them as you learn. The system gets smarter with every project.
