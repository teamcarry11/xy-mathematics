# Grain Core Agent: Development Plan

**Agent**: Grain Core Agent (4th Agent)  
**Status**: Phase 58 Complete, Starting Phase 59  
**Last Updated**: 2025-12-05-170522-pst

---

## Overview

Grain Core Agent is responsible for building the desktop environment compositor and system services for Grain OS. This includes window management, system services, and infrastructure for mobile/database backends. As the core agentic-prompt-engineering pilot seat driver, Grain Core Agent coordinates system-level infrastructure and services that enable other agents to function effectively.

**Key Goals**:
- Wayland compositor implementation
- System services (resource monitoring, process management, health monitoring)
- Infrastructure for mobile/database backends (API server, authentication)
- Integration with kernel syscalls

---

## Completed Phases

### Phase 50: Update Management ✅ **COMPLETE**
- Update management module (`src/grain_core/update_manager.zig`)
- Update types (security, feature, bugfix)
- Update states (available, downloading, installing, installed, failed)
- Update lifecycle management
- Compositor integration
- Tests (`tests/102_grain_os_update_manager_test.zig`)

### Phase 51: Package Management ✅ **COMPLETE**
- Package management module (`src/grain_core/package_manager.zig`)
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
- Health monitor module (`src/grain_core/health_monitor.zig`)
- Health statuses (healthy, warning, critical, unknown)
- Health check creation and management
- Overall health status calculation
- Health check counts tracking
- Last check time tracking
- Compositor integration
- Tests (`tests/104_grain_os_health_monitor_test.zig`)

### Phase 54: Process Supervision ✅ **COMPLETE**
- Process supervision module (`src/grain_core/process_supervision.zig`)
- Supervised process management
- Automatic restart logic
- Restart limits and delays
- Process exit recording
- State tracking (running, crashed, stopped counts)
- Compositor integration
- Tests (`tests/105_grain_os_process_supervision_test.zig`)

### Phase 55: System Metrics Aggregation ✅ **COMPLETE**
- System metrics module (`src/grain_core/system_metrics.zig`)
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
- Kernel integration: Phase 3.7 Process Priority Support (from Vantage Agent)

### Phase 58: System Diagnostics ✅ **COMPLETE**
- System diagnostics module (`src/grain_core/system_diagnostics.zig`)
- Diagnostic severity levels (info, warning, err, critical)
- Diagnostic check creation (add diagnostic check with name, severity, message, timestamp)
- Diagnostic check management (add, find, remove diagnostic checks)
- Diagnostic check counts by severity
- Clear all diagnostic checks
- Clear diagnostic checks by severity
- Timestamp tracking
- Compositor integration (all system diagnostics methods)
- Comprehensive tests (`tests/107_grain_os_system_diagnostics_test.zig`)

### Phase 58.5: Build System Refactoring ✅ **COMPLETE**

### Phase 58.6: Grain OS → Grain Core Rename ✅ **COMPLETE**
- Renamed `src/grain_os/` → `src/grain_core/` directory
- Renamed `docs/plans/plan_os.md` → `docs/plans/plan_core.md`
- Renamed `docs/tasks/tasks_os.md` → `docs/tasks/tasks_core.md`
- Updated all code imports: `@import("grain_os")` → `@import("grain_core")`
- Updated all build system references (`build.zig`, `build/modules.zig`, `build/agents.zig`)
- Updated all documentation references ("Grain OS Agent" → "Grain Core Agent")
- Updated agent branding: "core agentic-prompt-engineering pilot seat driver"
- Updated module header in `src/grain_core/root.zig`
- **Status**: Core rename complete, test system fixes in progress
- Modular build system structure (`build/` directory) ✅
- Helper functions (`build/helpers.zig`) ✅
- Shared modules configuration (`build/modules.zig`) ✅
- Agent-specific modules configuration (`build/modules.zig`) ✅
- Kernel/VM build configuration (`build/kernel.zig`) ✅
- Userspace utilities build configuration (`build/userspace.zig`) ✅
- macOS applications (`build/macos_apps.zig`) ✅
- Build tools (`build/tools.zig`) ✅
- Test organization helpers (`build/tests.zig`) ✅
- Orchestration guide (`docs/build_orchestration_guide.md`) ✅
- **Status**: Modular structure complete, ready for gradual migration
- **Goal**: Reduce `build.zig` from 3,200+ lines to manageable modular structure
- **Progress**: 7 of 7 modular files created, orchestration guide complete
- **Migration**: Incremental migration strategy documented, ready for use

