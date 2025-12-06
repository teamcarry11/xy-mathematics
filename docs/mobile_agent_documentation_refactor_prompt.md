# Grain Mobile Agent: Documentation Refactor Prompt

**Date**: 2025-12-03-165133-pst  
**Agent**: Grain Mobile Agent (6th Agent)  
**Purpose**: Refactor plan and tasks into new hybrid documentation structure

---

## Context

The Grain OS project has migrated to a **hybrid documentation structure** to improve performance and maintain coordination across 7 agents working in parallel.

### New Structure

```
docs/
├── plan.md                    # Master overview (high-level, all agents)
├── tasks.md                   # Master task list (high-level, all agents)
├── plans/
│   ├── plan_core.md            # Grain Core Agent detailed plan
│   ├── plan_aurora.md        # Aurora Agent detailed plan
│   ├── plan_skate.md         # Skate Agent detailed plan
│   ├── plan_workspace.md     # Workspace Agent detailed plan
│   ├── plan_kernel.md        # Kernel Agent detailed plan
│   ├── plan_database.md      # Database Agent detailed plan
│   └── plan_mobile.md        # YOUR FILE (to be created)
└── tasks/
    ├── tasks_core.md           # Grain Core Agent detailed tasks
    ├── tasks_aurora.md       # Aurora Agent detailed tasks
    ├── tasks_skate.md        # Skate Agent detailed tasks
    ├── tasks_workspace.md   # Workspace Agent detailed tasks
    ├── tasks_kernel.md      # Kernel Agent detailed tasks
    ├── tasks_database.md    # Database Agent detailed tasks
    └── tasks_mobile.md      # YOUR FILE (to be created)
```

### Why This Structure?

- **Performance**: Master files reduced from 5,252 lines to 431 lines (92% reduction)
- **Coordination**: Master files maintain cross-agent awareness
- **Clarity**: Agent-specific files focus on your work
- **Scalability**: Structure grows with agent count, not total work

**Reference**: See [`docs/documentation_structure_recommendation.md`](documentation_structure_recommendation.md) for full rationale.

---

## Your Task

Create two files following the Grain Core Agent's example:

1. **`docs/plans/plan_mobile.md`** — Detailed development plan
2. **`docs/tasks/tasks_mobile.md`** — Detailed task list

### Reference Files

- **Example Plan**: [`docs/plans/plan_core.md`](plans/plan_core.md) — Grain Core Agent plan (448 lines)
- **Example Tasks**: [`docs/tasks/tasks_core.md`](tasks/tasks_core.md) — Grain Core Agent tasks (188 lines)
- **Master Plan**: [`docs/plan.md`](plan.md) — Master overview (236 lines)
- **Master Tasks**: [`docs/tasks.md`](tasks.md) — Master task list (195 lines)

---

## Content to Include

### 1. Plan File (`docs/plans/plan_mobile.md`)

**Structure**:
```markdown
# Grain Mobile Agent: Development Plan

**Agent**: Grain Mobile Agent (6th Agent)
**Status**: [Current status]
**Last Updated**: 2025-12-03-165133-pst

---

## Overview

[Brief description of Grain Mobile cross-platform mobile development framework]

**Key Goals**:
- [Goal 1]
- [Goal 2]
- [Goal 3]

---

## Completed Phases

### Phase 1: Core Module & Validation ✅ **COMPLETE**
- [Description]
- [Key achievements]
- [Files created/modified]
- [Tests]

### Phase 2: Crypto & Authentication ✅ **COMPLETE**
- [Description]
- [Key achievements]
- [Files created/modified]
- [Tests]

[... more completed phases ...]

---

## Current Work: Phase [X] - [Phase Name]

**Priority**: [Priority level]
**Status**: [Status]
**Estimated Time**: [Time estimate]

### Why This Phase
[Rationale]

### Features
[Feature list]

### Deliverables
[Deliverables list]

### Dependencies
- **Needs**: [What you need from other agents]
- **Provides**: [What you provide to other agents]
- **Coordinates with**: [Other agents]

---

## Planned Phases

### Phase 4: Android App Development (PLANNED)
[Description]

### Phase 5: iOS App Development (PLANNED)
[Description]

---

## Coordination Points

### With Grain Core Agent

**Integration Points**:
- API Server (Phase 59) for mobile backend connection
- Authentication Service (Phase 60) for secure mobile app authentication
- Network Stack (Phase 61) for network capabilities

**Coordination Notes**:
- Mobile Agent depends on Grain Core Agent's API Server (Phase 59)
- Secure authentication depends on Authentication Service (Phase 60)
- Network capabilities depend on Network Stack (Phase 61)

### With Grain Database Agent

**Integration Points**:
- REST API for mobile backend connection
- Database backend for mobile app data storage

**Coordination Notes**:
- Mobile Agent uses Database Agent's REST API
- Database Agent provides backend for mobile applications
- Both depend on Grain Core Agent's API Server (Phase 59)

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Grain Mobile Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](../grain_mobile_agent_prompt.md)
- **Grain Mobile Core Architecture**: [`docs/grain_mobile_core_architecture.md`](../grain_mobile_core_architecture.md)
- [Other references]
```

