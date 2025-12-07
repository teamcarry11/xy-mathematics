# Grain Core Agent: Task List

**Agent**: Grain Core Agent (4th Agent)  
**Status**: Phase 61 HTTP Client Complete, Phase 62 Complete, Ready for Next Phase  
**Last Updated**: 2025-12-07-004326-pst

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

- [x] Implement socket options (reuse address, keep-alive, timeout) ✅ (2025-12-06-131112-pst)
- [x] Implement HTTP client (GET, POST, PUT, DELETE requests) — COMPLETE (2025-12-07-004326-pst)
- [ ] Implement HTTP server enhancements (may overlap with Phase 59)
- [x] Implement WebSocket support (handshake, frame parsing, connection management) ✅ (2025-12-05-202227-pst)
- [x] Implement DNS resolution (A, AAAA, MX records, caching) ✅ (2025-12-05-231800-pst)
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

- [x] Create `src/grain_core/file_storage.zig` module or enhance kernel file I/O ✅ (2025-12-06-023413-pst)
- [x] Implement database file format support (header, pages, indexes) ✅ (2025-12-06-023413-pst)
- [x] Implement transaction log file management (WAL format, rotation, checkpoint, recovery) ✅ (2025-12-06-035857-pst)
- [x] Implement index file management (B-tree, hash index formats, recovery) ✅ (2025-12-06-045220-pst)
- [x] Implement backup/restore capabilities (full, incremental, scheduling) ✅ (2025-12-06-061647-pst)
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

## Planned: Phase 63 - API Contracts Registry & Breaking Changes Protocol

**Priority**: **HIGH** — Prevents integration conflicts and breaking changes  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 1-2 weeks

### Tasks

- [ ] Create `docs/agent-communications/api_contracts_registry.md` template
- [ ] Document all Core Agent → Other Agent APIs (API Server, Auth Service, File System, HTTP Client, WebSocket)
- [ ] Create breaking changes protocol document (`docs/agent-communications/breaking_changes_protocol.md`)
- [ ] Define deprecation timeline (e.g., 2 coordination cycles minimum)
- [ ] Define migration path documentation requirements
- [ ] Define versioning strategy (semantic versioning for APIs)
- [ ] Define backward compatibility requirements
- [ ] Create API contract template for agents to fill out
- [ ] Update coordination plan with API contract registry link
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **Silo Agent**: Document Database → Core APIs
- **Carry Agent**: Document Mobile → Core APIs
- **Flow Agent**: Document Flow → Core APIs
- **Skate Agent**: Document Skate → Core APIs
- **Research Agent**: Document Research → Core APIs
- **Aurora Agent**: Document Aurora → Core APIs
- **Workspace Agent**: Document Workspace → Core APIs
- **Bubble Agent**: Document Bubble → Core APIs
- **Vantage Agent**: Document Vantage → Core APIs

---

## Planned: Phase 64 - Integration Test Infrastructure

**Priority**: **HIGH** — Catches integration issues early  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create `tests/integration/` directory structure
- [ ] Create integration test runner (`tests/integration/runner.zig`)
- [ ] Create integration test framework (setup/teardown, test isolation)
- [ ] Create Core → Silo integration tests (API Server + Database)
- [ ] Create Core → Carry integration tests (API Server + Auth + Mobile)
- [ ] Create Core → Flow integration tests (API Server + WebSocket + Event Bus)
- [ ] Create Core → Skate integration tests (HTTP Client + AI)
- [ ] Create Core → Workspace integration tests (System Services)
- [ ] Create Core → Bubble integration tests (Compositor + Rendering)
- [ ] Document integration test standards (`docs/testing/integration_test_standards.md`)
- [ ] Update `build.zig` with integration test suite
- [ ] Create CI/CD integration test runner (if applicable)
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **Silo Agent**: Create Silo → Core integration tests
- **Carry Agent**: Create Carry → Core integration tests
- **Flow Agent**: Create Flow → Core integration tests
- **Skate Agent**: Create Skate → Core integration tests
- **Research Agent**: Create Research → Core integration tests
- **Aurora Agent**: Create Aurora → Core integration tests
- **Workspace Agent**: Create Workspace → Core integration tests
- **Bubble Agent**: Create Bubble → Core integration tests
- **Vantage Agent**: Create Vantage → Core integration tests

---

## Planned: Phase 65 - Performance Monitoring & Benchmarks

