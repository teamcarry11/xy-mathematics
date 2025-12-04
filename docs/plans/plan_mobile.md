# Grain Mobile Agent: Development Plan

**Agent**: Grain Mobile Agent (6th Agent)  
**Status**: Phase 4 Complete — Responsive Style System & FFI Layer  
**Last Updated**: 2025-12-04-102305-pst

---

## Overview

Grain Mobile Agent is responsible for building a cross-platform mobile development framework and applications for the Grain OS ecosystem. The framework uses Zig as the shared business logic core with native platform UIs (Kotlin/Jetpack Compose for Android, Swift/SwiftUI for iOS).

**Key Goals**:
- Cross-platform mobile development with maximum code reuse (>80% shared logic)
- Native performance (<5ms vs React Native's 10-50ms)
- Single source of truth for security-critical code (authentication, cryptography)
- Responsive design system for consistent mobile UIs
- Secure authentication (OAuth 2.0, email/password, 2FA, magic email OTP)

---

## Completed Phases

### Phase 1: Core Module & Validation ✅ **COMPLETE** (2025-12-03-160538-pst)

**Description**: Established Grain Mobile Core module structure and implemented email/password validation with 32-character minimum password requirement and 1Password-inspired strategy.

**Key Achievements**:
- Grain Mobile Core module structure (`src/grain_mobile_core/`)
- Email validation (`src/grain_mobile_core/validation/email.zig`)
- Password validation (`src/grain_mobile_core/validation/password.zig`)
- 32-character minimum password requirement (security best practice)
- 1Password "Memorable Password" strategy support
- Password strength calculation
- Comprehensive validation tests

**Files Created**:
- `src/grain_mobile_core/root.zig` — Module root and exports
- `src/grain_mobile_core/validation/email.zig` — Email validation
- `src/grain_mobile_core/validation/password.zig` — Password validation
- `src/grain_mobile_core/utils/errors.zig` — Error handling utilities
- `tests/108_grain_mobile_core_validation_test.zig` — Validation tests

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit: `MAX_EMAIL_LEN`, `MAX_PASSWORD_LEN`)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

---

### Phase 2: Crypto & Authentication ✅ **COMPLETE** (2025-12-03-163715-pst)

**Description**: Implemented cryptography and authentication primitives including secure random generation, password hashing, OTP generation, and TOTP 2FA (RFC 6238, Google Authenticator-compatible).

**Key Achievements**:
- Secure random number generation (`src/grain_mobile_core/crypto/random.zig`)
- Password hashing with SHA-256 + salt (`src/grain_mobile_core/crypto/hash.zig`)
- Magic email OTP generation/validation (`src/grain_mobile_core/auth/otp.zig`)
- TOTP 2FA implementation (`src/grain_mobile_core/auth/totp.zig`)
- HMAC-SHA1 implementation for TOTP
- Comprehensive crypto/auth tests

**Files Created**:
- `src/grain_mobile_core/crypto/random.zig` — Secure random generation
- `src/grain_mobile_core/crypto/hash.zig` — Password hashing (SHA-256 + salt)
- `src/grain_mobile_core/auth/otp.zig` — Magic email OTP
- `src/grain_mobile_core/auth/totp.zig` — TOTP 2FA (RFC 6238)
- `tests/109_grain_mobile_core_crypto_auth_test.zig` — Crypto/auth tests

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (`SALT_LEN`, `HASH_LEN`, `OTP_CODE_LEN`, `TOTP_SECRET_LEN`)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

---

### Phase 3: Email Auth & JWT ✅ **COMPLETE** (2025-12-03-165554-pst)

**Description**: Implemented email/password authentication flow and JWT token creation/validation with HS256 algorithm, Base64URL encoding, and expiration handling.

**Key Achievements**:
- Email/password authentication (`src/grain_mobile_core/auth/email.zig`)
- User account creation and authentication
- Session token generation (32-byte secure random tokens)
- JWT token creation (`src/grain_mobile_core/auth/jwt.zig`)
- JWT token validation (signature verification, expiration checking)
- Base64URL encoding/decoding (manual implementation, Grain Style compliant)
- HMAC-SHA256 for JWT signatures
- Comprehensive authentication tests

**Files Created**:
- `src/grain_mobile_core/auth/email.zig` — Email/password authentication
- `src/grain_mobile_core/auth/jwt.zig` — JWT token creation/validation
- `tests/110_grain_mobile_core_email_jwt_test.zig` — Email auth and JWT tests

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (`MAX_USER_ID_LEN`, `SESSION_TOKEN_LEN`, `MAX_JWT_LEN`)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- Manual JSON encoding (no fmt functions for Grain Style compliance)
- All compiler warnings enabled

