# Grain Mobile Core Architecture

**Date**: 2025-12-03-151539-pst  
**Purpose**: Cross-platform mobile development strategy using Zig as shared core  
**Module Name**: `grain_mobile_core`

---

## Overview

**Grain Mobile Core** (`grain_mobile_core`) is a Grain OS module that provides a high-performance, cross-platform shared codebase for mobile applications. Unlike React Native (JavaScript bridge overhead) or Flutter (Dart runtime), Grain Mobile Core compiles Zig code to native libraries, providing near-native performance while maximizing code reuse.

### Core Philosophy

1. **Shared Business Logic in Zig**: All business logic, data models, API clients, validation, and cryptography in Zig (Grain Style compliant)
2. **Native UI per Platform**: Platform-specific UI (Kotlin Compose for Android, SwiftUI for iOS)
3. **Zero Runtime Overhead**: Direct native library calls, no JavaScript bridge or VM
4. **Grain Style Compliance**: Full Grain Style compliance in Zig shared code
5. **Type Safety**: Strong typing across the boundary via C-compatible FFI

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Applications                    │
├──────────────────────────┬───────────────────────────────┤
│   Android (Kotlin)      │      iOS (Swift)              │
│   - Jetpack Compose UI   │      - SwiftUI UI             │
│   - ViewModels           │      - ViewModels             │
│   - Platform Services    │      - Platform Services      │
└──────────────┬───────────┴───────────────┬───────────────┘
               │                           │
               │ JNI                       │ C Interop
               │                           │
┌──────────────▼───────────────────────────▼───────────────┐
│           Grain Mobile Core (Zig)                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │  C-Compatible FFI Layer                           │  │
│  │  - Exported C functions                            │  │
│  │  - Memory-safe wrappers                            │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Business Logic Layer                              │  │
│  │  - Authentication (OAuth, email, 2FA)              │  │
│  │  - API clients (HTTP, WebSocket)                  │  │
│  │  - Data models and validation                      │  │
│  │  - Cryptography (hashing, encryption)             │  │
│  │  - State management                                │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Platform Abstraction Layer                       │  │
│  │  - Network (HTTP client)                           │  │
│  │  - Storage (key-value, secure storage)             │  │
│  │  - Crypto (platform-native or Zig)                │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

### Module Structure

```
src/grain_mobile_core/
├── root.zig                    # Module root, exports
├── ffi/
│   ├── c_api.zig              # C-compatible FFI exports
│   ├── jni_bindings.zig       # JNI-specific helpers
│   └── swift_bindings.zig     # Swift-specific helpers
├── auth/
│   ├── oauth.zig              # OAuth 2.0 implementation
│   ├── email.zig              # Email/password auth
│   ├── otp.zig                # Magic email OTP
│   ├── totp.zig               # TOTP 2FA (RFC 6238)
│   └── jwt.zig                # JWT token handling
├── api/
│   ├── client.zig             # HTTP client (shared)
│   ├── models.zig             # API request/response models
│   ├── endpoints.zig          # API endpoint definitions
│   └── validation.zig         # Input validation
├── crypto/
│   ├── hash.zig               # Hashing (SHA-256, bcrypt, Argon2)
│   ├── encryption.zig         # Encryption/decryption
│   └── random.zig             # Secure random generation
├── storage/
│   ├── kv_store.zig           # Key-value storage interface
│   └── secure_store.zig       # Secure storage (tokens, keys)
├── state/
│   ├── state_manager.zig      # Application state management
│   └── cache.zig              # Response caching
├── validation/
│   ├── email.zig              # Email validation
│   ├── password.zig           # Password strength validation
│   └── input.zig              # General input validation
└── utils/
    ├── errors.zig             # Error types and handling
    ├── logging.zig            # Logging interface
    └── memory.zig             # Memory management helpers
```

---

## FFI Strategy

### C-Compatible API

Zig compiles to C-compatible libraries. We export a C API that both platforms can call:

```zig
// src/grain_mobile_core/ffi/c_api.zig

// Export C-compatible functions
export fn grain_mobile_auth_validate_email(
    email_ptr: [*c]const u8,
    email_len: u32,
) c_int {
    // Grain Style: assertions, bounded operations
    std.debug.assert(email_ptr != null);
    std.debug.assert(email_len > 0);
    std.debug.assert(email_len <= MAX_EMAIL_LEN);
    
    const email = email_ptr[0..email_len];
    return if (validation.email.is_valid(email)) 1 else 0;
}

export fn grain_mobile_auth_hash_password(
    password_ptr: [*c]const u8,
    password_len: u32,
    hash_out: [*c]u8,
    hash_out_len: *u32,
) c_int {
    // Implementation with Grain Style compliance
    // ...
}
```

### Android JNI Bindings

Kotlin calls Zig via JNI:

```kotlin
// Android: JNI wrapper
class GrainMobileCore {
    companion object {
        init {
            System.loadLibrary("grain_mobile_core")
        }
    }
    
    external fun validateEmail(email: String): Boolean
    external fun hashPassword(password: String): String
    external fun generateOTP(): String
    // ...
}
```

