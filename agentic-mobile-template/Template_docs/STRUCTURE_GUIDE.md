# 🤖 Agent Structure Guide - Mobile Template

> How AI agents should understand and use this template

## 🎯 Purpose

This guide tells AI agents (like Claude) **exactly how to read and use** this mobile template to build features correctly.

---

## 📖 Reading Order (CRITICAL)

When a user asks you to build a feature, read files in this **exact order**:

### 1. PROJECT_CONTEXT.md (FIRST - REQUIRED)
**Why:** Tells you the tech stack, patterns, and structure  
**What to extract:**
- React Native version (Expo or bare?)
- Navigation library (Expo Router or React Navigation?)
- State management (Zustand? Redux? Context?)
- Auth provider (Supabase? Firebase? Custom?)
- Styling approach (NativeWind? StyleSheet?)
- Directory structure (where to put files)

**Example:**
```
User tech stack = Expo + Expo Router + Zustand + Supabase + NativeWind
Therefore: Use Expo Router file-based routing, Zustand stores, Supabase client
```

### 2. INITIAL.md (SECOND - REQUIRED)
**Why:** Tells you WHAT to build  
**What to extract:**
- Feature description
- Specific requirements
- Examples to follow
- Gotchas to avoid
- Success criteria

### 3. .agent/context/GLOBAL_RULES.md (THIRD - REQUIRED)
**Why:** Universal standards that apply to ALL code  
**What to extract:**
- File naming conventions
- Security requirements (never log passwords!)
- Testing requirements (write tests for all logic)
- Error handling patterns
- Documentation standards

### 4. .agent/orchestration/directives/mobile_feature.md (FOURTH - REQUIRED)
**Why:** Step-by-step process for building features  
**What to do:**
- Follow the 6-step process exactly
- Don't skip validation steps
- Test on both iOS and Android
- Record metrics after completion

### 5. .agent/orchestration/knowledge_base/*.yaml (FIFTH - OPTIONAL BUT RECOMMENDED)
**Why:** Learn from past mistakes  
**What to check:**
- `failure_patterns.yaml` - What went wrong before? Prevent it!
- `success_metrics.yaml` - What worked well? Use those patterns!
- `library_gotchas.yaml` - Known issues with libraries

---

## 🔄 Step-by-Step Process

### Phase 1: Understanding (Read Files)

```
1. Read PROJECT_CONTEXT.md → Extract tech stack
2. Read INITIAL.md → Extract requirements
3. Read GLOBAL_RULES.md → Note standards
4. Read mobile_feature.md → Understand process
5. Check knowledge_base/ → Load failure patterns
```

### Phase 2: Planning (Generate PRP)

```
1. Create implementation plan
2. List files to create/modify
3. Identify validation steps
4. Note potential issues from knowledge_base
5. Calculate confidence score (1-10)
```

**Example Plan:**
```markdown
# Implementation Plan: User Authentication

## Files to Create:
- src/stores/authStore.ts (Zustand store)
- src/services/auth/supabase.ts (Auth service)
- src/app/(auth)/login.tsx (Login screen)
- src/app/(auth)/signup.tsx (Signup screen)

## Validation:
- [ ] Tokens stored in SecureStore (not AsyncStorage!)
- [ ] Password never logged
- [ ] Works on iOS simulator
- [ ] Works on Android emulator

## Confidence: 8/10
- High: Supabase auth is well-documented
- Risk: Platform-specific secure storage differences
```

### Phase 3: Validation (Before Coding)

```
1. Check all dependencies exist
2. Verify file paths match PROJECT_CONTEXT.md structure
3. Confirm no security violations
4. Review failure patterns for this feature type
```

### Phase 4: Implementation (Build It)

```
1. Create files in correct locations
2. Follow patterns from PROJECT_CONTEXT.md
3. Apply GLOBAL_RULES.md standards
4. Handle errors properly
5. Add tests
```

### Phase 5: Testing (Verify It Works)

```
1. Build for iOS: npm run ios
2. Build for Android: npm run android
3. Run tests: npm test
4. Manual testing on simulators
5. Check both platforms work
```

### Phase 6: Learning (Update Knowledge)

```
1. If successful:
   - Record implementation time
   - Record success metrics
   - Extract successful patterns

2. If failed:
   - Record failure pattern
   - Identify root cause
   - Add to knowledge base
   - Fix and retry
```

---

## 🎯 Decision Making Framework

### "Which navigation library should I use?"

```python
# Read PROJECT_CONTEXT.md → See user chose Expo Router
# Therefore: Use file-based routing, not stack navigator
```

### "Where should I put the auth service?"

```python
# Read PROJECT_CONTEXT.md → See directory structure
# User structure shows: src/services/auth/
# Therefore: Create src/services/auth/supabase.ts
```

### "How should I handle errors?"

```python
# Read GLOBAL_RULES.md → See error handling section
# Standard: try/catch with user-friendly messages
# Never: Log sensitive data
# Therefore: Wrap in try/catch, show Alert, log generic error
```

### "Should I use AsyncStorage for tokens?"

```python
# Check failure_patterns.yaml → See "insecure_token_storage"
# Pattern says: Never use AsyncStorage for sensitive data
# Therefore: Use SecureStore or Keychain
```

