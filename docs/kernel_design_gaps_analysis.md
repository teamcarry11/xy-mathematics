# Kernel Design Gaps Analysis

**Date**: 2025-12-23-203000-pst  
**Agent**: Grain Vantage Agent  
**Purpose**: Identify potential kernel design gaps based on other agents' coordination needs

---

## Executive Summary

After reviewing coordination documents for Carry, Bubble, Research, Court, Skate, Flow, Silo, Workspace, and Aurora agents, several potential kernel design gaps have been identified. These gaps may need to be addressed to fully support SLC products and agent coordination.

---

## Critical Gaps (Must Address)

### 1. **Syscall Timeout Mechanism** ⚠️ **CRITICAL**

**Issue**: Multiple agents (Carry, Bubble) are requesting timeout handling coordination. The kernel has `sleep_until` but no timeout mechanism for syscalls themselves.

**Current State**:
- `sleep_until` syscall exists but is non-blocking stub
- No timeout parameter for network operations (TCP/UDP)
- No timeout parameter for file operations
- No timeout parameter for IPC operations

**Agent Needs**:
- **Carry Agent**: Request timeout handling for HTTP requests (CRITICAL)
- **Bubble Agent**: Operation timeout handling for Court compute operations (CRITICAL)

**Recommendation**:
- Add timeout parameter to network syscalls (`tcp_connect`, `tcp_send`, `tcp_recv`, `udp_sendto`, `udp_recvfrom`)
- Add timeout parameter to file operations (`read`, `write`)
- Add timeout parameter to IPC operations (`channel_send`, `channel_recv`)
- Consider adding a global timeout configuration syscall

**Impact**: High — Without timeout handling, operations could hang indefinitely, causing resource exhaustion.

---

### 2. **Enhanced Error Reporting** ⚠️ **HIGH PRIORITY**

**Issue**: Agents need more granular error information for debugging and error handling.

**Current State**:
- `BasinError` enum has basic error types
- Error information is limited to error code
- No error context or detailed error messages

**Agent Needs**:
- **Bubble Agent**: Error types for Court compute operations (CRITICAL)
- **Carry Agent**: Error response parsing for database operations
- **Flow Agent**: Error handling for workflow operations

**Recommendation**:
- Extend `BasinError` with more specific error types
- Add error context field to `SyscallResult` (optional error details)
- Add error code enumeration for subsystem-specific errors
- Consider adding `get_last_error()` syscall for detailed error information

**Impact**: Medium-High — Better error reporting improves debugging and error handling.

---

### 3. **Service-to-Service Authentication** ⚠️ **HIGH PRIORITY**

**Issue**: Carry Agent needs service-to-service authentication for database operations.

**Current State**:
- `UserContext` has basic user/group ID tracking
- `has_capability()` function exists but is stub
- No service account support
- No token-based authentication

**Agent Needs**:
- **Carry Agent**: Service-to-service authentication for Silo Agent requests (CRITICAL)
- **Bubble Agent**: Authentication for Court compute operations
- **All Agents**: Token management and refresh

**Recommendation**:
- Add service account support to `UserContext`
- Implement capability-based access control
- Add token validation syscall
- Add token refresh mechanism
- Consider adding `authenticate_service()` syscall

**Impact**: High — Without authentication, service-to-service operations will fail.

---

## High Priority Gaps (Should Address)

### 4. **Resource Limits and Rate Limiting** ⚠️ **HIGH PRIORITY**

**Issue**: Multiple agents mention rate limiting and resource limits, but kernel has no built-in support.

**Current State**:
- No rate limiting syscalls
- No resource quota management
- No per-process resource limits

**Agent Needs**:
- **Carry Agent**: Rate limiting handling (429 Too Many Requests) (HIGH PRIORITY)
- **Bubble Agent**: Operation queuing for Court compute (HIGH PRIORITY)
- **Flow Agent**: Resource limits for workflow operations

**Recommendation**:
- Add `set_resource_limit()` syscall (CPU, memory, network, file descriptors)
- Add `get_resource_usage()` syscall
- Add rate limiting support to network syscalls
- Consider adding `check_rate_limit()` syscall

