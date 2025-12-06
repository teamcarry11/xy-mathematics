# Grain Carry Agent: Development Plan

**Agent**: Grain Carry Agent (6th Agent)  
**Status**: WebSocket Support Available — Ready for WebSocket Client Implementation  
**Last Updated**: 2025-12-06-061647-pst

---

## Overview

Grain Carry Agent is responsible for building a cross-platform mobile development framework and applications for the Grain OS ecosystem. The framework uses Zig as the shared business logic core with native platform UIs (Kotlin/Jetpack Compose for Android, Swift/SwiftUI for iOS).

**Key Goals**:
- Cross-platform mobile development with maximum code reuse (>80% shared logic)
- Native performance (<5ms vs React Native's 10-50ms)
- Single source of truth for security-critical code (authentication, cryptography)
- Responsive design system for consistent mobile UIs
- Secure authentication (OAuth 2.0, email/password, 2FA, magic email OTP)

---

## Completed Phases

### Phase 1: Core Module & Validation ✅ **COMPLETE** (2025-12-03-160538-pst)

**Description**: Established Grain Carry Core module structure and implemented email/password validation with 32-character minimum password requirement and 1Password-inspired strategy.

**Key Achievements**:
- Grain Carry Core module structure (`src/grain_carry_core/`)
- Email validation (`src/grain_carry_core/validation/email.zig`)
- Password validation (`src/grain_carry_core/validation/password.zig`)
- 32-character minimum password requirement (security best practice)
- 1Password "Memorable Password" strategy support
- Password strength calculation
- Comprehensive validation tests

**Files Created**:
- `src/grain_carry_core/root.zig` — Module root and exports
- `src/grain_carry_core/validation/email.zig` — Email validation
- `src/grain_carry_core/validation/password.zig` — Password validation
- `src/grain_carry_core/utils/errors.zig` — Error handling utilities
- `tests/108_grain_carry_core_validation_test.zig` — Validation tests

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
- Secure random number generation (`src/grain_carry_core/crypto/random.zig`)
- Password hashing with SHA-256 + salt (`src/grain_carry_core/crypto/hash.zig`)
- Magic email OTP generation/validation (`src/grain_carry_core/auth/otp.zig`)
- TOTP 2FA implementation (`src/grain_carry_core/auth/totp.zig`)
- HMAC-SHA1 implementation for TOTP
- Comprehensive crypto/auth tests

**Files Created**:
- `src/grain_carry_core/crypto/random.zig` — Secure random generation
- `src/grain_carry_core/crypto/hash.zig` — Password hashing (SHA-256 + salt)
- `src/grain_carry_core/auth/otp.zig` — Magic email OTP
- `src/grain_carry_core/auth/totp.zig` — TOTP 2FA (RFC 6238)
- `tests/109_grain_carry_core_crypto_auth_test.zig` — Crypto/auth tests

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
- Email/password authentication (`src/grain_carry_core/auth/email.zig`)
- User account creation and authentication
- Session token generation (32-byte secure random tokens)
- JWT token creation (`src/grain_carry_core/auth/jwt.zig`)
- JWT token validation (signature verification, expiration checking)
- Base64URL encoding/decoding (manual implementation, Grain Style compliant)
- HMAC-SHA256 for JWT signatures
- Comprehensive authentication tests

**Files Created**:
- `src/grain_carry_core/auth/email.zig` — Email/password authentication
- `src/grain_carry_core/auth/jwt.zig` — JWT token creation/validation
- `tests/110_grain_carry_core_email_jwt_test.zig` — Email auth and JWT tests

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
- Color palettes (light/dark themes) (`src/grain_carry_core/style/colors.zig`)
- Typography scales (15 text styles) (`src/grain_carry_core/style/typography.zig`)
- Spacing system (6 sizes: xs, sm, md, lg, xl, xxl) (`src/grain_carry_core/style/spacing.zig`)
- Responsive breakpoints (6 breakpoints: phone/tablet/desktop variants) (`src/grain_carry_core/style/breakpoints.zig`)
- Theme management (`src/grain_carry_core/style/themes.zig`)
- Component specifications (10 component types) (`src/grain_carry_core/style/components.zig`)
- FFI layer for style queries (`src/grain_carry_core/ffi/style_api.zig`)
- Comprehensive style system tests
- FFI tests for all style exports

**Files Created**:
- `src/grain_carry_core/style/root.zig` — Style module root
- `src/grain_carry_core/style/colors.zig` — Color palettes
- `src/grain_carry_core/style/typography.zig` — Typography scales
- `src/grain_carry_core/style/spacing.zig` — Spacing system
- `src/grain_carry_core/style/breakpoints.zig` — Responsive breakpoints
- `src/grain_carry_core/style/themes.zig` — Theme management
- `src/grain_carry_core/style/components.zig` — Component specifications
- `src/grain_carry_core/ffi/style_api.zig` — FFI exports for style system
- `tests/111_grain_carry_core_style_test.zig` — Style system tests
- `tests/112_grain_carry_core_style_ffi_test.zig` — FFI tests
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

## Current Work: Handler Adapter Testing

**Priority**: **HIGH** — Handler adapter tests complete, ready for end-to-end testing  
**Status**: **COMPLETE** — Handler adapters, OS integration, and tests implemented  
**Estimated Time**: Complete (2025-12-05-122910-pst)

### Why This Work

While waiting for Grain Core Agent's API Server (Phase 59), we can prepare the API client module structure. This includes request/response models, error handling, and client foundation that will be ready when the API Server is available.

### Completed: API Client Module Structure ✅ (2025-12-04-104041-pst)

**Key Achievements**:
- API client module structure (`src/grain_carry_core/api/`)
- Request/response models (`api/client.zig`)
- HTTP method and status enums
- Header management
- URL building
- Default headers support
- Comprehensive API client tests

**Files Created**:
- `src/grain_carry_core/api/root.zig` — API module root
- `src/grain_carry_core/api/client.zig` — API client (request/response models)
- `tests/113_grain_carry_core_api_client_test.zig` — API client tests

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

### Completed: API Endpoint Definitions ✅ (2025-12-04-150157-pst)

**Key Achievements**:
- API endpoint path definitions (`src/grain_carry_core/api/endpoints.zig`)
- Endpoint registry for mobile app endpoints
- Endpoint path constants (authentication, user endpoints)
- Comprehensive endpoint tests

**Files Created**:
- `src/grain_carry_core/api/endpoints.zig` — Endpoint path definitions
- `tests/114_grain_carry_core_api_endpoints_test.zig` — Endpoint tests
- `docs/agent-communications/mobile_agent_phase_59_acknowledgment.md` — Acknowledgment document

**Endpoint Paths Defined**:
- Authentication: `/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/logout`, `/api/v1/auth/refresh`
- OTP: `/api/v1/auth/otp/send`, `/api/v1/auth/otp/verify`
- 2FA: `/api/v1/auth/2fa/enable`, `/api/v1/auth/2fa/verify`
- Users: `/api/v1/users/profile`, `/api/v1/users/settings`

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (`MAX_ENDPOINT_PATHS`)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Prepare handler function implementations (when JSON support available)
- Register endpoints with Grain Core API Server (when HTTP server ready)
- Implement request/response handling (when JSON support available)

### Completed: API Data Models & Response Helpers ✅ (2025-12-04-153123-pst)

**Key Achievements**:
- API request/response data models (`src/grain_carry_core/api/models.zig`)
- Response builder helpers (`src/grain_carry_core/api/responses.zig`)
- Manual JSON construction (Grain Style compliant, no std.json dependency)
- Request models for authentication endpoints
- Response models for success/error/auth responses
- Comprehensive model tests

**Files Created**:
- `src/grain_carry_core/api/models.zig` — API data models (requests/responses)
- `src/grain_carry_core/api/responses.zig` — Response builder helpers
- `tests/115_grain_carry_core_api_models_test.zig` — Model tests

**Request Models**:
- `RegisterRequest` — User registration (email, password, username)
- `LoginRequest` — User login (email, password)
- `OtpSendRequest` — OTP email send (email)
- `OtpVerifyRequest` — OTP verification (email, code)

**Response Models**:
- `AuthResponse` — Authentication response (token, refresh_token, user_id, expires_in)
- `ErrorResponse` — Error response (error_code, message)

**Response Builders**:
- `build_success_response()` — Build success JSON response
- `build_error_response()` — Build error JSON response
- `build_auth_response()` — Build authentication JSON response

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (`MAX_EMAIL_LEN`, `MAX_PASSWORD_LEN`, `MAX_TOKEN_LEN`, `MAX_MESSAGE_LEN`)
- Minimum 2 assertions per function
- Max 70 lines per function (refactored with helper functions)
- Max 100 characters per line
- Manual JSON construction (no std.json dependency)
- All compiler warnings enabled

**Next Steps**:
- Integrate with Grain Core API Server JSON support (when available)
- Add request parsing helpers (when JSON parsing available)
- Add response parsing helpers (when JSON parsing available)

### Completed: Handler Structures & Validation Helpers ✅ (2025-12-04-155500-pst)

**Key Achievements**:
- Handler function structures for all API endpoints (`src/grain_carry_core/api/handlers.zig`)
- Request validation helpers (`src/grain_carry_core/api/validation.zig`)
- Middleware helpers (`src/grain_carry_core/api/middleware.zig`)
- Handler registry for managing endpoint handlers
- Comprehensive validation and handler tests

**Files Created**:
- `src/grain_carry_core/api/handlers.zig` — Handler function structures and registry
- `src/grain_carry_core/api/validation.zig` — Request validation helpers
- `src/grain_carry_core/api/middleware.zig` — Middleware helpers
- `tests/116_grain_carry_core_api_validation_test.zig` — Validation tests
- `tests/117_grain_carry_core_api_handlers_test.zig` — Handler tests
- `tests/118_grain_carry_core_api_middleware_test.zig` — Middleware tests

**Handler Functions**:
- `handle_register()` — User registration handler
- `handle_login()` — User login handler
- `handle_logout()` — User logout handler
- `handle_refresh()` — Token refresh handler
- `handle_otp_send()` — OTP send handler
- `handle_otp_verify()` — OTP verify handler
- `handle_2fa_enable()` — 2FA enable handler
- `handle_2fa_verify()` — 2FA verify handler
- `handle_users_profile()` — User profile handler
- `handle_users_settings()` — User settings handler

**Validation Functions**:
- `validate_register_request()` — Validate registration request
- `validate_login_request()` — Validate login request
- `validate_otp_send_request()` — Validate OTP send request
- `validate_otp_verify_request()` — Validate OTP verify request

**Middleware Functions**:
- `check_authentication()` — Authentication middleware
- `validate_request_body()` — Request body validation middleware
- `build_error_response_middleware()` — Error response builder
- `build_success_response_middleware()` — Success response builder

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Implement handler logic when JSON support and database are available
- Integrate with Grain Core API Server route registration
- Add authentication middleware integration
- Add database integration for user operations

### Completed: HTTP Request/Response Integration ✅ (2025-12-04-171220-pst)

**Key Achievements**:
- HTTP request/response adapters (`src/grain_carry_core/api/integration.zig`)
- Request extraction helpers (headers, auth tokens)
- Response building helpers (status, headers, body, JSON)
- Integration with Grain Core API Server HTTP structures
- Comprehensive integration tests

**Files Created**:
- `src/grain_carry_core/api/integration.zig` — HTTP request/response adapters
- `tests/119_grain_carry_core_api_integration_test.zig` — Integration tests

**Request Extraction Functions**:
- `get_header_value()` — Extract header value from HTTP request
- `get_auth_token()` — Extract authorization token from "Bearer <token>" format

**Response Building Functions**:
- `set_response_status()` — Set HTTP response status code
- `add_response_header()` — Add header to HTTP response
- `set_response_body_json()` — Set response body from JSON string
- `build_auth_http_response()` — Build HTTP response from AuthResponse model
- `build_error_http_response()` — Build HTTP response from ErrorResponse model
- `build_success_http_response()` — Build HTTP response from success message

**Integration Features**:
- Compatible HTTP request/response structures (matches Grain Core API Server)
- Header extraction and manipulation
- Authorization token extraction
- JSON response body generation
- Status code management
- Ready for route handler integration

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit: MAX_PATH_LEN, MAX_HEADERS, etc.)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Integrate with Grain Core API Server route handlers (when HTTP server ready)
- Add JSON request body parsing (when JSON support available)
- Add query parameter extraction
- Add path parameter extraction integration

