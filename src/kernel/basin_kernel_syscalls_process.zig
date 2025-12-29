//! Basin Kernel Process Syscalls
//! Why: Process management syscalls (spawn, exit, wait, yield, process groups, signals).
//! Grain Style: Explicit types, static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const ProcessContext = @import("process.zig").ProcessContext;
const Signal = @import("signal.zig").Signal;
const SignalAction = @import("signal.zig").SignalAction;
const elf_parser = @import("elf_parser.zig");
const segment_loader = @import("segment_loader.zig");
const resource_cleanup = @import("resource_cleanup.zig");

// Import types
const types = @import("basin_kernel_types.zig");
const BasinError = types.BasinError;
const SyscallResult = types.SyscallResult;
const Process = types.Process;
const MAX_PROCESSES = types.MAX_PROCESSES;

// Import core
const core = @import("basin_kernel_core.zig");
const BasinKernel = core.BasinKernel;

/// Process syscall handlers for BasinKernel.
/// Why: Extract process management syscalls to separate module for organization.
pub const ProcessSyscalls = struct {
    pub fn syscall_spawn(
        self: *BasinKernel,
        executable: u64,
        args_ptr: u64,
        args_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: executable pointer must be valid (non-zero, within VM memory).
        if (executable == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (executable >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Executable pointer exceeds VM memory
        }
        
        // Assert: executable must be at least ELF header size (64 bytes for ELF64).
        // Why: Minimum size for valid ELF executable header.
        const MIN_ELF_SIZE: u64 = 64;
        if (executable + MIN_ELF_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Executable doesn't fit in VM memory
        }
        
        // Assert: args pointer must be valid (can be zero for no args, or valid pointer).
        if (args_ptr != 0) {
            if (args_ptr >= VM_MEMORY_SIZE) {
                return BasinError.invalid_argument; // Args pointer exceeds VM memory
            }
            
            // Assert: args length must be reasonable (max 64KB).
            if (args_len == 0) {
                return BasinError.invalid_argument; // Zero-length args with non-zero pointer
            }
            if (args_len > 64 * 1024) {
                return BasinError.invalid_argument; // Args too large (> 64KB)
            }
            
            // Assert: args must fit within VM memory.
            if (args_ptr + args_len > VM_MEMORY_SIZE) {
                return BasinError.invalid_argument; // Args exceed VM memory
            }
        } else {
            // Args pointer is zero: args_len must also be zero.
            if (args_len != 0) {
                return BasinError.invalid_argument; // Non-zero args_len with null pointer
            }
        }
        
        // Find free process slot.
        var slot: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (!self.processes[i].allocated) {
                slot = i;
                break;
            }
        }
        
        if (slot == null) {
            return BasinError.out_of_memory; // No free process slots
        }
        
        const idx = slot.?;
        
        // Allocate process ID.
        const process_id = self.next_process_id;
        self.next_process_id += 1;
        
        // Parse ELF header to get entry point and validate executable.
        // Why: Extract entry point for process setup, validate ELF format.
        const ELF_HEADER_SIZE: u32 = 64;
        var elf_header_buffer: [ELF_HEADER_SIZE]u8 = undefined;
        
        // Read ELF header from VM memory (if memory reader is available).
        var entry_point: u64 = 0;
        var executable_len: u64 = MIN_ELF_SIZE;
        
        if (self.vm_memory_reader) |reader| {
            // Read ELF header from VM memory.
            const bytes_read = reader(executable, ELF_HEADER_SIZE, &elf_header_buffer) orelse {
                return BasinError.invalid_argument; // Failed to read ELF header
            };
            
            // Assert: Must read full ELF header.
            if (bytes_read < ELF_HEADER_SIZE) {
                return BasinError.invalid_argument; // Incomplete ELF header
            }
            
            // Parse ELF header to get entry point.
            const elf_info = elf_parser.parse_elf_header(&elf_header_buffer);
            if (!elf_info.valid) {
                return BasinError.invalid_argument; // Invalid ELF format
            }
            
            entry_point = elf_info.entry_point;
            
            // Parse and load program segments (Phase 3.18: Program Segment Loading).
            // Why: Load PT_LOAD segments into VM memory with proper mappings.
            if (elf_info.phnum > 0 and elf_info.phoff > 0 and elf_info.phentsize >= 56) {
                // Read and parse program headers to create memory mappings.
                const MAX_SEGMENTS: u16 = 16; // Reasonable limit for process segments
                const segment_count = @min(elf_info.phnum, MAX_SEGMENTS);
                var segments_loaded: u16 = 0;
                
                var ph_idx: u16 = 0;
                while (ph_idx < segment_count) : (ph_idx += 1) {
                    // Calculate program header offset.
                    const ph_offset = elf_info.phoff + (@as(u64, ph_idx) * @as(u64, elf_info.phentsize));
                    
                    // Read program header (56 bytes for ELF64).
                    const ELF64_PHDR_SIZE: u32 = 56;
                    var phdr_buffer: [ELF64_PHDR_SIZE]u8 = undefined;
                    const phdr_bytes_read = reader(executable + ph_offset, ELF64_PHDR_SIZE, &phdr_buffer) orelse {
                        break; // Failed to read program header, skip remaining
                    };
                    
                    if (phdr_bytes_read < ELF64_PHDR_SIZE) {
                        break; // Incomplete program header, skip remaining
                    }
                    
                    // Parse program header.
                    const segment = elf_parser.parse_program_header(&phdr_buffer);
                    if (!segment.valid) {
                        continue; // Skip invalid segments
                    }
                    
                    // Load program segment (mapping + data loading).
                    // Why: Extract segment loading logic to reduce nesting and function length.
                    if (self.vm_memory_reader) |read_fn| {
                        if (self.vm_memory_writer) |write_fn| {
                            const loaded = segment_loader.load_program_segment(
                                segment,
                                executable,
                                read_fn,
                                write_fn,
                                self,
                            );
                            
                            if (loaded) {
                                segments_loaded += 1;
                            }
                        }
                    }
                }
                
                // Update executable length based on segments loaded.
                // Why: Track actual executable size for better process management.
                if (segments_loaded > 0) {
                    executable_len = MIN_ELF_SIZE; // Minimum, actual size tracked by mappings
                } else {
                    executable_len = MIN_ELF_SIZE; // Fallback to minimum
                }
            } else {
                // No program headers or invalid header info: use minimum size.
                executable_len = MIN_ELF_SIZE;
            }
        } else {
            // No memory reader: use stub entry point (will be set by VM later).
            // Why: Backward compatibility when memory reader is not available.
            entry_point = executable; // Use executable pointer as stub entry point
        }
        
        // Set up stack pointer (default stack location).
        // Why: Process needs stack for execution.
        const DEFAULT_STACK_POINTER: u64 = 0x3ff000; // Near end of 4MB VM memory
        const stack_pointer = DEFAULT_STACK_POINTER;
        
        // Create process context with entry point and stack pointer.
        // Why: Track process execution state (PC, SP, entry point).
        const process_context = ProcessContext.init(entry_point, stack_pointer, entry_point);
        
        // Create process entry.
        self.processes[idx].id = process_id;
        self.processes[idx].state = .running;
        self.processes[idx].exit_status = 0;
        self.processes[idx].executable_ptr = executable;
        self.processes[idx].executable_len = executable_len;
        self.processes[idx].entry_point = entry_point;
        self.processes[idx].stack_pointer = stack_pointer;
        self.processes[idx].context = process_context;
        // Get parent process ID from current process (if any).
        const current_pid = self.scheduler.get_current();
        self.processes[idx].parent_pid = if (current_pid > 0) current_pid else 0;
        
        // Get parent process group ID for limit checking.
        var parent_pgid: u64 = 0;
        if (current_pid > 0) {
            var parent_idx: u32 = 0;
            while (parent_idx < MAX_PROCESSES) : (parent_idx += 1) {
                if (self.processes[parent_idx].allocated and self.processes[parent_idx].id == current_pid) {
                    parent_pgid = self.processes[parent_idx].pgid;
                    break;
                }
            }
        }
        
        // Check process count limit before spawning.
        // Why: Enforce process group resource limits.
        if (parent_pgid != 0) {
            // Count current processes in the group.
            var process_count: u32 = 0;
            var i: u32 = 0;
            while (i < MAX_PROCESSES) : (i += 1) {
                if (self.processes[i].allocated and self.processes[i].pgid == parent_pgid) {
                    process_count += 1;
                }
            }
            
            // Check if spawning would exceed limit.
            if (!self.process_group_limits.can_spawn_process(parent_pgid, process_count)) {
                return BasinError.resource_exhausted; // Process count limit exceeded
            }
        }
        
        // Initialize resource tracking.
        self.processes[idx].cpu_time_ns = 0;
        self.processes[idx].memory_used = executable_len; // Initial memory = executable size
        self.processes[idx].priority = 0; // Default priority (nice value 0)
        self.processes[idx].pgid = parent_pgid; // Inherit parent's process group
        self.processes[idx].allocated = true;
        
        // Set as current running process in scheduler.
        // Set current process with time slice quantum.
        const time_slice = self.processes[idx].time_slice_quantum;
        self.scheduler.set_current(process_id, time_slice);
        
        // Assert: process must be allocated correctly.
        Debug.kassert(self.processes[idx].allocated, "Process not allocated", .{});
        Debug.kassert(self.processes[idx].id == process_id, "Process ID mismatch", .{});
        Debug.kassert(self.processes[idx].state == .running, "Process not running", .{});
        Debug.kassert(self.processes[idx].entry_point != 0, "Entry point is zero", .{});
        Debug.kassert(self.processes[idx].stack_pointer != 0, "Stack pointer is zero", .{});
        Debug.kassert(self.processes[idx].context != null, "Process context is null", .{});
        if (self.processes[idx].context) |ctx| {
            Debug.kassert(ctx.initialized, "Process context not initialized", .{});
            Debug.kassert(ctx.pc == entry_point, "Process PC mismatch", .{});
            Debug.kassert(ctx.sp == stack_pointer, "Process SP mismatch", .{});
        }
        Debug.kassert(self.scheduler.is_current(process_id), "Process not current", .{});
        
        // Return process ID.
        const result = SyscallResult.ok(process_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == process_id, "Result value mismatch", .{});
        
        // Assert: Process ID must be non-zero (valid process ID).
        Debug.kassert(process_id != 0, "Process ID is 0", .{});
        
        return result;
    }
    
    pub fn syscall_exit(
        self: *BasinKernel,
        status: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: status must be valid (0-255 for exit code).
        Debug.kassert(status <= 255, "Exit status > 255", .{});
        const exit_status = @as(u32, @truncate(status));
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == current_process_id) {
                found = i;
                break;
            }
        }
        
        if (found) |idx| {
            const process = &self.processes[idx];
            
            // Update process group statistics.
            // Why: Track exited processes in groups.
            if (process.pgid != 0) {
                self.process_group_stats.increment_exited_count(process.pgid);
                
                // Update process count in group.
                var process_count: u32 = 0;
                var i: u32 = 0;
                while (i < MAX_PROCESSES) : (i += 1) {
                    if (self.processes[i].allocated and self.processes[i].pgid == process.pgid) {
                        process_count += 1;
                    }
                }
                // Decrement count since this process is exiting.
                if (process_count > 0) {
                    process_count -= 1;
                }
                self.process_group_stats.update_process_count(process.pgid, process_count);
            }
            
            // Mark process as exited.
            process.state = .exited;
            process.exit_status = exit_status;
            
            // Clear from scheduler if it's the current process.
            if (self.scheduler.is_current(current_process_id)) {
                self.scheduler.clear_current();
            }
            
            // Clean up process resources (memory mappings, handles, channels).
            // Why: Free resources when process exits to prevent leaks.
            const process_id_u32 = @as(u32, @truncate(current_process_id));
            const resources_cleaned = resource_cleanup.cleanup_process_resources(
                self,
                process_id_u32,
            );
            
            // Assert: process must be marked as exited.
            Debug.kassert(self.processes[idx].state == .exited, "Process not exited", .{});
            Debug.kassert(self.processes[idx].exit_status == exit_status, "Exit status mismatch", .{});
            
            // Assert: Resources cleaned must be reasonable (postcondition).
            const MAX_RESOURCES: u32 = 1000;
            Debug.kassert(resources_cleaned <= MAX_RESOURCES * 3, "Resources cleaned too large", .{});
        }
        
        // Exit syscall: terminate process with status code.
        // Note: In full implementation, we would also:
        // - Wake up any processes waiting on this process
        // - Schedule next process (if any)
        
        // Return status code (VM will handle actual termination).
        return SyscallResult.ok(status);
    }
    
    pub fn syscall_yield(
        self: *BasinKernel,
        _arg1: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Yield syscall: voluntary CPU yield (cooperative scheduling hint).
        // Why: Simple implementation - return success immediately.
        // Note: VM scheduler (if implemented) can use this hint for context switching.
        // For now, just return success (no-op).
        return SyscallResult.ok(0);
    }
    
    pub fn syscall_wait(
        self: *BasinKernel,
        process: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: process ID must be valid (non-zero).
        if (process == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == process) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        
        // Check if process has exited.
        if (self.processes[idx].state == .exited) {
            // Process already exited: return exit status.
            const exit_status: u64 = self.processes[idx].exit_status;
            const result = SyscallResult.ok(exit_status);
            
            // Assert: result must be success (not error).
            Debug.kassert(result == .success, "Result not success", .{});
            Debug.kassert(result.success == exit_status, "Result value mismatch", .{});
            
            // Assert: Exit status must be valid (0-255).
            Debug.kassert(exit_status <= 255, "Exit status > 255", .{});
            
            return result;
        }
        
        // Process is still running: check if we can wait (blocking).
        // Note: In full implementation with preemptive scheduling, we would:
        // - Block current process until target process exits
        // - Wake up when target process calls exit()
        // - Return exit status when process exits
        // For now, with cooperative scheduling, we return error if process still running.
        
        // Check if target process has exited (polling approach for now).
        // In full implementation, this would block and wake up on exit.
        if (self.processes[idx].state == .exited) {
            const exit_status: u64 = self.processes[idx].exit_status;
            const result = SyscallResult.ok(exit_status);
            
            // Assert: result must be success (not error).
            Debug.kassert(result == .success, "Result not success", .{});
            Debug.kassert(result.success == exit_status, "Result value mismatch", .{});
            
            return result;
        }
        
        // Process still running: return error (blocking wait not fully implemented).
        return BasinError.would_block; // Process still running (would block)
    }
    
    pub fn syscall_setpgid(
        self: *BasinKernel,
        pid: u64,
        pgid: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Assert: Process group ID must be valid (non-zero).
        if (pgid == 0) {
            return BasinError.invalid_argument; // Invalid process group ID
        }
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        
        // Set process group ID.
        // Why: Assign process to a process group.
        self.processes[idx].pgid = pgid;
        
        // Update process group statistics.
        // Why: Track process count in groups.
        var process_count: u32 = 0;
        var i: u32 = 0;
        while (i < MAX_PROCESSES) : (i += 1) {
            if (self.processes[i].allocated and self.processes[i].pgid == pgid) {
                process_count += 1;
            }
        }
        self.process_group_stats.update_process_count(pgid, process_count);
        
        // Return success.
        return SyscallResult.ok(0);
    }
    
    pub fn syscall_getpgid(
        self: *BasinKernel,
        pid: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        
        // Get process group ID.
        // Why: Return process group ID for userspace queries.
        const pgid = self.processes[idx].pgid;
        
        // Return process group ID.
        return SyscallResult.ok(pgid);
    }
    
    pub fn syscall_setsid(
        self: *BasinKernel,
        _arg1: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Get current process ID.
        const current_pid = self.scheduler.get_current();
        if (current_pid == 0) {
            return BasinError.invalid_argument; // No current process
        }
        
        // Create new session.
        // Why: Create a new session for the current process.
        const sid = self.process_group_manager.create_session(current_pid);
        if (sid == 0) {
            return BasinError.resource_exhausted; // No free session slot
        }
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        
        // Set session ID for current process.
        // Why: Assign process to the new session.
        self.processes[idx].sid = sid;
        
        // Create a new process group in the session.
        // Why: Process becomes leader of both session and group.
        const pgid = self.process_group_manager.create_group(
            current_pid,
            sid,
            &self.processes,
            MAX_PROCESSES,
        );
        if (pgid == 0) {
            return BasinError.resource_exhausted; // No free group slot
        }
        
        // Return session ID.
        return SyscallResult.ok(sid);
    }
    
    pub fn syscall_getsid(
        self: *BasinKernel,
        pid: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Find process in process table.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        
        // Get session ID.
        // Why: Return session ID for userspace queries.
        const sid = self.processes[idx].sid;
        
        // Return session ID.
        return SyscallResult.ok(sid);
    }
    
    pub fn syscall_kill(
        self: *BasinKernel,
        pid: u64,
        signal_num: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Signal number must be valid (< 32).
        if (signal_num >= 32) {
            return BasinError.invalid_argument;
        }
        
        // Convert signal number to Signal enum.
        const signal = @as(Signal, @enumFromInt(@as(u32, @truncate(signal_num))));
        
        // Check if PID indicates process group or session delivery.
        // Why: POSIX allows negative PIDs to send signals to process groups/sessions.
        // Note: We use bit flags to indicate delivery target:
        // - Bit 63 (0x8000000000000000): Process group delivery
        // - Bit 62 (0x4000000000000000): Session delivery
        // - Both bits clear: Single process delivery
        const is_process_group = (pid & 0x8000000000000000) != 0;
        const is_session = (pid & 0x4000000000000000) != 0;
        
        if (is_process_group) {
            // Process group delivery: send signal to all processes in the process group.
            // Extract process group ID by clearing the sign bit.
            const pgid = pid & 0x7FFFFFFFFFFFFFFF;
            if (pgid == 0) {
                return BasinError.invalid_argument; // Invalid process group ID
            }
            return ProcessSyscalls.kill_process_group(self, pgid, signal);
        }
        
        if (is_session) {
            // Session delivery: send signal to all processes in the session.
            // Extract session ID by clearing the session bit (bit 62).
            const sid = pid & 0x3FFFFFFFFFFFFFFF;
            if (sid == 0) {
                return BasinError.invalid_argument; // Invalid session ID
            }
            return ProcessSyscalls.kill_session(self, sid, signal);
        }
        
        // Assert: PID must be valid (non-zero) for single process.
        if (pid == 0) {
            return BasinError.invalid_argument;
        }
        
        // Positive PID: send signal to single process (existing behavior).
        // Find process by PID.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found; // Process not found
        }
        
        const idx = found.?;
        const process = &self.processes[idx];
        
        // Send signal to process.
        process.signals.send_signal(signal);
        
        // SIGKILL immediately terminates process.
        if (signal == .sigkill) {
            process.state = .exited;
            process.exit_status = 128 + @intFromEnum(signal); // Exit code = 128 + signal
            self.scheduler.clear_current(); // Clear current process
        }
        
        // Assert: Signal must be sent (postcondition).
        Debug.kassert(process.signals.is_pending(signal) or signal == .sigkill, "Signal not sent", .{});
        
        return SyscallResult.ok(0);
    }
    
    /// Send signal to all processes in a process group.
    /// Why: Support POSIX signal delivery to process groups.
    /// Contract: pgid must be valid (non-zero), signal must be valid.
    pub fn kill_process_group(
        self: *BasinKernel,
        pgid: u64,
        signal: Signal,
    ) BasinError!SyscallResult {
        // Assert: Process group ID must be valid (non-zero).
        if (pgid == 0) {
            return BasinError.invalid_argument; // Invalid process group ID
        }
        
        // Find all processes in the process group.
        var processes_found: u32 = 0;
        var process_indices: [MAX_PROCESSES]usize = undefined;
        
        var idx: u32 = 0;
        while (idx < MAX_PROCESSES) : (idx += 1) {
            if (self.processes[idx].allocated and self.processes[idx].pgid == pgid) {
                process_indices[processes_found] = idx;
                processes_found += 1;
            }
        }
        
        // If no processes found in group, return error.
        if (processes_found == 0) {
            return BasinError.not_found; // Process group not found or empty
        }
        
        // Send signal to all processes in the group.
        var i: u32 = 0;
        while (i < processes_found) : (i += 1) {
            const process_idx = process_indices[i];
            const process = &self.processes[process_idx];
            
            // Send signal to process.
            process.signals.send_signal(signal);
            
            // SIGKILL immediately terminates process.
            if (signal == .sigkill) {
                process.state = .exited;
                process.exit_status = 128 + @intFromEnum(signal); // Exit code = 128 + signal
                
                // Clear current process if it's the one being killed.
                if (self.scheduler.get_current() == process.id) {
                    self.scheduler.clear_current();
                }
            }
        }
        
        // Return success (number of processes signaled).
        return SyscallResult.ok(processes_found);
    }
    
    /// Send signal to all processes in a session.
    /// Why: Support POSIX signal delivery to sessions.
    /// Contract: sid must be valid (non-zero), signal must be valid.
    pub fn kill_session(
        self: *BasinKernel,
        sid: u64,
        signal: Signal,
    ) BasinError!SyscallResult {
        // Assert: Session ID must be valid (non-zero).
        if (sid == 0) {
            return BasinError.invalid_argument; // Invalid session ID
        }
        
        // Find all processes in the session.
        var processes_found: u32 = 0;
        var process_indices: [MAX_PROCESSES]usize = undefined;
        
        var idx: u32 = 0;
        while (idx < MAX_PROCESSES) : (idx += 1) {
            if (self.processes[idx].allocated and self.processes[idx].sid == sid) {
                process_indices[processes_found] = idx;
                processes_found += 1;
            }
        }
        
        // If no processes found in session, return error.
        if (processes_found == 0) {
            return BasinError.not_found; // Session not found or empty
        }
        
        // Send signal to all processes in the session.
        var i: u32 = 0;
        while (i < processes_found) : (i += 1) {
            const process_idx = process_indices[i];
            const process = &self.processes[process_idx];
            
            // Send signal to process.
            process.signals.send_signal(signal);
            
            // SIGKILL immediately terminates process.
            if (signal == .sigkill) {
                process.state = .exited;
                process.exit_status = 128 + @intFromEnum(signal); // Exit code = 128 + signal
                
                // Clear current process if it's the one being killed.
                if (self.scheduler.get_current() == process.id) {
                    self.scheduler.clear_current();
                }
            }
        }
        
        // Return success (number of processes signaled).
        return SyscallResult.ok(processes_found);
    }
    
    pub fn syscall_signal(
        self: *BasinKernel,
        signal_num: u64,
        _handler_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _handler_ptr;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Signal number must be valid (< 32).
        if (signal_num >= 32) {
            return BasinError.invalid_argument;
        }
        
        // Get current process.
        const current_pid = self.scheduler.get_current();
        if (current_pid == 0) {
            return BasinError.invalid_user; // No current process
        }
        
        // Find current process.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found;
        }
        
        const process = &self.processes[found.?];
        const signal = @as(Signal, @enumFromInt(@as(u32, @truncate(signal_num))));
        
        // Create signal action (handler_ptr is function pointer, ignored for now).
        const action = SignalAction{
            .handler = null, // Stub: handler registration requires function pointer translation
            .context = null,
            .mask = 0,
            .flags = 0,
        };
        
        process.signals.register_handler(signal, action);
        
        // Assert: Handler must be registered (postcondition).
        Debug.kassert(process.signals.actions[@intFromEnum(signal)].handler == action.handler, "Handler not registered", .{});
        
        return SyscallResult.ok(0);
    }
    
    pub fn syscall_sigaction(
        self: *BasinKernel,
        signal_num: u64,
        action_ptr: u64,
        old_action_ptr: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Signal number must be valid (< 32).
        if (signal_num >= 32) {
            return BasinError.invalid_argument;
        }
        
        // Get current process.
        const current_pid = self.scheduler.get_current();
        if (current_pid == 0) {
            return BasinError.invalid_user;
        }
        
        // Find current process.
        var found: ?usize = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return BasinError.not_found;
        }
        
        const process = &self.processes[found.?];
        const signal = @as(Signal, @enumFromInt(@as(u32, @truncate(signal_num))));
        
        // Save old action if old_action_ptr is non-zero (stub: would read from VM memory).
        _ = old_action_ptr;
        
        // Set new action if action_ptr is non-zero (stub: would read from VM memory).
        if (action_ptr != 0) {
            const action = SignalAction{
                .handler = null, // Stub: requires function pointer translation
                .context = null,
                .mask = 0,
                .flags = 0,
            };
            process.signals.register_handler(signal, action);
        }
        
        return SyscallResult.ok(0);
    }
};