**Impact**: Medium-High — Resource limits prevent resource exhaustion and improve fairness.

---

### 5. **Health Check and Monitoring Syscalls** ⚠️ **MEDIUM PRIORITY**

**Issue**: Silo Agent mentions health check endpoints, but kernel has no health check syscalls.

**Current State**:
- `sysinfo` syscall provides basic system information
- `get_kernel_stats_snapshot()` method exists but no syscall
- No health check syscall
- No subsystem health status

**Agent Needs**:
- **Silo Agent**: Health check endpoint availability
- **Bubble Agent**: Health checks for Court compute (MEDIUM)
- **Flow Agent**: Monitoring for workflow operations

**Recommendation**:
- Add `kernel_get_stats()` syscall (expose `get_kernel_stats_snapshot()`)
- Add `health_check()` syscall (overall system health)
- Add `subsystem_health()` syscall (per-subsystem health)
- Consider adding health status to `SysInfo` struct

**Impact**: Medium — Health checks enable better monitoring and debugging.

---

### 6. **Async Syscall Support** ⚠️ **MEDIUM PRIORITY**

**Issue**: Carry Agent is waiting for async response handling patterns, but kernel has no async syscall support.

**Current State**:
- All syscalls are synchronous
- No async operation support
- No completion callback mechanism

**Agent Needs**:
- **Carry Agent**: Async HTTP response handling pattern (HIGH PRIORITY)
- **Bubble Agent**: Async Court compute operations
- **Flow Agent**: Async workflow operations

**Recommendation**:
- Consider adding async syscall variants (e.g., `tcp_connect_async`)
- Add completion notification mechanism (event or callback)
- Add `wait_for_async()` syscall
- Consider adding async operation handle type

**Impact**: Medium — Async operations improve responsiveness and resource utilization.

---

## Medium Priority Gaps (Nice to Have)

### 7. **DNS Resolution Support** ⚠️ **MEDIUM PRIORITY**

**Issue**: Aurora Agent mentions DNS resolution deferred to Zig 0.16.0, but kernel has no DNS syscalls.

**Current State**:
- Network interfaces support IPv4/IPv6 configuration
- No DNS resolution syscalls
- No DNS server configuration

**Agent Needs**:
- **Aurora Agent**: DNS resolution infrastructure (deferred to Zig 0.16.0)
- **Carry Agent**: DNS resolution for HTTP requests
- **All Agents**: DNS resolution for network operations

**Recommendation**:
- Add `dns_resolve()` syscall (hostname to IP address)
- Add `dns_resolve_reverse()` syscall (IP address to hostname)
- Add DNS server configuration to network interface
- Consider adding DNS cache support

**Impact**: Medium — DNS resolution is needed for network operations.

---

### 8. **Enhanced IPC and Event Bus Support** ⚠️ **MEDIUM PRIORITY**

**Issue**: Multiple agents coordinate via events, but kernel has basic channel-based IPC only.

**Current State**:
- `channel_create`, `channel_send`, `channel_recv` syscalls exist
- No event bus support
- No pub/sub mechanism
- No event filtering

**Agent Needs**:
- **Flow Agent**: Event bus for workflow coordination
- **Research Agent**: Event-driven coordination
- **All Agents**: Event-based agent coordination

**Recommendation**:
- Consider adding event bus syscalls (`event_subscribe`, `event_publish`, `event_unsubscribe`)
- Add event filtering support
- Add event routing support
- Consider adding event queue management

**Impact**: Medium — Event bus improves agent coordination and decoupling.

---

### 9. **File System Enhancements** ⚠️ **LOW PRIORITY**

**Issue**: SLC products need file operations, but kernel has basic file ops only.

**Current State**:
- Basic file operations: `open`, `read`, `write`, `close`, `unlink`, `rename`, `mkdir`, `opendir`, `readdir`, `closedir`
- No file metadata syscalls
- No file permissions syscalls
- No symbolic link support

**Agent Needs**:
- **SLC Products**: File system operations for Nostr profiles, DAG websites, workspace files
- **Workspace Agent**: File Manager operations

