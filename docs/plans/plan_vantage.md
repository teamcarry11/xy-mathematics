# Grain Vantage Agent: Development Plan

**Agent**: Grain Vantage Agent (1st Agent)  
**Status**: Phase 5.3 Complete, Ready for Next Phase  
**Last Updated**: 2025-12-07-064245-pst

---

## Overview

Grain Vantage Agent is responsible for building the RISC-V64 virtual machine (Grain Vantage VM) and the kernel (Grain Basin Kernel) that runs within it. The VM provides JIT-accelerated RISC-V64 emulation, comprehensive statistics and profiling, debugging capabilities, and memory protection. The kernel provides syscalls for process management, resource monitoring, file I/O, IPC, and system services.

**Key Goals**:
- RISC-V64 VM with JIT acceleration for performance
- Comprehensive VM statistics and profiling for optimization
- Kernel syscalls for userspace applications
- Process management and scheduling
- Resource monitoring and system information
- Integration with Grain Core compositor

---

## Completed Phases

### Phase 2: VM Integration & JIT ✅ **COMPLETE**

**Date**: Various (Phase 2.1.1 through Phase 2.1.25)

**Completed Work**:

1. **VM Integration** (`src/kernel_vm/vm.zig`):
   - JIT integration with dispatch loop
   - `init_with_jit()` and `step_jit()` methods
   - Interpreter fallback for JIT failures
   - Guest state synchronization

2. **JIT Performance Enhancements**:
   - **Phase 2.1.1**: JIT Performance Timing — Timing measurements for compilation and execution
   - **Phase 2.1.2**: JIT Hot Path Detection — Tracks frequently executed blocks (MAX_HOT_PATHS: 32)
   - **Phase 2.1.3**: JIT Code Size Tracking — Code size tracking per block (total, min, max, average)
   - **Phase 2.1.22**: JIT Missing Instruction Support — SLT, SLTU, SLTI, SLTIU instructions
   - **Phase 2.1.23**: JIT Block Chaining — Links consecutive blocks to reduce dispatch overhead
   - **Phase 2.1.24**: JIT Block Invalidation — Ability to invalidate and recompile blocks
   - **Phase 2.1.25**: JIT Compilation Thresholds — Compile only frequently executed blocks

3. **VM Statistics & Profiling**:
   - **Phase 2.1.4**: VM Memory Statistics — Memory usage and access pattern tracking
   - **Phase 2.1.5**: VM Instruction Execution Statistics — Instruction frequency and categorization
   - **Phase 2.1.6**: VM Syscall Execution Statistics — Syscall frequency and categorization
   - **Phase 2.1.7**: VM Execution Flow Tracking — PC history and loop detection
   - **Phase 2.1.8**: VM Statistics Aggregator — Unified statistics reporting interface
   - **Phase 2.1.9**: VM Branch Prediction Statistics — Branch outcome tracking
   - **Phase 2.1.10**: VM Register Usage Statistics — Register read/write frequency
   - **Phase 2.1.11**: VM Instruction Performance Profiling — Execution time per instruction type
   - **Phase 2.1.12**: VM Statistics Export — JSON export for all VM statistics

4. **VM Debugging & Inspection**:
   - **Phase 2.1.13**: VM Debugging Interface — Breakpoint and watchpoint management
   - **Phase 2.1.14**: VM State Inspection — Register and memory inspection
   - **Phase 2.1.15**: VM Execution Control — Step, continue, pause execution
   - **Phase 2.1.16**: VM Debugging Command Interface — Command-based debugging interface
   - **Phase 2.1.17**: VM Instruction Trace Logging — Instruction execution trace logging

5. **VM Advanced Features**:
   - **Phase 2.1.18**: VM Checkpoint/Restore — Save and restore VM state
   - **Phase 2.1.19**: VM Performance Optimization Hints — Optimization suggestions
   - **Phase 2.1.20**: VM Performance Benchmarking Framework — Benchmarking infrastructure
   - **Phase 2.1.21**: VM Memory Protection — Page table and memory protection