---

### Phase 4: Responsive Style System & FFI Layer ✅ **COMPLETE** (2025-12-04-100923-pst)

**Description**: Implemented comprehensive responsive style system with color palettes, typography scales, spacing system, responsive breakpoints, component specifications, and complete FFI layer for native platform consumption.

**Key Achievements**:
- Color palettes (light/dark themes) (`src/grain_mobile_core/style/colors.zig`)
- Typography scales (15 text styles) (`src/grain_mobile_core/style/typography.zig`)
- Spacing system (6 sizes: xs, sm, md, lg, xl, xxl) (`src/grain_mobile_core/style/spacing.zig`)
- Responsive breakpoints (6 breakpoints: phone/tablet/desktop variants) (`src/grain_mobile_core/style/breakpoints.zig`)
- Theme management (`src/grain_mobile_core/style/themes.zig`)
- Component specifications (10 component types) (`src/grain_mobile_core/style/components.zig`)
- FFI layer for style queries (`src/grain_mobile_core/ffi/style_api.zig`)
- Comprehensive style system tests
- FFI tests for all style exports

**Files Created**:
- `src/grain_mobile_core/style/root.zig` — Style module root
- `src/grain_mobile_core/style/colors.zig` — Color palettes
- `src/grain_mobile_core/style/typography.zig` — Typography scales
- `src/grain_mobile_core/style/spacing.zig` — Spacing system
- `src/grain_mobile_core/style/breakpoints.zig` — Responsive breakpoints
- `src/grain_mobile_core/style/themes.zig` — Theme management
- `src/grain_mobile_core/style/components.zig` — Component specifications
- `src/grain_mobile_core/ffi/style_api.zig` — FFI exports for style system
- `tests/111_grain_mobile_core_style_test.zig` — Style system tests
- `tests/112_grain_mobile_core_style_ffi_test.zig` — FFI tests
- `docs/grain_mobile_style_system.md` — Style system design document

**FFI API Functions**:
- `grain_mobile_get_breakpoint(width_dp, height_dp)` — Breakpoint query
- `grain_mobile_init_color_palette_light/dark(palette_out)` — Color palette initialization
- `grain_mobile_color_to_argb(color)` — Color to ARGB conversion
- `grain_mobile_init_typography_scale(scale_out)` — Typography scale initialization
- `grain_mobile_init_spacing_scale(scale_out)` — Spacing scale initialization
- `grain_mobile_get_spacing(scale, size, spacing_out)` — Spacing value getter
- `grain_mobile_init_theme_data(theme, theme_data_out)` — Theme data initialization
- `grain_mobile_get_component_spec(component_type, breakpoint, theme_data, spec_out)` — Component spec query

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- No recursion
- All compiler warnings enabled

---

## Current Work: API Client Module Preparation

**Priority**: **MEDIUM** — Preparation for API Server integration  
**Status**: **IN PROGRESS** — API client structure complete, ready for HTTP implementation  
**Estimated Time**: 1-2 weeks

### Why This Work

While waiting for Grain OS Agent's API Server (Phase 59), we can prepare the API client module structure. This includes request/response models, error handling, and client foundation that will be ready when the API Server is available.

### Completed: API Client Module Structure ✅ (2025-12-04-104041-pst)

**Key Achievements**:
- API client module structure (`src/grain_mobile_core/api/`)
- Request/response models (`api/client.zig`)
- HTTP method and status enums
- Header management
- URL building
- Default headers support
- Comprehensive API client tests

**Files Created**:
- `src/grain_mobile_core/api/root.zig` — API module root
- `src/grain_mobile_core/api/client.zig` — API client (request/response models)
- `tests/113_grain_mobile_core_api_client_test.zig` — API client tests

**Features**:
- HTTP methods (GET, POST, PUT, DELETE, PATCH)
- HTTP status codes
- Request building (method, URL, headers, body)
- Response parsing (status, headers, body)
- Default headers support
- URL building from base URL + path

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (`MAX_URL_LEN`, `MAX_HEADERS`, `MAX_BODY_LEN`)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Implement HTTP client execution (when API Server available)
- Add retry logic
- Add timeout handling
- Add response parsing helpers

---

## Waiting for Grain OS Agent Infrastructure

**Priority**: **BLOCKED** — Waiting for Grain OS Agent Phase 59 (API Server)  
**Status**: **READY** — Core modules complete, waiting for backend infrastructure  
**Estimated Time**: Depends on Grain OS Agent progress

### Why We're Waiting