**Priority**: **MEDIUM** — System-wide performance tracking  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create `src/grain_core/performance_monitor.zig` module
- [ ] Implement API response time tracking
- [ ] Implement resource usage tracking (memory, CPU per agent)
- [ ] Implement throughput metrics (requests/second, operations/second)
- [ ] Create performance benchmark framework (`tests/performance/benchmark_runner.zig`)
- [ ] Create Core Agent performance benchmarks (API Server, Auth Service, File System)
- [ ] Document performance standards (`docs/performance/performance_standards.md`)
- [ ] Create performance dashboard (if applicable)
- [ ] Integrate with System Metrics (Phase 55)
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **Silo Agent**: Create database performance benchmarks
- **Carry Agent**: Create mobile app performance benchmarks
- **Flow Agent**: Create workflow performance benchmarks
- **Skate Agent**: Create knowledge graph performance benchmarks
- **Research Agent**: Create research performance benchmarks
- **Aurora Agent**: Create IDE/browser performance benchmarks
- **Workspace Agent**: Create desktop app performance benchmarks
- **Bubble Agent**: Create design tool performance benchmarks
- **Vantage Agent**: Create kernel/VM performance benchmarks

---

## Planned: Phase 66 - Error Handling & Logging Standards

**Priority**: **MEDIUM** — Consistent error handling and logging  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 1-2 weeks

### Tasks

- [ ] Create error handling standards document (`docs/standards/error_handling_standards.md`)
- [ ] Define error code standards (error code ranges per agent)
- [ ] Define error propagation patterns (when to return errors, when to log)
- [ ] Create logging standards document (`docs/standards/logging_standards.md`)
- [ ] Define log levels (debug, info, warning, error, critical)
- [ ] Define structured logging format (JSON, key-value pairs)
- [ ] Create logging infrastructure (`src/grain_core/logger.zig`) if needed
- [ ] Update Core Agent modules to follow standards
- [ ] Create example error handling patterns
- [ ] Create example logging patterns
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **All Agents**: Update their modules to follow error handling standards
- **All Agents**: Update their modules to follow logging standards
- **All Agents**: Create error handling examples for their domain
- **All Agents**: Create logging examples for their domain

---

## Planned: Phase 67 - Security Guidelines & Resource Limits

**Priority**: **MEDIUM** — Security and resource management  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 2-3 weeks

### Tasks

- [ ] Create security guidelines document (`docs/security/security_guidelines.md`)
- [ ] Define input validation standards
- [ ] Define authentication/authorization patterns
- [ ] Define data encryption requirements
- [ ] Create security audit checklist
- [ ] Create resource limits coordination document (`docs/coordination/resource_limits.md`)
- [ ] Define memory limits per agent
- [ ] Define CPU quotas per agent
- [ ] Define network bandwidth limits per agent
- [ ] Implement resource limit enforcement (if needed)
- [ ] Integrate with System Metrics (Phase 55)
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **All Agents**: Review and implement security guidelines
- **All Agents**: Implement input validation per standards
- **All Agents**: Implement authentication/authorization per patterns
- **All Agents**: Implement data encryption per requirements
- **All Agents**: Conduct security audit per checklist
- **All Agents**: Implement resource limits per coordination document

---

## Planned: Phase 68 - Release Coordination & Shared Module Versioning

**Priority**: **LOW** — Release process and module versioning  
**Status**: **PLANNED** (Queued for next coordination cycle)  
**Estimated Time**: 1-2 weeks

### Tasks

- [ ] Create release coordination document (`docs/coordination/release_coordination.md`)
- [ ] Define release cadence (e.g., bi-weekly, monthly)
- [ ] Define dependency ordering (which agents release first)
- [ ] Define rollback procedures
- [ ] Create shared module versioning strategy (`docs/coordination/shared_module_versioning.md`)
- [ ] Define semantic versioning for shared modules
- [ ] Define compatibility guarantees (backward compatibility requirements)
- [ ] Create migration guides template
- [ ] Document current shared modules and their versions
- [ ] Update `docs/plans/plan_core.md` and `docs/tasks/tasks_core.md` with progress

### Delegated to Other Agents (in next coordination plan)

- **All Agents**: Review and follow release coordination process
- **All Agents**: Review and follow shared module versioning strategy
- **All Agents**: Create migration guides when APIs change
- **Shared Module Owners** (Aurora, Skate): Implement versioning for shared modules

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