### Completed: Middleware Integration with Grain Core ✅ (2025-12-05-083552-pst)

**Key Achievements**:
- Mobile-specific middleware functions (`src/grain_carry_core/api/middleware_integration.zig`)
- Integration with Grain Core middleware framework
- Mobile authentication middleware (JWT token validation)
- Mobile request validation middleware (Content-Type validation)
- Mobile error/success response middleware
- Middleware configuration for different endpoint types
- Comprehensive middleware integration tests

**Files Created**:
- `src/grain_carry_core/api/middleware_integration.zig` — Middleware integration (184 lines)
- `tests/120_grain_carry_core_api_middleware_integration_test.zig` — Middleware integration tests

**Middleware Functions**:
- `mobile_auth_middleware()` — Mobile authentication middleware (validates JWT tokens)
- `mobile_validation_middleware()` — Mobile request validation middleware (Content-Type validation)
- `mobile_error_middleware()` — Mobile error response middleware
- `mobile_success_middleware()` — Mobile success response middleware

**Middleware Configuration**:
- `MiddlewareConfig` — Configuration structure for endpoint middleware
- `for_public_endpoint()` — Configuration for public endpoints (no auth required)
- `for_auth_endpoint()` — Configuration for authentication endpoints
- `for_protected_endpoint()` — Configuration for protected endpoints (auth + rate limiting)