Mobile Agent has completed all core modules (validation, crypto, authentication, style system, FFI layer). To proceed with mobile app development, we need:

1. **API Server (Grain OS Agent Phase 59)**: Required for mobile backend connection
2. **Authentication Service (Grain OS Agent Phase 60)**: Required for secure mobile app authentication
3. **Network Stack (Grain OS Agent Phase 61)**: Required for network capabilities (HTTPS, WebSocket)

### What We're Ready For

- ✅ Core business logic (validation, crypto, authentication)
- ✅ Style system (responsive design, component specs)
- ✅ FFI layer (C-compatible API for Kotlin/Swift)
- ✅ JWT token handling
- ✅ Password hashing and validation
- ✅ OTP and TOTP 2FA

### Next Steps When Unblocked

1. **Android App Development** (Phase 5): Native Kotlin app with Jetpack Compose
2. **iOS App Development** (Phase 6): Native Swift app with SwiftUI
3. **OAuth Integration** (Phase 7): Google, Facebook, GitHub, Apple Sign-In
4. **API Client Integration**: Connect to Grain OS API Server

---

## Planned Phases

### Phase 5: Android App Development (PLANNED)

**Priority**: **HIGH** — First mobile platform  
**Status**: **PLANNED** — Waiting for Grain OS Agent Phase 59  
**Estimated Time**: 4-6 weeks

**Description**: Build native Android application using Kotlin and Jetpack Compose, integrated with Grain Mobile Core via JNI bindings.

**Features**:
- Native Kotlin application structure
- Jetpack Compose UI with Grain Mobile style system
- JNI bindings for Grain Mobile Core FFI
- API client implementation (when API Server available)
- Authentication UI (email/password, OAuth, 2FA)
- Main app UI (candidate profiles, policy stances, search)
- Responsive design using breakpoint system

**Deliverables**:
- Android app project structure
- JNI bindings (`android/app/src/main/jni/`)
- Kotlin wrapper classes for Grain Mobile Core
- Jetpack Compose UI components
- Integration tests

**Dependencies**:
- **Needs**: API Server (Grain OS Agent Phase 59), Authentication Service (Grain OS Agent Phase 60)
- **Provides**: Android mobile application
- **Coordinates with**: Grain OS Agent (API contracts), Grain Database Agent (REST API)

---

### Phase 6: iOS App Development (PLANNED)

**Priority**: **HIGH** — Second mobile platform  
**Status**: **PLANNED** — Waiting for Grain OS Agent Phase 59  
**Estimated Time**: 4-6 weeks

**Description**: Build native iOS application using Swift and SwiftUI, integrated with Grain Mobile Core via C interop.

**Features**:
- Native Swift application structure
- SwiftUI UI with Grain Mobile style system
- C interop bindings for Grain Mobile Core FFI
- API client implementation (when API Server available)
- Authentication UI (email/password, OAuth, 2FA, Apple Sign-In)
- Main app UI (candidate profiles, policy stances, search)
- Responsive design using breakpoint system

**Deliverables**:
- iOS app project structure
- C interop bindings
- Swift wrapper classes for Grain Mobile Core
- SwiftUI UI components
- Integration tests

**Dependencies**:
- **Needs**: API Server (Grain OS Agent Phase 59), Authentication Service (Grain OS Agent Phase 60)
- **Provides**: iOS mobile application
- **Coordinates with**: Grain OS Agent (API contracts), Grain Database Agent (REST API)

---

### Phase 7: OAuth Integration (PLANNED)

**Priority**: **MEDIUM** — Enhanced authentication  
**Status**: **PLANNED** — Waiting for Grain OS Agent Phase 60  
**Estimated Time**: 2-3 weeks

**Description**: Implement OAuth 2.0 integration for Google, Facebook, GitHub, and Apple Sign-In (iOS).

**Features**:
- Google OAuth integration
- Facebook OAuth integration
- GitHub OAuth integration
- Apple Sign-In integration (iOS)
- OAuth token management
- User profile synchronization

**Deliverables**:
- OAuth provider integrations
- Token management
- User profile sync
- Integration tests

**Dependencies**:
- **Needs**: Authentication Service (Grain OS Agent Phase 60)
- **Provides**: OAuth authentication for mobile apps
- **Coordinates with**: Grain OS Agent (OAuth flow)

---

### Phase 8: Advanced Features (PLANNED)

**Priority**: **LOW** — Future enhancements  
**Status**: **PLANNED**  
**Estimated Time**: 6-8 weeks

**Description**: Implement advanced mobile features including location-based features, event coordination, livestream coordination, and candidate verification checks.

