//! Grain Basin kernel — The foundation that holds everything
//!
//! Grain Basin kernel is a Zig monolith kernel for RISC-V64, designed for the next 30 years.
//! Non-POSIX, type-safe, minimal syscall surface, Grain Style safety.
//!
//! **Homebrew Bundle**: `grainbasin`
//!
//! **Vision**: Modern kernel design inspired by seL4 (minimal), Aero OS (monolithic),
//! and Fuchsia (capability-based), but built in pure Zig for RISC-V.
//!
//! **Note**: Theseus OS uses SAS/SPL architecture (not traditional monolithic).
//! Aero OS proves monolithic kernels work (runs real apps), but targets x86_64 only.
//! Grain Basin kernel fills the gap: RISC-V native, non-POSIX, minimal syscall surface.
//!
//! **Target**: Framework 13 DeepComputing RISC-V Mainboard
//! **Development**: macOS Tahoe IDE with RISC-V VM for testing

const std = @import("std");
const Debug = @import("debug.zig");
const Timer = @import("timer.zig").Timer;
const InterruptController = @import("interrupt.zig").InterruptController;
const Scheduler = @import("scheduler.zig").Scheduler;
const ChannelTable = @import("channel.zig").ChannelTable;
const ProcessContext = @import("process.zig").ProcessContext;
const Storage = @import("storage.zig").Storage;
const Keyboard = @import("keyboard.zig").Keyboard;
const Mouse = @import("mouse.zig").Mouse;
const MemoryPool = @import("memory.zig").MemoryPool;
const SignalTable = @import("signal.zig").SignalTable;
const Signal = @import("signal.zig").Signal;
const SignalAction = @import("signal.zig").SignalAction;
const elf_parser = @import("elf_parser.zig");
const segment_loader = @import("segment_loader.zig");
const page_table = @import("page_table.zig");
const PageTable = page_table.PageTable;
const page_fault_stats = @import("page_fault_stats.zig");
const PageFaultStats = page_fault_stats.PageFaultStats;
const memory_stats = @import("memory_stats.zig");
const MemoryStats = memory_stats.MemoryStats;
const cow = @import("cow.zig");
const CowTable = cow.CowTable;
const resource_cleanup = @import("resource_cleanup.zig");
const KernelLogBuffer = @import("kernel_log_buffer.zig").KernelLogBuffer;
const KernelLogEntry = @import("kernel_log_buffer.zig").KernelLogEntry;
const KernelLogLevel = @import("kernel_log_buffer.zig").KernelLogLevel;
const scheduler_stats = @import("scheduler_stats.zig");
const process_group = @import("process_group.zig");
const ProcessGroupManager = process_group.ProcessGroupManager;
const process_group_stats = @import("process_group_stats.zig");
const ProcessGroupStatsManager = process_group_stats.ProcessGroupStatsManager;
const process_group_limits = @import("process_group_limits.zig");
const ProcessGroupLimitsManager = process_group_limits.ProcessGroupLimitsManager;
const network = @import("network.zig");
const NetworkInterfaceManager = network.NetworkInterfaceManager;
const tcp_socket = @import("tcp_socket.zig");
const TcpSocketManager = tcp_socket.TcpSocketManager;
const udp_socket = @import("udp_socket.zig");
const UdpSocketManager = udp_socket.UdpSocketManager;
const audio = @import("audio.zig");
const AudioDeviceManager = audio.AudioDeviceManager;
const kernel_stats_aggregator = @import("kernel_stats_aggregator.zig");
const KernelStatsSnapshot = kernel_stats_aggregator.KernelStatsSnapshot;

// Import types from separate module
const types = @import("basin_kernel_types.zig");

// Import core BasinKernel struct and helpers
const core = @import("basin_kernel_core.zig");

// Import process syscalls
const process_syscalls = @import("basin_kernel_syscalls_process.zig");
const ProcessSyscalls = process_syscalls.ProcessSyscalls;

// Import file syscalls
const file_syscalls = @import("basin_kernel_syscalls_file.zig");
const FileSyscalls = file_syscalls.FileSyscalls;

// Import network syscalls
const network_syscalls = @import("basin_kernel_syscalls_network.zig");
const NetworkSyscalls = network_syscalls.NetworkSyscalls;

// Import audio syscalls
const audio_syscalls = @import("basin_kernel_syscalls_audio.zig");
const AudioSyscalls = audio_syscalls.AudioSyscalls;

// Import stats syscalls
const stats_syscalls = @import("basin_kernel_syscalls_stats.zig");
const StatsSyscalls = stats_syscalls.StatsSyscalls;

// Re-export all public types for backward compatibility
pub const Syscall = types.Syscall;
pub const MapFlags = types.MapFlags;
pub const OpenFlags = types.OpenFlags;
pub const ClockId = types.ClockId;
pub const Handle = types.Handle;
pub const SysInfo = types.SysInfo;
pub const ProcessInfo = types.ProcessInfo;
pub const ResourceUsage = types.ResourceUsage;
pub const UserId = types.UserId;
pub const GroupId = types.GroupId;
pub const User = types.User;
pub const UserContext = types.UserContext;
pub const BasinError = types.BasinError;
pub const SyscallResult = types.SyscallResult;
pub const ProcessState = types.ProcessState;
pub const Process = types.Process;

// Re-export internal types used by BasinKernel
const MemoryMapping = types.MemoryMapping;
const FileHandle = types.FileHandle;
const DirectoryHandle = types.DirectoryHandle;

// Re-export constants
const MAX_MAPPINGS = types.MAX_MAPPINGS;
const MAX_HANDLES = types.MAX_HANDLES;
const MAX_DIR_HANDLES = types.MAX_DIR_HANDLES;
const MAX_PROCESSES = types.MAX_PROCESSES;
const MAX_USERS = types.MAX_USERS;

// Export resource_cleanup for tests.
pub const resource_cleanup_module = resource_cleanup;

// Export RawIO for tests to disable hardware access.
pub const RawIO = @import("raw_io.zig");

// Compile-time assertions for handle table size.
comptime {
    std.debug.assert(MAX_HANDLES > 0);
    std.debug.assert(MAX_HANDLES <= 0xFFFFFFFF);
    std.debug.assert(MAX_HANDLES < 0xFFFFFFFF);
}

// Re-export BasinKernel from core module
pub const BasinKernel = core.BasinKernel;