**Integration Features**:
- Compatible with Grain Core middleware framework
- Uses Grain Core HttpRequest/HttpResponse types
- Integrates with Grain Core middleware execution chain
- Ready for route registration with middleware
- Supports CORS, logging, auth, validation, rate limiting

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Register middleware with mobile endpoints (when route registration ready)
- Integrate JWT validation in auth middleware (when JWT support available)
- Add request body validation in validation middleware (when JSON parsing available)
- Test middleware chain execution with actual routes

### Completed: Route Registration Helpers ✅ (2025-12-05-095917-pst)

**Key Achievements**:
- Route registration helpers (`src/grain_carry_core/api/route_registration.zig`)
- Endpoint configuration system
- Handler adapter functions (prepared for Grain Core integration)
- Middleware configuration mapping
- Comprehensive route registration tests

**Files Created**:
- `src/grain_carry_core/api/route_registration.zig` — Route registration helpers (173 lines)
- `tests/121_grain_carry_core_api_route_registration_test.zig` — Route registration tests

**Route Registration Functions**:
- `register_mobile_endpoint()` — Register single mobile endpoint with handler
- `register_all_mobile_endpoints()` — Register all 10 mobile endpoints at once
- `get_endpoint_config()` — Get endpoint configuration by path
- `get_middleware_config_for_endpoint()` — Get middleware configuration for endpoint
- `create_handler_adapter()` — Create handler adapter for Grain Core RouteHandler

**Endpoint Configuration**:
- `EndpointConfig` — Configuration structure for each endpoint
- `MOBILE_ENDPOINTS` — Array of all 10 mobile endpoint configurations
- Config includes: path, method, requires_auth, is_public flags
- Automatic middleware configuration based on endpoint type

**Endpoint Types**:
- Public endpoints (AUTH_REGISTER, AUTH_LOGIN, AUTH_OTP_SEND, AUTH_OTP_VERIFY) — No auth required
- Protected endpoints (AUTH_LOGOUT, AUTH_REFRESH, AUTH_2FA_ENABLE, AUTH_2FA_VERIFY, USERS_PROFILE, USERS_SETTINGS) — Auth required

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- Integrate with Grain Core API Server route registration (when HTTP server ready)
- Implement handler adapter logic (when Grain Core types available)
- Test route registration with actual API server
- Verify middleware chain execution with registered routes

### Completed: Authentication Service Integration ✅ (2025-12-05-140857-pst)

**Key Achievements**:
- Authentication integration module (`src/grain_carry_core/api/auth_integration.zig`)
- Integration with Grain Core Authentication Service (Phase 60)
- JWT token validation using AuthService
- JWT token generation (access and refresh tokens)
- Password hashing and verification using AuthService
- Token extraction from Authorization headers
- Enhanced middleware with AuthService integration
- OS integration updated to accept AuthService instance
- Comprehensive authentication integration tests