---

## Completed: Phase 59 - HTTP/REST API Server Module ✅

**Priority**: **HIGHEST** — Enables Database Agent and Carry Agent  
**Status**: **COMPLETE** (2025-12-05-120808-pst) (Started 2025-12-04-142508-pst)  
**Estimated Time**: 2-3 weeks

### Why This Phase

- **Grain Database Agent** needs REST API server for mobile backend
- **Grain Carry Agent** needs API endpoints for mobile apps
- Foundation for all API-based features

### Module: `src/grain_core/api_server.zig`

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

- `src/grain_core/api_server.zig` module ✅ (Core structure complete)
- REST endpoint routing ✅ (Route registration and matching complete)
- JSON request/response handling ⏳ (Planned)
- Middleware support ⏳ (Planned)
- Compositor integration ✅ (Start/stop, route registration complete)
- Comprehensive tests ✅ (`tests/109_grain_os_api_server_test.zig`)

### Progress

**Completed** (2025-12-04-142508-pst):
- ✅ Core API server module structure (`src/grain_core/api_server.zig`)
- ✅ HTTP request/response structures (HttpRequest, HttpResponse, HttpHeader)
- ✅ HTTP method and status code enums
- ✅ Route registration and lookup system
- ✅ Path pattern matching (exact match, ready for parameter expansion)
- ✅ Bounded allocations (MAX_ROUTES, MAX_REQUEST_SIZE, MAX_RESPONSE_SIZE, etc.)
- ✅ Compositor integration (register_api_route, start_api_server, stop_api_server)
- ✅ Comprehensive tests (10 test cases covering all core functionality)
- ✅ Module export in `src/grain_core/root.zig`
- ✅ Test integration in `build.zig`

**Completed (2025-12-05-120808-pst)**:
- ✅ Process manager integration
- ✅ Server process registration (`register_server_process`)
- ✅ Server process state tracking (`update_server_process_state`)
- ✅ Server process ID retrieval (`get_server_process_id`)
- ✅ Integration with ProcessManager for process lifecycle tracking
- ✅ All functions comply with 70-line limit
- ✅ Comprehensive tests for process integration

**Completed (2025-12-05-102808-pst)**:
- ✅ Network integration (`api_server_network.zig`)
- ✅ Network server binding and listening
- ✅ HTTP request processing integration
- ✅ Connection manager integration
- ✅ Route handling integration
- ✅ Middleware execution integration
- ✅ All functions comply with 70-line limit
- ✅ Comprehensive tests for network integration

**Completed (2025-12-05-083604-pst)**:
- ✅ Connection handling (`connection_manager.zig`)
- ✅ Connection state management (idle, reading, writing, keep-alive, closing, closed)
- ✅ Keep-alive support (timeout management)
- ✅ Request timeout handling
- ✅ Connection pooling (bounded MAX_CONNECTIONS)
- ✅ Timeout cleanup (automatic cleanup of timed-out connections)
- ✅ All functions comply with 70-line limit
- ✅ Comprehensive tests for connection manager

**Completed (2025-12-04-173933-pst)**:
- ✅ Middleware framework (`middleware.zig`)
- ✅ Middleware registration (`add_middleware_to_route`)
- ✅ Middleware execution chain (`execute_middleware_chain`)
- ✅ Common middleware functions (CORS, logging, rate limiting, auth, content-type)
- ✅ All functions comply with 70-line limit
- ✅ Comprehensive tests for middleware

**Completed (2025-12-04-171158-pst)**:
- ✅ JSON request/response handling (`json_helpers.zig`)
- ✅ JSON parsing from request bodies (string, number, boolean extraction)
- ✅ JSON generation to response bodies (string, number, boolean writing)
- ✅ API server JSON helper methods (parse_json_string_from_request, etc.)
- ✅ All functions comply with 70-line limit
- ✅ Comprehensive tests for JSON helpers

**Completed (2025-12-04-164105-pst)**:
- ✅ HTTP/1.1 request parsing (`parse_http_request`)
- ✅ HTTP/1.1 response generation (`generate_http_response`)
- ✅ Path parameter extraction (`extract_path_parameters`)
- ✅ Helper functions for parsing (method parsing, line boundaries, body start)
- ✅ Helper functions for generation (status line, headers, body writing)
- ✅ All functions comply with 70-line limit (refactored)
- ✅ Comprehensive tests for parsing and generation

