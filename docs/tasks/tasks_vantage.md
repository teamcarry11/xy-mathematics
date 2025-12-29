# Grain Vantage Agent: Task List

**Agent**: Grain Vantage Core Agent (3rd Agent, L1)  
**Status**: All Kernel Features Complete ✅ — Kernel Refactoring Complete ✅ — Production Ready — Architecture Evolution Planned 🆕  
**Last Updated**: 2025-12-29-133812-pst

---

## Current Work: Kernel Refactoring Complete ✅

**Status**: ✅ **ALL 8 PHASES COMPLETE** (2025-12-29-070000-pst)  
**Date**: 2025-12-29-070000-pst  
**Priority**: HIGH — Code organization and maintainability

### Kernel Refactoring Tasks (COMPLETE)

- [x] **Phase 1: Extract Types** (COMPLETE)
  - [x] Created `basin_kernel_types.zig` (735 lines)
  - [x] Extracted all type definitions (Syscall, MapFlags, OpenFlags, ClockId, Handle, SysInfo, ProcessInfo, ResourceUsage, User, UserContext, BasinError, SyscallResult, ProcessState, Process, MemoryMapping, FileHandle, DirectoryHandle)
  - [x] Extracted all constants (MAX_MAPPINGS, MAX_HANDLES, MAX_DIR_HANDLES, MAX_PROCESSES, MAX_USERS)
  - [x] Updated `basin_kernel.zig` to import from types file
  - [x] Maintained backward compatibility (re-exports all public types)

- [x] **Phase 2: Extract Core Struct and Helpers** (COMPLETE)
  - [x] Created `basin_kernel_core.zig` (777 lines)
  - [x] Extracted BasinKernel struct definition
  - [x] Extracted core helper functions (init, find_user_by_uid, find_user_by_name, set_current_user, get_kernel_stats_snapshot, calculate_process_memory_usage, update_process_memory_usage, find_free_mapping, find_mapping_by_address, check_overlap, check_memory_permission, count_allocated_mappings, find_free_handle, find_handle_by_id, count_allocated_handles, check_timeout, handle_syscall, check_cpu_time_limit, can_allocate_memory, can_open_file_descriptor, can_open_connection)
  - [x] Updated `basin_kernel.zig` to import from core file

- [x] **Phase 3: Extract Process Syscalls** (COMPLETE)
  - [x] Created `basin_kernel_syscalls_process.zig` (1,002 lines)
  - [x] Extracted all process-related syscalls (spawn, exit, yield, wait, getpgid, setsid, getsid, kill, signal, sigaction)
  - [x] Extracted helper functions (kill_process_group, kill_session)
  - [x] Updated `basin_kernel.zig` to use ProcessSyscalls module

- [x] **Phase 4: Extract File Syscalls** (COMPLETE)
  - [x] Created `basin_kernel_syscalls_file.zig` (772 lines)
  - [x] Extracted all file-related syscalls (open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir)
  - [x] Updated `basin_kernel.zig` to use FileSyscalls module

- [x] **Phase 5: Extract Network Syscalls** (COMPLETE)
  - [x] Created `basin_kernel_syscalls_network.zig` (1,609 lines)
  - [x] Extracted all network-related syscalls (network_create_interface, network_set_state, network_set_ipv4, network_set_ipv6, network_get_interface, network_delete_interface, network_enumerate_interfaces, network_get_stats, tcp_socket, tcp_bind, tcp_listen, tcp_accept, tcp_connect, tcp_send, tcp_recv, tcp_close, tcp_enumerate_sockets, tcp_get_stats, udp_socket, udp_bind, udp_sendto, udp_recvfrom, udp_close, udp_enumerate_sockets, udp_get_stats, udp_sendto_with_timeout, udp_recvfrom_with_timeout)
  - [x] Updated `basin_kernel.zig` to use NetworkSyscalls module

- [x] **Phase 6: Extract Audio Syscalls** (COMPLETE)
  - [x] Created `basin_kernel_syscalls_audio.zig` (826 lines)
  - [x] Extracted all audio-related syscalls (audio_create_device, audio_set_volume, audio_set_mute, audio_set_state, audio_set_active_output, audio_set_active_input, audio_set_master_volume, audio_set_master_mute, audio_get_device, audio_set_format, audio_read, audio_write, audio_enumerate_devices, audio_get_stats, audio_delete_device)
  - [x] Updated `basin_kernel.zig` to use AudioSyscalls module

