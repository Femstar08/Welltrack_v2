# Feature Request Template

> Fill this out to describe what you want to build. The agent will use this to generate a comprehensive PRP.

## 🎯 FEATURE

**What are you building?**

[Describe the feature clearly and completely. Be specific about functionality, user experience, and requirements.]

**Example:**
```
Build a user authentication flow for the mobile app that includes:
- Email/password login and signup
- Social login (Google, Apple)
- Forgot password flow
- Email verification
- Persistent sessions with secure token storage
- Auto-login on app open if session valid
```

---

## 🏗️ TECH STACK

**Platform/Framework:**
- [ ] React Native (bare workflow)
- [ ] Expo (managed workflow)
- [ ] Next.js/React
- [ ] FastAPI/Python
- [ ] Other: ___________

**Navigation** (mobile only):
- [ ] Expo Router
- [ ] React Navigation
- [ ] Native navigation
- [ ] N/A

**Authentication:**
- [ ] Supabase Auth
- [ ] Firebase Auth
- [ ] Custom JWT
- [ ] Auth0
- [ ] Clerk
- [ ] None needed
- [ ] Other: ___________

**State Management:**
- [ ] Zustand
- [ ] Redux Toolkit
- [ ] Context API
- [ ] Jotai
- [ ] Recoil
- [ ] None needed
- [ ] Other: ___________

**Backend/Database:**
- [ ] Supabase
- [ ] Firebase
- [ ] Custom REST API
- [ ] GraphQL
- [ ] PostgreSQL (direct)
- [ ] None needed
- [ ] Other: ___________

**Styling** (web/mobile):
- [ ] Tailwind CSS
- [ ] NativeWind (Tailwind for React Native)
- [ ] Styled Components
- [ ] CSS Modules
- [ ] Vanilla CSS
- [ ] Other: ___________

**Additional Libraries/Services:**
```
List any specific libraries or services this feature needs:
- Stripe for payments
- react-query for data fetching
- Expo notifications
- etc.
```

---

## 📝 EXAMPLES

**Code patterns to follow:**

[Reference specific files in the `examples/` directory that show patterns you want to mimic]

**Example:**
```
- examples/auth/supabase-auth.ts - Follow this pattern for auth setup
- examples/navigation/protected-routes.tsx - Use this approach for route protection
- examples/state/user-store.ts - Mimic this Zustand store structure
```

**Anti-patterns to avoid:**

[Mention any patterns you explicitly DON'T want to use]

**Example:**
```
- Don't use AsyncStorage directly; use our secure storage wrapper
- Avoid inline styles; use our theme system
- No prop drilling; use state management for shared state
```

---

## 📚 DOCUMENTATION

**Official documentation URLs:**

[Include links to relevant docs, APIs, or guides]

**Example:**
```
- Supabase Auth: https://supabase.com/docs/guides/auth
- Expo Router: https://expo.github.io/router/docs/
- React Navigation: https://reactnavigation.org/docs/getting-started
```

**Internal documentation:**

[Link to any internal docs, Notion pages, Confluence, etc.]

---

## ⚠️ OTHER CONSIDERATIONS

**Gotchas and edge cases:**

[Mention anything that typically trips up AI or is commonly missed]

**Example:**
```
- Expo Router requires specific file structure; don't deviate
- Supabase sessions expire; implement refresh token logic
- iOS requires NSCameraUsageDescription in app.json for camera access
- Android requires permissions in AndroidManifest.xml
```

**Performance requirements:**

[Any specific performance needs]

**Example:**
```
- Login should complete in < 2 seconds
- Image uploads must show progress
- Offline support needed for core features
```

**Security requirements:**

[Any security considerations]

**Example:**
```
- Store tokens in secure storage (Keychain/Keystore)
- Never log sensitive data
- Implement rate limiting on API calls
- Validate all user inputs
```

**Testing requirements:**

[What tests are needed]

**Example:**
```
- Unit tests for auth logic
- Integration tests for API calls
- E2E tests for login/signup flows
```

---

## ✅ SUCCESS CRITERIA

**How do you know this feature is complete and working?**

[List specific, measurable criteria]

**Example:**
```
- [ ] User can sign up with email/password
- [ ] User receives verification email
- [ ] User can log in with verified account
- [ ] User can log in with Google/Apple
- [ ] Session persists across app restarts
- [ ] User can reset password
- [ ] All auth flows have error handling
- [ ] Unit tests pass (>80% coverage)
- [ ] Integration tests pass
- [ ] No console errors or warnings
```

---

## 🎨 UI/UX NOTES

**Design references:**

[Link to Figma, mockups, or describe the UI]

**Example:**
```
- Figma: https://figma.com/file/xyz
- Follow Material Design guidelines for Android
- Follow HIG for iOS
- Use our design system components
```

**Accessibility requirements:**

[Any a11y needs]

**Example:**
```
- All inputs must have labels
- Support screen readers
- Minimum touch target: 44x44 points
- Color contrast ratio: 4.5:1
```

---

## 🚀 DEPLOYMENT NOTES

**Where will this be deployed?**

[Staging, production, app stores, etc.]

**Example:**
```
- Deploy to Expo Go for testing
- Submit to TestFlight for iOS beta
- Upload to Google Play internal track
```

**Environment variables needed:**

[List any env vars]

**Example:**
```
- SUPABASE_URL
- SUPABASE_ANON_KEY
- GOOGLE_CLIENT_ID
- APPLE_CLIENT_ID
```

---

## 📅 TIMELINE

**When is this needed?**

[Optional: Add deadline or urgency]

**Priority:**
- [ ] Critical (blocks other work)
- [ ] High (needed soon)
- [ ] Medium (important but not urgent)
- [ ] Low (nice to have)

---

## 💭 ADDITIONAL CONTEXT

[Anything else the agent should know]

**Example:**
```
- This is part of a larger onboarding redesign
- We're planning to add biometric auth in v2
- User feedback indicated password resets are confusing
- Current auth system is legacy and needs replacement
```

---

## 🎯 AGENT INSTRUCTIONS

Once you've filled this out:

1. Save this file
2. Run: `/generate-prp INITIAL.md`
3. Review the generated PRP in `PRPs/your-feature-name.md`
4. Run: `/execute-prp PRPs/your-feature-name.md`
5. Let the agent implement, test, and learn

The more detail you provide here, the better the PRP and implementation will be.
