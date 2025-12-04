# Grain OS Agent: Development Plan

**Agent**: Grain OS Agent (4th Agent)  
**Status**: Phase 58 Complete, Starting Phase 59  
**Last Updated**: 2025-12-03-163301-pst

---

## Overview

Grain OS Agent is responsible for building the desktop environment compositor and system services for Grain OS. This includes window management, system services, and infrastructure for mobile/database backends.

**Key Goals**:
- Wayland compositor implementation
- System services (resource monitoring, process management, health monitoring)
- Infrastructure for mobile/database backends (API server, authentication)
- Integration with kernel syscalls

---

## Completed Phases

### Phase 50: Update Management ✅ **COMPLETE**
- Update management module (`src/grain_os/update_manager.zig`)
- Update types (security, feature, bugfix)
- Update states (available, downloading, installing, installed, failed)
- Update lifecycle management
- Compositor integration
- Tests (`tests/102_grain_os_update_manager_test.zig`)

### Phase 51: Package Management ✅ **COMPLETE**
- Package management module (`src/grain_os/package_manager.zig`)
- Package states (installed, available, updating, failed)
- Package dependencies
- Package installation/removal
- Compositor integration
- Tests (`tests/103_grain_os_package_manager_test.zig`)

### Phase 52: Enhanced SysInfo Integration ✅ **COMPLETE**
- Enhanced ResourceMonitor integration with kernel SysInfo
- Updated buffer size from 40 to 56 bytes for enhanced SysInfo
- Uses kernel-calculated `used_memory` field
- Process count tracking (total_processes, running_processes, exited_processes)
- Added `update_usage_with_processes()` method
- Added `get_total_processes()`, `get_running_processes()`, `get_exited_processes()` methods
- Updated `update_from_kernel()` to use enhanced sysinfo fields
- Compositor integration for process count access
- Updated tests to verify enhanced sysinfo integration

### Phase 53: System Health Monitoring ✅ **COMPLETE**
- Health monitor module (`src/grain_os/health_monitor.zig`)
- Health statuses (healthy, warning, critical, unknown)
- Health check creation and management
- Overall health status calculation
- Health check counts tracking
- Last check time tracking
- Compositor integration
- Tests (`tests/104_grain_os_health_monitor_test.zig`)

### Phase 54: Process Supervision ✅ **COMPLETE**
- Process supervision module (`src/grain_os/process_supervision.zig`)
- Supervised process management
- Automatic restart logic
- Restart limits and delays
- Process exit recording
- State tracking (running, crashed, stopped counts)
- Compositor integration
- Tests (`tests/105_grain_os_process_supervision_test.zig`)

### Phase 55: System Metrics Aggregation ✅ **COMPLETE**
- System metrics module (`src/grain_os/system_metrics.zig`)
- System status aggregation (CPU, memory, disk, processes, health)
- Metrics aggregation from multiple sources
- Overall system health calculation
- System status structure
- Health thresholds
- Compositor integration
- Tests (`tests/106_grain_os_system_metrics_test.zig`)

### Phase 56: Shared Module Coordination ✅ **ACKNOWLEDGED**
- Reviewed Grain Skate agent's shared module refactoring plan
- Acknowledged font renderer unification coordination request
- Documented Grain OS font renderer status and requirements
- Ready for shared font renderer migration
- Coordination document created (`docs/grain_os_font_renderer_coordination.md`)
- ⏳ Waiting for shared font renderer implementation (`src/shared/font_renderer.zig`)

### Phase 57: Process Priority Kernel Integration ✅ **COMPLETE**
- Kernel priority syscall integration (`set_priority`, `get_priority`)
- Nice value to ProcessPriority enum conversion
- Set/get process priority via kernel syscall
- Priority conversion logic (nice value ranges to enum values)
- Internal priority tracking update on kernel calls
- Compositor integration (set_process_priority_via_kernel, get_process_priority_via_kernel)
- Updated tests to verify kernel priority integration
- Kernel integration: Phase 3.7 Process Priority Support (from Vantage VM Basin Kernel Agent)

### Phase 58: System Diagnostics ✅ **COMPLETE**
- System diagnostics module (`src/grain_os/system_diagnostics.zig`)
- Diagnostic severity levels (info, warning, err, critical)
- Diagnostic check creation (add diagnostic check with name, severity, message, timestamp)
- Diagnostic check management (add, find, remove diagnostic checks)
- Diagnostic check counts by severity
- Clear all diagnostic checks
- Clear diagnostic checks by severity
- Timestamp tracking
- Compositor integration (all system diagnostics methods)
- Comprehensive tests (`tests/107_grain_os_system_diagnostics_test.zig`)

