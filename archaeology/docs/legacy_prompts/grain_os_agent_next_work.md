# Grain Core Agent: Next Work Priorities

**Date**: 2025-12-03-163301-pst  
**Agent**: Grain Core Agent  
**Status**: Planning Next Phases  
**Context**: Phases 52-58 Complete, Database Agent and Mobile Agent Need Infrastructure

---

## Current Status

### Completed Phases (52-58)

✅ **Phase 52**: Enhanced SysInfo Integration  
✅ **Phase 53**: System Health Monitoring  
✅ **Phase 54**: Process Supervision  
✅ **Phase 55**: System Metrics Aggregation  
✅ **Phase 56**: Shared Module Coordination  
✅ **Phase 57**: Process Priority Kernel Integration  
✅ **Phase 58**: System Diagnostics  

### Integration Status

- ✅ Enhanced SysInfo integrated into ResourceMonitor
- ✅ Process priority syscalls integrated into ProcessManager
- ✅ System health, supervision, metrics, and diagnostics modules complete
- ⏳ Waiting for shared font renderer implementation (Grain Skate Agent)

---

## Recommended Next Phases

### Phase 59: HTTP/REST API Server Module — **HIGHEST PRIORITY**

**Why**: Grain Database Agent needs REST API server for mobile backend. Grain Mobile Agent needs API endpoints for mobile apps.

**Module**: `src/grain_core/api_server.zig`

**Features**:
1. **HTTP Server**:
   - HTTP/1.1 server implementation
   - Request parsing (method, path, headers, body)
   - Response generation (status code, headers, body)
   - Connection handling (keep-alive, timeout)
   - Bounded request/response sizes

2. **REST Endpoint Routing**:
   - Route registration (method + path pattern)
   - Route matching (path parameters, query strings)
   - Handler function pointers
   - Middleware support (authentication, logging, rate limiting)

3. **JSON Support**:
   - JSON request body parsing
   - JSON response body generation
   - Bounded JSON buffer sizes
   - Error handling for malformed JSON

4. **Middleware**:
   - Authentication middleware (JWT validation)
   - Rate limiting middleware
   - CORS middleware
   - Request logging middleware

5. **Integration**:
   - Compositor integration (start/stop server)
   - Network manager integration (bind to interface)
   - Process manager integration (server process tracking)

**Grain Style Requirements**:
- All functions use `grain_case` naming
- Bounded allocations: `MAX_ROUTES`, `MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Deliverables**:
- `src/grain_core/api_server.zig` module
- REST endpoint routing
- JSON request/response handling
- Middleware support
- Compositor integration
- Comprehensive tests (`tests/109_grain_os_api_server_test.zig`)

**Estimated Time**: 2-3 weeks

---

### Phase 60: Authentication Service Module — **HIGH PRIORITY**

**Why**: Grain Mobile Agent needs authentication for mobile apps. Grain Database Agent needs authentication for API endpoints.

**Module**: `src/grain_core/auth_service.zig`

**Features**:
1. **OAuth 2.0 Integration**:
   - OAuth provider configuration (Google, Facebook, GitHub, Apple)
   - Authorization code flow
   - Token exchange
   - Token refresh
   - Provider-specific implementations

2. **JWT Token Management**:
   - JWT token generation (access tokens, refresh tokens)
   - JWT token validation (signature, expiration, claims)
   - Token refresh logic
   - Token revocation (blacklist)

3. **Password Authentication**:
   - Password hashing (bcrypt, Argon2)
   - Password validation
   - Password strength requirements
   - Secure password storage

4. **Two-Factor Authentication (2FA)**:
   - TOTP generation (Google Authenticator compatible)
   - TOTP validation
   - Backup codes generation
   - 2FA enrollment/removal

5. **Magic Email OTP**:
   - One-time password generation
   - Email delivery (integration with email service)
   - OTP validation (time-limited, single-use)
   - OTP expiration tracking

6. **Session Management**:
   - Session creation (session ID, expiration)
   - Session validation
   - Session refresh
   - Session revocation (logout)

7. **Integration**:
   - API server middleware integration
   - Database integration (user accounts, sessions)
   - Compositor integration (authentication state)

**Grain Style Requirements**:
- All functions use `grain_case` naming
- Bounded allocations: `MAX_SESSIONS`, `MAX_OTP_LENGTH`, `MAX_TOKEN_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled
- Secure cryptographic operations (use Zig crypto libraries)

**Deliverables**:
- `src/grain_core/auth_service.zig` module
- OAuth 2.0 integration
- JWT token management
- Password authentication
- 2FA support
- Magic email OTP
- Session management
- Compositor integration
- Comprehensive tests (`tests/110_grain_os_auth_service_test.zig`)

**Estimated Time**: 3-4 weeks

