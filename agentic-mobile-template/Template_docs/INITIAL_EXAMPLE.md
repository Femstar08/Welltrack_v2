# Feature Request: User Authentication Flow

> This is an example INITIAL.md showing how to fully describe a feature request.

## 🎯 FEATURE

**What are you building?**

Build a complete user authentication system for a mobile app that includes:

**Core Features:**
- Email/password signup with email verification
- Email/password login
- Social authentication (Google and Apple Sign-In)
- Forgot password flow with email reset link
- Change password (for logged-in users)
- Persistent sessions with secure token storage
- Auto-login on app launch if valid session exists
- Logout functionality

**User Experience:**
- Smooth transitions between auth screens
- Loading states for all async operations
- Clear error messages for failed operations
- Success feedback for completed actions
- Remember me option (optional)

**Security Requirements:**
- Store tokens in secure storage (Keychain/Keystore)
- Implement token refresh logic
- Never log sensitive data
- Validate all inputs client-side
- Handle rate limiting gracefully

---

## 🏗️ TECH STACK

**Platform/Framework:**
- [X] Expo (managed workflow)
- [ ] React Native (bare workflow)
- [ ] Next.js/React
- [ ] FastAPI/Python
- [ ] Other: ___________

**Navigation** (mobile only):
- [X] Expo Router
- [ ] React Navigation
- [ ] Native navigation
- [ ] N/A

**Authentication:**
- [X] Supabase Auth
- [ ] Firebase Auth
- [ ] Custom JWT
- [ ] Auth0
- [ ] Clerk
- [ ] None needed
- [ ] Other: ___________

**State Management:**
- [X] Zustand
- [ ] Redux Toolkit
- [ ] Context API
- [ ] Jotai
- [ ] Recoil
- [ ] None needed
- [ ] Other: ___________

**Backend/Database:**
- [X] Supabase
- [ ] Firebase
- [ ] Custom REST API
- [ ] GraphQL
- [ ] PostgreSQL (direct)
- [ ] None needed
- [ ] Other: ___________

**Styling** (web/mobile):
- [X] NativeWind (Tailwind for React Native)
- [ ] Tailwind CSS
- [ ] Styled Components
- [ ] CSS Modules
- [ ] Vanilla CSS
- [ ] Other: ___________

**Additional Libraries/Services:**
```
- expo-secure-store - For secure token storage
- react-hook-form - For form handling and validation
- zod - For schema validation
- @react-native-google-signin/google-signin - For Google auth
- expo-apple-authentication - For Apple auth
- expo-web-browser - For OAuth web views
```

---

## 📝 EXAMPLES

**Code patterns to follow:**

```
If you have existing auth patterns:
- examples/auth/supabase-setup.ts - Follow this Supabase client setup
- examples/state/auth-store.ts - Use this store structure
- examples/components/AuthInput.tsx - Mimic this input component pattern
- examples/navigation/auth-stack.tsx - Follow this navigation structure

If starting fresh, the agent will create these patterns.
```

**Anti-patterns to avoid:**

```
- Don't store tokens in AsyncStorage; use Expo SecureStore
- Don't expose API keys in client code; use environment variables
- Avoid synchronous crypto operations; they block the JS thread
- Don't navigate immediately after login; wait for state to update
- Never log user credentials or tokens, even in development
```

---

## 📚 DOCUMENTATION

**Official documentation URLs:**

```
Supabase Auth:
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/auth/social-login
- https://supabase.com/docs/guides/auth/server-side/email-based-auth-with-pkce-flow-for-ssr

Expo Router:
- https://docs.expo.dev/router/introduction/
- https://docs.expo.dev/router/reference/authentication/

Expo Secure Store:
- https://docs.expo.dev/versions/latest/sdk/securestore/

React Hook Form:
- https://react-hook-form.com/get-started

Zod:
- https://zod.dev/

Social Auth:
- https://docs.expo.dev/guides/google-authentication/
- https://docs.expo.dev/versions/latest/sdk/apple-authentication/
```

**Internal documentation:**

```
[If you have internal docs, link them here]
- Notion: Design System Guidelines
- Confluence: Security Best Practices
- etc.
```

---

## ⚠️ OTHER CONSIDERATIONS

**Gotchas and edge cases:**

```
Expo Router Specific:
- Auth flow must use (auth) group for unauthenticated routes
- Protected routes go in (app) group
- Use Redirect component, not router.push(), for auth redirects
- Initial route checks must complete before rendering

Supabase Specific:
- Sessions expire after 1 hour by default; implement refresh logic
- Email verification required by default; handle unverified state
- Magic links work but need proper URL scheme configuration
- Social auth requires redirect URLs in Supabase dashboard

iOS Specific:
- Apple Sign In required if offering other social logins
- NSFaceIDUsageDescription needed for biometric unlock
- Keychain access requires proper entitlements
- Universal Links config needed for magic links

Android Specific:
- SHA-1 fingerprint needed for Google Sign In
- Deep link handling different from iOS
- Keystore access requires additional permissions
- Email verification links must handle intent filters

General:
- Network errors should be handled gracefully
- Rate limiting (6 emails per hour on Supabase free tier)
- Development vs production redirect URLs
- Email templates should match app branding
```