**Files Created/Modified**:
- `src/grain_carry_core/api/auth_integration.zig` — Authentication integration module (new)
- `src/grain_carry_core/api/middleware_integration.zig` — Updated to use AuthService
- `src/grain_carry_core/api/os_integration.zig` — Updated to accept AuthService parameter
- `src/grain_carry_core/api/root.zig` — Exported auth_integration module
- `tests/123_grain_carry_core_auth_integration_test.zig` — Authentication integration tests (new)
- `tests/122_grain_carry_core_api_handler_adapters_test.zig` — Updated to include AuthService
- `build.zig` — Added auth integration test configuration

**Authentication Integration Functions**:
- `set_auth_service()` / `get_auth_service()` — AuthService instance management
- `validate_jwt_token()` — Validate JWT tokens using AuthService
- `generate_access_token()` — Generate access tokens using AuthService
- `generate_refresh_token()` — Generate refresh tokens using AuthService
- `hash_password()` — Hash passwords using AuthService
- `verify_password()` — Verify passwords using AuthService
- `extract_jwt_token_from_request()` — Extract JWT from Authorization header

**Middleware Integration**:
- `mobile_auth_middleware()` — Updated to use AuthService for JWT validation
- Validates JWT tokens using AuthService.validate_jwt_token()
- Extracts tokens from Authorization headers
- Returns 401 for invalid or expired tokens

**Test Coverage**:
- AuthService set/get tests
- JWT token generation tests
- JWT token validation tests
- Password hashing and verification tests
- Token extraction from request tests

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- No recursion
- All compiler warnings enabled

**Next Steps**:
- ✅ Handler adapters enhanced with auth service integration
- ✅ Password hashing integrated in register handler
- ✅ JWT token generation integrated in login handler
- ✅ Token validation integrated in protected endpoint handlers
- ⏳ Enhanced handler logic with database integration (when database available)

### Completed: Handler Adapters Enhanced with Auth Service Integration ✅ (2025-12-06-010336-pst)

**Key Achievements**:
- Enhanced all handler adapters to use Authentication Service integration
- Register handler: Password hashing using AuthService
- Login handler: JWT token generation (access and refresh tokens)
- Logout handler: Token revocation
- Refresh handler: Refresh token validation and new access token generation
- OTP handlers: OTP generation and validation using AuthService
- Protected endpoints: JWT token validation (users/profile, users/settings)

**Files Modified**:
- `src/grain_carry_core/api/handler_adapters.zig` — Enhanced all handler adapters (577 lines)

**Handler Adapter Enhancements**:
- `handle_register_adapter()` — Hashes passwords using `auth_integration.hash_password()`
- `handle_login_adapter()` — Generates access and refresh tokens using `auth_integration.generate_access_token()` and `auth_integration.generate_refresh_token()`
- `handle_logout_adapter()` — Revokes JWT tokens using `auth_service.revoke_token()`
- `handle_refresh_adapter()` — Validates refresh tokens and generates new access tokens
- `handle_otp_send_adapter()` — Generates OTP codes using `auth_service_integration.generate_email_otp()`
- `handle_otp_verify_adapter()` — Validates OTP codes and generates JWT tokens
- `handle_users_profile_adapter()` — Validates JWT tokens using `auth_service_integration.extract_and_validate_token()`
- `handle_users_settings_adapter()` — Validates JWT tokens using `auth_service_integration.extract_and_validate_token()`

**Grain Style Compliance**:
- ✅ `grain_case` function names
- ✅ `u32`/`u64` types (no `usize`)
- ✅ Bounded allocations (all limits explicit)
- ✅ Minimum 2 assertions per function
- ✅ Max 70 lines per function (all functions compliant)
- ✅ Max 100 characters per line
- ✅ All compiler warnings enabled

**Next Steps**:
- ✅ Enhanced handler adapter tests to verify auth service integration
- ⏳ Integrate with database when available (user storage, credential verification)
- ⏳ Add email service integration for OTP delivery

### Completed: Handler Adapter Tests Enhanced with Auth Service Integration ✅ (2025-12-06-014044-pst)

**Key Achievements**:
- Enhanced all handler adapter tests to verify auth service integration
- Register handler test: Verifies JWT token generation in response
- Login handler test: Verifies JWT token generation in response
- Logout handler test: Tests token revocation with valid JWT token
- Users profile handler test: Tests protected endpoint with valid JWT token
- Users profile unauthorized test: Verifies 401 response for missing/invalid tokens
- OTP send handler test: Tests OTP generation with auth service
- All tests now set up AuthService instance before running

**Files Modified**:
- `tests/122_grain_mobile_core_api_handler_adapters_test.zig` — Enhanced all tests with auth service setup
- `src/grain_carry_core/api/root.zig` — Exported `auth_service_integration` module

**Test Enhancements**:
- All tests now initialize AuthService with secret key
- Register/login tests verify token presence in response body
- Logout test generates token before testing revocation
- Protected endpoint tests use valid JWT tokens in Authorization header
- Unauthorized test verifies 401 response for missing tokens

**Grain Style Compliance**:
- ✅ `grain_case` function names
- ✅ `u32`/`u64` types (no `usize`)
- ✅ Bounded allocations (all limits explicit)
- ✅ Minimum 2 assertions per function
- ✅ Max 70 lines per function (all functions compliant)
- ✅ Max 100 characters per line
- ✅ All compiler warnings enabled

**Next Steps**:
- ✅ WebSocket client core module complete
- ⏳ Integrate with database when available (user storage, credential verification)
- ⏳ Add email service integration for OTP delivery
- ⏳ Complete WebSocket client with connection management and message handling