### 2. Tasks File (`docs/tasks/tasks_mobile.md`)

**Structure**:
```markdown
# Grain Mobile Agent: Task List

**Agent**: Grain Mobile Agent (6th Agent)
**Status**: [Current status]
**Last Updated**: 2025-12-03-165133-pst

---

## Current Work: Phase [X] - [Phase Name]

**Priority**: [Priority]
**Status**: [Status]
**Estimated Time**: [Time]

### Tasks

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Grain Style Requirements
[Requirements]

### Dependencies
[Dependencies]

---

## Planned: Phase 4 - Android App Development

[Similar structure]

---

## Completed Phases (Summary)

[Summary of completed work]

---

## Coordination Tasks

[Coordination tasks with other agents]

---

## References

[References]
```

---

## Your Recent Work to Include

### Completed: Phase 1 - Core Module & Validation ✅

**Date**: 2025-12-03-160538-pst

**Completed Work**:
1. **Grain Mobile Core Module** (`src/grain_mobile_core/`):
   - Module structure and root exports
   - Email validation (`src/grain_mobile_core/validation/email.zig`)
   - Password validation (`src/grain_mobile_core/validation/password.zig`)
   - 32-char minimum password strategy (1Password-inspired)
   - Comprehensive validation tests

**Features**:
- Email validation (format checking, domain validation)
- Password validation (32-char minimum, strength checking, 1Password strategy)
- Validation error handling
- Bounded allocations (all limits explicit)

**Files**:
- `src/grain_mobile_core/root.zig` — Module root and exports
- `src/grain_mobile_core/validation/email.zig` — Email validation
- `src/grain_mobile_core/validation/password.zig` — Password validation
- `src/grain_mobile_core/utils/errors.zig` — Error handling utilities

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Phase 2 - Crypto & Authentication ✅

**Date**: 2025-12-03-163715-pst

**Completed Work**:
1. **Cryptography Module** (`src/grain_mobile_core/crypto/`):
   - Secure random number generation (`src/grain_mobile_core/crypto/random.zig`)
   - Password hashing (`src/grain_mobile_core/crypto/hash.zig`)
   - OTP (One-Time Password) generation (`src/grain_mobile_core/auth/otp.zig`)
   - TOTP (Time-based OTP) 2FA (`src/grain_mobile_core/auth/totp.zig`)
   - Comprehensive crypto tests

**Features**:
- Secure random number generation (cryptographically secure)
- Password hashing (bcrypt/Argon2 strategy)
- OTP generation (time-limited, single-use tokens)
- TOTP 2FA (RFC 6238, Google Authenticator-compatible)
- Secure token generation/validation

**Files**:
- `src/grain_mobile_core/crypto/random.zig` — Secure random generation
- `src/grain_mobile_core/crypto/hash.zig` — Password hashing
- `src/grain_mobile_core/auth/otp.zig` — OTP generation
- `src/grain_mobile_core/auth/totp.zig` — TOTP 2FA

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Phase 3 - Email Auth & JWT ✅