**Features**:
- RISC-V64 emulator with JIT acceleration
- Comprehensive VM statistics and profiling
- Debugging and inspection capabilities
- Performance optimization and benchmarking
- Memory protection and page table management

**Files**:
- `src/kernel_vm/vm.zig` — Main VM implementation
- `src/kernel_vm/jit.zig` — JIT compiler
- `src/kernel_vm/memory_stats.zig` — Memory statistics
- `src/kernel_vm/instruction_stats.zig` — Instruction statistics
- `src/kernel_vm/syscall_stats.zig` — Syscall statistics
- `src/kernel_vm/execution_flow.zig` — Execution flow tracking
- `src/kernel_vm/stats_aggregator.zig` — Statistics aggregator
- `src/kernel_vm/branch_stats.zig` — Branch statistics
- `src/kernel_vm/register_stats.zig` — Register statistics
- `src/kernel_vm/instruction_perf.zig` — Instruction performance profiling
- `src/kernel_vm/stats_export.zig` — Statistics export
- `src/kernel_vm/debug_interface.zig` — Debugging interface
- `src/kernel_vm/state_inspection.zig` — State inspection
- `src/kernel_vm/execution_control.zig` — Execution control
- Multiple test files (`tests/058_*` through `tests/074_*`)

---

### Phase 3: Kernel Features ✅ **COMPLETE**

#### Phase 3.1: Process Enumeration ✅

**Date**: 2025-12-02

