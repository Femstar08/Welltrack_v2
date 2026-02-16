# 📱 Mobile App Template - Complete Package

> Everything you need to build React Native/Expo mobile apps with AI agents

## 📦 What's In This Package

```
mobile-template/
├── README.md                           ← You are here
├── STRUCTURE_GUIDE.md                  ← How the agent understands this
├── PROJECT_CONTEXT.md                  ← Define your mobile app's tech stack
├── INITIAL.md                          ← Template for feature requests
├── INITIAL_EXAMPLE.md                  ← Complete example
├── .agent/
│   ├── context/
│   │   └── GLOBAL_RULES.md            ← Universal coding standards
│   ├── orchestration/
│   │   ├── directives/
│   │   │   └── mobile_feature.md      ← How to build mobile features
│   │   └── knowledge_base/
│   │       ├── failure_patterns.yaml
│   │       ├── success_metrics.yaml
│   │       ├── template_versions.yaml
│   │       └── library_gotchas.yaml
│   └── execution/
│       └── context_utils.py           ← ML learning system
└── requirements.txt                    ← Python dependencies

```

---

## 🎯 What This Template Does

Helps AI agents build mobile app features by:
1. **Understanding** your tech stack (React Native/Expo, navigation, auth, etc.)
2. **Learning** from successes and failures
3. **Preventing** common mobile development mistakes
4. **Generating** production-ready code

---

## ⚡ Quick Start (5 minutes)

### Step 1: Copy to Your Project

```bash
# Your mobile project
cd my-mobile-app

# Copy this entire template
cp -r /path/to/mobile-template/* .
cp -r /path/to/mobile-template/.agent .
```

### Step 2: Initialize

```bash
# Install Python dependencies (for ML system)
pip install -r requirements.txt

# Initialize knowledge base
python .agent/execution/context_utils.py init
```

You'll see:
```
🧠 Initializing knowledge base...
  ✓ Created failure_patterns.yaml
  ✓ Created success_metrics.yaml
  ✓ Created template_versions.yaml
  ✓ Created library_gotchas.yaml
✅ Knowledge base initialized!
```

### Step 3: Configure Your Stack

Edit `PROJECT_CONTEXT.md` and fill in YOUR choices:

```markdown
## 📱 Tech Stack

**Platform:**
- React Native: 0.73
- Workflow: [X] Expo Managed

**Navigation:**
- Library: Expo Router
- Strategy: File-based routing

**State Management:**
- Global State: Zustand
- Server State: React Query

**Authentication:**
- Provider: Supabase
- Strategy: Email/Password + OAuth

# ... etc
```

### Step 4: Build Your First Feature

Edit `INITIAL.md` with what you want to build:

```markdown
## 🎯 FEATURE

User authentication with email/password and Google OAuth

## 🏗️ TECH STACK
[Fill in using PROJECT_CONTEXT.md]

## 📝 EXAMPLES TO FOLLOW
[Add code patterns you like]
```

Then tell your AI agent:
```
Read INITIAL.md and build this feature following the directive in .agent/orchestration/directives/mobile_feature.md
```

---

## 🧠 How The Agent Understands This

### File Reading Order

The agent should read files in this order:

1. **PROJECT_CONTEXT.md** - Understands your tech stack
2. **INITIAL.md** - Understands what to build
3. **`.agent/context/GLOBAL_RULES.md`** - Follows coding standards
4. **`.agent/orchestration/directives/mobile_feature.md`** - Follows the process
5. **`.agent/orchestration/knowledge_base/*.yaml`** - Learns from past

### Agent Process (Automatic)

```
1. Read PROJECT_CONTEXT.md → Know tech stack
2. Read INITIAL.md → Know requirements
3. Check knowledge_base/ → Load failure patterns
4. Generate implementation plan
5. Validate before coding
6. Build feature
7. Test on iOS & Android
8. Record success/failure metrics
9. Update knowledge base
```

---

## 📋 Template Structure Explained

### Core Files (You Edit These)

**PROJECT_CONTEXT.md**
- Your mobile app's tech stack
- Navigation patterns
- Auth configuration
- State management
- Directory structure
- Design system

**INITIAL.md**
- Template for feature requests
- Tells agent WHAT to build
- Include tech stack, examples, gotchas

**INITIAL_EXAMPLE.md**
- Complete example showing best practices
- Use as reference when writing INITIAL.md

### Agent Files (Agent Uses These)

**`.agent/context/GLOBAL_RULES.md`**
- Universal coding standards
- File naming conventions
- Security requirements
- Testing standards

**`.agent/orchestration/directives/mobile_feature.md`**
- Step-by-step process for building features
- Research → Plan → Validate → Build → Test → Learn