**Date**: 2025-12-03-165554-pst

**Completed Work**:
1. **Authentication Module** (`src/grain_mobile_core/auth/`):
   - Email/password authentication (`src/grain_mobile_core/auth/email.zig`)
   - JWT token creation (`src/grain_mobile_core/auth/jwt.zig`)
   - JWT token validation (`src/grain_mobile_core/auth/jwt.zig`)
   - Token expiration handling
   - Comprehensive authentication tests

**Features**:
- Email/password authentication
- JWT token creation (signed tokens with expiration)
- JWT token validation (signature verification, expiration checking)
- Secure token storage strategies
- Authentication error handling

**Files**:
- `src/grain_mobile_core/auth/email.zig` — Email/password authentication
- `src/grain_mobile_core/auth/jwt.zig` — JWT token creation/validation

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: FFI Layer ✅

**Date**: 2025-12-03 (estimated)

**Completed Work**:
1. **FFI Layer** (`src/grain_mobile_core/ffi/`):
   - C-compatible FFI exports (`src/grain_mobile_core/ffi/c_api.zig`)
   - JNI bindings for Android (`src/grain_mobile_core/ffi/jni_bindings.zig`)
   - Swift bindings for iOS (`src/grain_mobile_core/ffi/swift_bindings.zig`)
   - Style API for UI components (`src/grain_mobile_core/ffi/style_api.zig`)
   - Comprehensive FFI tests

**Features**:
- C-compatible API for cross-platform FFI
- JNI bindings for Android (Kotlin integration)
- Swift bindings for iOS (Swift integration)
- Style API for UI components (colors, typography, spacing, themes)
- FFI error handling and type conversion

**Files**:
- `src/grain_mobile_core/ffi/c_api.zig` — C-compatible FFI exports
- `src/grain_mobile_core/ffi/jni_bindings.zig` — JNI bindings
- `src/grain_mobile_core/ffi/swift_bindings.zig` — Swift bindings
- `src/grain_mobile_core/ffi/style_api.zig` — Style API

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

### Completed: Style System ✅

**Date**: 2025-12-03 (estimated)

**Completed Work**:
1. **Style System** (`src/grain_mobile_core/style/`):
   - Colors (`src/grain_mobile_core/style/colors.zig`)
   - Typography (`src/grain_mobile_core/style/typography.zig`)
   - Spacing (`src/grain_mobile_core/style/spacing.zig`)
   - Breakpoints (`src/grain_mobile_core/style/breakpoints.zig`)
   - Themes (`src/grain_mobile_core/style/themes.zig`)
   - Components (`src/grain_mobile_core/style/components.zig`)
   - Comprehensive style tests (`tests/111_grain_mobile_core_style_test.zig`)

**Features**:
- Color system (primary, secondary, accent, background, text)
- Typography system (font families, sizes, weights, line heights)
- Spacing system (consistent spacing scale)
- Breakpoints (responsive design breakpoints)
- Themes (light, dark, custom themes)
- UI components (buttons, inputs, cards, etc.)

**Files**:
- `src/grain_mobile_core/style/root.zig` — Style module root
- `src/grain_mobile_core/style/colors.zig` — Color system
- `src/grain_mobile_core/style/typography.zig` — Typography system
- `src/grain_mobile_core/style/spacing.zig` — Spacing system
- `src/grain_mobile_core/style/breakpoints.zig` — Breakpoints
- `src/grain_mobile_core/style/themes.zig` — Theme system
- `src/grain_mobile_core/style/components.zig` — UI components

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations
- Assertions for preconditions
- Max 70 lines per function
- Max 100 characters per line

---

## Coordination with Other Agents

### With Grain Core Agent

**Integration Points**:
- **API Server (Phase 59)**: Mobile Agent depends on Grain Core Agent's API Server for backend connection
  - Mobile apps connect to API Server
  - API Server routes requests to Database Agent
  - Coordination on API contracts and endpoints