---

## 🚨 Critical Rules for Agents

### NEVER Do This:

❌ Skip reading PROJECT_CONTEXT.md  
❌ Assume tech stack (always read context!)  
❌ Use libraries not listed in user's stack  
❌ Ignore platform differences (iOS ≠ Android)  
❌ Skip testing on both platforms  
❌ Log sensitive data (passwords, tokens)  
❌ Hard-code values (use config/constants)  
❌ Create files in wrong directories  

### ALWAYS Do This:

✅ Read PROJECT_CONTEXT.md FIRST  
✅ Use exact tech stack from context  
✅ Follow directory structure specified  
✅ Test on iOS AND Android  
✅ Handle errors gracefully  
✅ Write tests for logic  
✅ Update knowledge base after  
✅ Check failure patterns before starting  

---

## 📋 Context Extraction Examples

### Example 1: Simple Request

```
User: "Add a login screen"

Agent reads PROJECT_CONTEXT.md:
- Platform: Expo Managed
- Navigation: Expo Router
- Auth: Supabase
- State: Zustand
- Styling: NativeWind

Agent generates:
- src/app/(auth)/login.tsx (Expo Router file)
- Uses Supabase auth methods
- Updates Zustand authStore
- Styled with NativeWind classes
- Tests both platforms
```

### Example 2: Complex Request

```
User: "Add user profile with image upload"

Agent reads PROJECT_CONTEXT.md:
- Storage: Supabase Storage
- Image handling: expo-image-picker
- State: React Query for server state
- Platform: Need iOS permissions in Info.plist

Agent checks knowledge_base:
- failure_patterns.yaml shows: "image_picker_permissions"
- Pattern: iOS needs camera/photo library permissions

Agent generates:
- Adds permissions to app.json
- Creates image picker component
- Handles upload to Supabase Storage
- Updates user profile with image URL
- Tests on both platforms (permissions work)
```

---

## 🧠 Learning System Usage

### When to Check Patterns

**Before Implementation:**
```python
Check failure_patterns.yaml for feature type
If "authentication" has failures → Read and prevent
If "image_upload" has gotchas → Handle them
```

**During Implementation:**
```python
If something fails → Record failure
If something succeeds → Record success
Always → Update knowledge base
```

**After Implementation:**
```python
Calculate success metrics:
- Time taken
- Success/failure
- Confidence score accuracy

Add to success_metrics.yaml
```

---

## 📊 Confidence Scoring Guide

When generating a plan, assign confidence (1-10):

**9-10 (High Confidence):**
- Tech stack well-known
- Similar feature done before
- Clear documentation
- No platform-specific issues

**6-8 (Medium Confidence):**
- Some unknowns
- New library combination
- Moderate complexity
- Minor platform differences

**1-5 (Low Confidence):**
- Unfamiliar tech stack
- No similar examples
- High complexity
- Major platform differences

**Use confidence to:**
- Warn user of risks
- Request clarification
- Add extra validation

---

## 🔍 Quality Checklist

Before marking feature complete, verify:

### Code Quality
- [ ] Follows PROJECT_CONTEXT.md structure
- [ ] Matches GLOBAL_RULES.md standards
- [ ] No hard-coded values
- [ ] Proper error handling
- [ ] TypeScript types defined

### Mobile-Specific
- [ ] Works on iOS simulator
- [ ] Works on Android emulator
- [ ] Platform-specific code handled
- [ ] Permissions configured
- [ ] Images optimized

### Security
- [ ] No sensitive data logged
- [ ] Tokens in secure storage
- [ ] User input validated
- [ ] API calls authenticated

### Testing
- [ ] Unit tests written
- [ ] Manual testing done
- [ ] Both platforms tested
- [ ] Edge cases handled

---

## 💡 Pro Tips for Agents

### Tip 1: Context is King
More context in PROJECT_CONTEXT.md = Better results  
Always ask user to fill it completely

### Tip 2: Check Before Coding
5 minutes of validation saves 30 minutes of debugging  
Read failure patterns BEFORE implementing

### Tip 3: Platform Awareness
iOS and Android are different  
Always test both, handle differences explicitly

### Tip 4: Learn from Everything
Success or failure → Update knowledge base  
Every implementation teaches the system

### Tip 5: Communicate Confidence
Low confidence? Tell the user BEFORE building  
High confidence? Still validate thoroughly

---

## 🎯 Success Metrics

Track these for every feature:

```yaml
feature_name: "user-authentication"
started_at: "2024-02-08T10:00:00Z"
completed_at: "2024-02-08T10:45:00Z"
implementation_time_minutes: 45
success: true
confidence_score: 8
platforms_tested: ["ios", "android"]
issues_encountered: []
patterns_used:
  - "secure-token-storage"
  - "supabase-auth-flow"
```

---

## 📚 Quick Reference

| Question | Answer Found In |
|----------|----------------|
| What tech stack? | PROJECT_CONTEXT.md |
| What to build? | INITIAL.md |
| How to structure code? | GLOBAL_RULES.md |
| What's the process? | mobile_feature.md |
| What failed before? | failure_patterns.yaml |
| What worked before? | success_metrics.yaml |

---

**This structure guide ensures agents build mobile features correctly, consistently, and efficiently.** 🤖