### Completed: WebSocket Client Core Module ✅ (2025-12-06-033256-pst)

**Key Achievements**:
- WebSocket client module structure (`src/grain_carry_core/websocket/client.zig`)
- WebSocket client connection management (`WebSocketClient`, `WebSocketClientManager`)
- Client key generation for handshake
- Upgrade request building for WebSocket handshake
- Text and binary message sending functions
- Frame parsing for received messages
- Comprehensive WebSocket client tests

**Files Created**:
- `src/grain_carry_core/websocket/client.zig` — WebSocket client module (430 lines)
- `src/grain_carry_core/websocket/root.zig` — WebSocket module root
- `tests/125_grain_carry_core_websocket_client_test.zig` — WebSocket client tests

**WebSocket Client Features**:
- `WebSocketClient` — Client connection structure with state management
- `WebSocketClientManager` — Manager for multiple client connections (max 16)
- `generate_client_key()` — Generate WebSocket client key for handshake
- `build_upgrade_request()` — Build HTTP upgrade request for WebSocket handshake
- `send_text_message()` — Send text messages via WebSocket
- `send_binary_message()` — Send binary messages via WebSocket
- `parse_received_frame()` — Parse received WebSocket frames
- `handle_received_frame()` — Handle received frames and update client state
- `send_ping()` — Send ping frames for keepalive
- `send_pong()` — Send pong frames in response to ping
- `close_connection()` — Close connection with status code and reason
- `set_connected()` — Update client state to connected
- `set_disconnected()` — Update client state to disconnected
- `extract_text_message()` — Extract text messages from received frames
- `extract_binary_message()` — Extract binary messages from received frames

**Grain Style Compliance**:
- ✅ `grain_case` function names
- ✅ `u32`/`u64` types (no `usize`)
- ✅ Bounded allocations (all limits explicit: `MAX_CLIENT_CONNECTIONS`, `MAX_CLIENT_MESSAGE_SIZE`)
- ✅ Minimum 2 assertions per function
- ✅ Max 70 lines per function (all functions compliant)
- ✅ Max 100 characters per line
- ✅ All compiler warnings enabled

**Test Coverage**:
- Client manager initialization
- Client creation and management
- URL setting
- Client key generation
- Upgrade request building
- Client finding and removal
- Connection state management (set_connected, set_disconnected)
- Ping/pong frame generation
- Connection closing with status codes
- Message extraction (text/binary)

**Next Steps**:
- ✅ Message receiving and handling complete
- ✅ Ping/pong support for keepalive complete
- ✅ Connection state management complete
- ⏳ Complete connection management (TCP socket connection, handshake completion)
- ⏳ Integrate with network stack when available

### Completed: WebSocket Client Enhanced with Message Handling and Keepalive ✅ (2025-12-06-060251-pst)

**Key Achievements**:
- Enhanced WebSocket client with message receiving and handling
- Ping/pong support for keepalive
- Connection state management (set_connected, set_disconnected)
- Connection closing with status codes
- Text and binary message extraction from frames
- Frame handling with activity tracking
- Comprehensive tests for enhanced features

**Files Modified**:
- `src/grain_carry_core/websocket/client.zig` — Enhanced with message handling and keepalive (430 lines)
- `tests/125_grain_carry_core_websocket_client_test.zig` — Added tests for enhanced features

**New WebSocket Client Features**:
- `handle_received_frame()` — Handle received frames and update client state
- `send_ping()` — Send ping frames for keepalive
- `send_pong()` — Send pong frames in response to ping
- `close_connection()` — Close connection with status code and reason
- `set_connected()` — Update client state to connected
- `set_disconnected()` — Update client state to disconnected
- `extract_text_message()` — Extract text messages from received frames
- `extract_binary_message()` — Extract binary messages from received frames

**Grain Style Compliance**:
- ✅ `grain_case` function names
- ✅ `u32`/`u64` types (no `usize`)
- ✅ Bounded allocations (all limits explicit)
- ✅ Minimum 2 assertions per function
- ✅ Max 70 lines per function (all functions compliant)
- ✅ Max 100 characters per line
- ✅ All compiler warnings enabled

**Test Coverage**:
- Connection state management (set_connected, set_disconnected)
- Ping/pong frame generation
- Connection closing with status codes
- Message extraction (text/binary)

**Next Steps**:
- Complete connection management (TCP socket connection, handshake completion)
- Integrate with network stack when available

### Completed: Handler Adapters for API Server Integration ✅ (2025-12-05-104041-pst)

**Key Achievements**:
- Handler adapter functions (`src/grain_carry_core/api/handler_adapters.zig`)
- OS integration module (`src/grain_carry_core/api/os_integration.zig`)
- Adapter functions for all 10 mobile endpoints
- Handler result to HTTP response conversion
- Integration with Grain Core API Server RouteHandler signature
- Comprehensive handler adapter tests using `process_http_request()`

**Files Created**:
- `src/grain_carry_core/api/handler_adapters.zig` — Handler adapters (433 lines)
- `src/grain_carry_core/api/os_integration.zig` — OS integration (route registration)
- `tests/122_grain_carry_core_api_handler_adapters_test.zig` — Handler adapter tests (updated)