**Completed Work**:
- `enumerate_processes` syscall (#51) for listing all processes
- `ProcessInfo` structure for userspace process information (32 bytes)
- Process table enumeration with bounded buffer support
- Error handling (null pointer, buffer too small, invalid arguments)

**Files**:
- `src/kernel/basin_kernel.zig` — Syscall implementation
- `tests/075_kernel_process_enumeration_test.zig` — Comprehensive tests

---

#### Phase 3.2: Per-Process Resource Tracking ✅

**Date**: 2025-12-02

**Completed Work**:
- `get_process_info` syscall (#52) for querying process resources
- CPU time tracking (`cpu_time_ns`) in Process struct
- Memory usage tracking (`memory_used`) in Process struct
- Parent process ID tracking (`parent_pid`) in Process struct
- Resource initialization in `syscall_spawn`

**Files**:
- `src/kernel/basin_kernel.zig` — Syscall implementation
- `tests/075_kernel_process_enumeration_test.zig` — Comprehensive tests

---

#### Phase 3.3: Kernel Log Reading ✅

**Date**: 2025-12-02

**Completed Work**:
- `read_kernel_log` syscall (#53) for reading kernel log entries
- `KernelLogBuffer` for storing log entries (circular buffer, max 256 entries)
- `KernelLogEntry` structure (timestamp, level, source, message)
- Log level enumeration (debug, info, warn, error)
- Bounded buffer support and error handling

**Files**:
- `src/kernel/kernel_log_buffer.zig` — Log buffer module
- `src/kernel/basin_kernel.zig` — Syscall implementation
- `tests/076_kernel_log_reading_test.zig` — Comprehensive tests

---

#### Phase 3.4: CPU Time Tracking ✅

**Date**: 2025-12-02

**Completed Work**:
- CPU time tracking during process execution
- Timer-based measurement (start/end time tracking)
- Process CPU time accumulation (`cpu_time_ns` field updates)
- Integration with process execution loop in `integration.zig`
- Saturating arithmetic for overflow/underflow protection

**Files**:
- `src/kernel_vm/integration.zig` — CPU time tracking integration
- `tests/077_cpu_time_tracking_test.zig` — Comprehensive tests

---

#### Phase 3.5: Memory Usage Tracking ✅

**Date**: 2025-12-02

**Completed Work**:
- Memory usage calculation from memory mappings
- Process memory usage updates on `map`/`unmap` syscalls
- `calculate_process_memory_usage` helper function
- Integration with memory mapping operations
- Saturating arithmetic for overflow protection

**Files**:
- `src/kernel/basin_kernel.zig` — Memory usage calculation
- `tests/078_memory_usage_tracking_test.zig` — Comprehensive tests

---

#### Phase 3.6: Enhanced System Information ✅

**Date**: 2025-12-02

**Completed Work**:
- Enhanced `SysInfo` structure (56 bytes, expanded from 32 bytes)
- `used_memory` field (kernel-calculated, total - available)
- `total_processes` field (count of allocated processes)
- `running_processes` field (count of running processes)
- `exited_processes` field (count of exited processes)
- Process statistics calculation in `syscall_sysinfo`

**Integration**:
- Used by Grain Core Agent's ResourceMonitor
- Integrated in Phase 52 (Enhanced SysInfo Integration)

**Files**:
- `src/kernel/basin_kernel.zig` — Enhanced SysInfo structure and syscall
- `tests/079_enhanced_sysinfo_test.zig` — Comprehensive tests

---

#### Phase 3.7: Process Priority Support ✅

**Date**: 2025-12-02-174212-pst

**Completed Work**:
- Process priority field (`priority`) in Process struct (nice value, -20 to 19, default 0)
- `set_priority` syscall (#54) for setting process priority
- `get_priority` syscall (#55) for getting process priority
- Priority value validation (nice value range checking)
- Priority initialization in process spawn (default 0)
- Priority value conversion (signed to unsigned for syscall interface)

**Integration**:
- Used by Grain Core Agent's ProcessManager
- Integrated in Phase 57 (Process Priority Kernel Integration)

**Files**:
- `src/kernel/basin_kernel.zig` — Priority syscalls
- `tests/080_process_priority_test.zig` — Comprehensive tests

---

#### Phase 3.8: Priority-Based Scheduling ✅

**Date**: 2025-12-02

**Completed Work**:
- Priority-based process selection in scheduler
- Highest priority process selection (lowest nice value)
- Round-robin fallback for processes with same priority
- Scheduler integration with Process.priority field
- Priority-aware `find_next_runnable` implementation

**Files**:
- `src/kernel/scheduler.zig` — Priority-based scheduling
- Scheduler tests updated for priority selection

---

#### Phase 3.9: Time Slice Management ✅

**Date**: 2025-12-02

**Completed Work**:
- Time slice tracking in scheduler (`time_slice_remaining` field)
- Time slice quantum in Process struct (`time_slice_quantum`, default 1000 steps)
- Time slice decrement during execution
- Time slice expiration detection
- Preemption support via time slice expiration

**Files**:
- `src/kernel/scheduler.zig` — Time slice management
- `src/kernel/basin_kernel.zig` — Process time slice quantum
- Scheduler tests updated for time slice management

---

#### Phase 3.10: Time Slice Preemption Integration ✅

**Date**: 2025-12-02

**Completed Work**:
- Time slice checking integrated into process execution loop
- Time slice decrement after each VM step
- Preemption when time slice expires
- Process context saving on preemption
- Integration with scheduler in `execute_process_slice`
- Backward compatibility (optional scheduler parameter)

**Files**:
- `src/kernel/process_execution.zig` — Time slice preemption
- `src/kernel_vm/integration.zig` — Integration layer updates
- Process execution tests updated

---

#### Phase 3.11: Scheduler Loop Implementation ✅

**Date**: 2025-12-02

**Completed Work**:
- Time slice quantum used in `schedule_and_run_next`
- Preemption detection after process execution
- Scheduler loop for coordinated process execution
- Bounded execution with max cycles limit
- Automatic rescheduling on time slice expiration
- Priority-based scheduling with time slice preemption

**Files**:
- `src/kernel_vm/integration.zig` — Scheduler loop implementation
- Integration tests updated

---

#### Phase 3.12: Scheduler Statistics Tracking ✅

**Date**: 2025-12-02

**Completed Work**:
- Scheduler statistics module (`scheduler_stats.zig`)
- Statistics tracking (scheduling decisions, preemptions, context switches)
- Selection method tracking (priority-based vs round-robin)
- Time slice expiration tracking
- Statistics printing and reset functionality
- Integration with scheduler operations

**Files**:
- `src/kernel/scheduler_stats.zig` — Scheduler statistics
- `src/kernel/scheduler.zig` — Statistics integration
- Scheduler statistics tests

---

#### Phase 3.13: Process Groups and Sessions ✅

**Date**: 2025-12-03

**Completed Work**:
- Process group manager module (`process_group.zig`)
- Process group ID (PGID) and session ID (SID) fields in Process struct
- Process group and session tables (MAX_PROCESS_GROUPS: 64, MAX_SESSIONS: 32)
- `setpgid` syscall (#56) for setting process group
- `getpgid` syscall (#57) for getting process group
- `setsid` syscall (#58) for creating new session
- `getsid` syscall (#59) for getting session ID
- Process group and session initialization in process spawn

**Files**:
- `src/kernel/process_group.zig` — Process group manager
- `src/kernel/basin_kernel.zig` — Process group syscalls
- `tests/081_process_group_test.zig` — Comprehensive tests

---

#### Phase 3.14: Signal Delivery to Process Groups ✅

**Date**: 2025-12-03-173514-pst

**Completed Work**:
- Enhanced `syscall_kill` to support process group delivery
- Negative PID detection using high bit flag (0x8000000000000000)
- Process group ID extraction from negative PID
- `kill_process_group()` helper function
- Signal delivery to all processes in a group
- SIGKILL termination of entire process groups
- Error handling for invalid/empty process groups

**Files**:
- `src/kernel/basin_kernel.zig` — Enhanced kill syscall
- `tests/082_signal_process_group_test.zig` — Comprehensive tests

---

#### Phase 3.15: Signal Delivery to Sessions ✅

**Date**: 2025-12-04-101252-pst

**Completed Work**:
- Enhanced `syscall_kill` to support session delivery
- Session PID detection using bit 62 flag (0x4000000000000000)
- Session ID extraction from special PID
- `kill_session()` helper function
- Signal delivery to all processes in a session
- SIGKILL termination of entire sessions
- Error handling for invalid/empty sessions
- Distinction between process group and session delivery

**Files**:
- `src/kernel/basin_kernel.zig` — Enhanced kill syscall with session support
- `tests/083_signal_session_test.zig` — Comprehensive tests

---

#### Phase 3.16: Process Group Statistics ✅

**Date**: 2025-12-05-152509-pst

**Completed Work**:
- Process group statistics module (`process_group_stats.zig`)
- Statistics tracking per process group (process count, CPU time, memory usage, signals sent, exited count)
- Statistics manager with bounded allocation (MAX_PROCESS_GROUP_STATS: 64)
- Statistics updates on process group operations (setpgid, exit, kill)
- Statistics printing and reset functionality
- Integration with process group manager

**Files**:
- `src/kernel/process_group_stats.zig` — Process group statistics module
- `src/kernel/basin_kernel.zig` — Statistics integration
- `tests/084_process_group_stats_test.zig` — Comprehensive tests

---

#### Phase 3.17: Process Group Resource Limits ✅

**Date**: 2025-12-06-000107-pst

**Completed Work**:
- Process group resource limits module (`process_group_limits.zig`)
- Resource limit structures (CPU time, memory, process count)
- Limits manager with bounded allocation (MAX_PROCESS_GROUP_LIMITS: 64)
- Limit enforcement in `syscall_spawn` (process count limits)
- Limit enforcement in `syscall_map` (memory limits)
- Limit checking functions (`can_spawn_process()`, `can_allocate_memory()`)
- Unlimited limits by default (0 = unlimited)
- Integration with process group manager

**Files**:
- `src/kernel/process_group_limits.zig` — Process group limits module
- `src/kernel/basin_kernel.zig` — Limits integration and enforcement
- `tests/085_process_group_limits_test.zig` — Comprehensive tests

---

## Current Work: Phase 5.3 Complete, Ready for Next Phase

**Status**: Phase 5 Complete (Audio Device Management, I/O, & Tests)  
**Next Priority**: Coordinate with Grain Core Agent on audio API integration or plan next kernel feature (Phase 6: AArch64 Support)

### Potential Next Phases

1. **Phase 6: AArch64 Support** (MEDIUM priority) — AArch64 cloud deployment and VM support
   - AArch64 cloud deployment
   - AArch64 VM support
   - AArch64 kernel port
   - Cross-platform compatibility
   - Enables cloud deployment and cross-platform compatibility
   - Larger scope (6-8 weeks estimated)

---

## Planned Phases

### Phase 4: Network Syscalls (IN PROGRESS)

**Priority**: **MEDIUM** — Network capabilities for API server and mobile apps  
**Status**: **IN PROGRESS** (Phase 4.1 & 4.2 Complete)  
**Estimated Time**: 4-6 weeks

**Features**:
- ✅ Network interface management (Phase 4.1 - COMPLETE)
- ✅ TCP syscalls (Phase 4.2 - COMPLETE)
- ✅ UDP syscalls (Phase 4.3 - COMPLETE)
- ✅ Network Tests (Phase 4.4 - COMPLETE)
- ✅ IP configuration (IPv4/IPv6, netmask, gateway) (Phase 4.1 - COMPLETE)
- ✅ Interface state control (up/down) (Phase 4.1 - COMPLETE)

**Completed Work**:
- **Phase 4.1: Network Interface Management** (2025-12-06-062932-pst)
  - Network interface management module (`src/kernel/network.zig`)
  - Interface creation, configuration, and state management
  - IPv4/IPv6 address support
  - Network syscalls: `network_create_interface`, `network_set_state`, `network_set_ipv4`, `network_get_interface`
- **Phase 4.2: TCP Syscalls** (2025-12-06-121157-pst)
  - TCP socket management module (`src/kernel/tcp_socket.zig`)
  - TCP socket operations: `tcp_socket`, `tcp_bind`, `tcp_listen`, `tcp_accept`, `tcp_connect`, `tcp_send`, `tcp_recv`, `tcp_close`
  - Socket state management (closed, listening, connecting, connected, closing)
  - Send/receive buffer management (64KB buffers)

**Dependencies**:
- **Provides**: Network syscalls (for Grain Core Agent API server, Carry Agent)
- **Needs**: Coordination with Grain Core Agent on API design

---

### Phase 5: Audio Device Management (IN PROGRESS)

**Priority**: **LOW** — Audio capabilities for multimedia applications  
**Status**: **IN PROGRESS** (Phase 5.1 Complete)  
**Estimated Time**: 3-4 weeks

**Features**:
- ✅ Audio device enumeration (Phase 5.1 - COMPLETE)
- ✅ Audio device control (volume, mute) (Phase 5.1 - COMPLETE)
- ✅ Audio I/O syscalls (Phase 5.3 - COMPLETE)
- ✅ Device selection (output/input) (Phase 5.1 - COMPLETE)
- ✅ Comprehensive tests (Phase 5.4 - COMPLETE)
- ✅ Audio format support (Phase 5.3 - COMPLETE)

**Completed Work**:
- **Phase 5.1: Audio Device Management** (2025-12-07-033535-pst) ✅ **COMPLETE**
- **Phase 5.3: Audio I/O Syscalls** (2025-12-07-064245-pst) ✅ **COMPLETE**
- **Phase 5.4: Audio Tests** (2025-12-07-042228-pst) ✅ **COMPLETE**
  - Audio device management module (`src/kernel/audio.zig`)
  - Device structures (`AudioDevice`, `AudioDeviceType`, `AudioDeviceState`)
  - Device manager with bounded allocation (MAX_AUDIO_DEVICES: 16)
  - Device creation, configuration, and state management
  - Volume and mute control (per-device and master)
  - Active device selection (output/input)
  - Audio syscalls:
    - `audio_create_device` (#120) — Create audio device
    - `audio_set_volume` (#121) — Set device volume
    - `audio_set_mute` (#122) — Set device mute state
    - `audio_set_state` (#123) — Set device state
    - `audio_set_active_output` (#124) — Set active output device
    - `audio_set_active_input` (#125) — Set active input device
    - `audio_set_master_volume` (#126) — Set master volume
    - `audio_set_master_mute` (#127) — Set master mute state
    - `audio_get_device` (#128) — Get device information
  - Comprehensive test suite (`tests/089_audio_device_test.zig`)
  - Tests cover device creation, volume/mute control, state management, active device selection, master controls, error handling, and multiple device scenarios
- **Phase 5.3: Audio I/O Syscalls** (2025-12-07-064245-pst) ✅ **COMPLETE**
  - Audio format support (`AudioFormat` struct with sample rate, channels, bit depth)
  - Audio I/O buffers (64KB input/output buffers per device)
  - Audio format validation (sample rate 8kHz-192kHz, channels 1-8, bit depth 8/16/24/32)
  - Audio read/write operations (`read_audio`, `write_audio`)
  - Audio syscalls:
    - `audio_set_format` (#129) — Set audio format (sample rate, channels, bit depth)
    - `audio_read` (#130) — Read audio data from input device
    - `audio_write` (#131) — Write audio data to output device
  - Extended test suite with format, read, and write tests
  - Input/output device capability validation

**Dependencies**:
- **Provides**: Audio syscalls (for Grain Core Agent Audio Manager)
- **Needs**: Coordination with Grain Core Agent on API design

---

### Phase 6: AArch64 Support (PLANNED)

**Priority**: **MEDIUM** — Cloud deployment and hardware support  
**Status**: **PLANNED**  
**Estimated Time**: 6-8 weeks

**Features**:
- AArch64 cloud deployment
- AArch64 VM support
- AArch64 kernel port
- Cross-platform compatibility

**Dependencies**:
- **Provides**: AArch64 support (for cloud deployment, Framework 13 RISC-V hardware)
- **Needs**: Coordination with Grain Core Agent on deployment strategy

---

## Coordination Points

### With Grain Core Agent

**Integration Points**:
- **Kernel Syscalls**: Grain Core Agent uses kernel syscalls via compositor:
  - Process management: `spawn`, `exit`, `wait`, `kill`
  - Resource monitoring: `sysinfo`, `get_process_info`, `enumerate_processes`
  - Process priority: `set_priority`, `get_priority`
  - Process groups: `setpgid`, `getpgid`, `setsid`, `getsid`
  - File I/O: `open`, `read`, `write`, `close`, `unlink`, `rename`
  - IPC channels: `channel_create`, `channel_send`, `channel_recv`
  - Input events: `read_input_event` syscall #60
  - Framebuffer operations: `fb_clear`, `fb_draw_pixel`, `fb_draw_text`
  - Kernel logging: `read_kernel_log`
- **Syscall API Design**: Coordination on syscall interface design
- **Feature Priorities**: Coordination on which kernel features to prioritize

**Coordination Notes**:
- Kernel provides syscall interface for userspace
- Grain Core Agent uses syscalls via compositor (not directly)
- Coordination needed on syscall API design and feature priorities

**Recent Coordination**:
- **Phase 3.6 (Enhanced SysInfo)**: Integrated by Grain Core Agent in Phase 52
- **Phase 3.7 (Process Priority)**: Integrated by Grain Core Agent in Phase 57
- **Response Document**: Created `docs/kernel_agent_response_to_grain_os.md` detailing available and planned features

**Recent Coordination**:
- **Network Syscalls**: Integrated by Grain Core Agent (Phase 4 complete)
- **Audio Device Management**: Phase 5.1 complete, ready for Grain Core Agent integration
- **AArch64 Support**: Coordinate on deployment strategy (Phase 6 planned)

---

### With Grain Workspace Agent

**Integration Points**:
- Applications use kernel syscalls via Grain Core compositor
- No direct coordination needed — Grain Core Agent handles kernel integration

---

### With Other Agents

**Integration Points**:
- All agents use kernel syscalls via Grain Core compositor
- Kernel provides foundation for all userspace applications

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md)
- **Master Plan**: [`docs/plan.md`](../plan.md)
- **Grain Core Agent Plan**: [`docs/plans/plan_core.md`](plan_core.md)
- **Vantage Agent Response**: [`docs/kernel_agent_response_to_grain_os.md`](../kernel_agent_response_to_grain_os.md)
- **Grain OS Integration Response**: [`docs/grain_os_kernel_integration_response.md`](../grain_os_kernel_integration_response.md)

---

**Note**: This is a detailed development plan for the Grain Vantage Agent. For high-level overview and cross-agent coordination, see [`docs/plan.md`](../plan.md).