**Planned**:
- ⏳ Connection handling (keep-alive, timeout)
- ⏳ Network manager integration
- ⏳ Process manager integration

### Agent Coordination

**Grain Database Agent** (2025-12-04-150909-pst):
- ✅ Integration module created (`src/grain_database/integration_os.zig`)
- ✅ Route registration helper function ready
- ✅ All 9 database endpoints prepared
- ✅ Handler function stubs match API Server interface
- ✅ Ready for route registration

**Grain Carry Agent** (2025-12-04-151505-pst):
- ✅ Endpoint definitions created (`src/grain_carry_core/api/endpoints.zig`)
- ✅ Endpoint registry structure ready
- ✅ All 10 mobile app endpoints prepared
- ✅ Handler function preparation structure ready
- ✅ Ready for route registration

### Dependencies

- **Provides**: API Server (for Database Agent, Carry Agent)
- **Needs**: Network Manager (exists), Process Manager (exists)
- **Coordinates with**: Database Agent (API contracts), Carry Agent (API contracts)

---

## Planned Phases

### Phase 60: Authentication Service Module — **COMPLETE** ✅

**Why**: Grain Carry Agent needs authentication for mobile apps. Grain Database Agent needs authentication for API endpoints.

**Module**: `src/grain_core/auth_service.zig`

**Status**: Complete (2025-12-05-134449-pst)

**Completed Features**:
1. **JWT Token Management** ✅:
   - JWT token generation (access tokens, refresh tokens)
   - JWT token validation (signature, expiration, claims)
   - Token revocation (blacklist)
   - Base64URL encoding/decoding
   - HMAC-SHA256 signatures

2. **Password Authentication** ✅:
   - Password hashing (SHA-256 with salt)
   - Password validation
   - Secure password storage
   - Note: bcrypt/Argon2 can be added later for production

3. **Two-Factor Authentication (2FA)** ✅:
   - TOTP generation (Google Authenticator compatible)
   - TOTP validation (with time window tolerance)
   - HMAC-SHA1 for TOTP

4. **Magic Email OTP** ✅:
   - One-time password generation
   - OTP validation (time-limited, single-use)
   - OTP expiration tracking
   - Note: Email delivery integration pending

5. **Session Management** ✅:
   - Session creation (session ID, expiration)
   - Session validation
   - Session revocation (logout)
   - Bounded session storage (100 sessions)

6. **Integration** ✅:
   - API server middleware integration (enhanced auth_middleware)
   - Module exported in `grain_core` root
   - Comprehensive tests (`tests/114_grain_os_auth_service_test.zig`)

**Pending Features** (Future):
- OAuth 2.0 Integration (stub for now):
  - OAuth provider configuration (Google, Facebook, GitHub, Apple)
  - Authorization code flow
  - Token exchange
  - Token refresh
  - Provider-specific implementations
- Database integration (user accounts, sessions) — coordinate with Database Agent
- Compositor integration (authentication state)

**Dependencies**:
- **Needs**: API Server (Phase 59) ✅
- **Provides**: Authentication Service (for Database Agent, Carry Agent) ✅
- **Coordinates with**: Database Agent (user accounts, sessions), Carry Agent (auth flow)

---

### Phase 61: Network Stack Enhancements — **IN PROGRESS**

**Why**: Both Database Agent and Carry Agent need enhanced network capabilities (TCP/UDP, WebSocket).

**Current State**: `src/grain_core/network_manager.zig` exists but only handles interface management.

**Status**: Core TCP/UDP socket support complete (2025-12-05-143449-pst)

**Completed**:
- ✅ Core `network_stack.zig` module structure
- ✅ TCP socket creation, bind, listen, accept, connect
- ✅ UDP socket creation, bind, send, receive
- ✅ Socket state management
- ✅ Non-blocking I/O support
- ✅ Socket error handling
- ✅ Comprehensive tests (`tests/115_grain_os_network_stack_test.zig`)

**Enhancements**:

1. **TCP/UDP Socket Support** ✅:
   - ✅ TCP socket creation (bind, listen, accept, connect)
   - ✅ UDP socket creation (bind, send, receive)
   - ⏳ Socket options (reuse address, keep-alive, timeout) — PENDING
   - ✅ Non-blocking I/O support
   - ✅ Socket error handling

2. **HTTP Client/Server**:
   - HTTP client (GET, POST, PUT, DELETE requests)
   - HTTP server (request handling, response generation) — may overlap with Phase 59
   - HTTP/1.1 protocol support
   - Connection pooling
   - Request/response streaming