**Note**: Some authentication logic may be in `grain_mobile_core`, but backend service is needed for server-side validation and session management.

---

### Phase 61: Network Stack Enhancements — **MEDIUM PRIORITY**

**Why**: Both Database Agent and Mobile Agent need enhanced network capabilities (TCP/UDP, WebSocket).

**Current State**: `src/grain_core/network_manager.zig` exists but only handles interface management.

**Enhancements**:

1. **TCP/UDP Socket Support**:
   - TCP socket creation (bind, listen, accept, connect)
   - UDP socket creation (bind, send, receive)
   - Socket options (reuse address, keep-alive, timeout)
   - Non-blocking I/O support
   - Socket error handling

2. **HTTP Client/Server**:
   - HTTP client (GET, POST, PUT, DELETE requests)
   - HTTP server (request handling, response generation)
   - HTTP/1.1 protocol support
   - Connection pooling
   - Request/response streaming

3. **WebSocket Support**:
   - WebSocket handshake (HTTP upgrade)
   - WebSocket frame parsing (text, binary, ping, pong, close)
   - WebSocket frame generation
   - WebSocket connection management
   - WebSocket server (for livestream coordination)

4. **DNS Resolution**:
   - DNS query (A, AAAA, MX records)
   - DNS cache (bounded cache size)
   - DNS error handling
   - DNS timeout handling

5. **TLS/SSL Support**:
   - TLS client (HTTPS support)
   - TLS server (secure API endpoints)
   - Certificate validation
   - TLS handshake
   - TLS error handling

**Module**: `src/grain_core/network_stack.zig` (new) or enhance `network_manager.zig`