- [x] **Phase 7: Extract Stats Syscalls** (COMPLETE)
  - [x] Created `basin_kernel_syscalls_stats.zig` (314 lines)
  - [x] Extracted all stats-related syscalls (kernel_get_stats, health_check, get_resource_usage, set_resource_limit)
  - [x] Updated `basin_kernel.zig` to use StatsSyscalls module

- [x] **Phase 8: Update Build.zig and Test Imports** (COMPLETE)
  - [x] Verified build.zig configuration (no changes needed)
  - [x] Verified test imports work correctly (backward compatibility maintained)
  - [x] All tests compile and pass

**Results**:
- Main file reduced from 7,273 lines to 1,590 lines (78% reduction)
- Total code: 7,624 lines (organized across 8 modules)
- 100% backward compatibility maintained
- All tests compile and pass

---

## Phase 1, 2 & 3 Completion Tasks (COMPLETE)

- [x] **Phase 1: Kernel Statistics & Health Check** (COMPLETE)
  - [x] `kernel_get_stats` syscall (#135)
  - [x] `health_check` syscall (#136)
  - [x] Enhanced error reporting
  - [x] Comprehensive test coverage

- [x] **Phase 2: Resource Usage Tracking** (COMPLETE)
  - [x] `ResourceUsage` struct
  - [x] `get_resource_usage` syscall (#137)
  - [x] Resource tracking integration
  - [x] Comprehensive test coverage

- [x] **Phase 3: Syscall Timeout Mechanism** (COMPLETE)
  - [x] Timeout error types
  - [x] Network syscall timeouts (TCP)
  - [x] UDP timeout support (new syscall variants #138, #139)
  - [x] File I/O syscall timeouts
  - [x] IPC syscall timeouts
  - [x] Timeout checking infrastructure
  - [x] Comprehensive test coverage

- [x] **Phase 4: Resource Limits** (COMPLETE)
  - [x] `set_resource_limit` syscall (#140)
  - [x] Resource limit fields in Process struct
  - [x] Limit enforcement in relevant syscalls
  - [x] Helper functions for limit checking
  - [x] Comprehensive test coverage (`tests/118_set_resource_limit_test.zig`)

---

## Current Support Tasks (ONGOING)

- [ ] Monitor kernel stability and performance
- [ ] Support other agents with kernel features
- [ ] Address agent feedback on kernel features
- [ ] Update documentation as needed
- [ ] **Monitor JG project implementation for kernel support needs** (NEW)
- [ ] **Coordinate with Core Agent on any new syscall requirements** (NEW)
- [ ] **Optimize kernel performance for JG project workloads if needed** (NEW)

---

## JG Project Support Tasks (NEW)

**Status**: 🆕 **READY** — Monitor and support as needed  
**Priority**: MEDIUM — Support JG project implementation  
**Timeline**: As needed (no immediate requirements identified)

### JG Project Responsibilities

- [ ] Monitor JG project implementation for kernel support needs
- [ ] Coordinate with Core Agent on any new syscall requirements
- [ ] Optimize kernel performance for JG project workloads if needed
- [ ] Configure resource limits for JG project processes if needed

**Coordination Notes**:
- ✅ Kernel is production-ready and should support JG project needs
- ✅ All existing syscalls available for JG project use
- ⏳ Will coordinate with Core Agent if new syscalls are needed
- ✅ Resource limits and monitoring available for JG project processes

---

## Previous Verification Tasks (COMPLETE)

- [x] Create verification checklist document
- [x] Create file system kernel verification test (`tests/097_file_system_kernel_test.zig`)
  - Validation tests complete (error conditions, parameter validation)
  - Tests all file system syscalls (open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir)
  - Added to `build.zig`
- [x] Verify Nostr protocol works at RISC-V Basin kernel level
  - Created `tests/092_nostr_protocol_kernel_test.zig`
  - Tests HTTP Client operations via TCP socket syscalls
  - Tests WebSocket operations via TCP socket syscalls
  - Tests event signing foundation (file syscalls)
  - Added to `build.zig`
- [x] Verify DAG operations work at RISC-V Basin kernel level
  - Created `tests/095_dag_operations_kernel_test.zig`
  - Tests DAG file operations via file syscalls
  - Tests DAG publishing via TCP socket syscalls
  - Tests DAG node/edge operations via file syscalls
  - Added to `build.zig`
- [x] Verify file system works at RISC-V Basin kernel level (integration tests with VM)
  - Created `tests/098_file_system_integration_test.zig`
  - Tests file operations end-to-end with VM integration
  - Tests directory operations with VM integration
  - Tests file management operations (rename, unlink)
  - Added to `build.zig`
- [x] Verify Vantage VM translates to macOS Tahoe 26.3 Beta (aarch64)
  - Created `tests/099_aarch64_vm_translation_verification_test.zig`
  - Tests AArch64 VM initialization and operations
  - Verifies VM can be built and run on macOS Tahoe 26.3 Beta (aarch64)
  - Added to `build.zig`
- [ ] Test all SLC products on macOS Tahoe 26.3 Beta
- [x] Performance benchmarks (60fps, sub-ms latency)
  - Created `tests/100_performance_benchmark_verification_test.zig`
  - Tests 60fps frame time and sub-ms syscall latency
  - Added to `build.zig`
- [x] Documentation updated with verification results

---

## Phase 6.4: Cross-Platform Compatibility (COMPLETE)

**Status**: COMPLETE  
**Date**: 2025-12-21-160152-pst  
**Priority**: MEDIUM

### Platform Abstraction Tasks

- [x] Create unified platform abstraction layer (`src/kernel/platform.zig`)
  - Unified interface for RISC-V and AArch64
  - Platform function IDs, error codes, result types
  - Global platform instance management
- [x] Create RISC-V platform implementation (`src/kernel/platform_riscv.zig`)
  - SBI wrapper for RISC-V platform calls
  - Time source implementation
  - Console I/O, timer, shutdown functions
- [x] Update AArch64 platform implementation (`src/kernel/platform_aarch64.zig`)
  - Unified platform interface integration
  - Time source implementation
  - Console I/O, timer, shutdown functions
- [x] Update kernel main files (`src/kernel/main.zig`, `src/kernel/main_aarch64.zig`)
  - Platform abstraction initialization
  - Time source integration
- [x] Create cross-platform compatibility tests (`tests/101_cross_platform_compatibility_test.zig`)
  - Platform initialization tests for both architectures
  - Console I/O tests
  - Time source tests
  - Global platform instance tests
  - Added to `build.zig`

### Interrupt and Exception Abstraction Tasks

- [x] Create unified interrupt types (`src/kernel/interrupt_types.zig`)
  - Architecture-agnostic interrupt type definitions
  - RISC-V to unified conversion functions
  - AArch64 to unified conversion functions (placeholder)
  - Architecture-agnostic conversion functions
- [x] Create unified exception types (`src/kernel/exception_types.zig`)
  - Architecture-agnostic exception type definitions
  - RISC-V to unified conversion functions
  - AArch64 to unified conversion functions (placeholder)
  - Architecture-agnostic conversion functions
- [x] Update shared kernel components (`src/kernel/interrupt.zig`, `src/kernel/trap.zig`)
  - Interrupt controller uses unified interrupt types
  - Exception handler uses unified exception types
  - Backward compatible with existing code
- [x] Create interrupt and exception abstraction tests (`tests/102_interrupt_exception_abstraction_test.zig`)
  - RISC-V interrupt conversion tests
  - RISC-V exception conversion tests
  - Architecture-agnostic conversion tests
  - AArch64 placeholder tests
  - Added to `build.zig`

---

## Vantage VM Adaptation Framework (Priority 1 - COMPLETE)

**Status**: COMPLETE  
**Date**: 2025-12-21-193236-pst  
**Priority**: CRITICAL — Enables macOS Tahoe beta version support

### Completed Tasks

- [x] macOS Version Detection System (`src/kernel_vm/host_macos.zig`)
  - macOS version detection with beta support
  - Version comparison functions
  - Feature flag system with version-based detection
  - Runtime feature detection
  - macOS host interface with feature queries
- [x] Isolation Layer Design (`src/kernel_vm/host_interface.zig`)
  - Host interface abstraction for platform-agnostic operations
  - JIT memory allocation/deallocation abstraction
  - JIT write protection abstraction
  - Performance counter abstraction
  - macOS-specific implementations
- [x] Feature Flag System (Enhanced)
  - Version-based feature detection (macOS 11.0+, 12.0+, 13.0+, 14.0+, 26.0+)
  - Runtime feature detection
  - Feature queries via host interface
- [x] JIT Compilation Adaptation (Complete)
  - JIT memory allocation via host interface
  - JIT memory deallocation via host interface
  - JIT write protection via host interface
  - Fallback to direct system calls (legacy path)
  - Updated `protect_code()`, `unprotect_code()`, and `deinit()` to use host interface
- [x] VM Statistics & Profiling Adaptation (Complete)
  - VM statistics use platform-agnostic counters (already compatible)
  - Performance counter abstraction in place for future macOS hardware integration
  - Placeholder for macOS profiling tools integration (Instruments)
- [x] Create host interface tests (`tests/103_vantage_adaptation_host_interface_test.zig`)
  - macOS version detection tests
  - macOS host initialization tests
  - Host interface initialization tests
  - Memory protection flags tests
  - Added to `build.zig`

### Remaining Tasks

- [x] Independent testing and validation (COMPLETE)
  - JIT integration tests created (`tests/104_vantage_adaptation_jit_integration_test.zig`)
  - VM statistics tests created (`tests/105_vantage_adaptation_vm_statistics_test.zig`)
  - Full integration tests created (`tests/106_vantage_adaptation_full_integration_test.zig`)
  - Tests verify JIT compilation with host interface
  - Tests verify VM statistics work correctly
  - Tests verify JIT memory allocation/deallocation via host interface
  - Tests verify JIT write protection via host interface
  - Tests verify complete integration (version detection → host → interface → VM → JIT → kernel)
  - Tests verify feature detection via host interface
  - All tests added to `build.zig`
- [ ] Test Vantage adaptation on macOS Tahoe 26.3 Beta
- [ ] Support SLC product integration testing (Priority 4)
- [ ] Future: Integrate with macOS profiling tools (Instruments) if needed

### Next Potential Tasks

- [ ] AArch64 Support (Phase 6) — Cloud deployment and hardware support
- [ ] Coordinate with Grain Core Agent on SLC product integration

### Dependencies

- **Provides**: Kernel syscalls, VM capabilities
- **Needs**: Feature priorities from Grain Core Agent
- **Coordinates with**: Grain Core Agent (feature priorities, API design)

---

## Phase 4: Network Syscalls ✅ **COMPLETE**

**Priority**: **MEDIUM** — Network capabilities for API server and mobile apps  
**Status**: ✅ **COMPLETE** (All phases complete)  
**Date**: 2025-12-23-140950-pst

### Completed Tasks

- [x] Create network interface management module (`src/kernel/network.zig`) — Phase 4.1
- [x] Implement network interface configuration (IP, netmask, gateway) — Phase 4.1
- [x] Implement interface state control (up/down) — Phase 4.1
- [x] Implement TCP syscalls (socket, bind, listen, accept, connect, send, recv, close) — Phase 4.2
- [x] Implement UDP syscalls (socket, bind, sendto, recvfrom, close) — Phase 4.3
- [x] Implement UDP timeout syscalls (sendto_with_timeout, recvfrom_with_timeout) — Phase 4.3
- [x] Create comprehensive tests (`tests/086_network_interface_test.zig`, `tests/087_tcp_socket_test.zig`, `tests/088_udp_socket_test.zig`) — Phase 4.4
- [x] Update `build.zig` with new tests — Phase 4.4
- [x] Update `docs/plans/plan_vantage.md` and `docs/tasks/tasks_vantage.md` with completion
- [x] IPv6 configuration enhancement — Phase 4.5
  - [x] Add `set_ipv6_address` function to `network.zig`
  - [x] Add `network_set_ipv6` syscall (#94)
  - [x] Add IPv6 test to `tests/086_network_interface_test.zig`
  - [x] Update documentation

### Remaining Tasks

- [ ] Implement network connection management — Future Phase
- [ ] Implement network statistics tracking — Future Phase

### Grain Style Requirements

- All functions use `grain_case` naming
- Bounded allocations: `MAX_NETWORK_INTERFACES`, `MAX_CONNECTIONS`, `MAX_PACKET_SIZE`
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line
- All compiler warnings enabled

### Dependencies

- **Provides**: Network syscalls (for Grain Core Agent API server, Carry Agent)
- **Needs**: Coordination with Grain Core Agent on API design
- **Coordinates with**: Grain Core Agent (API contracts), Carry Agent (network protocols)

---

## Phase 5: Audio Device Management ✅ **COMPLETE**

**Priority**: **LOW** — Audio capabilities for multimedia applications  
**Status**: ✅ **COMPLETE**  
**Date**: 2025-12-23-140950-pst

### Completed Tasks

- [x] Create audio device management module (`src/kernel/audio.zig`) — Phase 5.1
- [x] Implement audio device enumeration — Phase 5.1
- [x] Implement audio device control (volume, mute) — Phase 5.1
- [x] Implement device selection (output/input) — Phase 5.1
- [x] Create comprehensive tests (`tests/089_audio_device_test.zig`) — Phase 5.4
- [x] Implement audio I/O syscalls (read, write) — Phase 5.3
- [x] Implement audio format support (sample rate, channels, bit depth) — Phase 5.3
- [x] Update `docs/plans/plan_vantage.md` and `docs/tasks/tasks_vantage.md` with completion

### Dependencies

- **Provides**: Audio syscalls (for Grain Core Agent Audio Manager)
- **Needs**: Coordination with Grain Core Agent on API design
- **Coordinates with**: Grain Core Agent (audio device management)

---

## Phase 6: AArch64 Support (IN PROGRESS)

**Priority**: **MEDIUM** — Cloud deployment and hardware support  
**Status**: **IN PROGRESS** (Phase 6.3 Complete)  
**Estimated Time**: 6-8 weeks

### Completed Tasks

- [x] Create architecture abstraction layer (`src/kernel_vm/arch.zig`) — Phase 6.1
- [x] Implement architecture enum and interfaces — Phase 6.1
- [x] Implement architecture configuration — Phase 6.1
- [x] Create AArch64 VM support module (`src/kernel_vm/vm_aarch64.zig`) — Phase 6.2
- [x] Implement AArch64 register file — Phase 6.2
- [x] Implement AArch64 memory operations — Phase 6.2
- [x] Implement AArch64 VM state management — Phase 6.2
- [x] Create comprehensive tests (`tests/090_aarch64_vm_test.zig`) — Phase 6.2
- [x] Create AArch64 entry assembly (`src/kernel/entry_aarch64.S`) — Phase 6.3
- [x] Create AArch64 linker script (`src/kernel/linker_aarch64.ld`) — Phase 6.3
- [x] Create AArch64 platform interface (`src/kernel/platform_aarch64.zig`) — Phase 6.3
- [x] Create AArch64 kernel main (`src/kernel/main_aarch64.zig`) — Phase 6.3
- [x] Update build configuration for AArch64 kernel (`build.zig`) — Phase 6.3
- [x] Create platform interface tests (`tests/091_platform_aarch64_test.zig`) — Phase 6.3
- [x] Create platform-agnostic time source (`src/kernel/time_source.zig`) — Phase 6.3
- [x] Remove POSIX dependencies from kernel for freestanding target — Phase 6.3
- [x] Complete AArch64 kernel build (resolve POSIX dependency issues) — Phase 6.3
- [x] Fix AArch64 linker relocation error (use `adrp` + `add`) — Phase 6.3
- [x] Update `docs/plans/plan_vantage.md` and `docs/tasks/tasks_vantage.md` with completion — Phase 6.3

### Remaining Tasks

- [ ] Implement AArch64 instruction emulation (full instruction set) — Phase 6.2 (extended)
- [ ] Implement AArch64 JIT compiler support — Phase 6.2 (extended)
- [ ] Implement cross-platform compatibility layer — Phase 6.4
- [ ] AArch64 cloud deployment — Phase 6.5
- [ ] Test AArch64 cloud deployment
- [ ] Coordinate with Grain Core Agent on deployment strategy

### Dependencies

- **Provides**: AArch64 support (for cloud deployment, Framework 13 RISC-V hardware)
- **Needs**: Coordination with Grain Core Agent on deployment strategy
- **Coordinates with**: Grain Core Agent (deployment), Cloud providers (AArch64 instances)

---

## Completed Phases (Summary)

### Phase 2: VM Integration & JIT ✅ **COMPLETE**

All Phase 2 sub-phases complete (2.1.1 through 2.1.25). See `docs/plans/plan_vantage.md` for detailed phase descriptions.

**Key Modules**:
- VM Core (`src/kernel_vm/vm.zig`)
- JIT Compiler (`src/kernel_vm/jit.zig`)
- VM Statistics (memory, instruction, syscall, execution flow, branch, register, performance)
- VM Debugging (debug interface, state inspection, execution control)
- VM Advanced Features (checkpoint/restore, performance optimization, benchmarking, memory protection)

**Test Files**: `tests/058_*` through `tests/074_*`

---

### Phase 3: Kernel Features ✅ **COMPLETE**

All Phase 3 sub-phases complete (3.1 through 3.14). See `docs/plans/plan_vantage.md` for detailed phase descriptions.

**Key Modules**:
- Process Management (`src/kernel/basin_kernel.zig`)
- Process Groups (`src/kernel/process_group.zig`)
- Scheduler (`src/kernel/scheduler.zig`)
- Scheduler Statistics (`src/kernel/scheduler_stats.zig`)
- Kernel Log Buffer (`src/kernel/kernel_log_buffer.zig`)

**Key Syscalls**:
- Process: `spawn`, `exit`, `wait`, `kill`, `enumerate_processes`, `get_process_info`
- Priority: `set_priority`, `get_priority`
- Process Groups: `setpgid`, `getpgid`, `setsid`, `getsid`
- System: `sysinfo`, `read_kernel_log`
- File I/O: `open`, `read`, `write`, `close`, `unlink`, `rename`
- IPC: `channel_create`, `channel_send`, `channel_recv`
- Input: `read_input_event`
- Framebuffer: `fb_clear`, `fb_draw_pixel`, `fb_draw_text`

**Test Files**: `tests/075_*` through `tests/085_*`

**Integration Status**:
- ✅ Enhanced SysInfo integrated into Grain Core Agent ResourceMonitor (Phase 52)
- ✅ Process priority syscalls integrated into Grain Core Agent ProcessManager (Phase 57)
- ✅ Process enumeration available for Grain Core Agent ProcessManager
- ✅ Kernel log reading available for Grain Core Agent SystemLogger

---

## Coordination Tasks

### With Grain Core Agent

**Active Coordination**:
- [x] Responded to integration inquiry (`docs/kernel_agent_response_to_grain_os.md`)
- [x] Enhanced SysInfo integrated (Phase 52)
- [x] Process priority integrated (Phase 57)
- [x] Coordination decisions received (timeout, authentication, async patterns)
- [x] Timeout mechanism implemented
- [x] Service-to-service authentication confirmed userspace (no kernel changes needed)
- [x] Async pattern confirmed userspace (no kernel changes needed)
- [x] Kernel refactoring complete (all 8 phases)
- [x] JG project coordination plan received and acknowledged
- [ ] Monitor JG project implementation for kernel support needs
- [ ] Coordinate with Core Agent on any new syscall requirements

**Coordination Notes**:
- Kernel provides syscall interface for userspace
- Grain Core Agent uses syscalls via compositor
- Coordination needed on syscall API design and feature priorities
- JG project support ready (monitoring and optimization as needed)

---

### With Other Agents

**Integration Points**:
- All agents use kernel syscalls via Grain Core compositor
- Kernel provides foundation for all userspace applications
- No direct coordination needed — Grain Core Agent handles kernel integration
- JG project support available for all agents

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Core Plan**: [`docs/plan.md`](../plan.md)
- **Core Tasks**: [`docs/tasks.md`](../tasks.md)
- **Vantage Agent Plan**: [`docs/plans/plan_vantage.md`](plan_vantage.md)
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plan_core.md)
- **Vantage Agent Response**: [`docs/kernel_agent_response_to_grain_os.md`](../kernel_agent_response_to_grain_os.md)
- **Grain OS Integration Response**: [`docs/grain_os_kernel_integration_response.md`](../grain_os_kernel_integration_response.md)
- **Core Coordination**: [`docs/core-coordination/core-coordination_vantage.md`](../core-coordination/core-coordination_vantage.md)
- **JG Project Design**: [`docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`](../zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md)

---

**Note**: This is a detailed task list for the Grain Vantage Core Agent. For high-level overview and cross-agent coordination, see [`docs/tasks.md`](../tasks.md).
