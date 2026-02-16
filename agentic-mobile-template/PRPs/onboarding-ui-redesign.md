# PRP: Onboarding UI Redesign

## Feature: 7-Screen Premium Onboarding Flow
**Confidence Score**: 8/10
**Priority**: Phase 2b (immediately after scaffold + auth)
**Status**: Planned

## Requirements

### Design Inspiration
- Apple Health aesthetic
- Clean, minimal, calm, premium subscription feel
- No clutter, no gamification, no emojis

### Target Users
- Busy professionals
- Parents managing family wellness
- General wellness users

### Tone
Confident, calm, intelligent. Not motivational hype. Not clinical.

## Screen Specifications

### Screen 1 — Welcome
- Headline: "Your health. Intelligently managed."
- Subtext: "We learn your patterns and guide your progress."
- Primary: Continue button
- Secondary: "Already have an account?" link to login
- No illustrations, no heavy gradients
- Soft off-white background (light) / near-black (dark)
- Accent: calm blue/teal

### Screen 2 — Primary Goal Selection
- Headline: "What would feel like progress right now?"
- Subtext: "Choose your current focus."
- 6 selectable cards (grid or vertical):
  - Improve Performance
  - Reduce Stress
  - Improve Sleep
  - Build Strength
  - Lose Fat
  - General Wellness
- Card style: minimal icon, soft border, rounded corners, subtle press animation
- Selected state: thin accent border + soft background tint
- Single selection only

### Screen 3 — Focus Intensity
- Headline: "How important is this right now?"
- Horizontal slider: Low | Moderate | High | Top Priority
- Subtext: "We'll tailor your recommendations accordingly."
- Clean slider, no technical explanation

### Screen 4 — Quick Profile Snapshot
- Minimal form, large spacing
- Fields: Age, Height (cm), Weight (kg), Activity Level (slider)
- Activity slider: Low → Moderate → High
- No dense forms, no medical language

### Screen 5 — Connect Devices (Optional)
- Headline: "Connect your data"
- Options: Garmin, Strava, Skip for now
- Footnote: "You can connect later in Settings."
- Minimal, no long explanations

### Screen 6 — 21-Day Focus Introduction
- Headline: "Your 21-Day Focus Begins"
- Subtext: "We use 21-day cycles to learn your patterns and optimise your progress."
- Display: Focus: [Selected Goal], Duration: 21 Days
- Primary: "Begin" button
- Premium tone, no gamification, no countdown graphics

### Screen 7 — Baseline Summary
- Loading state: "Building your baseline..."
- Then show "Your Starting Snapshot":
  - Target sleep
  - Suggested weekly load
  - Focus priority
  - Key metric to monitor
- Primary: "Enter WellTrack"
- No fireworks, no celebration animation

## Database Impact

### wt_profiles updates needed
- `primary_goal` text field (e.g., 'performance', 'stress', 'sleep', 'strength', 'fat_loss', 'wellness')
- `goal_intensity` text field (e.g., 'low', 'moderate', 'high', 'top_priority')

### wt_users updates
- `onboarding_completed` boolean (already exists)

## Visual System

### Colors
- Accent: calm teal/blue (#0D9488 or similar)
- Light bg: soft off-white (#F8F9FA)
- Dark bg: near-black (#121212)
- Text: high contrast but not harsh

### Typography
- Large headlines (headlineMedium or larger)
- Generous line height
- High whitespace between elements

### Transitions
- PageView with smooth horizontal slide
- Light haptic feedback on goal card selection
- No loud animations

## Goal-to-Dashboard Intelligence

| Goal | Primary Dashboard Metrics |
|------|--------------------------|
| Improve Performance | VO2 max + Recovery |
| Reduce Stress | Stress Score + Sleep |
| Improve Sleep | Sleep Quality + Consistency |
| Build Strength | Workouts + Nutrition |
| Lose Fat | Nutrition + Activity |
| General Wellness | Balanced overview |

## Navigation Rules
- ALL navigation uses GoRouter
- Onboarding complete → `context.go('/')`
- "Already have account" → `context.go('/login')`
- NEVER use Navigator.pushNamed or Navigator.pushReplacementNamed

## Success Criteria
- [ ] 7 screens render correctly in light and dark mode
- [ ] Goal selection persists to wt_profiles
- [ ] Focus intensity persists to wt_profiles
- [ ] Profile data (age/height/weight/activity) persists
- [ ] Device connection screen shows Garmin/Strava options
- [ ] 21-day focus displays selected goal
- [ ] Baseline summary shows calculated defaults
- [ ] Navigation to dashboard works via GoRouter
- [ ] onboardingCompleteProvider updated on completion
- [ ] No Navigator 1.0 API usage anywhere in flow

## Known Patterns / Failure Prevention
- NEVER use `Navigator.pushNamed()` — always GoRouter `context.go()`
- Dashboard route is `/` not `/dashboard`
- Update `onboardingCompleteProvider` before navigating to dashboard
- The signup trigger creates a primary profile — onboarding should UPDATE it, not INSERT a duplicate
- `wt_users.onboarding_completed` tracks completion, not `wt_profiles`
- Email is in `auth.users`, not `wt_users` — never query email from wt_users