**Features**:
- Location-based features (GPS, geofencing)
- Event coordination (calendar integration, notifications)
- Livestream coordination (WebSocket integration)
- Candidate verification checks
- Push notifications
- Offline mode support

**Deliverables**:
- Location services integration
- Event coordination features
- Livestream coordination
- Verification system
- Push notification support
- Offline mode

**Dependencies**:
- **Needs**: Network Stack (Grain OS Agent Phase 61), WebSocket support
- **Provides**: Advanced mobile features
- **Coordinates with**: Grain OS Agent (network capabilities), Grain Database Agent (data models)

---

## Coordination Points

### With Grain OS Agent

**Integration Points**:
- **API Server (Phase 59)**: Mobile Agent depends on Grain OS Agent's API Server for backend connection
  - Mobile apps connect to API Server via REST API
  - API Server routes requests to Database Agent
  - Coordination on API contracts and endpoints
- **Authentication Service (Phase 60)**: Secure mobile app authentication depends on Grain OS Agent's Authentication Service
  - JWT token validation
  - OAuth integration (Google, Facebook, GitHub, Apple)
  - 2FA support (TOTP, magic email OTP)
- **Network Stack (Phase 61)**: Network capabilities depend on Grain OS Agent's Network Stack
  - HTTPS/TLS support
  - WebSocket support (for livestream coordination)
  - Network error handling

**Coordination Notes**:
- Mobile Agent is **blocked** waiting for Grain OS Agent's API Server (Phase 59)
- Secure authentication depends on Authentication Service (Phase 60)
- Network capabilities depend on Network Stack (Phase 61)
- Mobile Agent has completed all core modules and is ready for integration

**Future Coordination**:
- **API Integration**: When Grain OS Agent completes Phase 59, integrate Mobile Agent's API clients
- **Authentication**: When Grain OS Agent completes Phase 60, integrate secure authentication
- **Network**: When Grain OS Agent completes Phase 61, integrate network capabilities
- **Style System Unification**: Consult with Grain OS Agent about unifying mobile and desktop style systems (see `docs/grain_os_agent_style_unification_prompt.md`)

---

### With Grain Database Agent

**Integration Points**:
- **REST API**: Mobile Agent uses Database Agent's REST API for backend connection
  - Mobile apps connect to Database Agent's REST API via Grain OS Agent's API Server
  - Database Agent provides data storage and retrieval
  - Mobile Agent provides mobile app UI and business logic
- **Database Backend**: Database Agent provides backend for mobile applications
  - User profiles, policy stances, candidate information
  - Social graph (relationships, connections)
  - Full-text search (policy topic search, candidate search)

**Coordination Notes**:
- Mobile Agent depends on Database Agent's REST API
- Database Agent provides backend for mobile applications
- Both agents depend on Grain OS Agent's API Server (Phase 59)

**Future Coordination**:
- **API Integration**: When Grain OS Agent completes Phase 59, Mobile Agent can connect to Database Agent's REST API
- **Data Models**: Coordinate on data models for mobile app (user profiles, policy stances, etc.)
- **Authentication**: Coordinate on authentication flow (JWT, OAuth, 2FA)

---

### With Vantage VM Basin Kernel Agent

**Integration Points**:
- **Kernel File I/O**: Not directly used (mobile apps use platform file systems)
- **Network Syscalls**: Not directly used (mobile apps use platform network stacks)
- **Indirect Integration**: Mobile apps use Grain OS infrastructure, which uses kernel syscalls

**Coordination Notes**:
- Mobile apps run on Android/iOS platforms, not directly on Grain OS kernel
- Mobile apps use Grain OS infrastructure (API Server, Database) which uses kernel syscalls
- No direct coordination needed — Grain OS Agent handles kernel integration

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Master Plan**: [`docs/plan.md`](../plan.md) — Master overview
- **Grain Mobile Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](../grain_mobile_agent_prompt.md) — Agent prompt and architecture
- **Grain Mobile Core Architecture**: [`docs/grain_mobile_core_architecture.md`](../grain_mobile_core_architecture.md) — Architecture details
- **Grain Mobile Style System**: [`docs/grain_mobile_style_system.md`](../grain_mobile_style_system.md) — Style system design
- **Grain OS Agent Plan**: [`docs/plans/plan_os.md`](plan_os.md) — Grain OS Agent plan
- **Grain Database Agent Plan**: [`docs/plans/plan_database.md`](plan_database.md) — Database Agent plan

---

**Last Updated**: 2025-12-04-102305-pst  
**Next Review**: When Grain OS Agent completes Phase 59 (API Server)

