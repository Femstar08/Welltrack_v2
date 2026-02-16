# Mobile App Project Context

> Project-specific rules and context for this React Native/Expo application.

## 📱 Tech Stack

**Platform:**
- React Native: [specify version]
- Workflow: [ ] Expo Managed / [ ] Bare / [ ] Native

**Navigation:**
- Library: [Expo Router / React Navigation / Native]
- Strategy: [Stack / Tabs / Drawer / Hybrid]

**State Management:**
- Global State: [Zustand / Redux / Context / Jotai]
- Server State: [React Query / SWR / Apollo / None]

**Authentication:**
- Provider: [Supabase / Firebase / Custom JWT / Auth0 / Clerk]
- Strategy: [Email/Password / Social / Biometric / Magic Link]

**Backend:**
- Type: [Supabase / Firebase / Custom REST / GraphQL / tRPC]
- Database: [Supabase / Firebase / PostgreSQL / MongoDB]

**Styling:**
- Approach: [NativeWind / Tailwind / Styled Components / StyleSheet]
- Theme: [Custom / System / Both]

**Key Libraries:**
```
List critical dependencies:
- @react-navigation/native (if used)
- zustand (if used)  
- expo-router (if used)
- react-query (if used)
- etc.
```

---

## 🏗️ Project Architecture

### Directory Structure

```
src/
├── app/              # Expo Router pages (if using Expo Router)
│   ├── (auth)/      # Auth-protected routes
│   ├── (tabs)/      # Tab navigation
│   └── index.tsx    # Entry point
├── screens/         # Full-screen components (if using React Navigation)
│   ├── auth/
│   ├── onboarding/
│   └── main/
├── components/      # Reusable UI components
│   ├── common/      # Shared across app
│   ├── auth/        # Auth-specific
│   └── [feature]/   # Feature-specific
├── services/        # API clients, external services
│   ├── api/         # API client
│   ├── auth/        # Auth service
│   └── storage/     # Local storage wrapper
├── stores/          # State management
│   ├── authStore.ts
│   ├── userStore.ts
│   └── [feature]Store.ts
├── hooks/           # Custom React hooks
│   ├── useAuth.ts
│   ├── useApi.ts
│   └── [feature hooks]
├── utils/           # Helper functions
│   ├── validation.ts
│   ├── formatting.ts
│   └── constants.ts
├── types/           # TypeScript definitions
│   ├── api.types.ts
│   ├── models.types.ts
│   └── navigation.types.ts
├── assets/          # Images, fonts, etc.
│   ├── images/
│   ├── icons/
│   └── fonts/
└── config/          # App configuration
    ├── theme.ts
    ├── api.config.ts
    └── env.ts
```

---

## 🎨 Design System

### Theme Configuration

**Colors:**
```typescript
const colors = {
  primary: '#your-primary',
  secondary: '#your-secondary',
  background: '#your-bg',
  text: '#your-text',
  error: '#your-error',
  // ... etc
};
```

**Typography:**
```typescript
const typography = {
  heading1: { fontSize: 32, fontWeight: 'bold' },
  heading2: { fontSize: 24, fontWeight: 'bold' },
  body: { fontSize: 16, fontWeight: 'normal' },
  // ... etc
};
```

**Spacing:**
```typescript
const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
};
```

### Component Patterns

**Button:**
```typescript
<Button 
  variant="primary" // primary | secondary | outline
  size="md"         // sm | md | lg
  onPress={handlePress}
>
  Button Text
</Button>
```

**Input:**
```typescript
<Input
  label="Email"
  placeholder="Enter email"
  error={errors.email}
  value={email}
  onChangeText={setEmail}
/>
```

---

## 🔐 Authentication Flow

### Strategy

[Describe your auth flow: e.g., "Email/password with email verification, social login via Google/Apple, and biometric unlock for returning users"]

### Implementation

**Auth Service Location:** `src/services/auth/`

**Auth Store Location:** `src/stores/authStore.ts`

**Protected Routes:** 
- [List which routes require authentication]
- [How are they protected? HOC, wrapper, middleware?]

**Token Management:**
- Storage: [SecureStore / Keychain / AsyncStorage with encryption]
- Refresh Strategy: [Automatic / Manual / Background]

---

## 🌐 API Integration

### Base Configuration

**API Base URL:** 
- Development: [URL]
- Staging: [URL]
- Production: [URL]

**Client Location:** `src/services/api/client.ts`

### Request/Response Pattern