**`.agent/orchestration/knowledge_base/*.yaml`**
- Machine learning data storage
- Failure patterns that emerged
- Success metrics tracked
- Library-specific gotchas

**`.agent/execution/context_utils.py`**
- Python script for ML operations
- Add failures, track successes, generate reports

---

## 🎯 Common Use Cases

### Build Authentication

```markdown
# INITIAL.md

## 🎯 FEATURE
User authentication with Supabase

## 🏗️ TECH STACK
- Platform: Expo Managed
- Auth: Supabase Auth
- Storage: SecureStore for tokens
- State: Zustand for auth state

## 📝 SUCCESS CRITERIA
- User can sign up with email
- User can log in
- Tokens stored securely
- Auth state persists
```

### Add Navigation

```markdown
# INITIAL.md

## 🎯 FEATURE
Tab navigation with protected routes

## 🏗️ TECH STACK
- Navigation: Expo Router
- Auth: Already implemented
- Protected: (auth) route group

## 📝 SUCCESS CRITERIA
- 4 tabs: Home, Profile, Settings, More
- Only logged-in users can access
```

### API Integration

```markdown
# INITIAL.md

## 🎯 FEATURE
Connect to Supabase API for user data

## 🏗️ TECH STACK
- API: Supabase REST API
- State: React Query for server state
- Types: TypeScript with generated types

## 📝 SUCCESS CRITERIA
- Fetch user profile
- Update user profile
- Loading and error states
```

---

## 📊 ML System Tracking

### View Failure Patterns

```bash
python .agent/execution/context_utils.py get-patterns react-native
```

### View Success Metrics

```bash
python .agent/execution/context_utils.py get-metrics authentication
```

### Generate Report

```bash
python .agent/execution/context_utils.py generate-report 30
```

Output:
```json
{
  "period_days": 30,
  "total_implementations": 15,
  "avg_implementation_time": 32.5,
  "avg_success_rate": 89.2,
  "most_common_patterns": [
    "Async storage access",
    "Navigation typing"
  ]
}
```

---

## 🎓 Learning Progression

**First 5 Features:**
- Agent relies on your examples
- May need guidance
- Builds knowledge base

**After 10 Features:**
- Agent recognizes common patterns
- Predicts platform-specific issues
- Higher success rate

**After 20 Features:**
- Auto-prevents known failures
- Knows your codebase patterns
- High confidence scores

---

## 🆘 Troubleshooting

### "Knowledge base not initialized"
```bash
python .agent/execution/context_utils.py init
```

### "Missing dependencies"
```bash
pip install -r requirements.txt
```

### "Agent doesn't follow PROJECT_CONTEXT.md"
Make sure agent reads this file FIRST before starting any work.

### "Agent makes mobile-specific mistakes"
Check `.agent/orchestration/knowledge_base/failure_patterns.yaml` - these patterns prevent repeat mistakes.

---

## 📱 Mobile-Specific Features

This template includes mobile-specific knowledge:

**Platform Handling:**
- iOS vs Android differences
- Permission requests
- Native modules
- Deep linking

**Performance:**
- Image optimization
- Bundle size
- Memory management
- Smooth animations

**Testing:**
- iOS simulator
- Android emulator
- Physical device testing
- E2E with Detox

---

## 🔄 Update Your Context

As you build, update PROJECT_CONTEXT.md with:
- Decisions made ("We use Zustand for all state")
- Patterns discovered ("Always use absolute imports")
- Gotchas found ("Camera permission needs Info.plist entry")

The more context, the better the agent performs.

---

## 💡 Pro Tips

1. **Start Simple** - First feature should be straightforward
2. **Add Examples** - Create `examples/` with good code patterns
3. **Be Specific** - More detail in INITIAL.md = better results
4. **Review Plans** - Check generated plan before building
5. **Update Context** - Keep PROJECT_CONTEXT.md current

---

## 📚 File Reference

| File | Purpose | Who Edits |
|------|---------|-----------|
| PROJECT_CONTEXT.md | Tech stack config | You |
| INITIAL.md | Feature requests | You |
| GLOBAL_RULES.md | Coding standards | Rarely |
| mobile_feature.md | Build process | Rarely |
| knowledge_base/*.yaml | ML data | Agent auto |
| context_utils.py | ML operations | Never |

---

## ✅ Success Checklist

Before first use:
- [ ] Copied all files to project
- [ ] Ran `python .agent/execution/context_utils.py init`
- [ ] Filled in PROJECT_CONTEXT.md
- [ ] Read INITIAL_EXAMPLE.md
- [ ] Created first INITIAL.md

Ready to build!

---

**This is a complete, standalone mobile template. Everything you need is in this package.** 📱