**Handler Adapter Functions**:
- `handle_register_adapter()` — Adapter for user registration endpoint (POST /api/v1/auth/register)
- `handle_login_adapter()` — Adapter for user login endpoint (POST /api/v1/auth/login)
- `handle_logout_adapter()` — Adapter for user logout endpoint (POST /api/v1/auth/logout)
- `handle_refresh_adapter()` — Adapter for token refresh endpoint (POST /api/v1/auth/refresh)
- `handle_otp_send_adapter()` — Adapter for OTP send endpoint (POST /api/v1/auth/otp/send)
- `handle_otp_verify_adapter()` — Adapter for OTP verify endpoint (POST /api/v1/auth/otp/verify)
- `handle_2fa_enable_adapter()` — Adapter for 2FA enable endpoint (POST /api/v1/auth/2fa/enable)
- `handle_2fa_verify_adapter()` — Adapter for 2FA verify endpoint (POST /api/v1/auth/2fa/verify)
- `handle_users_profile_adapter()` — Adapter for user profile endpoint (GET /api/v1/users/profile)
- `handle_users_settings_adapter()` — Adapter for user settings endpoint (GET /api/v1/users/settings)

**OS Integration Functions**:
- `register_mobile_endpoints_with_compositor()` — Register all 10 endpoints with Grain Core Compositor

**Response Conversion**:
- `convert_handler_result_to_response()` — Converts HandlerResult enum to HTTP response
- Maps handler results to appropriate HTTP status codes (200, 400, 401, 404, 500)
- Generates JSON error/success responses
- Sets appropriate Content-Type headers

**Integration Features**:
- Compatible with Grain Core API Server RouteHandler signature
- Uses Grain Core HttpRequest/HttpResponse types
- Integrates with handler context system
- Ready for route registration with actual API server
- Supports full request/response pipeline

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Test Coverage** (2025-12-05-122910-pst):
- Register endpoint test (POST /api/v1/auth/register)
- Login endpoint test (POST /api/v1/auth/login)
- Logout endpoint test (POST /api/v1/auth/logout)
- OTP send endpoint test (POST /api/v1/auth/otp/send)
- OTP verify endpoint test (POST /api/v1/auth/otp/verify)
- Users profile endpoint test (GET /api/v1/users/profile)
- Bad request handling test (invalid JSON)
- OS integration test (register all endpoints with Compositor)
- All tests use `process_http_request()` for full pipeline testing

**Next Steps**:
- End-to-end API testing with actual network connections (when HTTP server running)
- Enhanced handler logic (when database is available)

### Completed: Authentication Service Integration ✅ (2025-12-05-140857-pst)

**Key Achievements**:
- Auth service integration module (`src/grain_carry_core/api/auth_integration.zig`)
- Integration with Grain Core Authentication Service (Phase 60)
- JWT token extraction and validation
- Password hashing and verification
- Session management
- OTP generation and validation
- TOTP code generation and validation
- Token revocation
- Comprehensive auth service integration tests

**Files Created**:
- `src/grain_carry_core/api/auth_service_integration.zig` — Auth service integration (272 lines)
- `tests/124_grain_carry_core_api_auth_service_integration_test.zig` — Auth service integration tests

**Auth Service Integration Functions**:
- `set_auth_service()` — Set global auth service instance
- `extract_and_validate_token()` — Extract and validate JWT token from HTTP request
- `generate_tokens_for_user()` — Generate access and refresh tokens
- `hash_password()` — Hash password using auth service
- `verify_password()` — Verify password using auth service
- `create_user_session()` — Create session for user
- `validate_user_session()` — Validate user session
- `generate_email_otp()` — Generate OTP for email
- `validate_email_otp()` — Validate OTP code
- `generate_totp_code()` — Generate TOTP code from secret
- `validate_totp_code()` — Validate TOTP code
- `revoke_user_token()` — Revoke token (logout)

**Integration Features**:
- Direct integration with Grain Core Authentication Service
- Uses Grain Core AuthService for all authentication operations
- JWT token management (access/refresh tokens, validation, revocation)
- Password authentication (hashing, verification)
- Session management (create, validate)
- 2FA/TOTP support (code generation, validation)
- Magic email OTP support (generation, validation)
- Ready for handler adapter integration

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- ✅ Handler adapters enhanced with auth service integration
- ✅ Password hashing integrated in register handler
- ✅ JWT token generation integrated in login handler
- ✅ Token validation integrated in protected endpoint handlers
- ✅ Logout handler revokes tokens
- ✅ Refresh handler validates refresh tokens and generates new access tokens
- ✅ OTP handlers integrated with auth service

### Completed: Integration Pipeline Tests ✅ (2025-12-05-124416-pst)

**Key Achievements**:
- Integration tests using `process_http_request()` (`tests/123_grain_carry_core_api_integration_pipeline_test.zig`)
- Full request/response pipeline testing
- Route registration and handler execution testing
- Middleware chain execution testing
- Error handling and edge case testing

**Files Created**:
- `tests/123_grain_carry_core_api_integration_pipeline_test.zig` — Integration pipeline tests (207 lines)

**Test Coverage**:
- Route registration with compositor
- Register endpoint (POST /api/v1/auth/register)
- Login endpoint (POST /api/v1/auth/login)
- Users profile endpoint (GET /api/v1/users/profile)
- 404 handling for unregistered routes
- OTP send endpoint (POST /api/v1/auth/otp/send)
- Middleware execution with CORS
- Request parsing with query parameters
- Response generation and headers