```typescript
// Standard API call pattern
const response = await apiClient.get<ResponseType>('/endpoint');

// With error handling
try {
  const data = await apiClient.post('/endpoint', payload);
  return data;
} catch (error) {
  if (error instanceof NetworkError) {
    // Handle network issues
  } else if (error instanceof AuthError) {
    // Handle auth issues  
  }
  throw error;
}
```

### Authentication Headers

```typescript
headers: {
  'Authorization': `Bearer ${token}`,
  'Content-Type': 'application/json',
}
```

---

## 💾 Data Management

### Local Storage

**Library:** [Expo SecureStore / AsyncStorage / react-native-keychain]

**Usage:**
```typescript
// Sensitive data (tokens, passwords)
await SecureStore.setItemAsync('auth_token', token);

// Non-sensitive data (preferences, cache)
await AsyncStorage.setItem('user_preferences', JSON.stringify(prefs));
```

### State Persistence

**Persisted State:**
- Auth tokens
- User preferences
- [Other persisted data]

**Non-Persisted State:**
- Temporary UI state
- Form values
- [Other transient data]

---

## 🧪 Testing Strategy

### Unit Tests

**Location:** `src/**/__tests__/`

**What to Test:**
- Services (API clients, auth)
- Stores (state management logic)
- Utilities (helpers, formatters)
- Hooks (custom hooks)

**Example:**
```typescript
describe('authService', () => {
  it('should login user with valid credentials', async () => {
    const result = await authService.login('test@example.com', 'password');
    expect(result).toHaveProperty('token');
  });
});
```

### Integration Tests

**What to Test:**
- Complete user flows
- API integrations
- Navigation flows

### E2E Tests

**Tool:** [Detox / Maestro / Appium]

**Critical Flows:**
- Sign up → verification → login
- [Other critical flows]

---

## 📱 Platform-Specific Considerations

### iOS

**Permissions Required:**
```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>We need camera access for [reason]</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access for [reason]</string>
```

**Capabilities:**
- [ ] Push Notifications
- [ ] Background Modes
- [ ] Sign in with Apple
- [ ] [Other capabilities]

### Android

**Permissions Required:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

**Build Configuration:**
- Min SDK: [version]
- Target SDK: [version]
- Compile SDK: [version]

---

## 🚀 Build & Deployment

### Development

```bash
# Start development server
npm start

# Run on iOS simulator
npm run ios

# Run on Android emulator  
npm run android
```

### Staging

**Build Commands:**
```bash
# iOS
eas build --platform ios --profile staging

# Android
eas build --platform android --profile staging
```

**Distribution:**
- iOS: TestFlight
- Android: Internal Track

### Production

**Build Commands:**
```bash
# iOS
eas build --platform ios --profile production

# Android  
eas build --platform android --profile production
```

**Submission:**
```bash
# iOS
eas submit --platform ios

# Android
eas submit --platform android
```

---

## 🔧 Environment Variables

**Required Variables:**
```bash
# .env
API_BASE_URL=https://api.example.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_CLIENT_ID=your-client-id
APPLE_CLIENT_ID=your-client-id
```

**Loading:**
```typescript
import Constants from 'expo-constants';

const config = {
  apiUrl: Constants.expoConfig?.extra?.apiUrl,
  // ... other config
};
```

---

## 🐛 Known Issues & Gotchas

### General

- [Issue 1 and workaround]
- [Issue 2 and workaround]

### iOS-Specific

- [iOS-specific issue and workaround]

### Android-Specific

- [Android-specific issue and workaround]

---

## 📊 Performance Targets

**App Metrics:**
- Cold start: < 3 seconds
- Hot start: < 1 second
- Screen transition: < 300ms
- API response handling: < 500ms

**Bundle Size:**
- Target: < 50MB (iOS)
- Target: < 30MB (Android)

---

## 🔄 State Management Patterns

### Zustand Example (if using)

```typescript
// src/stores/authStore.ts
import { create } from 'zustand';

interface AuthStore {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  token: null,
  login: async (email, password) => {
    const { user, token } = await authService.login(email, password);
    set({ user, token });
  },
  logout: () => set({ user: null, token: null }),
}));
```

### Usage

```typescript
// In components
const { user, login } = useAuthStore();
```

---

## 📝 Additional Notes

[Any other project-specific information, conventions, or decisions that the agent should know about]

---

## ✅ Pre-Flight Checklist

Before starting development, ensure:

- [ ] All environment variables configured
- [ ] API access verified
- [ ] Development certificates installed (iOS)
- [ ] Emulators/simulators set up
- [ ] Dependencies installed (`npm install`)
- [ ] Project builds successfully
- [ ] Examples reviewed in `examples/`

---

This context file is your project's source of truth. Keep it updated as decisions are made and patterns emerge.