- **Authentication Service (Phase 60)**: Secure mobile app authentication depends on Grain Core Agent's Authentication Service
  - JWT token validation
  - OAuth integration (Google, Facebook, GitHub, etc.)
  - 2FA support
- **Network Stack (Phase 61)**: Network capabilities depend on Grain Core Agent's Network Stack
  - HTTPS/TLS support
  - WebSocket support (for livestream coordination)
  - Network error handling

**Coordination Notes**:
- Mobile Agent depends on Grain Core Agent's API Server (Phase 59) for backend connection
- Secure authentication depends on Authentication Service (Phase 60)
- Network capabilities depend on Network Stack (Phase 61)
- Mobile Agent is waiting for Grain Core Agent to complete these phases

**Future Coordination**:
- **API Integration**: When Grain Core Agent completes Phase 59, integrate Mobile Agent's API clients
- **Authentication**: When Grain Core Agent completes Phase 60, integrate secure authentication
- **Network**: When Grain Core Agent completes Phase 61, integrate network capabilities

### With Grain Database Agent

**Integration Points**:
- **REST API**: Mobile Agent uses Database Agent's REST API for backend connection
  - Mobile apps connect to Database Agent's REST API via Grain Core Agent's API Server
  - Database Agent provides data storage and retrieval
  - Mobile Agent provides mobile app UI and business logic
- **Database Backend**: Database Agent provides backend for mobile applications
  - User profiles, policy stances, candidate information
  - Social graph (relationships, connections)
  - Full-text search (policy topic search, candidate search)

**Coordination Notes**:
- Mobile Agent depends on Database Agent's REST API
- Database Agent provides backend for mobile applications
- Both agents depend on Grain Core Agent's API Server (Phase 59)

**Future Coordination**:
- **API Integration**: When Grain Core Agent completes Phase 59, Mobile Agent can connect to Database Agent's REST API
- **Data Models**: Coordinate on data models for mobile app (user profiles, policy stances, etc.)
- **Authentication**: Coordinate on authentication flow (JWT, OAuth, 2FA)

### With Vantage VM Basin Kernel Agent

**Integration Points**:
- **Kernel File I/O**: Not directly used (mobile apps use platform file systems)
- **Network Syscalls**: Not directly used (mobile apps use platform network stacks)
- **Indirect Integration**: Mobile apps use Grain OS infrastructure, which uses kernel syscalls

**Coordination Notes**:
- Mobile apps run on Android/iOS platforms, not directly on Grain OS kernel
- Mobile apps use Grain OS infrastructure (API Server, Database) which uses kernel syscalls
- No direct coordination needed — Grain Core Agent handles kernel integration

---

## What to Extract from Old Files

### From `archaeology/docs/plan_tasks_archive/plan_2025-12-03-165133-pst.md`:

Search for sections related to:
- "Grain Mobile", "Mobile Agent", "Phase 1", "Phase 2", "Phase 3"
- "mobile_core", "FFI", "validation", "crypto", "auth", "JWT"
- Your agent's work

Extract:
- Completed phases
- Current work
- Planned phases
- Coordination notes

### From `archaeology/docs/plan_tasks_archive/tasks_2025-12-03-165133-pst.md`:

Search for:
- Grain Mobile tasks
- Phase 1-3 tasks
- Mobile-specific tasks

Extract:
- Task lists for each phase
- Completed tasks
- Pending tasks
- Coordination tasks

---

## Key Phases to Document

### Completed Phases

**Phase 1: Core Module & Validation** ✅ (2025-12-03-160538-pst)
- Grain Mobile Core module structure
- Email validation
- Password validation (32-char minimum, 1Password strategy)
- Files: `src/grain_mobile_core/validation/email.zig`, `src/grain_mobile_core/validation/password.zig`

**Phase 2: Crypto & Authentication** ✅ (2025-12-03-163715-pst)
- Secure random number generation
- Password hashing
- OTP generation
- TOTP 2FA (RFC 6238, Google Authenticator-compatible)
- Files: `src/grain_mobile_core/crypto/random.zig`, `src/grain_mobile_core/crypto/hash.zig`, `src/grain_mobile_core/auth/otp.zig`, `src/grain_mobile_core/auth/totp.zig`