**Integration Features**:
- Uses `process_http_request()` for full pipeline testing
- Tests route registration with Grain Core Compositor
- Tests middleware chain execution
- Tests handler adapter execution
- Tests HTTP request parsing
- Tests HTTP response generation
- Verifies status codes and headers

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` types (no `usize`)
- Bounded allocations (all limits explicit)
- Minimum 2 assertions per function
- Max 70 lines per function (all functions compliant)
- Max 100 characters per line
- All compiler warnings enabled

**Next Steps**:
- End-to-end API testing with actual network connections (when network integration ready)
- Add database integration tests (when database available)
- Add authentication service integration tests (when Phase 60 complete)

---

## Phase 59 Complete: API Server Integration Ready

**Priority**: **COMPLETE** — Phase 59 API Server is complete  
**Status**: **READY** — All API infrastructure ready for mobile app development  
**Completion Date**: 2025-12-05-120808-pst

### What's Available Now

1. **API Server (Grain Core Agent Phase 59)**: ✅ **COMPLETE**
   - HTTP request parsing ✅
   - HTTP response generation ✅
   - Route registration ✅
   - Middleware framework ✅
   - Connection handling ✅
   - Network integration ✅
   - Process manager integration ✅
   - JSON support ✅

2. **Carry Agent Integration**: ✅ **COMPLETE**
   - Handler adapters for all endpoints ✅
   - Route registration with compositor ✅
   - Middleware integration ✅
   - Integration pipeline tests ✅

### What's Now Available

1. **API Server (Grain Core Agent Phase 59)**: ✅ **COMPLETE** (2025-12-05-120808-pst)
   - HTTP request parsing ✅
   - HTTP response generation ✅
   - Route registration ✅
   - Middleware framework ✅
   - Connection handling ✅
   - Network integration ✅
   - Process manager integration ✅
   - JSON support ✅
   - Carry Agent integration ✅

2. **Authentication Service (Grain Core Agent Phase 60)**: ✅ **COMPLETE** (2025-12-05-140711-pst)
   - JWT token generation and validation ✅
   - Password hashing and verification ✅
   - Session management ✅
   - 2FA/TOTP support ✅
   - Magic email OTP ✅
   - Carry Agent integration ✅

3. **WebSocket Support (Grain Core Agent Phase 61)**: ✅ **COMPLETE** (2025-12-05-202227-pst)
   - WebSocket handshake (HTTP upgrade) ✅
   - WebSocket frame parsing (text, binary, ping, pong, close) ✅
   - WebSocket frame generation ✅
   - WebSocket connection management ✅
   - Ready for Carry Agent WebSocket client implementation ✅

4. **DNS Resolution (Grain Core Agent Phase 61)**: ✅ **COMPLETE** (2025-12-05-231800-pst)
   - DNS resolver with bounded cache ✅
   - DNS cache entry management ✅
   - DNS cache expiration ✅
   - DNS record types (A, AAAA, MX) ✅
   - Hostname resolution ready for network integration ✅
   - Ready for Carry Agent domain name resolution ✅

5. **File Storage (Grain Core Agent Phase 62)**: ✅ **COMPLETE** (2025-12-06-061647-pst)
   - Database file format with header validation ✅
   - Page-based storage with integrity checks ✅
   - File handle management with locking ✅
   - Transaction Log File Management (WAL) ✅ (2025-12-06-035857-pst)
   - Index File Management ✅ (2025-12-06-045220-pst)
   - Backup/Restore Capabilities ✅ (2025-12-06-061647-pst)
   - Ready for Silo Agent database persistence with ACID guarantees, efficient queries, and data protection ✅
   - Enables Carry Agent database integration when Silo Agent completes ✅

### What We're Ready For

- ✅ Core business logic (validation, crypto, authentication)
- ✅ Style system (responsive design, component specs)
- ✅ FFI layer (C-compatible API for Kotlin/Swift)
- ✅ JWT token handling
- ✅ Password hashing and validation
- ✅ OTP and TOTP 2FA
- ✅ WebSocket client implementation (for livestream coordination)

### Next Steps When Unblocked

1. **Android App Development** (Phase 5): Native Kotlin app with Jetpack Compose
2. **iOS App Development** (Phase 6): Native Swift app with SwiftUI
3. **OAuth Integration** (Phase 7): Google, Facebook, GitHub, Apple Sign-In
4. **API Client Integration**: Connect to Grain Core API Server

---

## Planned Phases

### Phase 5: Android App Development (PLANNED)

**Priority**: **HIGH** — First mobile platform  
**Status**: **PLANNED** — Waiting for Grain Core Agent Phase 59  
**Estimated Time**: 4-6 weeks

**Description**: Build native Android application using Kotlin and Jetpack Compose, integrated with Grain Carry Core via JNI bindings.

**Features**:
- Native Kotlin application structure
- Jetpack Compose UI with Grain Mobile style system
- JNI bindings for Grain Carry Core FFI
- API client implementation (when API Server available)
- Authentication UI (email/password, OAuth, 2FA)
- Main app UI (candidate profiles, policy stances, search)
- Responsive design using breakpoint system

**Deliverables**:
- Android app project structure
- JNI bindings (`android/app/src/main/jni/`)
- Kotlin wrapper classes for Grain Carry Core
- Jetpack Compose UI components
- Integration tests

**Dependencies**:
- **Needs**: API Server (Grain Core Agent Phase 59), Authentication Service (Grain Core Agent Phase 60)
- **Provides**: Android mobile application
- **Coordinates with**: Grain Core Agent (API contracts), Grain Database Agent (REST API)

---

### Phase 6: iOS App Development (PLANNED)

**Priority**: **HIGH** — Second mobile platform  
**Status**: **PLANNED** — Waiting for Grain Core Agent Phase 59  
**Estimated Time**: 4-6 weeks

**Description**: Build native iOS application using Swift and SwiftUI, integrated with Grain Carry Core via C interop.

**Features**:
- Native Swift application structure
- SwiftUI UI with Grain Mobile style system
- C interop bindings for Grain Carry Core FFI
- API client implementation (when API Server available)
- Authentication UI (email/password, OAuth, 2FA, Apple Sign-In)
- Main app UI (candidate profiles, policy stances, search)
- Responsive design using breakpoint system

**Deliverables**:
- iOS app project structure
- C interop bindings
- Swift wrapper classes for Grain Carry Core
- SwiftUI UI components
- Integration tests

**Dependencies**:
- **Needs**: API Server (Grain Core Agent Phase 59), Authentication Service (Grain Core Agent Phase 60)
- **Provides**: iOS mobile application
- **Coordinates with**: Grain Core Agent (API contracts), Grain Database Agent (REST API)

---

### Phase 7: OAuth Integration (PLANNED)

**Priority**: **MEDIUM** — Enhanced authentication  
**Status**: **PLANNED** — Waiting for Grain Core Agent Phase 60  
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
- **Needs**: Authentication Service (Grain Core Agent Phase 60)
- **Provides**: OAuth authentication for mobile apps
- **Coordinates with**: Grain Core Agent (OAuth flow)

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
- **Needs**: WebSocket support ✅ **COMPLETE** (Grain Core Agent Phase 61)
- **Provides**: Advanced mobile features
- **Coordinates with**: Grain Core Agent (network capabilities), Grain Database Agent (data models)

---

## Coordination Points

### With Grain Core Agent

**Integration Points**:
- **API Server (Phase 59)**: Carry Agent depends on Grain Core Agent's API Server for backend connection
  - Mobile apps connect to API Server via REST API
  - API Server routes requests to Database Agent
  - Coordination on API contracts and endpoints
- **Authentication Service (Phase 60)**: Secure mobile app authentication depends on Grain Core Agent's Authentication Service
  - JWT token validation
  - OAuth integration (Google, Facebook, GitHub, Apple)
  - 2FA support (TOTP, magic email OTP)
- **WebSocket Support (Phase 61)**: ✅ **COMPLETE** (2025-12-05-202227-pst)
  - WebSocket handshake (HTTP upgrade) ✅
  - WebSocket frame parsing and generation ✅
  - WebSocket connection management ✅
  - Ready for Carry Agent WebSocket client implementation ✅
- **DNS Resolution (Phase 61)**: ✅ **COMPLETE** (2025-12-05-231800-pst)
  - DNS resolver with bounded cache ✅
  - DNS cache entry management ✅
  - DNS record types (A, AAAA, MX) ✅
  - Hostname resolution ✅
  - Enables domain name resolution for API clients ✅

**Coordination Notes**:
- Carry Agent is **ready** for API Server (Phase 59) ✅, Authentication Service (Phase 60) ✅, WebSocket Support (Phase 61) ✅, and DNS Resolution (Phase 61) ✅
- All core infrastructure is complete and ready for integration
- Carry Agent has completed all core modules and is ready for integration

**Future Coordination**:
- **API Integration**: ✅ Complete — Carry Agent's API clients integrated with Grain Core API Server
- **Authentication**: ✅ Complete — Secure authentication integrated with Grain Core Authentication Service
- **WebSocket**: ✅ Complete — WebSocket support available, ready for Carry Agent WebSocket client implementation
- **Style System Unification**: Consult with Grain Core Agent about unifying mobile and desktop style systems (see `docs/grain_core_agent_style_unification_prompt.md`)

---

### With Grain Database Agent

**Integration Points**:
- **REST API**: Carry Agent uses Database Agent's REST API for backend connection
  - Mobile apps connect to Database Agent's REST API via Grain Core Agent's API Server
  - Database Agent provides data storage and retrieval
  - Carry Agent provides mobile app UI and business logic
- **Database Backend**: Database Agent provides backend for mobile applications
  - User profiles, policy stances, candidate information
  - Social graph (relationships, connections)
  - Full-text search (policy topic search, candidate search)

**Coordination Notes**:
- Carry Agent depends on Database Agent's REST API
- Database Agent provides backend for mobile applications
- Both agents depend on Grain Core Agent's API Server (Phase 59)

**Future Coordination**:
- **API Integration**: When Grain Core Agent completes Phase 59, Carry Agent can connect to Database Agent's REST API
- **Data Models**: Coordinate on data models for mobile app (user profiles, policy stances, etc.)
- **Authentication**: Coordinate on authentication flow (JWT, OAuth, 2FA)

---

### With Vantage Agent

**Integration Points**:
- **Kernel File I/O**: Not directly used (mobile apps use platform file systems)
- **Network Syscalls**: Not directly used (mobile apps use platform network stacks)
- **Indirect Integration**: Mobile apps use Grain Core infrastructure, which uses kernel syscalls

**Coordination Notes**:
- Mobile apps run on Android/iOS platforms, not directly on Grain OS kernel
- Mobile apps use Grain Core infrastructure (API Server, Database) which uses kernel syscalls
- No direct coordination needed — Grain Core Agent handles kernel integration

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Core Plan**: [`docs/plan.md`](../plan.md) — Core overview
- **Grain Carry Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](../grain_mobile_agent_prompt.md) — Agent prompt and architecture
- **Grain Carry Core Architecture**: [`docs/grain_carry_core_architecture.md`](../grain_carry_core_architecture.md) — Architecture details
- **Grain Mobile Style System**: [`docs/grain_mobile_style_system.md`](../grain_mobile_style_system.md) — Style system design
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plan_core.md) — Grain Core Agent plan
- **Grain Database Agent Plan**: [`docs/plans/plan_database.md`](plan_database.md) — Database Agent plan

---

**Last Updated**: 2025-12-05-122910-pst  
**Next Review**: When ready for end-to-end testing with actual HTTP server