**Recommendation**:
- Add `get_file_info()` syscall (size, permissions, timestamps)
- Add `set_file_permissions()` syscall
- Add `create_symlink()` syscall
- Consider adding file watching syscalls

**Impact**: Low-Medium — File system enhancements improve usability.

---

### 10. **Process Priority and Scheduling Control** ⚠️ **LOW PRIORITY**

**Issue**: Agents may need process priority control, but kernel has basic priority support only.

**Current State**:
- `set_priority` and `get_priority` syscalls exist
- Basic priority levels
- No priority inheritance
- No real-time scheduling

**Agent Needs**:
- **Flow Agent**: Priority control for workflow operations
- **Bubble Agent**: Priority control for design operations

**Recommendation**:
- Enhance priority syscalls with more granular control
- Add priority inheritance support
- Consider adding real-time scheduling support
- Add `set_scheduler_policy()` syscall

**Impact**: Low — Priority control improves resource allocation.

---

## Summary

### Critical Gaps (Must Address)
1. ✅ **Syscall Timeout Mechanism** — **COMPLETE** (2025-12-28-150000-pst)
   - Timeout parameter added to TCP syscalls (connect, send, recv)
   - Timeout parameter added to file I/O syscalls (read, write)
   - Timeout parameter added to IPC syscalls (channel_send, channel_recv)
   - Timeout error types added (network_timeout, file_io_timeout, ipc_timeout)
2. ✅ **Enhanced Error Reporting** — **COMPLETE** (2025-12-23-212000-pst)
   - Extended `BasinError` enum with 20+ specific error types
   - Network errors, file system errors, process errors, IPC errors, resource errors
3. ✅ **Service-to-Service Authentication** — **USESPACE PATTERN** (2025-12-28-125036-pst)
   - Confirmed userspace pattern via Core Agent AuthService
   - No kernel changes needed

### High Priority Gaps (Should Address)
4. ✅ **Resource Limits and Rate Limiting** — **PARTIAL** (2025-12-23-220000-pst)
   - ✅ Resource usage tracking complete (`get_resource_usage` syscall)
   - ⏳ Resource limits enforcement (future work)
   - ⏳ Rate limiting support (future work)
5. ✅ **Health Check and Monitoring Syscalls** — **COMPLETE** (2025-12-23-212000-pst)
   - ✅ `kernel_get_stats` syscall (#135) complete
   - ✅ `health_check` syscall (#136) complete
   - ✅ Comprehensive kernel statistics aggregation
6. ✅ **Async Syscall Support** — **USESPACE PATTERN** (2025-12-28-125036-pst)
   - Confirmed userspace pattern via Flow Agent Event Bus
   - No kernel changes needed

### Medium Priority Gaps (Nice to Have)
7. ✅ DNS Resolution Support
8. ✅ Enhanced IPC and Event Bus Support
9. ✅ File System Enhancements
10. ✅ Process Priority and Scheduling Control

---

## Recommendations

### Immediate Actions
1. **Add timeout parameters to network syscalls** (Critical)
2. **Extend error reporting** with more granular error types (High Priority)
3. **Implement service-to-service authentication** (Critical)

### Short-Term Actions
4. **Add resource limit syscalls** (High Priority)
5. **Expose kernel statistics via syscall** (Medium Priority)
6. **Add health check syscall** (Medium Priority)

### Long-Term Actions
7. **Consider async syscall support** (Medium Priority)
8. **Add DNS resolution syscalls** (Medium Priority)
9. **Enhance IPC with event bus support** (Medium Priority)
10. **Add file system enhancements** (Low Priority)

---

## Coordination Notes

**With Core Agent**:
- Coordinate on timeout handling approach (per-syscall vs global)
- Coordinate on authentication token management
- Coordinate on async syscall design (if needed)

**With Other Agents**:
- **Carry Agent**: Timeout handling, authentication, error reporting
- **Bubble Agent**: Timeout handling, error reporting, health checks
- **Flow Agent**: Resource limits, monitoring, async operations
- **Silo Agent**: Health checks, monitoring
- **Aurora Agent**: DNS resolution (deferred to Zig 0.16.0)

---

**Status**: Design gaps identified — Ready for prioritization and implementation planning