**Phase 3: Email Auth & JWT** ✅ (2025-12-03-165554-pst)
- Email/password authentication
- JWT token creation/validation
- Token expiration handling
- Files: `src/grain_mobile_core/auth/email.zig`, `src/grain_mobile_core/auth/jwt.zig`

**FFI Layer** ✅
- C-compatible FFI exports
- JNI bindings for Android
- Swift bindings for iOS
- Style API for UI components
- Files: `src/grain_mobile_core/ffi/`

**Style System** ✅
- Colors, typography, spacing, breakpoints, themes, components
- Files: `src/grain_mobile_core/style/`, `tests/111_grain_mobile_core_style_test.zig`

### Planned Phases

**Phase 4: Android App Development** (PLANNED)
- Native Kotlin application with Jetpack Compose UI
- Integration with Grain Mobile Core via JNI
- API client implementation
- Authentication UI (email/password, OAuth, 2FA)
- Main app UI (candidate profiles, policy stances, search)

**Phase 5: iOS App Development** (PLANNED)
- Native Swift application with SwiftUI
- Integration with Grain Mobile Core via C interop
- API client implementation
- Authentication UI (email/password, OAuth, 2FA)
- Main app UI (candidate profiles, policy stances, search)

**Phase 6: OAuth Integration** (PLANNED)
- Google OAuth integration
- Facebook OAuth integration
- GitHub OAuth integration
- Apple Sign-In integration (iOS)

**Phase 7: Advanced Features** (PLANNED)
- Location-based features
- Event coordination
- Livestream coordination
- Candidate verification checks

---

## Guidelines

### File Size Target

- **Plan file**: ~400-600 lines (detailed but manageable, many phases)
- **Tasks file**: ~300-500 lines (detailed but manageable, many tasks)
- **Master files**: Will be updated by you after creating agent files

### Content Guidelines

1. **Be Detailed**: Include implementation details, file paths, test names
2. **Be Specific**: Include phase numbers, dates, status
3. **Be Coordinated**: Include dependencies and coordination points
4. **Be Current**: Include recent work (all 3 completed phases, FFI layer, Style system)

### Cross-References

- Link to master files: `[Master Plan](../plan.md)`
- Link to other agent files: `[Grain OS Plan](../plans/plan_core.md)`
- Link to shared docs: `[Grain Style](../grain_style.md)`
- Link to agent prompt: `[Grain Mobile Agent Prompt](../grain_mobile_agent_prompt.md)`
- Link to architecture: `[Grain Mobile Core Architecture](../grain_mobile_core_architecture.md)`

---

## Steps to Complete

1. **Read Reference Files**:
   - Read `docs/plans/plan_core.md` to understand structure
   - Read `docs/tasks/tasks_core.md` to understand task format
   - Read `docs/documentation_structure_recommendation.md` for rationale
   - Read `docs/grain_mobile_agent_prompt.md` for mobile details
   - Read `docs/grain_mobile_core_architecture.md` for architecture details

2. **Extract Your Content**:
   - Search old plan file for Grain Mobile sections
   - Search old tasks file for Grain Mobile tasks
   - Include recent work (all 3 completed phases, FFI layer, Style system)

3. **Create Plan File**:
   - Create `docs/plans/plan_mobile.md`
   - Follow structure from `plan_core.md`
   - Include completed phases (1-3, FFI, Style), current work, planned phases (4-7)
   - Include coordination points (especially with Grain Core Agent and Database Agent)

4. **Create Tasks File**:
   - Create `docs/tasks/tasks_mobile.md`
   - Follow structure from `tasks_core.md`
   - Include task lists for each phase
   - Include coordination tasks

5. **Update Master Files**:
   - Update `docs/plan.md` with Mobile Agent summary (if not already there)
   - Update `docs/tasks.md` with Mobile Agent summary (if not already there)
   - Keep summaries concise (1-2 paragraphs)

6. **Verify**:
   - Check file sizes (plan: ~400-600 lines, tasks: ~300-500 lines)
   - Check cross-references work
   - Check coordination points are documented