---

## Current Work: Phase 59 - HTTP/REST API Server Module

**Priority**: **HIGHEST** — Enables Database Agent and Mobile Agent  
**Status**: **STARTING**  
**Estimated Time**: 2-3 weeks

### Why This Phase

- **Grain Database Agent** needs REST API server for mobile backend
- **Grain Mobile Agent** needs API endpoints for mobile apps
- Foundation for all API-based features

### Module: `src/grain_os/api_server.zig`

### Features

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
   - Authentication middleware (JWT validation) — will integrate with Phase 60
   - Rate limiting middleware
   - CORS middleware
   - Request logging middleware

5. **Integration**:
   - Compositor integration (start/stop server)
   - Network manager integration (bind to interface)
   - Process manager integration (server process tracking)

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_ROUTES`, `MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

### Deliverables

- `src/grain_os/api_server.zig` module
- REST endpoint routing
- JSON request/response handling
- Middleware support
- Compositor integration
- Comprehensive tests (`tests/109_grain_os_api_server_test.zig`)

### Dependencies

- **Provides**: API Server (for Database Agent, Mobile Agent)
- **Needs**: Network Manager (exists), Process Manager (exists)
- **Coordinates with**: Database Agent (API contracts), Mobile Agent (API contracts)

---

## Planned Phases

### Phase 60: Authentication Service Module — **HIGH PRIORITY**

**Why**: Grain Mobile Agent needs authentication for mobile apps. Grain Database Agent needs authentication for API endpoints.

**Module**: `src/grain_os/auth_service.zig`

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
   - Database integration (user accounts, sessions) — will coordinate with Database Agent
   - Compositor integration (authentication state)

**Estimated Time**: 3-4 weeks

**Dependencies**:
- **Needs**: API Server (Phase 59)
- **Provides**: Authentication Service (for Database Agent, Mobile Agent)
- **Coordinates with**: Database Agent (user accounts, sessions), Mobile Agent (auth flow)

---

### Phase 61: Network Stack Enhancements — **MEDIUM PRIORITY**

**Why**: Both Database Agent and Mobile Agent need enhanced network capabilities (TCP/UDP, WebSocket).

**Current State**: `src/grain_os/network_manager.zig` exists but only handles interface management.

**Enhancements**:

1. **TCP/UDP Socket Support**:
   - TCP socket creation (bind, listen, accept, connect)
   - UDP socket creation (bind, send, receive)
   - Socket options (reuse address, keep-alive, timeout)
   - Non-blocking I/O support
   - Socket error handling

2. **HTTP Client/Server**:
   - HTTP client (GET, POST, PUT, DELETE requests)
   - HTTP server (request handling, response generation) — may overlap with Phase 59
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

5. **TLS/SSL Support** (Optional):
   - TLS client (HTTPS support)
   - TLS server (secure API endpoints)
   - Certificate validation
   - TLS handshake
   - TLS error handling

**Estimated Time**: 4-5 weeks (can be split into sub-phases)

**Dependencies**:
- **Needs**: Network Manager (exists)
- **Provides**: Enhanced networking (for Database Agent, Mobile Agent)
- **Coordinates with**: Kernel Agent (network syscalls), Database Agent (WebSocket), Mobile Agent (HTTP/WebSocket)

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

**Estimated Time**: 3-4 weeks

**Dependencies**:
- **Needs**: Kernel file I/O syscalls (exists)
- **Provides**: File storage (for Database Agent)
- **Coordinates with**: Kernel Agent (file system), Database Agent (database files)

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

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) - Coding principles
- **Grain Database Agent Prompt**: [`docs/grain_database_agent_prompt.md`](../grain_database_agent_prompt.md) - Database agent requirements
- **Grain Mobile Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](../grain_mobile_agent_prompt.md) - Mobile agent requirements
- **Next Work Priorities**: [`docs/grain_os_agent_next_work.md`](../grain_os_agent_next_work.md) - Detailed priorities
- **HTTP Client**: `src/dream_http_client.zig` - HTTP patterns
- **Network Manager**: `src/grain_os/network_manager.zig` - Network infrastructure
- **Compositor**: `src/grain_os/compositor.zig` - System integration point

---

**Next Steps**: Start Phase 59 (HTTP/REST API Server) implementation.