**Performance requirements:**

```
- Login should complete in < 2 seconds on good connection
- Form validation should be instant (< 100ms)
- Token refresh should happen in background
- App should handle offline state gracefully
- Auto-login should not delay app startup
```

**Security requirements:**

```
- Use Expo SecureStore for all sensitive data
- Implement token refresh before expiration
- Validate all inputs with Zod schemas
- Use HTTPS for all API calls
- Implement exponential backoff for failed attempts
- Clear sensitive data on logout
- Handle session invalidation server-side
```

**Testing requirements:**

```
Unit Tests:
- Auth service methods
- Form validation logic
- Token refresh logic
- Store actions

Integration Tests:
- Complete login flow
- Complete signup flow
- Password reset flow
- Social auth flows

E2E Tests (optional):
- End-to-end user journey
- Cross-platform testing
```

---

## ✅ SUCCESS CRITERIA

**How do you know this feature is complete and working?**

**Functional Requirements:**
- [ ] User can sign up with email/password
- [ ] User receives verification email
- [ ] User can verify email via link
- [ ] User can log in with verified account
- [ ] User can log in with Google (if available)
- [ ] User can log in with Apple (iOS only)
- [ ] User can request password reset
- [ ] User receives password reset email
- [ ] User can reset password via link
- [ ] Logged-in user can change password
- [ ] User can log out
- [ ] Session persists across app restarts
- [ ] Token refreshes automatically before expiry
- [ ] App auto-logs in on launch if session valid

**Technical Requirements:**
- [ ] All sensitive data stored in SecureStore
- [ ] No tokens/passwords logged to console
- [ ] All API calls have error handling
- [ ] Loading states shown for all async operations
- [ ] Clear error messages for all failures
- [ ] Input validation prevents bad data
- [ ] Navigation flows work correctly
- [ ] Works on both iOS and Android
- [ ] No memory leaks in auth flow

**Quality Requirements:**
- [ ] Unit tests pass (>80% coverage)
- [ ] Integration tests pass
- [ ] No ESLint errors
- [ ] No TypeScript errors
- [ ] Builds successfully on both platforms
- [ ] No console warnings

---

## 🎨 UI/UX NOTES

**Design references:**

```
Follow Material Design 3 / iOS HIG:
- Use native keyboard types (email, password)
- Implement proper focus management
- Show/hide password toggle
- Loading spinners for async operations
- Success animations on completion
- Error messages below fields
- Accessible form labels

Design System:
- Use project's Button component
- Use project's Input component
- Use project's theme colors
- Follow spacing guidelines (8px grid)
- Match typography scale
```

**Screens Needed:**
1. Welcome/Landing (with Login/Sign Up buttons)
2. Login
3. Sign Up
4. Forgot Password
5. Check Email (after signup/reset)
6. Profile/Settings (for change password)

**Accessibility requirements:**

```
- All inputs must have accessible labels
- Support screen readers
- Minimum touch targets: 44x44 points
- Color contrast ratio: 4.5:1 minimum
- Support dynamic font sizes
- Keyboard navigation support (web)
```

---

## 🚀 DEPLOYMENT NOTES

**Where will this be deployed?**

```
Development:
- Expo Go for initial testing

Staging:
- TestFlight (iOS)
- Google Play Internal Track (Android)

Production:
- App Store (iOS)
- Google Play (Android)
```

**Environment variables needed:**

```
# .env
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
EXPO_PUBLIC_GOOGLE_CLIENT_ID=your-google-client-id
EXPO_PUBLIC_APPLE_CLIENT_ID=your-apple-client-id
EXPO_PUBLIC_API_URL=https://api.yourapp.com

# Different per environment:
# .env.development
# .env.staging  
# .env.production
```

---

## 📅 TIMELINE

**When is this needed?**

Target: Sprint 1 (2 weeks)

**Priority:**
- [X] Critical (blocks other work)
- [ ] High (needed soon)
- [ ] Medium (important but not urgent)
- [ ] Low (nice to have)

---

## 💭 ADDITIONAL CONTEXT

**Why we're building this:**
- Current app has no user accounts
- Need personalization features
- Required for user-generated content
- Preparing for paid features

**User feedback:**
- Users want to save preferences
- Requested social login for convenience
- Asked for biometric unlock (Phase 2)

**Future considerations:**
- Phase 2: Biometric authentication
- Phase 2: Multi-device session management
- Phase 3: Two-factor authentication
- Phase 3: Account deletion flow

**Known constraints:**
- Supabase free tier: 50,000 monthly active users
- Email sending limits on free tier
- Must comply with GDPR for EU users
- Need Terms of Service before launch

---

## 🎯 AGENT INSTRUCTIONS

Once you've filled this out:

1. Save this file as `INITIAL.md`
2. Run: `/generate-prp INITIAL.md`
3. Review the generated PRP in `PRPs/user-authentication.md`
4. If it looks good, run: `/execute-prp PRPs/user-authentication.md`
5. Let the agent implement, test, and learn

**Note to agent:**
- This is a complex, multi-step feature
- Follow the mobile_feature_development directive
- Pay special attention to security requirements
- Test thoroughly on both platforms
- Update knowledge base with any Supabase gotchas discovered