```zig
// Zig: JNI-compatible exports
export fn Java_com_grain_election_GrainMobileCore_validateEmail(
    env: *JNIEnv,
    _: jclass,
    email: jstring,
) jboolean {
    // JNI string extraction and validation
    // Call internal Zig function
    // Return result
}
```

### iOS C Interop

Swift calls Zig via C interop:

```swift
// iOS: Swift wrapper
@_cdecl("grain_mobile_auth_validate_email")
func validateEmail(_ email: UnsafePointer<CChar>, _ len: UInt32) -> Int32

// Usage
let email = "user@example.com"
let isValid = validateEmail(email, UInt32(email.utf8.count)) != 0
```

---

## Shared Components

### 1. Authentication Logic

**All authentication logic in Zig**:
- OAuth 2.0 flow implementation
- Email/password validation and hashing
- OTP generation and validation
- TOTP secret generation and validation
- JWT token parsing and validation

**Platform-specific**: Only UI and platform OAuth SDK integration

### 2. API Client

**HTTP client in Zig**:
- Request building
- Response parsing
- Error handling
- Retry logic
- Request signing (if needed)

**Platform-specific**: Only network transport (uses platform HTTP libraries via FFI)

### 3. Data Models

**All data models in Zig**:
- Request/response structures
- Validation rules
- Serialization/deserialization (JSON)

**Platform-specific**: Only UI data binding

### 4. Cryptography

**All crypto in Zig**:
- Password hashing (bcrypt, Argon2)
- Token generation
- Encryption/decryption
- Secure random generation

**Platform-specific**: None (pure Zig implementation)

### 5. State Management

**State management in Zig**:
- Application state structures
- State transitions
- Validation

**Platform-specific**: Only UI state binding

---

## Build Configuration

### Zig Library Build

```zig
// build.zig for grain_mobile_core

pub fn build(b: *std.Build) void {
    // Android: Build .so shared library
    const android_lib = b.addSharedLibrary(.{
        .name = "grain_mobile_core",
        .root_source_file = b.path("src/grain_mobile_core/root.zig"),
        .target = .{
            .cpu_arch = .aarch64, // or .x86_64
            .os_tag = .linux,     // Android uses Linux
            .abi = .gnu,          // Android ABI
        },
        .optimize = .ReleaseFast,
    });
    
    // iOS: Build static library or framework
    const ios_lib = b.addStaticLibrary(.{
        .name = "grain_mobile_core",
        .root_source_file = b.path("src/grain_mobile_core/root.zig"),
        .target = .{
            .cpu_arch = .aarch64, // Apple Silicon
            .os_tag = .ios,
        },
        .optimize = .ReleaseFast,
    });
}
```

### Android Integration

```kotlin
// android/app/build.gradle.kts
android {
    // ...
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("../../../zig-out/lib")
        }
    }
}
```

### iOS Integration

```swift
// Xcode: Link static library
// Add grain_mobile_core.a to "Link Binary With Libraries"
```

---

## Benefits Over React Native / Flutter

### Performance

1. **No JavaScript Bridge**: Direct native calls, no serialization overhead
2. **No VM Overhead**: No Dart VM or JavaScript engine
3. **Native Compilation**: Zig compiles to native machine code
4. **Zero-Copy Where Possible**: Direct memory access via FFI

### Code Reuse

1. **Business Logic**: 100% shared (Zig)
2. **Data Models**: 100% shared (Zig)
3. **Validation**: 100% shared (Zig)
4. **Cryptography**: 100% shared (Zig)
5. **API Clients**: 100% shared (Zig)
6. **UI**: Platform-specific (Kotlin/Swift) - but this is necessary for native UX

### Security

1. **Grain Style Compliance**: Full safety guarantees in shared code
2. **Type Safety**: Strong typing across FFI boundary
3. **Memory Safety**: Zig's safety features in shared code
4. **Auditability**: Single codebase for security-critical logic

### Maintainability

1. **Single Source of Truth**: Business logic in one place
2. **Consistent Behavior**: Same logic on both platforms
3. **Easier Testing**: Test Zig code independently
4. **Grain Style**: Code that teaches, explicit limits, assertions

---

## Grain Style Compliance

### In Zig Shared Code

**Full Grain Style compliance**:
- `grain_case` function names
- Explicit types (`u32`, `u64`, not `usize`)
- Bounded allocations (`MAX_*` constants)
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- No recursion (iterative algorithms)
- Static allocation preferred after initialization
- All compiler warnings enabled

### In Platform Code (Kotlin/Swift)

**Apply Grain Style principles where possible**:
- Explicit types (avoid `var` with type inference when unclear)
- Null safety (Kotlin `?`, Swift optionals) - use explicitly
- Immutable data structures (`data class`, `struct`)
- Descriptive naming (`grain_case` for functions, `PascalCase` for types)
- Small functions (<70 lines where practical)
- Assertions (preconditions, postconditions)
- Document "why" in comments

---

## Example: Authentication Flow

### Zig Shared Code

