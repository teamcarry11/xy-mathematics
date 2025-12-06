# Grain Core Agent: Task List

**Agent**: Grain Core Agent (4th Agent)  
**Status**: Phase 59 Complete, Starting Phase 60  
**Last Updated**: 2025-12-05-170522-pst

---

## Completed: Phase 58.5 - Build System Refactoring ✅

**Priority**: **MEDIUM** — Improves maintainability and reduces conflicts  
**Status**: **COMPLETE**  
**Completed**: 2025-12-04-141613-pst

### Tasks

- [x] Create `build/` directory structure
- [x] Create `build/helpers.zig` (helper functions)
- [x] Create `build/modules.zig` (shared modules)
- [x] Create `build/kernel.zig` (kernel/VM build config)
- [x] Create `build/userspace.zig` (userspace utilities)
- [x] Create `build/tests.zig` (test organization)
- [x] Create orchestration guide (`docs/build_orchestration_guide.md`)
- [x] Document migration strategy
- [ ] Gradually migrate existing `build.zig` content (incremental, as needed)
- [ ] Verify all tests pass and build works after each migration step
- [x] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Progress

**Completed**:
- ✅ `build/helpers.zig` - Helper functions for modules, executables, tests
- ✅ `build/modules.zig` - Shared modules configuration + agent modules
- ✅ `build/kernel.zig` - Kernel and VM build configuration
- ✅ `build/userspace.zig` - Userspace utilities build configuration
- ✅ `build/tests.zig` - Test organization helper functions
- ✅ `build/macos_apps.zig` - macOS application executables (tahoe, grain_skate)
- ✅ `build/tools.zig` - Build tools and utilities

**Remaining**:
- ⏳ New orchestrated `build.zig` - Thin orchestrator that imports all modular files
- ⏳ Verification - Ensure all tests pass and build works
- ⏳ Migration of existing `build.zig` content to modular structure (gradual, as needed)

---

## Current Work: Phase 59 - HTTP/REST API Server Module

**Priority**: **HIGHEST** — Enables Database Agent and Carry Agent  
**Status**: **IN PROGRESS**  
**Estimated Time**: 2-3 weeks (started 2025-12-04-142508-pst)

### Tasks

- [x] Create `src/grain_core/api_server.zig` module structure
- [x] Implement HTTP request/response structures (HttpRequest, HttpResponse)
- [x] Implement REST endpoint routing (method + path pattern, route matching)
- [x] Implement route registration and lookup
- [x] Implement bounded request/response sizes (`MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`)
- [x] Implement compositor integration (start/stop server, route registration)
- [x] Create comprehensive tests (`tests/109_grain_core_api_server_test.zig`)
- [x] Update `build.zig` with new module and tests
- [x] Update `src/grain_core/root.zig` to export api_server module
- [x] Implement HTTP/1.1 server (request parsing, response generation) - Complete (2025-12-04-164105-pst)
- [x] Implement path parameter extraction - Complete (2025-12-04-164105-pst)
- [x] Implement JSON request/response handling (parsing, generation) - Complete (2025-12-04-171158-pst)
- [x] Implement middleware support (authentication, logging, rate limiting, CORS) - Complete (2025-12-04-173933-pst)
- [x] Implement connection handling (keep-alive, timeout) - Complete (2025-12-05-083604-pst)
- [x] Implement network manager integration (bind to interface) - Complete (2025-12-05-102808-pst)
- [x] Implement process manager integration (server process tracking) - Complete (2025-12-05-120808-pst)
- [x] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with completion - Complete (2025-12-05-120808-pst)

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_ROUTES`, `MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

### Dependencies

- **Provides**: API Server (for Database Agent, Carry Agent)
- **Needs**: Network Manager (exists), Process Manager (exists)
- **Coordinates with**: Database Agent (API contracts), Carry Agent (API contracts)

---

## Completed: Phase 60 - Authentication Service Module ✅

**Priority**: **HIGH** — Required for secure mobile app authentication  
**Status**: **COMPLETE**  
**Completed**: 2025-12-05-134449-pst

### Tasks