**Grain Style Requirements**:
- All functions use `grain_case` naming
- Bounded allocations: `MAX_SOCKETS`, `MAX_CONNECTIONS`, `MAX_DNS_CACHE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Deliverables**:
- Enhanced `src/grain_core/network_manager.zig` or new `network_stack.zig`
- TCP/UDP socket support
- HTTP client/server
- WebSocket support
- DNS resolution
- TLS/SSL support (optional, can be Phase 62)
- Compositor integration
- Comprehensive tests

**Estimated Time**: 4-5 weeks (can be split into sub-phases)

---

### Phase 62: File System Enhancements — **MEDIUM PRIORITY**

**Why**: Kernel Agent needs better file system for database persistence. Database Agent needs file-based storage.

**Current State**: Kernel has basic file I/O syscalls (`open`, `read`, `write`, `close`).

**Enhancements**:

1. **Database File Format Support**:
   - Database file structure (header, pages, indexes)
   - Page-based storage (fixed-size pages)
   - File locking (for concurrent access)
   - File integrity checks (checksums)

2. **Transaction Log File Management**:
   - Write-ahead log (WAL) file format
   - WAL rotation (when log file reaches size limit)
   - WAL checkpoint (merge WAL into database)
   - WAL recovery (on database startup)

3. **Index File Management**:
   - B-tree index file format
   - Hash index file format
   - Index file creation/update
   - Index file recovery

4. **Backup/Restore Capabilities**:
   - Database backup (full backup, incremental backup)
   - Database restore (from backup)
   - Backup file format
   - Backup scheduling

**Module**: `src/grain_core/file_storage.zig` (new) or enhance kernel file I/O

**Grain Style Requirements**:
- All functions use `grain_case` naming
- Bounded allocations: `MAX_FILE_SIZE`, `MAX_PAGE_SIZE`, `MAX_BACKUPS`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

**Deliverables**:
- `src/grain_core/file_storage.zig` module (or kernel enhancements)
- Database file format support
- Transaction log file management
- Index file management
- Backup/restore capabilities
- Comprehensive tests

**Estimated Time**: 3-4 weeks

**Note**: Some of this may be kernel-level work (coordinate with Vantage VM Basin Kernel Agent).

---

## Implementation Priority Order

### Immediate (Next 2-3 Weeks)

1. **Phase 59: HTTP/REST API Server** — **START HERE**
   - Enables Database Agent to build REST API
   - Enables Mobile Agent to connect to backend
   - Foundation for all API-based features

### Short-Term (Next Month)

2. **Phase 60: Authentication Service**
   - Enables secure mobile app authentication
   - Required for production deployment
   - Integrates with API server

3. **Phase 61: Network Stack Enhancements** (Part 1: TCP/UDP, HTTP)
   - Enables API server to work properly
   - Enables HTTP client for OAuth
   - Foundation for WebSocket

### Medium-Term (Next Quarter)

4. **Phase 61: Network Stack Enhancements** (Part 2: WebSocket, TLS)
   - Enables livestream coordination
   - Enables secure API endpoints
   - Production-ready networking

5. **Phase 62: File System Enhancements**
   - Enables database persistence
   - Enables backup/restore
   - Production-ready storage

---

## Coordination Points

### With Grain Database Agent

**Shared Components**:
- API server (Database Agent will use for REST endpoints)
- Authentication service (Database Agent will use for API authentication)
- File storage (Database Agent will use for database persistence)

**Integration Points**:
- Database Agent → API Server → Authentication Service
- Database Agent → File Storage → Database files
- Database Agent → Network Stack → HTTP/WebSocket

**Coordination Tasks**:
- Define API server interface (routes, handlers, middleware)
- Define authentication flow (JWT, OAuth, 2FA)
- Define file storage interface (database files, transaction logs)

### With Grain Mobile Agent

**Shared Components**:
- API server (Mobile Agent will connect to REST API)
- Authentication service (Mobile Agent will use for login)
- Network stack (Mobile Agent will use for HTTP/WebSocket)

**Integration Points**:
- Mobile App → HTTP Client → API Server
- Mobile App → OAuth → Authentication Service
- Mobile App → WebSocket → Livestream coordination

**Coordination Tasks**:
- Define REST API contracts (endpoints, request/response formats)
- Define authentication flow (OAuth, JWT, 2FA, magic email)
- Define WebSocket protocol (for livestream coordination)

### With Vantage VM Basin Kernel Agent

**Shared Components**:
- File system (kernel file I/O for database persistence)
- Network stack (kernel network syscalls for API server)
- Process management (kernel process syscalls for server processes)

**Integration Points**:
- API Server → Kernel Network Syscalls → HTTP/WebSocket
- File Storage → Kernel File I/O → Database files
- Authentication Service → Kernel Process Syscalls → Session management

**Coordination Tasks**:
- Coordinate on file system integration (database files, transaction logs)
- Coordinate on network stack (HTTP server, WebSocket)
- Coordinate on AArch64 deployment (VM integration)

---

## Success Criteria

### Phase 59: HTTP/REST API Server

1. **Functionality**:
   - HTTP/1.1 server handles requests
   - REST endpoint routing works
   - JSON request/response handling works
   - Middleware (auth, rate limiting, CORS) works

2. **Performance**:
   - Handles 1000+ requests/second
   - <50ms response time (p95)
   - Bounded memory usage

3. **Grain Style Compliance**:
   - Full compliance in Zig code
   - Bounded allocations
   - Comprehensive assertions
   - Max 70 lines per function

### Phase 60: Authentication Service

1. **Functionality**:
   - OAuth 2.0 integration works (Google, Facebook, GitHub)
   - JWT token generation/validation works
   - Password authentication works
   - 2FA works (TOTP)
   - Magic email OTP works

2. **Security**:
   - Secure password hashing (bcrypt, Argon2)
   - Secure token storage
   - Token expiration enforced
   - 2FA properly validated

3. **Grain Style Compliance**:
   - Full compliance in Zig code
   - Bounded allocations
   - Comprehensive assertions
   - Max 70 lines per function

### Phase 61: Network Stack Enhancements

1. **Functionality**:
   - TCP/UDP sockets work
   - HTTP client/server work
   - WebSocket works
   - DNS resolution works
   - TLS/SSL works (optional)

2. **Performance**:
   - Low latency (<10ms for local connections)
   - High throughput (1000+ connections)
   - Bounded memory usage

3. **Grain Style Compliance**:
   - Full compliance in Zig code
   - Bounded allocations
   - Comprehensive assertions
   - Max 70 lines per function

---

## Next Steps

1. **Immediate** (This Week):
   - Review and approve Phase 59 (HTTP/REST API Server)
   - Start implementation of `api_server.zig`
   - Coordinate with Database Agent on API contracts

2. **Short-Term** (This Month):
   - Complete Phase 59 (HTTP/REST API Server)
   - Begin Phase 60 (Authentication Service)
   - Coordinate with Mobile Agent on authentication flow

3. **Medium-Term** (Next Quarter):
   - Complete Phase 60 (Authentication Service)
   - Begin Phase 61 (Network Stack Enhancements)
   - Begin Phase 62 (File System Enhancements)

---

## References

- **Grain Style**: [`docs/grain_style.md`](grain_style.md) - Coding principles
- **Grain Database Agent Prompt**: [`docs/grain_database_agent_prompt.md`](grain_database_agent_prompt.md) - Database agent requirements
- **Grain Mobile Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](grain_mobile_agent_prompt.md) - Mobile agent requirements
- **HTTP Client**: `src/dream_http_client.zig` - HTTP patterns
- **Network Manager**: `src/grain_core/network_manager.zig` - Network infrastructure
- **Compositor**: `src/grain_core/compositor.zig` - System integration point

---

**Recommendation**: Start with **Phase 59: HTTP/REST API Server** as it enables both Database Agent and Mobile Agent to build their features. This is the foundation for all API-based functionality.

