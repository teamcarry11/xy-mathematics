# Grain OS Agent: Task List

**Agent**: Grain OS Agent (4th Agent)  
**Status**: Phase 58 Complete, Starting Phase 59  
**Last Updated**: 2025-12-03-163301-pst

---

## Current Work: Phase 59 - HTTP/REST API Server Module

**Priority**: **HIGHEST** — Enables Database Agent and Mobile Agent  
**Status**: **STARTING**  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create `src/grain_os/api_server.zig` module structure
- [ ] Implement HTTP/1.1 server (request parsing, response generation)
- [ ] Implement REST endpoint routing (method + path pattern, route matching)
- [ ] Implement JSON request/response handling (parsing, generation)
- [ ] Implement middleware support (authentication, logging, rate limiting, CORS)
- [ ] Implement connection handling (keep-alive, timeout)
- [ ] Implement bounded request/response sizes (`MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`)
- [ ] Implement compositor integration (start/stop server)
- [ ] Implement network manager integration (bind to interface)
- [ ] Implement process manager integration (server process tracking)
- [ ] Create comprehensive tests (`tests/109_grain_os_api_server_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_os.md` and `docs/tasks/tasks_os.md` with completion

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_ROUTES`, `MAX_REQUEST_SIZE`, `MAX_RESPONSE_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

### Dependencies

- **Provides**: API Server (for Database Agent, Mobile Agent)
- **Needs**: Network Manager (exists), Process Manager (exists)
- **Coordinates with**: Database Agent (API contracts), Mobile Agent (API contracts)

---

## Planned: Phase 60 - Authentication Service Module

**Priority**: **HIGH** — Required for secure mobile app authentication  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_os/auth_service.zig` module structure
- [ ] Implement OAuth 2.0 integration (Google, Facebook, GitHub, Apple)
- [ ] Implement JWT token management (generation, validation, refresh)
- [ ] Implement password authentication (bcrypt, Argon2 hashing)
- [ ] Implement 2FA (TOTP generation, validation, backup codes)
- [ ] Implement magic email OTP (generation, validation, expiration)
- [ ] Implement session management (creation, validation, refresh, revocation)
- [ ] Implement API server middleware integration
- [ ] Implement database integration (user accounts, sessions) — coordinate with Database Agent
- [ ] Implement compositor integration (authentication state)
- [ ] Create comprehensive tests (`tests/110_grain_os_auth_service_test.zig`)
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_os.md` and `docs/tasks/tasks_os.md` with completion

### Dependencies

- **Needs**: API Server (Phase 59)
- **Provides**: Authentication Service (for Database Agent, Mobile Agent)
- **Coordinates with**: Database Agent (user accounts, sessions), Mobile Agent (auth flow)

---

## Planned: Phase 61 - Network Stack Enhancements

**Priority**: **MEDIUM** — Enhanced network capabilities  
**Status**: **PLANNED**  
**Estimated Time**: 4-5 weeks (can be split into sub-phases)

### Tasks

- [ ] Enhance `src/grain_os/network_manager.zig` or create `network_stack.zig`
- [ ] Implement TCP/UDP socket support (bind, listen, accept, connect, send, receive)
- [ ] Implement HTTP client/server enhancements
- [ ] Implement WebSocket support (handshake, frame parsing, connection management)
- [ ] Implement DNS resolution (A, AAAA, MX records, caching)
- [ ] Implement TLS/SSL support (optional, for secure endpoints)
- [ ] Implement compositor integration
- [ ] Create comprehensive tests
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_os.md` and `docs/tasks/tasks_os.md` with completion

### Dependencies

- **Needs**: Network Manager (exists)
- **Provides**: Enhanced networking (for Database Agent, Mobile Agent)
- **Coordinates with**: Kernel Agent (network syscalls), Database Agent (WebSocket), Mobile Agent (HTTP/WebSocket)

---

## Planned: Phase 62 - File System Enhancements

**Priority**: **MEDIUM** — Database persistence support  
**Status**: **PLANNED**  
**Estimated Time**: 3-4 weeks

### Tasks

- [ ] Create `src/grain_os/file_storage.zig` module or enhance kernel file I/O
- [ ] Implement database file format support (header, pages, indexes)
- [ ] Implement transaction log file management (WAL format, rotation, checkpoint, recovery)
- [ ] Implement index file management (B-tree, hash index formats, recovery)
- [ ] Implement backup/restore capabilities (full, incremental, scheduling)
- [ ] Implement compositor integration
- [ ] Create comprehensive tests
- [ ] Update `build.zig` with new module and tests
- [ ] Update `docs/plans/plan_os.md` and `docs/tasks/tasks_os.md` with completion

### Dependencies

- **Needs**: Kernel file I/O syscalls (exists)
- **Provides**: File storage (for Database Agent)
- **Coordinates with**: Kernel Agent (file system), Database Agent (database files)

---

## Completed Phases (Summary)

### Phase 50-58: System Services ✅ **COMPLETE**

All phases complete. See `docs/plans/plan_os.md` for detailed phase descriptions.

**Key Modules**:
- Update Manager (`src/grain_os/update_manager.zig`)
- Package Manager (`src/grain_os/package_manager.zig`)
- Resource Monitor (enhanced with kernel SysInfo)
- Health Monitor (`src/grain_os/health_monitor.zig`)
- Process Supervision (`src/grain_os/process_supervision.zig`)
- System Metrics (`src/grain_os/system_metrics.zig`)
- System Diagnostics (`src/grain_os/system_diagnostics.zig`)

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

### With Grain Mobile Agent

- [ ] Define REST API contracts (endpoints, request/response formats)
- [ ] Define authentication flow (OAuth, JWT, 2FA, magic email)
- [ ] Define WebSocket protocol (for livestream coordination)
- [ ] Test integration with Mobile Agent

### With Vantage VM Basin Kernel Agent

- [ ] Coordinate on file system integration (database files, transaction logs)
- [ ] Coordinate on network stack (HTTP server, WebSocket)
- [ ] Coordinate on AArch64 deployment (VM integration)

---

## References

- **Plan**: [`docs/plans/plan_os.md`](../plans/plan_os.md) - Detailed development plan
- **Next Work Priorities**: [`docs/grain_os_agent_next_work.md`](../grain_os_agent_next_work.md) - Detailed priorities
- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) - Coding principles
- **Compositor**: `src/grain_os/compositor.zig` - System integration point

---

**Next Steps**: Start Phase 59 (HTTP/REST API Server) implementation.