---

## Example Master File Entry

After creating your files, the master `docs/plan.md` should have an entry like:

```markdown
### 6. Grain Mobile Agent

**Status**: Active — Cross-platform mobile development  
**Current Work**: Grain Mobile Core module  
**Details**: See [`docs/plans/plan_mobile.md`](plans/plan_mobile.md)

**Recent Progress**:
- Grain Mobile Core architecture ✅
- Phase 1: Core Module & Validation ✅ (2025-12-03-160538-pst)
- Phase 2: Crypto & Authentication ✅ (2025-12-03-163715-pst)
- Phase 3: Email Auth & JWT ✅ (2025-12-03-165554-pst)
- FFI layer ✅
- Style system ✅

**Provides**: Mobile app framework, shared business logic (Zig), platform bindings
```

---

## Questions to Answer

1. **What phases have you completed?**
   - Phase 1: Core Module & Validation ✅ (2025-12-03-160538-pst)
   - Phase 2: Crypto & Authentication ✅ (2025-12-03-163715-pst)
   - Phase 3: Email Auth & JWT ✅ (2025-12-03-165554-pst)
   - FFI Layer ✅
   - Style System ✅
   - List all completed phases with dates and achievements

2. **What is your current work?**
   - Current phase, status, priority, estimated time
   - Waiting for Grain Core Agent's API Server (Phase 59) for backend connection

3. **What phases are planned?**
   - Phase 4: Android App Development (PLANNED)
   - Phase 5: iOS App Development (PLANNED)
   - Phase 6: OAuth Integration (PLANNED)
   - Phase 7: Advanced Features (PLANNED)

4. **What do you coordinate with other agents?**
   - Grain Core Agent (API Server, Authentication Service, Network Stack)
   - Grain Database Agent (REST API, database backend)
   - Kernel Agent (indirect, via Grain OS infrastructure)

5. **What dependencies do you have?**
   - What you need from other agents (API Server, Authentication Service, Network Stack)
   - What you provide to other agents (mobile applications, mobile app framework)

---

## Success Criteria

✅ Plan file created (`docs/plans/plan_mobile.md`)  
✅ Tasks file created (`docs/tasks/tasks_mobile.md`)  
✅ Files follow structure from reference files  
✅ Recent work (all 3 completed phases, FFI layer, Style system) included  
✅ Coordination points documented (especially with Grain Core Agent and Database Agent)  
✅ Master files updated (if needed)  
✅ File sizes reasonable (~400-600 lines for plan, ~300-500 for tasks)  
✅ Cross-references work  
✅ Grain Style compliance mentioned where relevant

---

## References

- **Documentation Structure**: [`docs/documentation_structure_recommendation.md`](documentation_structure_recommendation.md)
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plans/plan_core.md) — Example structure
- **Grain Core Agent Tasks**: [`docs/tasks/tasks_core.md`](tasks/tasks_core.md) — Example structure
- **Master Plan**: [`docs/plan.md`](plan.md) — Master overview
- **Master Tasks**: [`docs/tasks.md`](tasks.md) — Master task list
- **Grain Style**: [`docs/grain_style.md`](grain_style.md) — Coding principles
- **Grain Mobile Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](grain_mobile_agent_prompt.md) — Agent prompt and architecture
- **Grain Mobile Core Architecture**: [`docs/grain_mobile_core_architecture.md`](grain_mobile_core_architecture.md) — Architecture details
- **Archived Files**: `archaeology/docs/plan_tasks_archive/` — Previous versions

---

**Your Mission**: Create `docs/plans/plan_mobile.md` and `docs/tasks/tasks_mobile.md` following the hybrid documentation structure, including your recent work (all 3 completed phases, FFI layer, Style system) and coordination points with Grain Core Agent, Database Agent, and other agents.

**Remember**: Be detailed, be specific, be coordinated. The goal is to have focused agent files while maintaining coordination through master files. Your mobile framework enables cross-platform mobile development with maximum code reuse and native performance!

Good luck! 🚀