/// Handle syscall from user space.
/// Why: Central syscall entry point, validate syscall number and arguments.
/// Grain Style: Comprehensive assertions for all syscall parameters and state.
pub fn handle_syscall(
    self: *BasinKernel,
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) BasinError!SyscallResult {
    // Assert: self pointer must be valid.
    const self_ptr = @intFromPtr(self);
    Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
    Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
    
    // Assert: syscall number must be >= 10 (kernel syscalls, not SBI).
    // Why: SBI calls use function ID < 10, kernel syscalls use >= 10.
    Debug.kassert(syscall_num >= 10, "Syscall num {d} < 10", .{syscall_num});
    
    // Assert: syscall number must be within valid range.
    Debug.kassert(syscall_num <= @intFromEnum(Syscall.getsid), "Syscall num {d} too high", .{syscall_num});
    
    // Decode syscall number.
    const syscall = @as(?Syscall, @enumFromInt(syscall_num)) orelse {
        // Assert: Invalid syscall number must return error.
        Debug.kassert(syscall_num < 10 or syscall_num > @intFromEnum(Syscall.getsid), "Invalid syscall logic", .{});
        return BasinError.invalid_syscall;
    };
    
    // Assert: syscall must be valid enum value.
    Debug.kassert(@intFromEnum(syscall) == syscall_num, "Syscall enum mismatch", .{});
    
    // Assert: syscall must be kernel syscall (not SBI).
    Debug.kassert(@intFromEnum(syscall) >= 10, "Syscall enum < 10", .{});
    
    // Profile syscall execution time (if profiling enabled).
    // Why: Track performance metrics for optimization.
    const start_time_ns = if (self.syscall_profiler.enabled)
        self.timer.get_monotonic_ns()
    else
        0;
    
    // Route to appropriate syscall handler.
    // Why: Explicit routing, type-safe syscall handling.
    const result = switch (syscall) {
            .spawn => ProcessSyscalls.syscall_spawn(self, arg1, arg2, arg3, arg4),
            .exit => ProcessSyscalls.syscall_exit(self, arg1, arg2, arg3, arg4),
            .yield => ProcessSyscalls.syscall_yield(self, arg1, arg2, arg3, arg4),
            .wait => ProcessSyscalls.syscall_wait(self, arg1, arg2, arg3, arg4),
            .map => self.syscall_map(arg1, arg2, arg3, arg4),
            .unmap => self.syscall_unmap(arg1, arg2, arg3, arg4),
            .protect => self.syscall_protect(arg1, arg2, arg3, arg4),
            .channel_create => self.syscall_channel_create(arg1, arg2, arg3, arg4),
            .channel_send => self.syscall_channel_send(arg1, arg2, arg3, arg4),
            .channel_recv => self.syscall_channel_recv(arg1, arg2, arg3, arg4),
            .open => FileSyscalls.syscall_open(self, arg1, arg2, arg3, arg4),
            .read => FileSyscalls.syscall_read(self, arg1, arg2, arg3, arg4),
            .write => FileSyscalls.syscall_write(self, arg1, arg2, arg3, arg4),
            .close => FileSyscalls.syscall_close(self, arg1, arg2, arg3, arg4),
            .unlink => FileSyscalls.syscall_unlink(self, arg1, arg2, arg3, arg4),
            .rename => FileSyscalls.syscall_rename(self, arg1, arg2, arg3, arg4),
            .mkdir => FileSyscalls.syscall_mkdir(self, arg1, arg2, arg3, arg4),
            .opendir => FileSyscalls.syscall_opendir(self, arg1, arg2, arg3, arg4),
            .readdir => FileSyscalls.syscall_readdir(self, arg1, arg2, arg3, arg4),
            .closedir => FileSyscalls.syscall_closedir(self, arg1, arg2, arg3, arg4),
            .clock_gettime => self.syscall_clock_gettime(arg1, arg2, arg3, arg4),
            .sleep_until => self.syscall_sleep_until(arg1, arg2, arg3, arg4),
            .sysinfo => self.syscall_sysinfo(arg1, arg2, arg3, arg4),
            .enumerate_processes => self.syscall_enumerate_processes(arg1, arg2, arg3, arg4),
            .get_process_info => self.syscall_get_process_info(arg1, arg2, arg3, arg4),
            .read_kernel_log => self.syscall_read_kernel_log(arg1, arg2, arg3, arg4),
            .set_priority => self.syscall_set_priority(arg1, arg2, arg3, arg4),
            .get_priority => self.syscall_get_priority(arg1, arg2, arg3, arg4),
            .setpgid => ProcessSyscalls.syscall_setpgid(self, arg1, arg2, arg3, arg4),
            .getpgid => ProcessSyscalls.syscall_getpgid(self, arg1, arg2, arg3, arg4),
            .setsid => ProcessSyscalls.syscall_setsid(self, arg1, arg2, arg3, arg4),
            .getsid => ProcessSyscalls.syscall_getsid(self, arg1, arg2, arg3, arg4),
            .read_input_event => self.syscall_read_input_event(arg1, arg2, arg3, arg4),
            .fb_clear => self.syscall_fb_clear(arg1, arg2, arg3, arg4),
            .fb_draw_pixel => self.syscall_fb_draw_pixel(arg1, arg2, arg3, arg4),
            .fb_draw_text => self.syscall_fb_draw_text(arg1, arg2, arg3, arg4),
            .kill => ProcessSyscalls.syscall_kill(self, arg1, arg2, arg3, arg4),
            .signal => ProcessSyscalls.syscall_signal(self, arg1, arg2, arg3, arg4),
            .sigaction => ProcessSyscalls.syscall_sigaction(self, arg1, arg2, arg3, arg4),
            .network_create_interface => NetworkSyscalls.syscall_network_create_interface(self, arg1, arg2, arg3, arg4),
            .network_set_state => NetworkSyscalls.syscall_network_set_state(self, arg1, arg2, arg3, arg4),
            .network_set_ipv4 => NetworkSyscalls.syscall_network_set_ipv4(self, arg1, arg2, arg3, arg4),
            .network_set_ipv6 => NetworkSyscalls.syscall_network_set_ipv6(self, arg1, arg2, arg3, arg4),
            .network_get_interface => NetworkSyscalls.syscall_network_get_interface(self, arg1, arg2, arg3, arg4),
            .network_delete_interface => NetworkSyscalls.syscall_network_delete_interface(self, arg1, arg2, arg3, arg4),
            .network_enumerate_interfaces => NetworkSyscalls.syscall_network_enumerate_interfaces(self, arg1, arg2, arg3, arg4),
            .network_get_stats => NetworkSyscalls.syscall_network_get_stats(self, arg1, arg2, arg3, arg4),
            .tcp_socket => NetworkSyscalls.syscall_tcp_socket(self, arg1, arg2, arg3, arg4),
            .tcp_bind => NetworkSyscalls.syscall_tcp_bind(self, arg1, arg2, arg3, arg4),
            .tcp_listen => NetworkSyscalls.syscall_tcp_listen(self, arg1, arg2, arg3, arg4),
            .tcp_accept => NetworkSyscalls.syscall_tcp_accept(self, arg1, arg2, arg3, arg4),
            .tcp_connect => NetworkSyscalls.syscall_tcp_connect(self, arg1, arg2, arg3, arg4),
            .tcp_send => NetworkSyscalls.syscall_tcp_send(self, arg1, arg2, arg3, arg4),
            .tcp_recv => NetworkSyscalls.syscall_tcp_recv(self, arg1, arg2, arg3, arg4),
            .tcp_close => NetworkSyscalls.syscall_tcp_close(self, arg1, arg2, arg3, arg4),
            .tcp_enumerate_sockets => NetworkSyscalls.syscall_tcp_enumerate_sockets(self, arg1, arg2, arg3, arg4),
            .tcp_get_stats => NetworkSyscalls.syscall_tcp_get_stats(self, arg1, arg2, arg3, arg4),
            .udp_socket => NetworkSyscalls.syscall_udp_socket(self, arg1, arg2, arg3, arg4),
            .udp_bind => NetworkSyscalls.syscall_udp_bind(self, arg1, arg2, arg3, arg4),
            .udp_sendto => NetworkSyscalls.syscall_udp_sendto(self, arg1, arg2, arg3, arg4),
            .udp_recvfrom => NetworkSyscalls.syscall_udp_recvfrom(self, arg1, arg2, arg3, arg4),
            .udp_close => NetworkSyscalls.syscall_udp_close(self, arg1, arg2, arg3, arg4),
            .udp_enumerate_sockets => NetworkSyscalls.syscall_udp_enumerate_sockets(self, arg1, arg2, arg3, arg4),
            .udp_get_stats => NetworkSyscalls.syscall_udp_get_stats(self, arg1, arg2, arg3, arg4),
            .udp_sendto_with_timeout => NetworkSyscalls.syscall_udp_sendto_with_timeout(self, arg1, arg2, arg3, arg4),
            .udp_recvfrom_with_timeout => NetworkSyscalls.syscall_udp_recvfrom_with_timeout(self, arg1, arg2, arg3, arg4),
            .audio_create_device => AudioSyscalls.syscall_audio_create_device(self, arg1, arg2, arg3, arg4),
            .audio_set_volume => AudioSyscalls.syscall_audio_set_volume(self, arg1, arg2, arg3, arg4),
            .audio_set_mute => AudioSyscalls.syscall_audio_set_mute(self, arg1, arg2, arg3, arg4),
            .audio_set_state => AudioSyscalls.syscall_audio_set_state(self, arg1, arg2, arg3, arg4),
            .audio_set_active_output => AudioSyscalls.syscall_audio_set_active_output(self, arg1, arg2, arg3, arg4),
            .audio_set_active_input => AudioSyscalls.syscall_audio_set_active_input(self, arg1, arg2, arg3, arg4),
            .audio_set_master_volume => AudioSyscalls.syscall_audio_set_master_volume(self, arg1, arg2, arg3, arg4),
            .audio_set_master_mute => AudioSyscalls.syscall_audio_set_master_mute(self, arg1, arg2, arg3, arg4),
            .audio_get_device => AudioSyscalls.syscall_audio_get_device(self, arg1, arg2, arg3, arg4),
            .audio_set_format => AudioSyscalls.syscall_audio_set_format(self, arg1, arg2, arg3, arg4),
            .audio_read => AudioSyscalls.syscall_audio_read(self, arg1, arg2, arg3, arg4),
            .audio_write => AudioSyscalls.syscall_audio_write(self, arg1, arg2, arg3, arg4),
            .audio_enumerate_devices => AudioSyscalls.syscall_audio_enumerate_devices(self, arg1, arg2, arg3, arg4),
            .audio_delete_device => AudioSyscalls.syscall_audio_delete_device(self, arg1, arg2, arg3, arg4),
            .audio_get_stats => AudioSyscalls.syscall_audio_get_stats(self, arg1, arg2, arg3, arg4),
            .kernel_get_stats => StatsSyscalls.syscall_kernel_get_stats(self, arg1, arg2, arg3, arg4),
            .health_check => StatsSyscalls.syscall_health_check(self, arg1, arg2, arg3, arg4),
            .get_resource_usage => StatsSyscalls.syscall_get_resource_usage(self, arg1, arg2, arg3, arg4),
            .set_resource_limit => StatsSyscalls.syscall_set_resource_limit(self, arg1, arg2, arg3, arg4),
        };
    
    // Record syscall execution time (if profiling enabled).
    // Why: Track performance metrics for optimization.
    if (self.syscall_profiler.enabled and start_time_ns > 0) {
        const end_time_ns = self.timer.get_monotonic_ns();
        const execution_time_ns = if (end_time_ns >= start_time_ns)
            end_time_ns - start_time_ns
        else
            1; // Handle clock rollback (shouldn't happen, but safe)
        
        // Assert: Execution time must be valid.
        Debug.kassert(execution_time_ns > 0, "Execution time is zero", .{});
        
        self.syscall_profiler.record_syscall(syscall_num, execution_time_ns);
    }
    
    return result;
    }
    
    // Syscall handlers (stubs for future implementation).
    // Why: Separate functions for each syscall, Grain Style function length limit.
    
    pub fn syscall_map(
        self: *BasinKernel,
        addr: u64,
        size: u64,
        flags: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: size must be non-zero and page-aligned.
        if (size == 0) {
            return BasinError.invalid_argument;
        }
        if (size % 4096 != 0) {
            return BasinError.unaligned_access;
        }
        
        // Assert: size must be reasonable (max 1GB per mapping, fits in VM memory).
        // VM memory size (matches VM_MEMORY_SIZE from kernel_vm).
        // Why: Consistent memory limits across VM and kernel syscall validation.
        // Note: Default 4MB, configurable via VM_MEMORY_SIZE constant.
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (safe for 8GB target)
        if (size > 1024 * 1024 * 1024) {
            return BasinError.invalid_argument; // Too large (> 1GB)
        }
        if (size > VM_MEMORY_SIZE) {
            return BasinError.out_of_memory; // Larger than VM memory
        }
        
        // Decode flags (MapFlags packed struct).
        const map_flags = @as(MapFlags, @bitCast(@as(u32, @truncate(flags))));
        
        // Assert: flags must be valid (at least one permission).
        if (!map_flags.read and !map_flags.write and !map_flags.execute) {
            return BasinError.invalid_argument; // No permissions set
        }
        
        // Assert: flags padding must be zero (no reserved bits set).
        if (map_flags._padding != 0) {
            return BasinError.invalid_argument; // Reserved bits set
        }
        
        // Determine mapping address.
        var mapping_addr: u64 = addr;
        
        // If addr is zero, kernel chooses address (simple allocator: start from user space).
        // Why: Simple implementation - allocate from user space region.
        const KERNEL_SPACE_END: u64 = 0x100000; // 1MB kernel space (typical)
        const USER_SPACE_START: u64 = KERNEL_SPACE_END; // User space starts after kernel
        
        if (mapping_addr == 0) {
            // Kernel chooses: allocate from next allocation address.
            // Why: Use simple allocator that tracks next free address.
            mapping_addr = self.next_alloc_addr;
            
            // Assert: Kernel-chosen address must be page-aligned.
            Debug.kassert(mapping_addr % 4096 == 0, "Kernel addr unaligned", .{});
            
            // Assert: Kernel-chosen address must fit in VM memory.
            if (mapping_addr + size > VM_MEMORY_SIZE) {
                return BasinError.out_of_memory; // No space for kernel-chosen address
            }
        } else {
            // User-provided address: validate alignment and range.
            if (mapping_addr % 4096 != 0) {
                return BasinError.unaligned_access;
            }
            
            // Assert: Address must be in user space (not kernel space).
            if (mapping_addr < USER_SPACE_START) {
                return BasinError.permission_denied; // Attempting to map in kernel space
            }
        }
        
        // Assert: Mapping must fit within VM memory.
        if (mapping_addr + size > VM_MEMORY_SIZE) {
            return BasinError.out_of_memory; // Mapping exceeds VM memory
        }
        
        // Assert: Mapping must not overlap kernel space.
        if (mapping_addr < KERNEL_SPACE_END) {
            return BasinError.permission_denied; // Overlaps kernel space
        }
        
        // Check if mapping overlaps with existing mappings.
        if (self.check_overlap(mapping_addr, size)) {
            return BasinError.invalid_argument; // Overlapping mapping
        }
        
        // Check memory limit for current process group.
        // Why: Enforce process group resource limits.
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            var process_idx: u32 = 0;
            var process_pgid: u64 = 0;
            while (process_idx < MAX_PROCESSES) : (process_idx += 1) {
                if (self.processes[process_idx].allocated and self.processes[process_idx].id == current_pid) {
                    process_pgid = self.processes[process_idx].pgid;
                    break;
                }
            }
            
            if (process_pgid != 0) {
                // Get current memory usage for the process group.
                var group_memory: u64 = 0;
                var i: u32 = 0;
                while (i < MAX_PROCESSES) : (i += 1) {
                    if (self.processes[i].allocated and self.processes[i].pgid == process_pgid) {
                        group_memory = group_memory +% self.processes[i].memory_used; // Saturating add
                    }
                }
                
                // Check if allocating this memory would exceed limit.
                if (!self.process_group_limits.can_allocate_memory(process_pgid, group_memory, size)) {
                    return BasinError.resource_exhausted; // Memory limit exceeded
                }
            }
        }
        
        // Find free mapping entry.
        const mapping_idx = self.find_free_mapping() orelse {
            return BasinError.out_of_memory; // Mapping table full
        };
        
        // Get current process ID from scheduler.
        // Why: Track which process owns this mapping for resource cleanup.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Allocate mapping entry.
        var mapping = &self.mappings[mapping_idx];
        mapping.address = mapping_addr;
        mapping.size = size;
        mapping.flags = map_flags;
        mapping.allocated = true;
        mapping.owner_process_id = owner_process_id;
        
        // Update page table (map pages with permissions).
        // Convert MapFlags to PageFlags (same structure).
        const page_flags = page_table.PageFlags{
            .read = map_flags.read,
            .write = map_flags.write,
            .execute = map_flags.execute,
            .shared = map_flags.shared,
            ._padding = 0,
        };
        self.page_table.map_pages(mapping_addr, size, page_flags);
        
        // Update memory statistics.
        self.memory_stats.update_from_page_table(@ptrCast(&self.page_table), VM_MEMORY_SIZE);
        self.memory_stats.update_mapping_count(self.count_allocated_mappings());
        
        // Update process memory usage.
        // Why: Track memory used by process for resource monitoring.
        if (owner_process_id > 0) {
            const owner_process_id_u64 = @as(u64, owner_process_id);
            self.update_process_memory_usage(owner_process_id_u64);
        }
        
        // Assert: Mapping entry must be allocated correctly.
        Debug.kassert(mapping.allocated, "Mapping not allocated", .{});
        Debug.kassert(mapping.address == mapping_addr, "Mapping addr mismatch", .{});
        Debug.kassert(mapping.size == size, "Mapping size mismatch", .{});
        
        // Update next allocation address (for kernel-chosen addresses).
        if (addr == 0) {
            // Kernel-chosen: advance next allocation address.
            self.next_alloc_addr = mapping_addr + size;
            
            // Assert: Next allocation address must be page-aligned.
            Debug.kassert(self.next_alloc_addr % 4096 == 0, "Next alloc addr unaligned", .{});
        }
        
        const result = SyscallResult.ok(mapping_addr);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == mapping_addr, "Result value mismatch", .{});
        
        // Assert: Returned address must be valid.
        Debug.kassert(result.success >= USER_SPACE_START, "Addr in kernel space", .{});
        Debug.kassert(result.success + size <= VM_MEMORY_SIZE, "Addr exceeds VM mem", .{});
        Debug.kassert(result.success % 4096 == 0, "Addr unaligned", .{});
        
        return result;
    }
    
    fn syscall_unmap(
        self: *BasinKernel,
        region: u64,
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
        
        // Assert: region address must be page-aligned (4KB pages).
        if (region % 4096 != 0) {
            return BasinError.unaligned_access;
        }
        
        // Assert: region address must be in user space (not kernel space).
        const KERNEL_SPACE_END: u64 = 0x100000; // 1MB kernel space (matches syscall_map)
        const USER_SPACE_START: u64 = KERNEL_SPACE_END;
        
        if (region < USER_SPACE_START) {
            return BasinError.permission_denied; // Attempting to unmap kernel space
        }
        
        // Assert: region address must be within VM memory bounds.
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (region >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Region address exceeds VM memory
        }
        
        // Find mapping by address.
        const mapping_idx = self.find_mapping_by_address(region) orelse {
            return BasinError.invalid_argument; // Mapping not found
        };
        
        // Assert: Mapping must be allocated.
        Debug.kassert(self.mappings[mapping_idx].allocated, "Mapping not allocated", .{});
        Debug.kassert(self.mappings[mapping_idx].address == region, "Mapping addr mismatch", .{});
        
        // Free mapping entry.
        var mapping = &self.mappings[mapping_idx];
        const mapping_size = mapping.size;
        const owner_process_id = mapping.owner_process_id;
        mapping.allocated = false;
        mapping.address = 0;
        mapping.size = 0;
        mapping.owner_process_id = 0;
        mapping.flags = MapFlags.init(.{});
        
        // Update page table (unmap pages).
        self.page_table.unmap_pages(region, mapping_size);
        
        // Update memory statistics.
        self.memory_stats.update_from_page_table(@ptrCast(&self.page_table), VM_MEMORY_SIZE);
        self.memory_stats.update_mapping_count(self.count_allocated_mappings());
        
        // Update process memory usage.
        // Why: Track memory used by process for resource monitoring.
        if (owner_process_id > 0) {
            const owner_process_id_u64 = @as(u64, owner_process_id);
            self.update_process_memory_usage(owner_process_id_u64);
        }
        
        // Assert: Mapping entry must be freed correctly.
        Debug.kassert(!mapping.allocated, "Mapping still allocated", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Unmap returns 0 on success
        
        return result;
    }
    
    fn syscall_protect(
        self: *BasinKernel,
        region: u64,
        flags: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: region address must be page-aligned (4KB pages).
        if (region % 4096 != 0) {
            return BasinError.unaligned_access;
        }
        
        // Assert: region address must be in user space (not kernel space).
        const KERNEL_SPACE_END: u64 = 0x100000; // 1MB kernel space (matches syscall_map)
        const USER_SPACE_START: u64 = KERNEL_SPACE_END;
        
        if (region < USER_SPACE_START) {
            return BasinError.permission_denied; // Attempting to protect kernel space
        }
        
        // Assert: region address must be within VM memory bounds.
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (region >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Region address exceeds VM memory
        }
        
        // Decode flags (MapFlags packed struct).
        const map_flags = @as(MapFlags, @bitCast(@as(u32, @truncate(flags))));
        
        // Assert: flags must be valid (at least one permission).
        if (!map_flags.read and !map_flags.write and !map_flags.execute) {
            return BasinError.invalid_argument; // No permissions set
        }
        
        // Assert: flags padding must be zero (no reserved bits set).
        if (map_flags._padding != 0) {
            return BasinError.invalid_argument; // Reserved bits set
        }
        
        // Find mapping by address.
        const mapping_idx = self.find_mapping_by_address(region) orelse {
            return BasinError.invalid_argument; // Mapping not found
        };
        
        // Assert: Mapping must be allocated.
        Debug.kassert(self.mappings[mapping_idx].allocated, "Mapping not allocated", .{});
        Debug.kassert(self.mappings[mapping_idx].address == region, "Mapping addr mismatch", .{});
        
        // Update mapping flags (permissions).
        var mapping = &self.mappings[mapping_idx];
        const mapping_size = mapping.size;
        mapping.flags = map_flags;
        
        // Update page table (protect pages with new permissions).
        // Convert MapFlags to PageFlags (same structure).
        const page_flags = page_table.PageFlags{
            .read = map_flags.read,
            .write = map_flags.write,
            .execute = map_flags.execute,
            .shared = map_flags.shared,
            ._padding = 0,
        };
        self.page_table.protect_pages(region, mapping_size, page_flags);
        
        // Update memory statistics.
        self.memory_stats.update_from_page_table(@ptrCast(&self.page_table), VM_MEMORY_SIZE);
        
        // Assert: Mapping flags must be updated correctly.
        Debug.kassert(mapping.flags.read == map_flags.read, "Read flag mismatch", .{});
        Debug.kassert(mapping.flags.write == map_flags.write, "Write flag mismatch", .{});
        Debug.kassert(mapping.flags.execute == map_flags.execute, "Exec flag mismatch", .{});
        Debug.kassert(mapping.flags.shared == map_flags.shared, "Shared flag mismatch", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Protect returns 0 on success
        
        return result;
    }
    
    fn syscall_channel_create(
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
        
        // Get current process ID from scheduler.
        // Why: Track which process owns this channel for resource cleanup.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Create channel in channel table.
        const channel_id = self.channels.create();
        
        if (channel_id == 0) {
            return BasinError.out_of_memory; // Channel table full
        }
        
        // Assert: Channel ID must be non-zero.
        Debug.kassert(channel_id != 0, "Channel ID is 0", .{});
        
        // Set owner process ID for the channel.
        // Why: Track which process owns this channel for resource cleanup.
        const channel = self.channels.find(channel_id);
        if (channel) |ch| {
            ch.owner_process_id = owner_process_id;
        }
        
        const result = SyscallResult.ok(channel_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == channel_id, "Result value mismatch", .{});
        
        return result;
    }
    
    fn syscall_channel_send(
        self: *BasinKernel,
        channel: u64,
        data_ptr: u64,
        data_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: channel ID must be valid (non-zero).
        if (channel == 0) {
            return BasinError.invalid_argument; // Invalid channel ID
        }
        
        // Assert: data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (data_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: data length must be reasonable (max 4KB per message, matches MAX_MESSAGE_SIZE).
        const MAX_MESSAGE_SIZE: u32 = 4096; // Matches channel.zig MAX_MESSAGE_SIZE
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > MAX_MESSAGE_SIZE) {
            return BasinError.invalid_argument; // Data too large (> 4KB)
        }
        
        // Assert: data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Look up channel in channel table.
        // Why: Find channel to send message to.
        const channel_ptr = self.channels.find(channel);
        if (channel_ptr == null) {
            return BasinError.not_found; // Channel not found
        }
        
        const ch = channel_ptr.?;
        
        // Assert: Channel must be allocated.
        Debug.kassert(ch.allocated, "Channel not allocated", .{});
        Debug.kassert(ch.id == channel, "Channel ID mismatch", .{});
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.ipc_timeout; // Timeout expired
        }
        
        // Read data from VM memory.
        // Why: Copy data from VM memory to channel message queue.
        if (self.vm_memory_reader == null) {
            return BasinError.invalid_syscall; // VM memory reader not available
        }
        
        const data_len_u32 = @as(u32, @truncate(data_len));
        var data_buffer: [4096]u8 = undefined;
        const data_slice = data_buffer[0..data_len_u32];
        
        const bytes_read = self.vm_memory_reader.?(data_ptr, data_len_u32, data_slice) orelse {
            return BasinError.invalid_argument; // Failed to read data from VM memory
        };
        
        if (bytes_read != data_len_u32) {
            return BasinError.invalid_argument; // Incomplete read
        }
        
        // Send message to channel.
        // Why: Add message to channel queue.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const sent = ch.send(data_slice);
        if (!sent) {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.ipc_timeout; // Timeout expired
            }
            return BasinError.would_block; // Channel queue full
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.ipc_timeout; // Timeout expired
        }
        
        // Assert: Message must be sent (postcondition).
        Debug.kassert(ch.message_count > 0, "Message not sent", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Channel_send returns 0 on success
        
        return result;
    }
    
    fn syscall_channel_recv(
        self: *BasinKernel,
        channel: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: channel ID must be valid (non-zero).
        if (channel == 0) {
            return BasinError.invalid_argument; // Invalid channel ID
        }
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be reasonable (max 4KB per message, matches MAX_MESSAGE_SIZE).
        const MAX_MESSAGE_SIZE: u32 = 4096; // Matches channel.zig MAX_MESSAGE_SIZE
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > MAX_MESSAGE_SIZE) {
            return BasinError.invalid_argument; // Buffer too large (> 4KB)
        }
        
        // Assert: buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Look up channel in channel table.
        // Why: Find channel to receive message from.
        const channel_ptr = self.channels.find(channel);
        if (channel_ptr == null) {
            return BasinError.not_found; // Channel not found
        }
        
        const ch = channel_ptr.?;
        
        // Assert: Channel must be allocated.
        Debug.kassert(ch.allocated, "Channel not allocated", .{});
        Debug.kassert(ch.id == channel, "Channel ID mismatch", .{});
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.ipc_timeout; // Timeout expired
        }
        
        // Receive message from channel.
        // Why: Get message from channel queue.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        var message_buffer: [4096]u8 = undefined;
        const bytes_received_u32 = ch.receive(&message_buffer);
        
        if (bytes_received_u32 == 0) {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.ipc_timeout; // Timeout expired
            }
            // Queue empty: return 0 bytes received (non-blocking).
            // Why: Non-blocking receive - return immediately if no message.
            const result = SyscallResult.ok(0);
            Debug.kassert(result == .success, "Result not success", .{});
            Debug.kassert(result.success == 0, "Result not 0", .{});
            return result;
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.ipc_timeout; // Timeout expired
        }
        
        // Write message data to VM memory.
        // Why: Copy message data from channel to VM memory buffer.
        if (self.vm_memory_writer == null) {
            return BasinError.invalid_syscall; // VM memory writer not available
        }
        
        const bytes_to_write = @min(bytes_received_u32, @as(u32, @truncate(buffer_len)));
        const message_slice = message_buffer[0..bytes_to_write];
        
        const bytes_written = self.vm_memory_writer.?(buffer_ptr, bytes_to_write, message_slice) orelse {
            return BasinError.invalid_argument; // Failed to write data to VM memory
        };
        
        if (bytes_written != bytes_to_write) {
            return BasinError.invalid_argument; // Incomplete write
        }
        
        // Assert: Bytes written must match bytes received (postcondition).
        Debug.kassert(bytes_written == bytes_to_write, "Bytes written mismatch", .{});
        
        const bytes_received: u64 = @as(u64, bytes_written);
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == bytes_received, "Result value mismatch", .{});
        Debug.kassert(result.success > 0, "Bytes received is 0", .{}); // Must receive at least 1 byte
        
        return result;
    }
    
    fn syscall_clock_gettime(
        self: *BasinKernel,
        clock_id: u64,
        timespec_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: clock_id must be valid (monotonic or realtime).
        const clock = @as(?ClockId, @enumFromInt(@as(u32, @truncate(clock_id)))) orelse {
            return BasinError.invalid_argument; // Invalid clock ID
        };
        
        // Assert: Clock must be valid (monotonic or realtime).
        Debug.kassert(clock == .monotonic or clock == .realtime, "Invalid clock", .{});
        
        // Assert: timespec pointer must be valid (non-zero, within VM memory).
        if (timespec_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (timespec_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Timespec pointer exceeds VM memory
        }
        
        // Assert: timespec must fit within VM memory (16 bytes: seconds + nanoseconds).
        const TIMESPEC_SIZE: u64 = 16; // 8 bytes seconds + 8 bytes nanoseconds
        if (timespec_ptr + TIMESPEC_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Timespec exceeds VM memory
        }
        
        // Note: This syscall is handled by integration layer (needs VM access).
        // This stub should never be called, but we include it for completeness.
        // Contract: clock_id and timespec_ptr must be valid (checked by integration layer).
        
        // This should not be reached (integration layer handles this syscall).
        return BasinError.invalid_syscall;
    }
    
    fn syscall_sleep_until(
        self: *BasinKernel,
        timestamp: u64,
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
        
        // Assert: timestamp must be valid (non-zero, reasonable value).
        // Note: Timestamp is nanoseconds since epoch (or boot, depending on clock type).
        // For now, accept any non-zero value (validation depends on clock implementation).
        if (timestamp == 0) {
            return BasinError.invalid_argument; // Zero timestamp (invalid)
        }
        
        // Get current monotonic time (nanoseconds since boot).
        const current_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Current time must be valid.
        Debug.kassert(current_time_ns >= 0, "Current time negative", .{});
        
        // Check if timestamp is in the past.
        // Note: timestamp is nanoseconds since boot (monotonic clock).
        if (timestamp < current_time_ns) {
            // Timestamp is in the past: return error.
            return BasinError.invalid_argument; // Timestamp in the past
        }
        
        // Calculate sleep duration (nanoseconds to wait).
        const sleep_duration_ns = timestamp - current_time_ns;
        
        // Assert: Sleep duration must be non-negative.
        Debug.kassert(sleep_duration_ns >= 0, "Sleep duration negative", .{});
        
        // TODO: Implement actual blocking sleep (when scheduler is implemented).
        // For now, return success immediately (non-blocking stub).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Set timer interrupt for timestamp
        // - Block current process until timer interrupt
        // - Wake up when timer interrupt fires
        // - Return success when woken up
        
        // Stub: Return success immediately (non-blocking).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Sleep_until returns 0 on success
        
        return result;
    }
    
    fn syscall_sysinfo(
        self: *BasinKernel,
        info_ptr: u64,
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
        
        // Assert: info pointer must be valid (non-zero, within VM memory).
        if (info_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (info_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Info pointer exceeds VM memory
        }
        
        // Assert: SysInfo structure must fit within VM memory.
        // SysInfo size: total_memory (8) + available_memory (8) + cpu_cores (4) + 
        //               uptime_ns (8) + load_avg_1min (4) = 32 bytes
        const SYSINFO_SIZE: u64 = 32;
        if (info_ptr + SYSINFO_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // SysInfo exceeds VM memory
        }
        
        // Get system information from kernel subsystems.
        // Why: Provide actual system statistics for userspace programs.
        // Note: Integration layer will write SysInfo structure to info_ptr.
        
        // Get total memory from memory pool (4MB max).
        const MAX_POOL_SIZE: u64 = 4 * 1024 * 1024; // From memory.zig
        const total_memory: u64 = MAX_POOL_SIZE;
        
        // Get available memory (unallocated pages).
        const MAX_PAGES: u32 = 1024; // From memory.zig
        const PAGE_SIZE: u64 = 4096;
        const allocated_pages = self.memory_pool.allocated_pages;
        const available_pages = MAX_PAGES - allocated_pages;
        const available_memory: u64 = @as(u64, available_pages) * PAGE_SIZE;
        
        // Calculate used memory (total - available).
        // Why: Track memory usage for resource monitoring.
        const used_memory: u64 = total_memory -% available_memory; // Saturating subtract
        
        // Assert: Available memory must be <= total memory.
        Debug.kassert(available_memory <= total_memory, "Available > total", .{});
        
        // Assert: Used memory must be <= total memory.
        Debug.kassert(used_memory <= total_memory, "Used > total", .{});
        
        // Get uptime from timer (nanoseconds since boot).
        const uptime_ns: u64 = self.timer.get_uptime_ns();
        
        // Assert: Uptime must be non-negative.
        Debug.kassert(uptime_ns >= 0, "Uptime negative", .{});
        
        // Calculate process statistics.
        // Why: Provide process count metrics for system monitoring.
        var total_count: u32 = 0;
        var running_count: u32 = 0;
        var exited_count: u32 = 0;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated) {
                total_count += 1;
                if (self.processes[i].state == .running) {
                    running_count += 1;
                } else if (self.processes[i].state == .exited) {
                    exited_count += 1;
                }
            }
        }
        
        // Assert: Process counts must be valid.
        Debug.kassert(total_count <= MAX_PROCESSES, "Total processes > max", .{});
        Debug.kassert(running_count <= total_count, "Running > total", .{});
        Debug.kassert(exited_count <= total_count, "Exited > total", .{});
        
        // Calculate load average (simple: running processes / max processes).
        // Why: Provide basic load metric for system monitoring.
        // Load average: running processes / max processes (scaled to 1000 for fixed-point).
        const load_avg_1min: u32 = if (MAX_PROCESSES > 0) (running_count * 1000) / MAX_PROCESSES else 0;
        
        // Assert: Load average must be <= 1000 (scaled).
        Debug.kassert(load_avg_1min <= 1000, "Load avg > 1000", .{});
        
        // Note: Integration layer will write SysInfo structure to info_ptr.
        // Structure layout:
        // - total_memory: u64 (offset 0)
        // - available_memory: u64 (offset 8)
        // - used_memory: u64 (offset 16)
        // - cpu_cores: u32 (offset 24)
        // - padding: [4]u8 (offset 28)
        // - uptime_ns: u64 (offset 32)
        // - load_avg_1min: u32 (offset 40)
        // - total_processes: u32 (offset 44)
        // - running_processes: u32 (offset 48)
        // - exited_processes: u32 (offset 52)
        // Total size: 56 bytes (with padding)
        
        // Return success (integration layer writes data).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Sysinfo returns 0 on success
        
        // Store system info in kernel for integration layer access.
        // Note: Integration layer can access these values via kernel.sysinfo_* fields.
        // For now, we calculate them here and integration layer will read them.
        
        return result;
    }

    fn syscall_enumerate_processes(
        self: *BasinKernel,
        buffer_ptr: u64,
        buffer_len: u64,
        max_processes: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be sufficient for at least one ProcessInfo.
        const PROCESS_INFO_SIZE: u64 = 32; // pid(4) + parent_pid(4) + state(1) + padding(3) + cpu_time_ns(8) + memory_used(8)
        if (buffer_len < PROCESS_INFO_SIZE) {
            return BasinError.invalid_argument; // Buffer too small
        }
        
        // Assert: max_processes must be reasonable.
        const MAX_PROCESSES_U64: u64 = MAX_PROCESSES;
        const limit: u64 = if (max_processes > 0 and max_processes < MAX_PROCESSES_U64) max_processes else MAX_PROCESSES_U64;
        
        // Calculate how many ProcessInfo structures fit in buffer.
        const max_fit: u64 = buffer_len / PROCESS_INFO_SIZE;
        const count: u64 = if (limit < max_fit) limit else max_fit;
        
        // Enumerate processes and write to buffer.
        // Note: Integration layer will write ProcessInfo structures to buffer_ptr.
        var written: u32 = 0;
        var i: u32 = 0;
        while (i < MAX_PROCESSES and written < count) : (i += 1) {
            if (self.processes[i].allocated) {
                written += 1;
            }
        }
        
        // Return number of processes found (integration layer writes data).
        const result = SyscallResult.ok(@intCast(written));
        
        // Assert: result must be success.
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }

    fn syscall_get_process_info(
        self: *BasinKernel,
        pid: u64,
        info_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Assert: info pointer must be valid (non-zero, within VM memory).
        if (info_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (info_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Info pointer exceeds VM memory
        }
        
        // Assert: ProcessInfo structure must fit within VM memory.
        const PROCESS_INFO_SIZE: u64 = 32;
        if (info_ptr + PROCESS_INFO_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // ProcessInfo exceeds VM memory
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
        
        // Update process memory usage before returning info.
        // Why: Ensure memory_used is current when querying process info.
        self.update_process_memory_usage(pid);
        
        // Get process information.
        // Note: Integration layer will write ProcessInfo structure to info_ptr.
        // Process data available: self.processes[idx].id, .parent_pid, .state, .cpu_time_ns, .memory_used
        // Structure layout:
        // - pid: u32 (offset 0)
        // - parent_pid: u32 (offset 4)
        // - state: u8 (offset 8)
        // - padding: [3]u8 (offset 9-11)
        // - cpu_time_ns: u64 (offset 12, but u64 alignment means offset 16)
        // - memory_used: u64 (offset 24)
        // Total size: 32 bytes
        
        // Return success (integration layer writes data).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success.
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }

    fn syscall_read_kernel_log(
        self: *BasinKernel,
        buffer_ptr: u64,
        buffer_len: u64,
        max_entries: u64,
        flags: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = flags; // Reserved for future use (filter flags)
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be sufficient for at least one KernelLogEntry.
        // Structure layout: timestamp(8) + level(1) + padding(7) + source(32) + message(256) = 304 bytes
        const KERNEL_LOG_ENTRY_SIZE: u64 = @sizeOf(KernelLogEntry);
        if (buffer_len < KERNEL_LOG_ENTRY_SIZE) {
            return BasinError.invalid_argument; // Buffer too small
        }
        
        // Get entry count from log buffer.
        const entry_count = self.log_buffer.get_entry_count();
        
        // Assert: max_entries must be reasonable.
        const MAX_LOG_ENTRIES_U64: u64 = 256;
        const limit: u64 = if (max_entries > 0 and max_entries < MAX_LOG_ENTRIES_U64) max_entries else MAX_LOG_ENTRIES_U64;
        
        // Calculate how many KernelLogEntry structures fit in buffer.
        const max_fit: u64 = buffer_len / KERNEL_LOG_ENTRY_SIZE;
        const count: u64 = if (limit < max_fit) limit else max_fit;
        const actual_count: u64 = if (count < entry_count) count else entry_count;
        
        // Enumerate log entries and write to buffer.
        // Note: Integration layer will write KernelLogEntry structures to buffer_ptr.
        var written: u32 = 0;
        var i: u32 = 0;
        while (i < actual_count) : (i += 1) {
            if (self.log_buffer.get_entry(i)) |_| {
                written += 1;
            }
        }
        
        // Return number of log entries found (integration layer writes data).
        const result = SyscallResult.ok(@intCast(written));
        
        // Assert: result must be success.
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }

    fn syscall_set_priority(
        self: *BasinKernel,
        pid: u64,
        priority: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: process ID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // Assert: priority must be valid nice value (-20 to 19).
        // Why: POSIX-style nice values: -20 (highest priority) to 19 (lowest priority).
        const MIN_NICE: i8 = -20;
        const MAX_NICE: i8 = 19;
        // Convert u64 to i8 (assuming value is in 0-39 range, subtract 20).
        // Why: Userspace passes nice value as unsigned (0-39), convert to signed (-20 to 19).
        const priority_offset: u64 = 20;
        if (priority < priority_offset or priority > priority_offset + 39) {
            return BasinError.invalid_argument; // Invalid priority value
        }
        const priority_i8 = @as(i8, @intCast(@as(i64, @intCast(priority)) - @as(i64, priority_offset)));
        
        // Assert: Priority must be in valid range after conversion.
        Debug.kassert(priority_i8 >= MIN_NICE and priority_i8 <= MAX_NICE, "Priority out of range", .{});
        
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
        
        // Set process priority.
        // Why: Update process priority for scheduling decisions.
        self.processes[idx].priority = priority_i8;
        
        // Assert: Priority must be set correctly.
        Debug.kassert(self.processes[idx].priority == priority_i8, "Priority not set", .{});
        
        // Return success.
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success.
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }

    fn syscall_get_priority(
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
        
        // Assert: process ID must be valid (non-zero).
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
        
        // Get process priority.
        // Why: Return process priority for userspace queries.
        const priority = self.processes[idx].priority;
        
        // Convert i8 to u64 for return value (add 20 to make it non-negative).
        // Why: Return nice value as unsigned (0-39 range: -20 becomes 0, 19 becomes 39).
        const priority_u64 = @as(u64, @intCast(@as(i32, priority) + 20));
        
        // Assert: Priority value must be in valid range (0-39).
        Debug.kassert(priority_u64 <= 39, "Priority value > 39", .{});
        
        // Return priority value.
        const result = SyscallResult.ok(priority_u64);
        
        // Assert: result must be success.
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    fn syscall_read_input_event(
        self: *BasinKernel,
        event_buf: u64,
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
        
        // Note: This syscall is handled by integration layer (needs VM access).
        // This stub should never be called, but we include it for completeness.
        // Contract: event_buf must be valid pointer (checked by integration layer).
        if (event_buf == 0) {
            return BasinError.invalid_argument;
        }
        
        // This should not be reached (integration layer handles this syscall).
        return BasinError.invalid_syscall;
    }
    
    fn syscall_fb_clear(
        self: *BasinKernel,
        color: u64,
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
        
        // Note: This syscall is handled by integration layer (needs VM access).
        // This stub should never be called, but we include it for completeness.
        // Contract: color must be valid 32-bit RGBA value.
        if (color > 0xFFFFFFFF) {
            return BasinError.invalid_argument;
        }
        
        // This should not be reached (integration layer handles this syscall).
        return BasinError.invalid_syscall;
    }
    
    fn syscall_fb_draw_pixel(
        self: *BasinKernel,
        x: u64,
        y: u64,
        color: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Note: This syscall is handled by integration layer (needs VM access).
        // This stub should never be called, but we include it for completeness.
        // Contract: coordinates and color must be valid.
        if (x > 0xFFFFFFFF or y > 0xFFFFFFFF or color > 0xFFFFFFFF) {
            return BasinError.invalid_argument;
        }
        
        // This should not be reached (integration layer handles this syscall).
        return BasinError.invalid_syscall;
    }
    
    fn syscall_fb_draw_text(
        self: *BasinKernel,
        text_ptr: u64,
        x: u64,
        y: u64,
        fg_color: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Note: This syscall is handled by integration layer (needs VM access).
        // This stub should never be called, but we include it for completeness.
        // Contract: text_ptr must be valid pointer, coordinates and color must be valid.
        if (text_ptr == 0) {
            return BasinError.invalid_argument;
        }
        if (x > 0xFFFFFFFF or y > 0xFFFFFFFF or fg_color > 0xFFFFFFFF) {
            return BasinError.invalid_argument;
        }
        
        // This should not be reached (integration layer handles this syscall).
        return BasinError.invalid_syscall;
    }

/// Basin Kernel module exports.
/// Why: Explicit exports, clear public API.
pub const basin_kernel = struct {
    pub const Syscall = @import("basin_kernel.zig").Syscall;
    pub const MapFlags = @import("basin_kernel.zig").MapFlags;
    pub const OpenFlags = @import("basin_kernel.zig").OpenFlags;
    pub const ClockId = @import("basin_kernel.zig").ClockId;
    pub const Handle = @import("basin_kernel.zig").Handle;
    pub const Signal = @import("signal.zig").Signal;
    pub const SysInfo = @import("basin_kernel.zig").SysInfo;
    pub const BasinError = @import("basin_kernel.zig").BasinError;
    pub const SyscallResult = @import("basin_kernel.zig").SyscallResult;
    pub const BasinKernel = @import("basin_kernel.zig").BasinKernel;
    pub const ProcessContext = @import("process.zig").ProcessContext;
    pub const Process = @import("basin_kernel.zig").Process;
    pub const process_execution = @import("process_execution.zig");
    pub const Storage = @import("storage.zig").Storage;
    pub const FileEntry = @import("storage.zig").FileEntry;
    pub const DirectoryEntry = @import("storage.zig").DirectoryEntry;
    pub const MAX_FILE_SIZE = @import("storage.zig").MAX_FILE_SIZE;
    pub const InterruptController = @import("interrupt.zig").InterruptController;
    pub const InterruptType = @import("interrupt.zig").InterruptType;
    pub const Timer = @import("timer.zig").Timer;
    pub const Keyboard = @import("keyboard.zig").Keyboard;
    pub const Mouse = @import("mouse.zig").Mouse;
    pub const KeyCode = @import("keyboard.zig").KeyCode;
    pub const ChannelTable = @import("channel.zig").ChannelTable;
    pub const Channel = @import("channel.zig").Channel;
    pub const MemoryPool = @import("memory.zig").MemoryPool;
    pub const MAX_PAGES = @import("memory.zig").MAX_PAGES;
    pub const PAGE_SIZE = @import("memory.zig").PAGE_SIZE;
    pub const MAX_MESSAGE_SIZE = @import("channel.zig").MAX_MESSAGE_SIZE;
    pub const BootSequence = @import("boot.zig").BootSequence;
    pub const BootPhase = @import("boot.zig").BootPhase;
    pub const boot_kernel = @import("boot.zig").boot_kernel;
    pub const ExceptionType = @import("trap.zig").ExceptionType;
    pub const handle_exception = @import("trap.zig").handle_exception;
};