```zig
// src/grain_mobile_core/auth/email.zig

pub const MAX_EMAIL_LEN: u32 = 256;
pub const MAX_PASSWORD_LEN: u32 = 128;

pub fn validate_email(email: []const u8) bool {
    std.debug.assert(email.len > 0);
    std.debug.assert(email.len <= MAX_EMAIL_LEN);
    
    // Validation logic
    // ...
    
    return is_valid;
}

pub fn hash_password(
    password: []const u8,
    hash_out: []u8,
) !void {
    std.debug.assert(password.len > 0);
    std.debug.assert(password.len <= MAX_PASSWORD_LEN);
    std.debug.assert(hash_out.len >= 64); // bcrypt hash size
    
    // Hashing logic (bcrypt/Argon2)
    // ...
}
```

### Android (Kotlin)

```kotlin
// Android: ViewModel
class LoginViewModel : ViewModel() {
    fun validateEmail(email: String): Boolean {
        return GrainMobileCore.validateEmail(email)
    }
    
    fun login(email: String, password: String) {
        viewModelScope.launch {
            val hash = GrainMobileCore.hashPassword(password)
            // Call API with hash
        }
    }
}
```

### iOS (Swift)

```swift
// iOS: ViewModel
class LoginViewModel: ObservableObject {
    func validateEmail(_ email: String) -> Bool {
        return grain_mobile_auth_validate_email(
            email, UInt32(email.utf8.count)
        ) != 0
    }
    
    func login(email: String, password: String) {
        // Call Zig functions via C interop
    }
}
```

---

## Migration Strategy

### Phase 1: Core Module (Week 1-2)
1. Create `grain_mobile_core` module structure
2. Implement FFI layer (C API exports)
3. Basic authentication functions (email validation, password hashing)
4. Build system integration (Android .so, iOS .a)

### Phase 2: Authentication (Week 3-4)
1. OAuth 2.0 implementation
2. Email/password authentication
3. OTP generation/validation
4. TOTP 2FA implementation
5. JWT token handling

### Phase 3: API Client (Week 5-6)
1. HTTP client implementation
2. Request/response models
3. Error handling
4. Retry logic

### Phase 4: Platform Integration (Week 7-8)
1. Android JNI bindings
2. iOS C interop bindings
3. Platform-specific wrappers
4. Integration testing

### Phase 5: Advanced Features (Week 9+)
1. State management
2. Caching layer
3. Offline support
4. Performance optimization

---

## Testing Strategy

### Zig Unit Tests

```zig
// tests/grain_mobile_core_auth_test.zig
test "validate email" {
    const valid = "user@example.com";
    const invalid = "not-an-email";
    
    std.debug.assert(auth.email.validate_email(valid));
    std.debug.assert(!auth.email.validate_email(invalid));
}
```

### Platform Integration Tests

- Test JNI bindings (Android)
- Test C interop (iOS)
- End-to-end authentication flows
- Performance benchmarks

---

## Naming Convention

**Module Name**: `grain_mobile_core`

**Rationale**:
- `grain_*` prefix: Follows Grain OS naming convention
- `mobile`: Clearly indicates mobile platform focus
- `core`: Indicates shared business logic/core functionality
- Short, memorable, descriptive

**Alternative Names Considered**:
- `grain_mobile_shared`: Less clear (shared with what?)
- `grain_cross_platform`: Too generic
- `grain_unified`: Too vague
- `grain_mobile_sdk`: Implies external SDK, not internal module

---

## Integration with Grain Election Agent

The Grain Election Agent should:

1. **Use `grain_mobile_core`** for all shared business logic
2. **Implement platform-specific UI** in Kotlin (Android) and Swift (iOS)
3. **Call Zig functions** via JNI (Android) or C interop (iOS)
4. **Follow Grain Style** in Zig code, apply principles in platform code
5. **Test shared logic** in Zig independently
6. **Document FFI contracts** clearly

---

## Future Enhancements

1. **Code Generation**: Generate JNI/Swift bindings from Zig FFI definitions
2. **Hot Reload**: Development-time hot reload for Zig code changes
3. **Performance Profiling**: Cross-platform performance profiling tools
4. **Shared UI Components**: Consider shared UI component definitions (declarative, platform renders)

---

## Success Metrics

1. **Code Reuse**: >80% of business logic shared between platforms
2. **Performance**: <5ms overhead for FFI calls (vs React Native's 10-50ms)
3. **Security**: Single codebase for security-critical logic (easier auditing)
4. **Maintainability**: Bug fixes in Zig benefit both platforms immediately
5. **Developer Experience**: Clear FFI contracts, good documentation

---

## Conclusion

**Grain Mobile Core** provides a high-performance, secure, and maintainable approach to cross-platform mobile development. By putting all business logic in Zig (with full Grain Style compliance) and keeping only UI platform-specific, we achieve:

- **High Performance**: Native code, no runtime overhead
- **Code Reuse**: Maximum shared code (business logic, models, validation)
- **Security**: Single source of truth for security-critical code
- **Maintainability**: Fix bugs once, benefit both platforms
- **Grain Style**: Full compliance in shared code, principles in platform code

This approach combines the best of both worlds: the performance and native UX of platform-specific UI, with the code reuse and safety of a shared business logic layer.

---

**now == next + 1** 🌾⚒️