3. **WebSocket Support** ✅ (2025-12-05-202227-pst):
   - ✅ WebSocket handshake (HTTP upgrade) - `websocket_handshake.zig`
   - ✅ WebSocket frame parsing (text, binary, ping, pong, close) - `parse_websocket_frame()`
   - ✅ WebSocket frame generation - `generate_websocket_frame()`
   - ✅ WebSocket connection management - `WebSocketManager`
   - ✅ WebSocket accept key generation - `generate_websocket_accept()`
   - ✅ WebSocket upgrade detection - `is_websocket_upgrade()`
   - ✅ Comprehensive tests (`tests/116_grain_core_websocket_test.zig`)

4. **DNS Resolution** ✅ (2025-12-05-231800-pst):
   - ✅ DNS cache (bounded cache size) - `DnsResolver` with `MAX_DNS_CACHE_ENTRIES`
   - ✅ DNS cache entry management - `add_cache_entry()`, `find_cache_entry()`
   - ✅ DNS cache expiration - `clear_expired_cache()`
   - ✅ DNS record types (A, AAAA, MX) - `DnsRecordType` enum
   - ✅ Hostname resolution stub - `resolve_hostname()` (ready for network implementation)
   - ✅ Comprehensive tests (`tests/117_grain_core_dns_resolver_test.zig`)
   - ⏳ DNS query implementation (requires network stack integration) — PENDING

5. **TLS/SSL Support** (Optional):
   - TLS client (HTTPS support)
   - TLS server (secure API endpoints)
   - Certificate validation
   - TLS handshake
   - TLS error handling

**Estimated Time**: 4-5 weeks (can be split into sub-phases)

**Dependencies**:
- **Needs**: Network Manager (exists)
- **Provides**: Enhanced networking (for Database Agent, Carry Agent)
- **Coordinates with**: Vantage Agent (network syscalls), Database Agent (WebSocket), Carry Agent (HTTP/WebSocket)

---

### Phase 62: File System Enhancements — **IN PROGRESS**

**Why**: Vantage Agent needs better file system for database persistence. Database Agent needs file-based storage.

**Current State**: Kernel has basic file I/O syscalls (`open`, `read`, `write`, `close`).

**Status**: Core file storage module complete (2025-12-06-023413-pst)

**Completed**:
- ✅ Core `file_storage.zig` module structure
- ✅ Database file header (`DatabaseFileHeader`) with validation
- ✅ Page-based storage (`FilePage`) with checksums
- ✅ File handle management (`FileHandle`, `FileStorageManager`)
- ✅ File locking/unlocking support
- ✅ File integrity checks (SHA-256 checksums)
- ✅ Comprehensive tests (`tests/118_grain_core_file_storage_test.zig`)

**Enhancements**:

1. **Database File Format Support** ✅:
   - ✅ Database file structure (header, pages, indexes)
   - ✅ Page-based storage (fixed-size pages)
   - ✅ File locking (for concurrent access)
   - ✅ File integrity checks (checksums)

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
- **Coordinates with**: Vantage Agent (file system), Database Agent (database files)

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

### With Grain Carry Agent

**Shared Components**:
- API server (Carry Agent will connect to REST API)
- Authentication service (Carry Agent will use for login)
- Network stack (Carry Agent will use for HTTP/WebSocket)

**Integration Points**:
- Mobile App → HTTP Client → API Server
- Mobile App → OAuth → Authentication Service
- Mobile App → WebSocket → Livestream coordination

**Coordination Tasks**:
- Define REST API contracts (endpoints, request/response formats)
- Define authentication flow (OAuth, JWT, 2FA, magic email)
- Define WebSocket protocol (for livestream coordination)

### With Vantage Agent

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
- **Grain Carry Agent Prompt**: [`docs/grain_mobile_agent_prompt.md`](../grain_mobile_agent_prompt.md) - Mobile agent requirements
- **Next Work Priorities**: [`docs/grain_os_agent_next_work.md`](../grain_os_agent_next_work.md) - Detailed priorities
- **HTTP Client**: `src/dream_http_client.zig` - HTTP patterns
- **Network Manager**: `src/grain_core/network_manager.zig` - Network infrastructure
- **Compositor**: `src/grain_core/compositor.zig` - System integration point

---

**Next Steps**: Start Phase 59 (HTTP/REST API Server) implementation.