- [x] Create `src/grain_core/auth_service.zig` module structure
- [x] Implement JWT token management (generation, validation, refresh)
- [x] Implement JWT token revocation (blacklist)
- [x] Implement password hashing (SHA-256 with salt)
- [x] Implement password validation
- [x] Implement session management (create, validate, revoke)
- [x] Implement TOTP generation and validation (2FA)
- [x] Implement magic email OTP generation and validation
- [x] Enhance API server middleware (auth_middleware)
- [x] Create comprehensive tests (`tests/114_grain_core_auth_service_test.zig`)
- [x] Update `build.zig` with new module and tests
- [x] Update `src/grain_core/root.zig` to export auth_service module
- [x] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with completion
- [ ] Implement OAuth 2.0 integration (Google, Facebook, GitHub, Apple) - **PENDING** (stub for now)
- [ ] Implement password authentication (bcrypt, Argon2 hashing)
- [ ] Implement 2FA (TOTP generation, validation, backup codes)
- [ ] Implement magic email OTP (generation, validation, expiration)
- [ ] Implement session management (creation, validation, refresh, revocation)
- [ ] Implement API server middleware integration
- [ ] Implement database integration (user accounts, sessions) — coordinate with Database Agent
- [ ] Implement compositor integration (authentication state)
- [ ] Create comprehensive tests (`tests/110_grain_core_auth_service_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with completion

### Dependencies

- **Needs**: API Server (Phase 59)
- **Provides**: Authentication Service (for Database Agent, Carry Agent)
- **Coordinates with**: Database Agent (user accounts, sessions), Carry Agent (auth flow)

---

## In Progress: Phase 61 - Network Stack Enhancements

**Priority**: **MEDIUM** — Enhanced network capabilities  
**Status**: **IN PROGRESS** — TCP/UDP socket support complete  
**Started**: 2025-12-05-143449-pst

### Completed Tasks

- [x] Create `src/grain_core/network_stack.zig` module structure
- [x] Implement TCP socket creation (bind, listen, accept, connect)
- [x] Implement UDP socket creation (bind, send, receive)
- [x] Implement socket state management
- [x] Implement non-blocking I/O support
- [x] Implement socket error handling
- [x] Create comprehensive tests (`tests/115_grain_core_network_stack_test.zig`)
- [x] Update `build.zig` with new module and tests
- [x] Update `src/grain_core/root.zig` to export network_stack module

### Remaining Tasks

- [ ] Implement socket options (reuse address, keep-alive, timeout)
- [ ] Implement HTTP client/server enhancements
- [x] Implement WebSocket support (handshake, frame parsing, connection management) ✅ (2025-12-05-202227-pst)
- [ ] Implement DNS resolution (A, AAAA, MX records, caching)
- [ ] Implement TLS/SSL support (optional, for secure endpoints)
- [ ] Implement compositor integration
- [ ] Create comprehensive tests
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with completion

### Dependencies

- **Needs**: Network Manager (exists)
- **Provides**: Enhanced networking (for Database Agent, Carry Agent)
- **Coordinates with**: Vantage Agent (network syscalls), Database Agent (WebSocket), Carry Agent (HTTP/WebSocket)

---

## Planned: Phase 62 - File System Enhancements

**Priority**: **MEDIUM** — Database persistence support  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_core/file_storage.zig` module or enhance kernel file I/O
- [ ] Implement database file format support (header, pages, indexes)
- [ ] Implement transaction log file management (WAL format, rotation, checkpoint, recovery)
- [ ] Implement index file management (B-tree, hash index formats, recovery)
- [ ] Implement backup/restore capabilities (full, incremental, scheduling)
- [ ] Implement compositor integration
- [ ] Create comprehensive tests
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with completion

### Dependencies

- **Needs**: Kernel file I/O syscalls (exists)
- **Provides**: File storage (for Database Agent)
- **Coordinates with**: Vantage Agent (file system), Database Agent (database files)

---

## Completed Phases (Summary)

### Phase 50-58: System Services ✅ **COMPLETE**

All phases complete. See `docs/plans/plan_core.md` for detailed phase descriptions.

**Key Modules**:
- Update Manager (`src/grain_core/update_manager.zig`)
- Package Manager (`src/grain_core/package_manager.zig`)
- Resource Monitor (enhanced with kernel SysInfo)
- Health Monitor (`src/grain_core/health_monitor.zig`)
- Process Supervision (`src/grain_core/process_supervision.zig`)
- System Metrics (`src/grain_core/system_metrics.zig`)
- System Diagnostics (`src/grain_core/system_diagnostics.zig`)

**Integration Status**:
- ✅ Enhanced SysInfo integrated into ResourceMonitor
- ✅ Process priority syscalls integrated into ProcessManager
- ✅ All system services integrated into Compositor
- ⏳ Waiting for shared font renderer implementation (Grain Skate Agent)

---

## Coordination Tasks

### With Grain Database Agent

- [ ] Define API server interface (routes, handlers, middleware)
- [ ] Define authentication flow (JWT, OAuth, 2FA)
- [ ] Define file storage interface (database files, transaction logs)
- [ ] Test integration with Database Agent

### With Grain Carry Agent

- [ ] Define REST API contracts (endpoints, request/response formats)
- [ ] Define authentication flow (OAuth, JWT, 2FA, magic email)
- [ ] Define WebSocket protocol (for livestream coordination)
- [ ] Test integration with Carry Agent

### With Vantage Agent

- [ ] Coordinate on file system integration (database files, transaction logs)
- [ ] Coordinate on network stack (HTTP server, WebSocket)
- [ ] Coordinate on AArch64 deployment (VM integration)

---

## References

- **Plan**: [`docs/plans/plan_core.md`](../plans/plan_core.md) - Detailed development plan
- **Next Work Priorities**: [`docs/grain_os_agent_next_work.md`](../grain_os_agent_next_work.md) - Detailed priorities
- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) - Coding principles
- **Compositor**: `src/grain_core/compositor.zig` - System integration point

---

**Next Steps**: Start Phase 59 (HTTP/REST API Server) implementation.

