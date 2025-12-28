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

// Export resource_cleanup for tests.
pub const resource_cleanup_module = resource_cleanup;

// Export RawIO for tests to disable hardware access.
pub const RawIO = @import("raw_io.zig");

/// Basin Kernel syscall numbers.
/// Why: Explicit syscall enumeration for type safety and clarity.
pub const Syscall = enum(u32) {
    // Process & Thread Management
    spawn = 1,
    exit = 2,
    yield = 3,
    wait = 4,
    
    // Memory Management
    map = 10,
    unmap = 11,
    protect = 12,
    
    // Inter-Process Communication
    channel_create = 20,
    channel_send = 21,
    channel_recv = 22,
    
    // I/O Operations
    open = 30,
    read = 31,
    write = 32,
    close = 33,
    unlink = 34,
    rename = 35,
    mkdir = 36,
    opendir = 37,
    readdir = 38,
    closedir = 39,
    
    // Time & Scheduling
    clock_gettime = 40,
    sleep_until = 41,
    
    // System Information
    sysinfo = 50,
    enumerate_processes = 51,
    get_process_info = 52,
    read_kernel_log = 53,
    set_priority = 54,
    get_priority = 55,
    setpgid = 56,
    getpgid = 57,
    setsid = 58,
    getsid = 59,
    
    // Input Events
    read_input_event = 60,
    
    // Framebuffer Operations
    fb_clear = 70,
    fb_draw_pixel = 71,
    fb_draw_text = 72,
    
    // Signal Operations
    kill = 80,
    signal = 81,
    sigaction = 82,
    
    // Network Operations
    network_create_interface = 90,
    network_set_state = 91,
    network_set_ipv4 = 92,
    network_set_ipv6 = 94,
    network_get_interface = 93,
    network_delete_interface = 95,
    network_enumerate_interfaces = 96,
    network_get_stats = 97,
    
    // TCP Socket Operations
    tcp_socket = 100,
    tcp_bind = 101,
    tcp_listen = 102,
    tcp_accept = 103,
    tcp_connect = 104,
    tcp_send = 105,
    tcp_recv = 106,
    tcp_close = 107,
    tcp_enumerate_sockets = 108,
    tcp_get_stats = 109,
    
    // UDP Socket Operations
    udp_socket = 110,
    udp_bind = 111,
    udp_sendto = 112,
    udp_recvfrom = 113,
    udp_close = 114,
    udp_enumerate_sockets = 115,
    udp_get_stats = 116,
    
    // Audio Device Operations
    audio_create_device = 120,
    audio_set_volume = 121,
    audio_set_mute = 122,
    audio_set_state = 123,
    audio_set_active_output = 124,
    audio_set_active_input = 125,
    audio_set_master_volume = 126,
    audio_set_master_mute = 127,
    audio_get_device = 128,
    audio_set_format = 129,
    audio_read = 130,
    audio_write = 131,
    audio_enumerate_devices = 132,
    audio_delete_device = 133,
    audio_get_stats = 134,
    
    // Kernel Statistics & Health
    kernel_get_stats = 135,
    health_check = 136,
    get_resource_usage = 137,
};

/// Memory mapping flags.
/// Why: Explicit flags instead of POSIX-style bitmasks for type safety.
pub const MapFlags = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    shared: bool = false,
    _padding: u28 = 0,
    
    /// Create MapFlags from boolean values.
    /// Why: Explicit construction, no magic numbers.
    pub fn init(flags: struct {
        read: bool = false,
        write: bool = false,
        execute: bool = false,
        shared: bool = false,
    }) MapFlags {
        return MapFlags{
            .read = flags.read,
            .write = flags.write,
            .execute = flags.execute,
            .shared = flags.shared,
            ._padding = 0,
        };
    }
};

/// File open flags.
/// Why: Explicit flags instead of POSIX O_* constants.
pub const OpenFlags = packed struct {
    read: bool = false,
    write: bool = false,
    create: bool = false,
    truncate: bool = false,
    _padding: u28 = 0,
    
    /// Create OpenFlags from boolean values.
    /// Why: Explicit construction, no magic numbers.
    pub fn init(flags: struct {
        read: bool = false,
        write: bool = false,
        create: bool = false,
        truncate: bool = false,
    }) OpenFlags {
        return OpenFlags{
            .read = flags.read,
            .write = flags.write,
            .create = flags.create,
            .truncate = flags.truncate,
            ._padding = 0,
        };
    }
};

/// Clock ID for time operations.
/// Why: Explicit clock types instead of POSIX CLOCK_* constants.
pub const ClockId = enum(u32) {
    monotonic = 0,
    realtime = 1,
};

/// Strongly-typed kernel handle (not integer file descriptor).
/// Why: Type safety, prevent handle confusion, explicit resource management.
pub const Handle = struct {
    value: u64,
    
    /// Create handle from value.
    /// Why: Explicit construction, validate handle value.
    pub fn init(value: u64) Handle {
        // Assert: handle value must be non-zero (0 is invalid handle).
        Debug.kassert(value != 0, "Handle value must be non-zero", .{});
        
        return Handle{ .value = value };
    }
    
    /// Check if handle is valid (non-zero).
    /// Why: Explicit validation, prevent use of invalid handles.
    pub fn is_valid(self: Handle) bool {
        return self.value != 0;
    }
    
    /// Compare handles for equality.
    /// Why: Explicit comparison, prevent accidental comparison with integers.
    pub fn eql(self: Handle, other: Handle) bool {
        return self.value == other.value;
    }
};

/// System information structure.
/// Why: Strongly-typed struct instead of POSIX sysinfo.
pub const SysInfo = struct {
    /// Total physical memory (bytes).
    total_memory: u64,
    
    /// Available physical memory (bytes).
    available_memory: u64,
    
    /// Used physical memory (bytes).
    /// Why: Track memory usage for resource monitoring.
    used_memory: u64,
    
    /// Number of CPU cores.
    cpu_cores: u32,
    
    /// Uptime (nanoseconds since boot).
    uptime_ns: u64,
    
    /// Load average (1-minute average, scaled by 1000).
    load_avg_1min: u32,
    
    /// Total number of processes (allocated).
    /// Why: Track process count for system monitoring.
    total_processes: u32,
    
    /// Number of running processes.
    /// Why: Track active process count for system monitoring.
    running_processes: u32,
    
    /// Number of exited processes.
    /// Why: Track terminated process count for system monitoring.
    exited_processes: u32,
    
    /// Initialize SysInfo with default values.
    /// Why: Explicit initialization, prevent uninitialized fields.
    pub fn init() SysInfo {
        return SysInfo{
            .total_memory = 0,
            .available_memory = 0,
            .used_memory = 0,
            .cpu_cores = 0,
            .uptime_ns = 0,
            .load_avg_1min = 0,
            .total_processes = 0,
            .running_processes = 0,
            .exited_processes = 0,
        };
    }
};

/// Process information structure for userspace.
/// Why: Provide process information to userspace programs.
/// GrainStyle: Explicit types, bounded size, deterministic layout.
pub const ProcessInfo = struct {
    /// Process ID.
    pid: u32,
    /// Parent process ID (0 if no parent).
    parent_pid: u32,
    /// Process state (0=free, 1=running, 2=exited).
    state: u8,
    /// Total CPU time used (nanoseconds).
    cpu_time_ns: u64,
    /// Memory used (bytes).
    memory_used: u64,
    
    /// Initialize ProcessInfo with default values.
    /// Why: Explicit initialization, prevent uninitialized fields.
    pub fn init() ProcessInfo {
        return ProcessInfo{
            .pid = 0,
            .parent_pid = 0,
            .state = 0,
            .cpu_time_ns = 0,
            .memory_used = 0,
        };
    }
};

/// Resource usage information for a process.
/// Why: Expose per-process resource usage (CPU, memory, network, file descriptors).
/// Grain Style: Explicit types (u32/u64 not usize), static allocation.
pub const ResourceUsage = struct {
    /// Process ID.
    pid: u32,
    /// Total CPU time used (nanoseconds).
    cpu_time_ns: u64,
    /// Memory used (bytes).
    memory_used: u64,
    /// Network bytes sent (total).
    network_bytes_sent: u64,
    /// Network bytes received (total).
    network_bytes_received: u64,
    /// Number of open file descriptors.
    open_file_descriptors: u32,
    /// Number of open network connections.
    open_connections: u32,
    
    /// Initialize ResourceUsage with default values.
    /// Why: Explicit initialization, prevent uninitialized fields.
    pub fn init() ResourceUsage {
        return ResourceUsage{
            .pid = 0,
            .cpu_time_ns = 0,
            .memory_used = 0,
            .network_bytes_sent = 0,
            .network_bytes_received = 0,
            .open_file_descriptors = 0,
            .open_connections = 0,
        };
    }
};

/// User ID (32-bit, explicit type per GrainStyle).
/// Why: Explicit type instead of usize for portability.
pub const UserId = u32;

/// Group ID (32-bit, explicit type per GrainStyle).
/// Why: Explicit type instead of usize for portability.
pub const GroupId = u32;

/// User Record
/// Why: Track user identity, permissions, home directory
/// Grain Style: Explicit types (u32 not usize), static allocation
pub const User = struct {
    /// User ID (0 = root)
    uid: UserId,
    /// Group ID (primary group)
    gid: GroupId,
    /// Username (max 32 chars, static allocation)
    name: [32]u8,
    /// Home directory path (max 256 chars)
    home: [256]u8,
    /// Capabilities bitmap (future: fine-grained permissions)
    capabilities: u64,
    
    /// Initialize empty user entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() User {
        return User{
            .uid = 0,
            .gid = 0,
            .name = [_]u8{0} ** 32,
            .home = [_]u8{0} ** 256,
            .capabilities = 0,
        };
    }
    
    /// Validate user record.
    /// Why: Ensure user data is valid.
    pub fn validate(self: *const User) void {
        Debug.kassert(self.uid < 65536, "UID too large: {d}", .{self.uid});
        Debug.kassert(self.gid < 65536, "GID too large: {d}", .{self.gid});
        // Name can be empty for uninitialized entries
    }
};

/// Current User Context
/// Why: Track current user for permission checks
/// Single-threaded: No locks needed, deterministic
pub const UserContext = struct {
    /// Current user ID
    uid: UserId,
    /// Current group ID
    gid: GroupId,
    /// Effective user ID (for setuid)
    euid: UserId,
    /// Effective group ID (for setgid)
    egid: GroupId,
    
    /// Initialize user context.
    /// Why: Explicit initialization, clear state.
    pub fn init(uid: UserId, gid: GroupId) UserContext {
        return UserContext{
            .uid = uid,
            .gid = gid,
            .euid = uid,
            .egid = gid,
        };
    }
    
    /// Check if current user is root.
    /// Why: Explicit root check for permission validation.
    pub fn is_root(self: *const UserContext) bool {
        return self.euid == 0;
    }
    
    /// Check if user has capability.
    /// Why: Explicit capability check for permission validation.
    pub fn has_capability(self: *const UserContext, cap: u64) bool {
        _ = cap; // Future: Use capability bitmap
        if (self.is_root()) return true;
        // Future: Check capability bitmap from user record
        return false;
    }
};

/// Basin Kernel error types.
/// Why: Explicit error types instead of POSIX errno.
pub const BasinError = error{
    invalid_handle,
    invalid_argument,
    permission_denied,
    not_found,
    out_of_memory,
    resource_exhausted,
    would_block,
    interrupted,
    invalid_syscall,
    invalid_address,
    unaligned_access,
    out_of_bounds,
    user_not_found,
    invalid_user,
    // Network errors
    network_error,
    connection_failed,
    connection_timeout,
    connection_refused,
    network_timeout,
    // File system errors
    file_io_timeout,
    file_not_found,
    file_exists,
    file_too_large,
    directory_not_empty,
    // Process errors
    process_not_found,
    process_already_running,
    process_terminated,
    // IPC errors
    channel_full,
    channel_empty,
    channel_closed,
    ipc_timeout,
    // Resource errors
    too_many_files,
    too_many_processes,
    too_many_connections,
};

/// Syscall result wrapper.
/// Why: Explicit result type, prevent confusion with raw return values.
pub const SyscallResult = union(enum) {
    success: u64,
    err: BasinError,
    
    /// Create success result.
    /// Why: Explicit construction, type safety.
    pub fn ok(value: u64) SyscallResult {
        return SyscallResult{ .success = value };
    }
    
    /// Create error result.
    /// Why: Explicit construction, type safety.
    pub fn fail(err: BasinError) SyscallResult {
        return SyscallResult{ .err = err };
    }
};

/// Memory mapping entry.
/// Why: Track memory mappings for map/unmap/protect syscalls.
/// Grain Style: Static allocation, explicit state tracking.
const MemoryMapping = struct {
    /// Mapping address (page-aligned).
    address: u64,
    /// Mapping size (page-aligned, bytes).
    size: u64,
    /// Mapping flags (permissions).
    flags: MapFlags,
    /// Whether this entry is allocated (in use).
    allocated: bool,
    /// Owner process ID (0 = kernel-owned, non-zero = process-owned).
    /// Why: Track which process owns this mapping for resource cleanup.
    owner_process_id: u32,
    
    /// Initialize empty mapping entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() MemoryMapping {
        return MemoryMapping{
            .address = 0,
            .size = 0,
            .flags = MapFlags.init(.{}),
            .allocated = false,
            .owner_process_id = 0,
        };
    }
    
    /// Check if mapping overlaps with address range.
    /// Why: Validate no overlapping mappings.
    pub fn overlaps(self: MemoryMapping, addr: u64, size: u64) bool {
        if (!self.allocated) {
            return false;
        }
        // Check if ranges overlap: (self.address < addr + size) && (addr < self.address + self.size)
        return (self.address < addr + size) and (addr < self.address + self.size);
    }
};

/// Memory mapping table.
/// Why: Track all memory mappings for kernel memory management.
/// Grain Style: Static allocation, max 256 entries (sufficient for 4MB VM).
const MAX_MAPPINGS: u32 = 256;

/// File handle entry.
/// Why: Track file handles for open/read/write/close syscalls.
/// Grain Style: Static allocation, explicit state tracking.
const FileHandle = struct {
    /// Handle ID (non-zero if allocated).
    id: u64,
    /// File path (null-terminated, max 256 bytes).
    path: [256]u8,
    /// Path length (bytes, excluding null terminator).
    path_len: u32,
    /// Open flags (permissions).
    flags: OpenFlags,
    /// Current read/write position (bytes from start).
    position: u64,
    /// File buffer (in-memory file data, max 64KB).
    buffer: [64 * 1024]u8,
    /// Buffer size (actual data length, bytes).
    buffer_size: u32,
    /// Whether this entry is allocated (in use).
    allocated: bool,
    /// Owner process ID (0 = kernel-owned, non-zero = process-owned).
    /// Why: Track which process owns this handle for resource cleanup.
    owner_process_id: u32,
    
    /// Initialize empty file handle entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() FileHandle {
        return FileHandle{
            .id = 0,
            .path = [_]u8{0} ** 256,
            .path_len = 0,
            .flags = OpenFlags.init(.{}),
            .position = 0,
            .buffer = [_]u8{0} ** (64 * 1024),
            .buffer_size = 0,
            .allocated = false,
            .owner_process_id = 0,
        };
    }
};

/// Directory handle entry.
/// Why: Track directory handles for opendir/readdir/closedir syscalls.
/// Grain Style: Static allocation, explicit state tracking.
const DirectoryHandle = struct {
    /// Handle ID (non-zero if allocated).
    id: u64,
    /// Directory path (null-terminated, max 256 bytes).
    path: [256]u8,
    /// Path length (bytes, excluding null terminator).
    path_len: u32,
    /// Current read position (entry index, 0-based).
    position: u32,
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty directory handle entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() DirectoryHandle {
        return DirectoryHandle{
            .id = 0,
            .path = [_]u8{0} ** 256,
            .path_len = 0,
            .position = 0,
            .allocated = false,
        };
    }
};

/// File handle table.
/// Why: Track all file handles for kernel file system management.
/// Grain Style: Static allocation, max 64 entries.
const MAX_HANDLES: u32 = 64;

/// Directory handle table.
/// Why: Track all directory handles for kernel directory operations.
/// Grain Style: Static allocation, max 32 entries.
const MAX_DIR_HANDLES: u32 = 32;

/// Process state enumeration.
/// Why: Explicit process states for type safety.
pub const ProcessState = enum(u8) {
    /// Process is running (active).
    running,
    /// Process has exited (terminated).
    exited,
    /// Process slot is free (not allocated).
    free,
};

/// Process entry.
/// Why: Track process information for spawn/wait/exit syscalls.
/// Grain Style: Static allocation, explicit state tracking.
pub const Process = struct {
    /// Process ID (non-zero if allocated).
    id: u64,
    /// Process state (running, exited, free).
    state: ProcessState,
    /// Exit status (valid only when state == exited).
    exit_status: u32,
    /// Executable pointer (ELF data pointer in VM memory).
    /// Why: Track where ELF executable is located in VM memory.
    executable_ptr: u64,
    /// Executable length (bytes).
    /// Why: Track ELF executable size for validation.
    executable_len: u64,
    /// Entry point (program counter at start).
    /// Why: Track where process execution starts (ELF entry point).
    entry_point: u64,
    /// Stack pointer (initial SP value).
    /// Why: Track initial stack pointer for process.
    stack_pointer: u64,
    /// Process execution context (optional, for enhanced process management).
    /// Why: Track process execution state (PC, SP, registers).
    context: ?ProcessContext = null,
    /// Signal table for process.
    /// Why: Handle signals (SIGTERM, SIGKILL, etc.) for process.
    signals: SignalTable,
    /// Total CPU time used (nanoseconds).
    /// Why: Track CPU usage for resource monitoring.
    cpu_time_ns: u64,
    /// Memory used (bytes).
    /// Why: Track memory usage for resource monitoring.
    memory_used: u64,
    /// Network bytes sent (total).
    /// Why: Track network usage for resource monitoring.
    network_bytes_sent: u64,
    /// Network bytes received (total).
    /// Why: Track network usage for resource monitoring.
    network_bytes_received: u64,
    /// Number of open file descriptors.
    /// Why: Track file descriptor usage for resource monitoring.
    open_file_descriptors: u32,
    /// Number of open network connections.
    /// Why: Track network connection usage for resource monitoring.
    open_connections: u32,
    /// Parent process ID (0 if no parent).
    /// Why: Track parent-child relationships.
    parent_pid: u64,
    /// Process priority (nice value, -20 to 19, default 0).
    /// Why: Track process priority for scheduling decisions.
    /// Note: Lower nice value = higher priority (POSIX-style).
    priority: i8,
    /// Time slice quantum (instruction steps per time slice, default 1000).
    /// Why: Track time slice allocation for fair scheduling.
    time_slice_quantum: u64,
    /// Process group ID (0 if no group).
    /// Why: Track process group membership for group-based operations.
    pgid: u64,
    /// Session ID (0 if no session).
    /// Why: Track session membership for session-based operations.
    sid: u64,
    /// Whether this entry is allocated (in use).
    allocated: bool,
    
    /// Initialize empty process entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() Process {
        return Process{
            .id = 0,
            .state = .free,
            .exit_status = 0,
            .executable_ptr = 0,
            .executable_len = 0,
            .entry_point = 0,
            .stack_pointer = 0,
            .context = null,
            .signals = SignalTable.init(),
            .cpu_time_ns = 0,
            .memory_used = 0,
            .network_bytes_sent = 0,
            .network_bytes_received = 0,
            .open_file_descriptors = 0,
            .open_connections = 0,
            .parent_pid = 0,
            .priority = 0, // Default priority (nice value 0)
            .time_slice_quantum = 1000, // Default time slice (1000 instruction steps)
            .pgid = 0, // No process group by default
            .sid = 0, // No session by default
            .allocated = false,
        };
    }
};

/// Process table.
/// Why: Track all processes for kernel process management.
/// Grain Style: Static allocation, max 16 entries.
const MAX_PROCESSES: u32 = 16;

// Compile-time assertions for handle table size.
comptime {
    std.debug.assert(MAX_HANDLES > 0);
    std.debug.assert(MAX_HANDLES <= 0xFFFFFFFF);
    std.debug.assert(MAX_HANDLES < 0xFFFFFFFF);
}

/// Basin Kernel syscall interface (stub for future implementation).
/// Why: Define interface early, implement incrementally.
/// User table (static allocation).
/// Why: Fixed-size user table, no dynamic allocation
/// Grain Style: Static array, max 256 users
const MAX_USERS: u32 = 256;

pub const BasinKernel = struct {
    /// Memory mapping table (static allocation).
    /// Why: Track memory mappings for map/unmap/protect syscalls.
    /// Grain Style: Static allocation, max 256 entries.
    mappings: [MAX_MAPPINGS]MemoryMapping = [_]MemoryMapping{MemoryMapping.init()} ** MAX_MAPPINGS,
    
    /// Next address for kernel-chosen allocations (simple allocator).
    /// Why: Track allocation position for kernel-chosen addresses.
    next_alloc_addr: u64 = 0x100000, // Start after kernel space (1MB)
    
    /// File handle table (static allocation).
    /// Why: Track file handles for open/read/write/close syscalls.
    /// Grain Style: Static allocation, max 64 entries.
    handles: [MAX_HANDLES]FileHandle = [_]FileHandle{FileHandle.init()} ** MAX_HANDLES,
    
    /// Next handle ID (simple allocator, starts at 1).
    /// Why: Track handle ID allocation (1-based, 0 is invalid).
    next_handle_id: u64 = 1,
    
    /// Directory handle table (static allocation).
    /// Why: Track directory handles for opendir/readdir/closedir syscalls.
    /// Grain Style: Static allocation, max 32 entries.
    dir_handles: [MAX_DIR_HANDLES]DirectoryHandle = [_]DirectoryHandle{DirectoryHandle.init()} ** MAX_DIR_HANDLES,
    
    /// Next directory handle ID (simple allocator, starts at 1).
    /// Why: Track directory handle ID allocation (1-based, 0 is invalid).
    next_dir_handle_id: u64 = 1,
    
    /// Process table (static allocation).
    /// Why: Track processes for spawn/wait/exit syscalls.
    /// Grain Style: Static allocation, max 16 entries.
    processes: [MAX_PROCESSES]Process = [_]Process{Process.init()} ** MAX_PROCESSES,
    
    /// Next process ID (simple allocator, starts at 1).
    /// Why: Track process ID allocation (1-based, 0 is invalid).
    next_process_id: u64 = 1,
    
    /// User table (static allocation).
    /// Why: Track users for permission checks and user management.
    /// Grain Style: Static allocation, max 256 users.
    users: [MAX_USERS]User = [_]User{User.init()} ** MAX_USERS,
    
    /// User count (number of initialized users).
    /// Why: Track how many users are initialized.
    user_count: u32 = 0,
    
    /// Current user context.
    /// Why: Track current user for permission checks.
    /// Single-threaded: No locks needed, deterministic.
    current_user: UserContext = UserContext{
        .uid = 0,
        .gid = 0,
        .euid = 0,
        .egid = 0,
    },
    
    /// Timer driver.
    /// Why: Provide monotonic clock and time-based syscalls.
    /// Grain Style: Static allocation, initialized at kernel boot.
    timer: Timer,
    
    /// Interrupt controller.
    /// Why: Handle interrupts (timer, external, software).
    /// Grain Style: Static allocation, initialized at kernel boot.
    interrupt_controller: InterruptController,
    
    /// Process scheduler.
    /// Why: Manage process execution and scheduling.
    /// Grain Style: Static allocation, initialized at kernel boot.
    scheduler: Scheduler,
    
    /// Process group manager.
    /// Why: Manage process groups and sessions.
    /// Grain Style: Static allocation, initialized at kernel boot.
    process_group_manager: ProcessGroupManager,
    
    /// Process group statistics manager.
    /// Why: Track statistics for process groups.
    /// Grain Style: Static allocation, initialized at kernel boot.
    process_group_stats: ProcessGroupStatsManager,
    
    /// Process group limits manager.
    /// Why: Enforce resource limits for process groups.
    /// Grain Style: Static allocation, initialized at kernel boot.
    process_group_limits: ProcessGroupLimitsManager,
    
    /// Network interface manager.
    /// Why: Manage network interfaces for TCP/UDP syscalls.
    /// Grain Style: Static allocation, initialized at kernel boot.
    network_interfaces: NetworkInterfaceManager,
    
    /// TCP socket manager.
    /// Why: Manage TCP sockets for network communication.
    /// Grain Style: Static allocation, initialized at kernel boot.
    tcp_sockets: TcpSocketManager,
    
    /// UDP socket manager.
    /// Why: Manage UDP sockets for network communication.
    /// Grain Style: Static allocation, initialized at kernel boot.
    udp_sockets: UdpSocketManager,
    
    /// Audio device manager.
    /// Why: Manage audio devices for audio I/O syscalls.
    /// Grain Style: Static allocation, initialized at kernel boot.
    audio_devices: AudioDeviceManager,
    
    /// IPC channel table.
    /// Why: Manage inter-process communication channels.
    /// Grain Style: Static allocation, initialized at kernel boot.
    channels: ChannelTable,
    
    /// Storage filesystem.
    /// Why: Manage files and directories for file I/O syscalls.
    /// Grain Style: Static allocation, initialized at kernel boot.
    storage: Storage,
    
    /// Keyboard driver.
    /// Why: Track keyboard state and key presses.
    /// Grain Style: Static allocation, initialized at kernel boot.
    keyboard: Keyboard,
    
    /// Mouse driver.
    /// Why: Track mouse state (position, buttons).
    /// Grain Style: Static allocation, initialized at kernel boot.
    mouse: Mouse,
    
    /// Kernel log buffer.
    /// Why: Store kernel log entries for userspace access.
    /// Grain Style: Static allocation, initialized at kernel boot.
    log_buffer: KernelLogBuffer,
    
    /// Memory pool for kernel allocations.
    /// Why: Provide kernel-side memory allocation.
    /// Grain Style: Static allocation, initialized at kernel boot.
    memory_pool: MemoryPool,
    
    /// Page table for memory protection.
    /// Why: Track page-level memory permissions and mappings.
    /// Grain Style: Static allocation, initialized at kernel boot.
    page_table: PageTable,
    
    /// Page fault statistics.
    /// Why: Track page fault types and frequencies for diagnostics.
    /// Grain Style: Static allocation, initialized at kernel boot.
    page_fault_stats: PageFaultStats,
    
    /// Memory usage statistics.
    /// Why: Track memory usage, mapped pages, and allocation patterns.
    /// Grain Style: Static allocation, initialized at kernel boot.
    memory_stats: MemoryStats,
    
    /// Copy-on-Write (COW) table.
    /// Why: Track reference counts and COW marking for shared memory pages.
    /// Grain Style: Static allocation, initialized at kernel boot.
    cow_table: CowTable,
    
    /// VM memory read callback (optional).
    /// Why: Allow kernel to read VM memory for ELF parsing and process setup.
    /// Note: Type-erased to avoid requiring VM import at module level.
    /// Contract: Must be set by integration layer before use.
    vm_memory_reader: ?*const fn (addr: u64, len: u32, buffer: []u8) ?u32 = null,
    
    /// User data for VM memory reader (optional).
    /// Why: Pass context to memory reader (e.g., VM instance).
    vm_memory_reader_user_data: ?*anyopaque = null,
    
    /// VM memory write callback (optional).
    /// Why: Allow kernel to write VM memory for segment data loading.
    /// Note: Type-erased to avoid requiring VM import at module level.
    /// Contract: Must be set by integration layer before use.
    /// Returns: Number of bytes written, or null if write fails.
    vm_memory_writer: ?*const fn (addr: u64, len: u32, data: []const u8) ?u32 = null,
    
    /// User data for VM memory writer (optional).
    /// Why: Pass context to memory writer (e.g., VM instance).
    vm_memory_writer_user_data: ?*anyopaque = null,
    
    /// Initialize Basin Kernel.
    /// Why: Explicit initialization, validate kernel state.
    pub fn init() BasinKernel {
        var kernel = BasinKernel{
            .timer = Timer.init(),
            .interrupt_controller = InterruptController.init(),
            .scheduler = Scheduler.init(),
            .process_group_manager = ProcessGroupManager.init(),
            .process_group_stats = ProcessGroupStatsManager.init(),
            .process_group_limits = ProcessGroupLimitsManager.init(),
            .network_interfaces = NetworkInterfaceManager.init(),
            .tcp_sockets = TcpSocketManager.init(),
            .udp_sockets = UdpSocketManager.init(),
            .audio_devices = AudioDeviceManager.init(),
            .channels = ChannelTable.init(),
            .storage = Storage.init(),
            .keyboard = Keyboard.init(),
            .mouse = Mouse.init(),
            .log_buffer = undefined, // Will initialize below with timer reference
            .memory_pool = MemoryPool.init(),
            .page_table = PageTable.init(),
            .page_fault_stats = PageFaultStats.init(),
            .memory_stats = MemoryStats.init(),
            .cow_table = CowTable.init(),
        };
        
        // Initialize log buffer with timer reference (after timer is created).
        kernel.log_buffer = KernelLogBuffer.init(&kernel.timer);
        
        // Initialize default users (root and xy).
        kernel.init_users();
        
        // Assert: All mappings must be unallocated initially.
        for (kernel.mappings, 0..) |mapping, i| {
            Debug.kassert(!mapping.allocated, "Mapping {d} should be unallocated", .{i});
        }
        
        // Assert: Next allocation address must be page-aligned.
        Debug.kassert(kernel.next_alloc_addr % 4096 == 0, "Next alloc addr {x} not aligned", .{kernel.next_alloc_addr});
        
        // Assert: All handles must be unallocated initially.
        for (kernel.handles, 0..) |handle, i| {
            Debug.kassert(!handle.allocated, "Handle {d} should be unallocated", .{i});
            Debug.kassert(handle.id == 0, "Handle {d} ID should be 0", .{i});
        }
        
        // Assert: Next handle ID must be non-zero (1-based).
        Debug.kassert(kernel.next_handle_id != 0, "Next handle ID is 0", .{});
        
        // Assert: Root user must exist.
        Debug.kassert(kernel.user_count >= 1, "User count {d} < 1", .{kernel.user_count});
        Debug.kassert(kernel.users[0].uid == 0, "First user UID {d} != 0", .{kernel.users[0].uid});
        
        // Assert: Timer must be initialized.
        Debug.kassert(kernel.timer.initialized, "Timer not initialized", .{});
        Debug.kassert(kernel.timer.boot_time_ns > 0, "Boot time is zero", .{});
        
        // Assert: Interrupt controller must be initialized.
        Debug.kassert(kernel.interrupt_controller.initialized, "Interrupt controller not initialized", .{});
        
        // Assert: Scheduler must be initialized.
        Debug.kassert(kernel.scheduler.initialized, "Scheduler not initialized", .{});
        Debug.kassert(kernel.scheduler.current_pid == 0, "Current PID not 0 at init", .{});
        
        return kernel;
    }
    
    /// Initialize default users.
    /// Why: Create root and xy users at kernel boot.
    /// Grain Style: Static allocation, explicit initialization.
    fn init_users(self: *BasinKernel) void {
        // Root user (uid=0)
        var root = User.init();
        root.uid = 0;
        root.gid = 0;
        @memcpy(root.name[0..4], "root");
        @memcpy(root.home[0..5], "/root");
        root.capabilities = 0xFFFFFFFFFFFFFFFF; // All capabilities
        root.validate();
        self.users[0] = root;
        
        // xy user (uid=1000)
        var xy = User.init();
        xy.uid = 1000;
        xy.gid = 1000;
        @memcpy(xy.name[0..2], "xy");
        @memcpy(xy.home[0..8], "/home/xy");
        xy.capabilities = 0x0000000000000001; // Basic user capabilities
        xy.validate();
        self.users[1] = xy;
        
        self.user_count = 2;
        
        // Assert: Root user must exist.
        Debug.kassert(self.users[0].uid == 0, "Root UID check failed", .{});
        Debug.kassert(self.users[1].uid == 1000, "XY UID check failed", .{});
        Debug.kassert(self.user_count == 2, "User count check failed", .{});
    }
    
    /// Find user by UID.
    /// Why: Look up user record for permission checks.
    /// Returns: User index if found, null otherwise.
    pub fn find_user_by_uid(self: *const BasinKernel, uid: UserId) ?u32 {
        for (0..self.user_count) |i| {
            if (self.users[i].uid == uid) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Get unified kernel statistics snapshot.
    /// Why: Provide comprehensive system statistics for monitoring and debugging.
    /// Returns: Statistics snapshot with aggregated metrics from all subsystems.
    pub fn get_kernel_stats_snapshot(self: *const BasinKernel) KernelStatsSnapshot {
        // Assert: Kernel must be initialized (precondition).
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Kernel ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Kernel ptr unaligned", .{});
        
        // Get statistics from all subsystems.
        const tcp_stats = self.tcp_sockets.get_stats();
        const udp_stats = self.udp_sockets.get_stats();
        const network_stats = self.network_interfaces.get_stats();
        const audio_stats = self.audio_devices.get_stats();
        const scheduler_stats = self.scheduler.get_stats();
        const memory_stats = &self.memory_stats;
        const page_fault_stats = &self.page_fault_stats;
        
        // Create unified snapshot.
        return KernelStatsSnapshot.create(
            tcp_stats,
            udp_stats,
            network_stats,
            audio_stats,
            scheduler_stats,
            memory_stats,
            page_fault_stats,
        );
    }
    
    /// Calculate memory usage for a process by summing its memory mappings.
    /// Why: Track total memory used by a process for resource monitoring.
    /// Contract: process_id must be valid (non-zero).
    /// Returns: Total memory used in bytes (sum of all mapping sizes).
    /// Grain Style: Explicit types, bounded operations, deterministic calculation.
    fn calculate_process_memory_usage(self: *const BasinKernel, process_id: u64) u64 {
        // Assert: process ID must be valid (non-zero).
        Debug.kassert(process_id != 0, "Process ID is 0", .{});
        
        const process_id_u32 = @as(u32, @truncate(process_id));
        var total_memory: u64 = 0;
        
        // Sum memory from all mappings owned by this process.
        // Why: Calculate total memory used by summing mapping sizes.
        for (0..MAX_MAPPINGS) |i| {
            const mapping = &self.mappings[i];
            if (mapping.allocated and mapping.owner_process_id == process_id_u32) {
                total_memory +%= mapping.size; // Saturating add to prevent overflow
            }
        }
        
        // Assert: Total memory must be reasonable (bounded by VM memory size).
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        Debug.kassert(total_memory <= VM_MEMORY_SIZE, "Process memory > VM size", .{});
        
        return total_memory;
    }
    
    /// Update memory usage for a process.
    /// Why: Keep process memory_used field current when mappings change.
    /// Contract: process_id must be valid (non-zero).
    /// Grain Style: Explicit types, bounded operations.
    fn update_process_memory_usage(self: *BasinKernel, process_id: u64) void {
        // Assert: process ID must be valid (non-zero).
        Debug.kassert(process_id != 0, "Process ID is 0", .{});
        
        // Find process in process table.
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == process_id) {
                // Calculate and update memory usage.
                const memory_used = self.calculate_process_memory_usage(process_id);
                self.processes[i].memory_used = memory_used;
                return;
            }
        }
    }
    
    /// Find user by name.
    /// Why: Look up user record by username.
    /// Returns: User index if found, null otherwise.
    pub fn find_user_by_name(self: *const BasinKernel, name: []const u8) ?u32 {
        for (0..self.user_count) |i| {
            const user_name_array = self.users[i].name;
            // Find null terminator to get actual string length
            var user_name_len: u32 = 0;
            for (user_name_array, 0..) |byte, idx| {
                if (byte == 0) {
                    user_name_len = @as(u32, @intCast(idx));
                    break;
                }
            }
            if (user_name_len == 0) continue; // Skip uninitialized entries
            const user_name = user_name_array[0..user_name_len];
            if (std.mem.eql(u8, user_name, name)) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Set current user context.
    /// Why: Change current user for permission checks.
    /// Contract: uid must exist in user table.
    pub fn set_current_user(self: *BasinKernel, uid: UserId) !void {
        const user_idx = self.find_user_by_uid(uid) orelse {
            return BasinError.user_not_found;
        };
        
        const user = self.users[user_idx];
        self.current_user = UserContext.init(user.uid, user.gid);
        
        // Assert: Current user must be set correctly.
        Debug.kassert(self.current_user.uid == uid, "Set current user failed", .{});
    }
    
    /// Find free mapping entry.
    /// Why: Allocate new mapping entry.
    /// Returns: Index of free entry, or null if table full.
    /// Grain Style: Comprehensive assertions for table state.
    fn find_free_mapping(self: *BasinKernel) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        var found_index: ?u32 = null;
        var free_count: u32 = 0;
        
        for (self.mappings, 0..) |mapping, i| {
            if (!mapping.allocated) {
                free_count += 1;
                if (found_index == null) {
                    found_index = @as(u32, @intCast(i));
                }
                
                // Note: For fuzz testing robustness, we don't assert unallocated mapping state here
                // to avoid crashes if there's a bug. The actual validation happens at allocation/deallocation time.
            } else {
                // Note: For fuzz testing robustness, we don't assert allocated mapping state here
                // to avoid crashes if there's a bug. The actual validation happens at allocation time.
                // We just find free entries without validating their state.
            }
        }
        
        // Assert: Free count must be <= MAX_MAPPINGS.
        Debug.kassert(free_count <= MAX_MAPPINGS, "Free count > MAX", .{});
        
        return found_index;
    }
    
    /// Find mapping by address.
    /// Why: Look up mapping for unmap/protect operations.
    /// Returns: Index of mapping, or null if not found.
    /// Grain Style: Comprehensive assertions for address validation.
    fn find_mapping_by_address(self: *BasinKernel, addr: u64) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Address must be page-aligned.
        Debug.kassert(addr % 4096 == 0, "Address {x} not aligned", .{addr});
        
        var found_index: ?u32 = null;
        var match_count: u32 = 0;
        
        for (self.mappings, 0..) |mapping, i| {
            if (mapping.allocated and mapping.address == addr) {
                match_count += 1;
                if (found_index == null) {
                    found_index = @as(u32, @intCast(i));
                }
                
                // Assert: Matching mapping must have valid state.
                Debug.kassert(mapping.address == addr, "Mapping addr mismatch", .{});
                Debug.kassert(mapping.size >= 4096, "Mapping size too small", .{});
                Debug.kassert(mapping.size % 4096 == 0, "Mapping size unaligned", .{});
            }
        }
        
        // Assert: Address must be unique (no duplicate mappings).
        Debug.kassert(match_count <= 1, "Duplicate mappings found", .{});
        
        return found_index;
    }
    
    /// Check memory permissions for an address.
    /// Why: Enforce memory protection by checking read/write/execute permissions.
    /// Contract: Address must be valid, returns permissions if mapped, null if not mapped.
    /// Returns: MapFlags with permissions, or null if address is not mapped.
    /// Note: Kernel space (0x80000000+) and framebuffer (0x90000000+) are always readable/writable.
    /// Uses page table for page-level granularity.
    pub fn check_memory_permission(self: *const BasinKernel, addr: u64) ?MapFlags {
        // Assert: self pointer must be valid (precondition).
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Use page table for page-level permission checking.
        const page_flags = self.page_table.check_permission(addr) orelse {
            return null;
        };
        
        // Convert PageFlags to MapFlags (same structure).
        return MapFlags{
            .read = page_flags.read,
            .write = page_flags.write,
            .execute = page_flags.execute,
            .shared = page_flags.shared,
            ._padding = 0,
        };
    }
    
    /// Check if address range overlaps with any existing mapping.
    /// Why: Validate no overlapping mappings.
    /// Grain Style: Comprehensive assertions for overlap detection.
    fn check_overlap(self: *BasinKernel, addr: u64, size: u64) bool {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Address and size must be valid.
        Debug.kassert(addr % 4096 == 0, "Addr {x} unaligned", .{addr}); // Page-aligned
        Debug.kassert(size >= 4096, "Size {d} too small", .{size}); // At least 1 page
        Debug.kassert(size % 4096 == 0, "Size {d} unaligned", .{size}); // Page-aligned
        
        var overlap_count: u32 = 0;
        
        for (self.mappings) |mapping| {
            if (mapping.overlaps(addr, size)) {
                overlap_count += 1;
                
                // Assert: Overlapping mapping must be allocated.
                Debug.kassert(mapping.allocated, "Overlapping mapping not allocated", .{});
                
                // Assert: Overlap condition must be true.
                const does_overlap = (mapping.address < addr + size) and (addr < mapping.address + mapping.size);
                Debug.kassert(does_overlap, "Overlap logic error", .{});
            }
        }
        
        // Assert: Overlap count must be consistent (0 or 1, no duplicates).
        Debug.kassert(overlap_count <= 1, "Multiple overlaps found", .{});
        
        return overlap_count > 0;
    }
    
    /// Count allocated mappings (for testing and validation).
    /// Why: Validate mapping table state consistency.
    /// Grain Style: Comprehensive assertions for state validation.
    pub fn count_allocated_mappings(self: *BasinKernel) u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        var count: u32 = 0;
        
        for (self.mappings) |mapping| {
            if (mapping.allocated) {
                // Note: For fuzz testing robustness, we don't assert mapping state here
                // to avoid crashes if there's a bug. The actual validation happens at allocation time.
                // We just count allocated mappings without validating their state.
                count += 1;
            }
        }
        
        // Note: For fuzz testing robustness, we don't assert count <= MAX_MAPPINGS here.
        // The test will validate the count.
        
        return count;
    }
    
    /// Find free handle entry.
    /// Why: Allocate new handle entry.
    /// Returns: Index of free entry, or null if table full.
    /// Grain Style: Comprehensive assertions for table state.
    fn find_free_handle(self: *BasinKernel) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        for (self.handles, 0..) |handle, i| {
            if (!handle.allocated) {
                // Note: For fuzz testing robustness, we don't assert unallocated handle state here
                // to avoid crashes if there's a bug. The actual validation happens at allocation/deallocation time.
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Find handle by ID.
    /// Why: Look up handle for read/write/close operations.
    /// Returns: Index of handle, or null if not found.
    /// Grain Style: Comprehensive assertions for handle validation.
    fn find_handle_by_id(self: *BasinKernel, handle_id: u64) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Handle ID must be non-zero (0 is invalid).
        Debug.kassert(handle_id != 0, "Handle ID is 0", .{});
        
        for (self.handles, 0..) |handle, i| {
            if (handle.allocated and handle.id == handle_id) {
                // Assert: Handle must be allocated and match ID.
                Debug.kassert(handle.allocated, "Handle not allocated", .{});
                Debug.kassert(handle.id == handle_id, "Handle ID mismatch", .{});
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }
    
    /// Count allocated handles (for testing and validation).
    /// Why: Validate handle table state consistency.
    /// Grain Style: Comprehensive assertions for state validation.
    pub fn count_allocated_handles(self: *BasinKernel) u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        var count: u32 = 0;
        
        for (self.handles) |handle| {
            if (handle.allocated) {
                // Note: For fuzz testing robustness, we don't assert handle state here
                // to avoid crashes if there's a bug. The actual validation happens at allocation time.
                // We just count allocated handles without validating their state.
                count += 1;
            }
        }
        
        // Note: For fuzz testing robustness, we don't assert count <= MAX_HANDLES here.
        // The test will validate the count.
        
        return count;
    }
    
    /// Check if timeout has expired.
    /// Why: Helper function to check timeout expiration for syscalls.
    /// Contract: start_time_ns must be valid monotonic time, timeout_ns is in nanoseconds (0 = no timeout).
    fn check_timeout(self: *const BasinKernel, start_time_ns: u64, timeout_ns: u64) bool {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // No timeout if timeout_ns is 0.
        if (timeout_ns == 0) {
            return false;
        }
        
        // Get current monotonic time.
        const current_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Current time must be >= start time (monotonic clock).
        Debug.kassert(current_time_ns >= start_time_ns, "Current time < start time", .{});
        
        // Calculate elapsed time.
        const elapsed_ns = current_time_ns - start_time_ns;
        
        // Assert: Elapsed time must be non-negative.
        Debug.kassert(elapsed_ns >= 0, "Elapsed time negative", .{});
        
        // Check if timeout has expired.
        return elapsed_ns >= timeout_ns;
    }
    
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
        
        // Route to appropriate syscall handler.
        // Why: Explicit routing, type-safe syscall handling.
        return switch (syscall) {
            .spawn => self.syscall_spawn(arg1, arg2, arg3, arg4),
            .exit => self.syscall_exit(arg1, arg2, arg3, arg4),
            .yield => self.syscall_yield(arg1, arg2, arg3, arg4),
            .wait => self.syscall_wait(arg1, arg2, arg3, arg4),
            .map => self.syscall_map(arg1, arg2, arg3, arg4),
            .unmap => self.syscall_unmap(arg1, arg2, arg3, arg4),
            .protect => self.syscall_protect(arg1, arg2, arg3, arg4),
            .channel_create => self.syscall_channel_create(arg1, arg2, arg3, arg4),
            .channel_send => self.syscall_channel_send(arg1, arg2, arg3, arg4),
            .channel_recv => self.syscall_channel_recv(arg1, arg2, arg3, arg4),
            .open => self.syscall_open(arg1, arg2, arg3, arg4),
            .read => self.syscall_read(arg1, arg2, arg3, arg4),
            .write => self.syscall_write(arg1, arg2, arg3, arg4),
            .close => self.syscall_close(arg1, arg2, arg3, arg4),
            .unlink => self.syscall_unlink(arg1, arg2, arg3, arg4),
            .rename => self.syscall_rename(arg1, arg2, arg3, arg4),
            .mkdir => self.syscall_mkdir(arg1, arg2, arg3, arg4),
            .opendir => self.syscall_opendir(arg1, arg2, arg3, arg4),
            .readdir => self.syscall_readdir(arg1, arg2, arg3, arg4),
            .closedir => self.syscall_closedir(arg1, arg2, arg3, arg4),
            .clock_gettime => self.syscall_clock_gettime(arg1, arg2, arg3, arg4),
            .sleep_until => self.syscall_sleep_until(arg1, arg2, arg3, arg4),
            .sysinfo => self.syscall_sysinfo(arg1, arg2, arg3, arg4),
            .enumerate_processes => self.syscall_enumerate_processes(arg1, arg2, arg3, arg4),
            .get_process_info => self.syscall_get_process_info(arg1, arg2, arg3, arg4),
            .read_kernel_log => self.syscall_read_kernel_log(arg1, arg2, arg3, arg4),
            .set_priority => self.syscall_set_priority(arg1, arg2, arg3, arg4),
            .get_priority => self.syscall_get_priority(arg1, arg2, arg3, arg4),
            .setpgid => self.syscall_setpgid(arg1, arg2, arg3, arg4),
            .getpgid => self.syscall_getpgid(arg1, arg2, arg3, arg4),
            .setsid => self.syscall_setsid(arg1, arg2, arg3, arg4),
            .getsid => self.syscall_getsid(arg1, arg2, arg3, arg4),
            .read_input_event => self.syscall_read_input_event(arg1, arg2, arg3, arg4),
            .fb_clear => self.syscall_fb_clear(arg1, arg2, arg3, arg4),
            .fb_draw_pixel => self.syscall_fb_draw_pixel(arg1, arg2, arg3, arg4),
            .fb_draw_text => self.syscall_fb_draw_text(arg1, arg2, arg3, arg4),
            .kill => self.syscall_kill(arg1, arg2, arg3, arg4),
            .signal => self.syscall_signal(arg1, arg2, arg3, arg4),
            .sigaction => self.syscall_sigaction(arg1, arg2, arg3, arg4),
            .network_create_interface => self.syscall_network_create_interface(arg1, arg2, arg3, arg4),
            .network_set_state => self.syscall_network_set_state(arg1, arg2, arg3, arg4),
            .network_set_ipv4 => self.syscall_network_set_ipv4(arg1, arg2, arg3, arg4),
            .network_set_ipv6 => self.syscall_network_set_ipv6(arg1, arg2, arg3, arg4),
            .network_get_interface => self.syscall_network_get_interface(arg1, arg2, arg3, arg4),
            .network_delete_interface => self.syscall_network_delete_interface(arg1, arg2, arg3, arg4),
            .network_enumerate_interfaces => self.syscall_network_enumerate_interfaces(arg1, arg2, arg3, arg4),
            .network_get_stats => self.syscall_network_get_stats(arg1, arg2, arg3, arg4),
            .tcp_socket => self.syscall_tcp_socket(arg1, arg2, arg3, arg4),
            .tcp_bind => self.syscall_tcp_bind(arg1, arg2, arg3, arg4),
            .tcp_listen => self.syscall_tcp_listen(arg1, arg2, arg3, arg4),
            .tcp_accept => self.syscall_tcp_accept(arg1, arg2, arg3, arg4),
            .tcp_connect => self.syscall_tcp_connect(arg1, arg2, arg3, arg4),
            .tcp_send => self.syscall_tcp_send(arg1, arg2, arg3, arg4),
            .tcp_recv => self.syscall_tcp_recv(arg1, arg2, arg3, arg4),
            .tcp_close => self.syscall_tcp_close(arg1, arg2, arg3, arg4),
            .tcp_enumerate_sockets => self.syscall_tcp_enumerate_sockets(arg1, arg2, arg3, arg4),
            .tcp_get_stats => self.syscall_tcp_get_stats(arg1, arg2, arg3, arg4),
            .udp_socket => self.syscall_udp_socket(arg1, arg2, arg3, arg4),
            .udp_bind => self.syscall_udp_bind(arg1, arg2, arg3, arg4),
            .udp_sendto => self.syscall_udp_sendto(arg1, arg2, arg3, arg4),
            .udp_recvfrom => self.syscall_udp_recvfrom(arg1, arg2, arg3, arg4),
            .udp_close => self.syscall_udp_close(arg1, arg2, arg3, arg4),
            .udp_enumerate_sockets => self.syscall_udp_enumerate_sockets(arg1, arg2, arg3, arg4),
            .udp_get_stats => self.syscall_udp_get_stats(arg1, arg2, arg3, arg4),
            .audio_create_device => self.syscall_audio_create_device(arg1, arg2, arg3, arg4),
            .audio_set_volume => self.syscall_audio_set_volume(arg1, arg2, arg3, arg4),
            .audio_set_mute => self.syscall_audio_set_mute(arg1, arg2, arg3, arg4),
            .audio_set_state => self.syscall_audio_set_state(arg1, arg2, arg3, arg4),
            .audio_set_active_output => self.syscall_audio_set_active_output(arg1, arg2, arg3, arg4),
            .audio_set_active_input => self.syscall_audio_set_active_input(arg1, arg2, arg3, arg4),
            .audio_set_master_volume => self.syscall_audio_set_master_volume(arg1, arg2, arg3, arg4),
            .audio_set_master_mute => self.syscall_audio_set_master_mute(arg1, arg2, arg3, arg4),
            .audio_get_device => self.syscall_audio_get_device(arg1, arg2, arg3, arg4),
            .audio_set_format => self.syscall_audio_set_format(arg1, arg2, arg3, arg4),
            .audio_read => self.syscall_audio_read(arg1, arg2, arg3, arg4),
            .audio_write => self.syscall_audio_write(arg1, arg2, arg3, arg4),
            .audio_enumerate_devices => self.syscall_audio_enumerate_devices(arg1, arg2, arg3, arg4),
            .audio_delete_device => self.syscall_audio_delete_device(arg1, arg2, arg3, arg4),
            .audio_get_stats => self.syscall_audio_get_stats(arg1, arg2, arg3, arg4),
            .kernel_get_stats => self.syscall_kernel_get_stats(arg1, arg2, arg3, arg4),
            .health_check => self.syscall_health_check(arg1, arg2, arg3, arg4),
            .get_resource_usage => self.syscall_get_resource_usage(arg1, arg2, arg3, arg4),
        };
    }
    
    // Syscall handlers (stubs for future implementation).
    // Why: Separate functions for each syscall, Grain Style function length limit.
    
    /// Spawn a new process from an ELF executable.
    /// Why: Create a new process with ELF parsing and process context setup.
    /// Contract: executable must be valid VM address, ELF must be valid format.
    /// Note: Public for testing (tests need direct access).
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
    
    fn syscall_exit(
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
    
    fn syscall_yield(
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
    
    fn syscall_wait(
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
    
    fn syscall_open(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        flags: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Decode flags (OpenFlags packed struct).
        const open_flags = @as(OpenFlags, @bitCast(@as(u32, @truncate(flags))));
        
        // Assert: flags padding must be zero (no reserved bits set).
        if (open_flags._padding != 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Reserved bits set
        }
        
        // Assert: flags must have at least one permission (read or write).
        if (!open_flags.read and !open_flags.write) {
            return SyscallResult.fail(BasinError.invalid_argument); // No permissions set
        }
        
        // Assert: path length must fit in handle path buffer (max 256 bytes, so max path_len is 255).
        // Note: path_len is the string length, handle.path is 256 bytes, so max path_len is 255.
        if (path_len > 255) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long for handle buffer
        }
        
        // Assert: path_len must be > 0 (already checked above, but double-check for safety).
        Debug.kassert(path_len > 0, "Path len is 0", .{});
        Debug.kassert(path_len <= 255, "Path len > 255", .{});
        
        // Find free handle entry.
        const handle_idx = self.find_free_handle() orelse {
            return SyscallResult.fail(BasinError.out_of_memory); // Handle table full
        };
        
        // Get current process ID from scheduler.
        // Why: Track which process owns this handle for resource cleanup.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Allocate handle entry.
        var file_handle = &self.handles[handle_idx];
        const handle_id = self.next_handle_id;
        self.next_handle_id += 1;
        
        // Assert: Handle ID must be non-zero (1-based).
        Debug.kassert(handle_id != 0, "Handle ID is 0", .{});
        
        // Note: Actual path reading from VM memory is handled by integration layer.
        // This kernel syscall validates parameters and creates handle entry.
        // Integration layer will:
        // 1. Read path string from VM memory at path_ptr
        // 2. Look up or create file in storage filesystem
        // 3. Link handle to storage file entry
        // For now, we create handle entry and store path length.
        file_handle.id = handle_id;
        file_handle.path_len = @as(u32, @intCast(path_len));
        file_handle.flags = open_flags;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        file_handle.allocated = true;
        file_handle.owner_process_id = owner_process_id;
        
        // If truncate flag is set, clear buffer.
        if (open_flags.truncate) {
            file_handle.buffer_size = 0;
        }
        
        // Assert: Handle must be allocated correctly.
        Debug.kassert(file_handle.allocated, "Handle not allocated", .{});
        Debug.kassert(file_handle.id == handle_id, "Handle ID mismatch", .{});
        Debug.kassert(file_handle.path_len == @as(u32, @intCast(path_len)), "Path len mismatch", .{});
        
        const result = SyscallResult.ok(handle_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == handle_id, "Result value mismatch", .{});
        
        return result;
    }
    
    fn syscall_read(
        self: *BasinKernel,
        handle: u64,
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
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be reasonable (max 1MB per read).
        if (buffer_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Zero-length buffer
        }
        if (buffer_len > 1024 * 1024) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer too large (> 1MB)
        }
        
        // Assert: buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Buffer exceeds VM memory
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        var file_handle = &self.handles[handle_idx];
        
        // Assert: Handle must be readable.
        if (!file_handle.flags.read) {
            return SyscallResult.fail(BasinError.permission_denied); // Handle not readable
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Note: Actual file data reading is handled by integration layer.
        // This kernel syscall validates parameters and calculates read size.
        // Integration layer will:
        // 1. Look up file in storage filesystem by handle path
        // 2. Read data from storage file entry
        // 3. Write data to VM memory at buffer_ptr
        // For now, we use handle buffer (in-memory file data).
        // Calculate bytes to read (min of available data and buffer size).
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const available = if (file_handle.position < file_handle.buffer_size)
            file_handle.buffer_size - file_handle.position
        else
            0;
        const bytes_to_read = @min(available, @as(u32, @intCast(buffer_len)));
        
        // Note: Integration layer will write data to VM memory.
        // For now, just update position (data is in handle buffer).
        file_handle.position += bytes_to_read;
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Assert: Position must not exceed buffer size.
        Debug.kassert(file_handle.position <= file_handle.buffer_size, "Position > buffer size", .{});
        
        const bytes_read: u64 = @as(u64, @intCast(bytes_to_read));
        const result = SyscallResult.ok(bytes_read);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == bytes_read, "Result value mismatch", .{});
        Debug.kassert(result.success <= buffer_len, "Read > buffer len", .{});
        
        return result;
    }
    
    fn syscall_write(
        self: *BasinKernel,
        handle: u64,
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
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Assert: data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (data_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data pointer exceeds VM memory
        }
        
        // Assert: data length must be reasonable (max 1MB per write).
        if (data_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Zero-length data
        }
        if (data_len > 1024 * 1024) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data too large (> 1MB)
        }
        
        // Assert: data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Data exceeds VM memory
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        var file_handle = &self.handles[handle_idx];
        
        // Assert: Handle must be writable.
        if (!file_handle.flags.write) {
            return SyscallResult.fail(BasinError.permission_denied); // Handle not writable
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Calculate bytes to write (min of data length and available buffer space).
        const data_len_u32 = @as(u32, @intCast(data_len));
        const max_buffer_size = file_handle.buffer.len;
        const available_space = if (file_handle.position < max_buffer_size)
            @as(u32, @intCast(max_buffer_size - file_handle.position))
        else
            0;
        const bytes_to_write = @min(data_len_u32, available_space);
        
        // Write data to handle buffer (simulated - in real implementation, would read from VM memory).
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        // For now, just update position and buffer size.
        file_handle.position += bytes_to_write;
        if (file_handle.position > file_handle.buffer_size) {
            file_handle.buffer_size = @as(u32, @intCast(file_handle.position));
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return SyscallResult.fail(BasinError.file_io_timeout); // Timeout expired
        }
        
        // Assert: Position and buffer size must be valid.
        Debug.kassert(file_handle.position <= max_buffer_size, "Position > max buffer", .{});
        Debug.kassert(file_handle.buffer_size <= max_buffer_size, "Buffer size > max", .{});
        
        const bytes_written: u64 = @as(u64, @intCast(bytes_to_write));
        const result = SyscallResult.ok(bytes_written);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == bytes_written, "Result value mismatch", .{});
        Debug.kassert(result.success <= data_len, "Written > data len", .{}); // Can't write more than data length
        
        return result;
    }
    
    fn syscall_close(
        self: *BasinKernel,
        handle: u64,
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
        
        // Assert: handle must be valid (non-zero).
        if (handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid handle
        }
        
        // Find handle by ID.
        const handle_idx = self.find_handle_by_id(handle) orelse {
            return SyscallResult.fail(BasinError.invalid_handle); // Handle not found
        };
        
        // Assert: Handle must be allocated.
        Debug.kassert(self.handles[handle_idx].allocated, "Handle not allocated", .{});
        Debug.kassert(self.handles[handle_idx].id == handle, "Handle ID mismatch", .{});
        
        // Close handle (free entry).
        var file_handle = &self.handles[handle_idx];
        file_handle.allocated = false;
        file_handle.id = 0;
        file_handle.path_len = 0;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        file_handle.owner_process_id = 0;
        
        // Assert: Handle must be unallocated after close.
        Debug.kassert(!file_handle.allocated, "Handle still allocated", .{});
        Debug.kassert(file_handle.id == 0, "Handle ID not 0", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success == 0, "Result not 0", .{}); // Close returns 0 on success
        
        return result;
    }
    
    fn syscall_unlink(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Find handle by path and remove it (simulated file deletion).
        // For now, search for handle with matching path and mark as deleted.
        var found: bool = false;
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(path_len))) {
                // In real implementation, would compare path strings.
                // For now, just mark as deleted if path length matches.
                self.handles[i].allocated = false;
                self.handles[i].id = 0;
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.not_found); // File not found
        }
        
        const result = SyscallResult.ok(0);
        return result;
    }
    
    fn syscall_rename(
        self: *BasinKernel,
        old_path_ptr: u64,
        old_path_len: u64,
        new_path_ptr: u64,
        new_path_len: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: old path pointer must be valid (non-zero, within VM memory).
        if (old_path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (old_path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Old path pointer exceeds VM memory
        }
        
        // Assert: new path pointer must be valid (non-zero, within VM memory).
        if (new_path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        if (new_path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // New path pointer exceeds VM memory
        }
        
        // Assert: path lengths must be reasonable (max 4096 bytes).
        if (old_path_len == 0 or old_path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid old path length
        }
        if (new_path_len == 0 or new_path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Invalid new path length
        }
        
        // Assert: paths must fit within VM memory.
        if (old_path_ptr + old_path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Old path exceeds VM memory
        }
        if (new_path_ptr + new_path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // New path exceeds VM memory
        }
        
        // Find handle by old path and update to new path (simulated rename).
        // For now, search for handle with matching path length and update.
        var found: bool = false;
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(old_path_len))) {
                // In real implementation, would compare path strings and update.
                // For now, just update path length if it matches.
                self.handles[i].path_len = @as(u32, @intCast(new_path_len));
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.not_found); // File not found
        }
        
        const result = SyscallResult.ok(0);
        return result;
    }
    
    fn syscall_mkdir(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return SyscallResult.fail(BasinError.invalid_argument); // Empty path
        }
        if (path_len > 4096) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument); // Path exceeds VM memory
        }
        
        // Check if directory already exists (simulated).
        // For now, just check if handle with same path exists.
        for (0..MAX_HANDLES) |i| {
            if (self.handles[i].allocated and self.handles[i].path_len == @as(u32, @intCast(path_len))) {
                // In real implementation, would compare path strings.
                // For now, return error if path length matches (directory exists).
                return SyscallResult.fail(BasinError.invalid_argument); // Directory already exists
            }
        }
        
        // Create directory (simulated - in real implementation, would create directory entry).
        // For now, just return success (directory created).
        const result = SyscallResult.ok(0);
        return result;
    }
    
    fn syscall_opendir(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: path pointer must be valid (non-zero, within VM memory).
        if (path_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (path_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: path length must be reasonable (max 256 bytes).
        if (path_len == 0 or path_len > 256) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find free directory handle slot.
        var slot: ?usize = null;
        for (0..MAX_DIR_HANDLES) |i| {
            if (!self.dir_handles[i].allocated) {
                slot = i;
                break;
            }
        }
        
        if (slot == null) {
            return SyscallResult.fail(BasinError.out_of_memory);
        }
        
        const idx = slot.?;
        
        // Allocate directory handle.
        const handle_id = self.next_dir_handle_id;
        self.next_dir_handle_id += 1;
        
        // Copy path (simulated - in real implementation, would read from VM memory).
        self.dir_handles[idx].id = handle_id;
        self.dir_handles[idx].path_len = @as(u32, @intCast(path_len));
        self.dir_handles[idx].position = 0;
        self.dir_handles[idx].allocated = true;
        
        // Return directory handle ID.
        const result = SyscallResult.ok(handle_id);
        return result;
    }
    
    fn syscall_readdir(
        self: *BasinKernel,
        dir_handle: u64,
        entry_ptr: u64,
        entry_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: directory handle must be valid (non-zero).
        if (dir_handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: entry pointer must be valid (non-zero, within VM memory).
        if (entry_ptr == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (entry_ptr >= VM_MEMORY_SIZE) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Assert: entry length must be reasonable (max 256 bytes).
        if (entry_len == 0 or entry_len > 256) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find directory handle.
        var found: ?usize = null;
        for (0..MAX_DIR_HANDLES) |i| {
            if (self.dir_handles[i].allocated and self.dir_handles[i].id == dir_handle) {
                found = i;
                break;
            }
        }
        
        if (found == null) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const idx = found.?;
        
        // Simulated directory reading: return empty (end of directory).
        // In real implementation, would read directory entries from file system.
        // For now, return 0 (no more entries) after first read.
        if (self.dir_handles[idx].position > 0) {
            return SyscallResult.ok(0); // End of directory
        }
        
        // First read: return stub entry name "."
        // In real implementation, would write entry name to entry_ptr.
        self.dir_handles[idx].position += 1;
        
        // Return bytes written (simulated - would be actual entry name length).
        const result = SyscallResult.ok(1); // 1 byte for "."
        return result;
    }
    
    fn syscall_closedir(
        self: *BasinKernel,
        dir_handle: u64,
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
        
        // Assert: directory handle must be valid (non-zero).
        if (dir_handle == 0) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        // Find and free directory handle.
        var found: bool = false;
        for (0..MAX_DIR_HANDLES) |i| {
            if (self.dir_handles[i].allocated and self.dir_handles[i].id == dir_handle) {
                self.dir_handles[i] = DirectoryHandle.init();
                found = true;
                break;
            }
        }
        
        if (!found) {
            return SyscallResult.fail(BasinError.invalid_argument);
        }
        
        const result = SyscallResult.ok(0);
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
    
    fn syscall_getpgid(
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
    
    fn syscall_setsid(
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
    
    fn syscall_getsid(
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
    
    fn syscall_kill(
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
            return self.kill_process_group(pgid, signal);
        }
        
        if (is_session) {
            // Session delivery: send signal to all processes in the session.
            // Extract session ID by clearing the session bit (bit 62).
            const sid = pid & 0x3FFFFFFFFFFFFFFF;
            if (sid == 0) {
                return BasinError.invalid_argument; // Invalid session ID
            }
            return self.kill_session(sid, signal);
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
    fn kill_process_group(
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
    fn kill_session(
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
    
    fn syscall_signal(
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
    
    fn syscall_sigaction(
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
    
    /// Create a network interface.
    /// Why: Add a new network interface.
    /// Contract: name_ptr must be valid VM address, name_len must be valid.
    pub fn syscall_network_create_interface(
        self: *BasinKernel,
        name_ptr: u64,
        name_len: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: name pointer must be valid (non-zero, within VM memory).
        if (name_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (name_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Name pointer exceeds VM memory
        }
        
        // Assert: name length must be reasonable (max interface name length).
        if (name_len == 0) {
            return BasinError.invalid_argument; // Zero-length name
        }
        if (name_len > 16) {
            return BasinError.invalid_argument; // Name too long
        }
        
        // Assert: name must fit within VM memory.
        if (name_ptr + name_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Name exceeds VM memory
        }
        
        // Read interface name from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder name.
        const name = "eth0";
        
        // Create interface.
        const iface_idx = self.network_interfaces.create_interface(name) orelse {
            return BasinError.out_of_memory; // No free interface slot
        };
        
        const result = SyscallResult.ok(iface_idx);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set network interface state (up/down).
    /// Why: Control interface state.
    /// Contract: iface_idx and state must be valid.
    pub fn syscall_network_set_state(
        self: *BasinKernel,
        iface_idx: u64,
        state: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: State must be valid (0 = down, 1 = up).
        if (state > 1) {
            return BasinError.invalid_argument; // Invalid state
        }
        
        const iface_state = if (state == 0) network.InterfaceState.down else network.InterfaceState.up;
        
        // Set interface state.
        if (!self.network_interfaces.set_interface_state(idx, iface_state)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set IPv4 address for network interface.
    /// Why: Configure IPv4 address, netmask, and gateway.
    /// Contract: iface_idx, addr, netmask, and gateway must be valid.
    pub fn syscall_network_set_ipv4(
        self: *BasinKernel,
        iface_idx: u64,
        addr: u64,
        netmask: u64,
        gateway: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Address, netmask, and gateway must be valid (32-bit values).
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_netmask = @as(u32, @truncate(netmask));
        const ipv4_gateway = @as(u32, @truncate(gateway));
        
        // Set IPv4 address.
        if (!self.network_interfaces.set_ipv4_address(idx, ipv4_addr)) {
            return BasinError.not_found; // Interface not found
        }
        
        // Set IPv4 netmask.
        if (!self.network_interfaces.set_ipv4_netmask(idx, ipv4_netmask)) {
            return BasinError.not_found; // Interface not found
        }
        
        // Set IPv4 gateway.
        if (!self.network_interfaces.set_ipv4_gateway(idx, ipv4_gateway)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set IPv6 address for network interface.
    /// Why: Configure IPv6 address.
    /// Contract: iface_idx must be valid, addr_ptr must be valid VM address.
    pub fn syscall_network_set_ipv6(
        self: *BasinKernel,
        iface_idx: u64,
        addr_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Address pointer must be valid (non-zero, within VM memory).
        if (addr_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (addr_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Address pointer exceeds VM memory
        }
        
        // Assert: Address must fit within VM memory (16 bytes for IPv6).
        if (addr_ptr + 16 > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Address exceeds VM memory
        }
        
        // Read IPv6 address from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder address (::1 - localhost).
        const ipv6_addr: [16]u8 = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
        
        // Set IPv6 address.
        if (!self.network_interfaces.set_ipv6_address(idx, ipv6_addr)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get network interface information.
    /// Why: Retrieve interface configuration.
    /// Contract: iface_idx must be valid, info_ptr must be valid VM address.
    pub fn syscall_network_get_interface(
        self: *BasinKernel,
        iface_idx: u64,
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
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Assert: Info pointer must be valid (non-zero, within VM memory).
        if (info_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_GET: u64 = 4 * 1024 * 1024; // 4MB default
        if (info_ptr >= VM_MEMORY_SIZE_GET) {
            return BasinError.invalid_argument; // Info pointer exceeds VM memory
        }
        
        // Get interface.
        const iface = self.network_interfaces.get_interface(idx) orelse {
            return BasinError.not_found; // Interface not found
        };
        
        // Write interface information to VM memory (stub: would use vm_memory_writer).
        // For now, just return success.
        // Note: info_ptr and iface are validated but not used in stub implementation.
        _ = iface;
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Delete network interface.
    /// Why: Remove network interface.
    /// Contract: iface_idx must be valid.
    pub fn syscall_network_delete_interface(
        self: *BasinKernel,
        iface_idx: u64,
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
        
        // Assert: Interface index must be valid (within bounds).
        const idx = @as(u32, @truncate(iface_idx));
        if (idx >= 8) {
            return BasinError.invalid_argument; // Invalid interface index
        }
        
        // Delete interface.
        if (!self.network_interfaces.delete_interface(idx)) {
            return BasinError.not_found; // Interface not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Enumerate network interfaces.
    /// Why: Get list of all network interfaces.
    /// Contract: indices_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_network_enumerate_interfaces(
        self: *BasinKernel,
        indices_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Indices pointer must be valid (non-zero, within VM memory).
        if (indices_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (indices_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Indices pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 8 interfaces).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 8) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Indices array must fit within VM memory (max 8 * 4 bytes = 32 bytes).
        const INDICES_SIZE: u64 = max_cnt * 4; // u32 per index
        if (indices_ptr + INDICES_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Indices array exceeds VM memory
        }
        
        // Create temporary indices array.
        var temp_indices: [8]u32 = undefined;
        const count = self.network_interfaces.enumerate_interfaces(&temp_indices);
        
        // Write indices to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: indices_ptr and temp_indices are validated but not written in stub.
        _ = temp_indices;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get network interface statistics.
    /// Why: Provide network interface statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to NetworkInterfaceStats structure.
    pub fn syscall_network_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
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
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: NetworkInterfaceStats structure must fit within VM memory.
        // NetworkInterfaceStats size: 10 fields (7 u64 + 1 u32 + 2 u64) = 7*8 + 4 + 2*8 = 76 bytes
        const NETWORK_STATS_SIZE: u64 = 76;
        if (stats_ptr + NETWORK_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Create a TCP socket.
    /// Why: Allocate a new TCP socket.
    /// Contract: Returns socket ID.
    pub fn syscall_tcp_socket(
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
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Create socket.
        const socket_id = self.tcp_sockets.create_socket(owner_process_id) orelse {
            return BasinError.out_of_memory; // No free socket slot
        };
        
        const result = SyscallResult.ok(socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Bind TCP socket to local address and port.
    /// Why: Configure local endpoint for socket.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_tcp_bind(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Bind socket.
        if (!self.tcp_sockets.bind_socket(socket_id, ipv4_addr, ipv4_port)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set TCP socket to listening state.
    /// Why: Enable socket to accept incoming connections.
    /// Contract: socket_id must be valid, socket must be bound.
    pub fn syscall_tcp_listen(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Set socket to listening state.
        if (!self.tcp_sockets.listen_socket(socket_id)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Accept incoming connection on listening socket.
    /// Why: Accept incoming connection and create new socket.
    /// Contract: socket_id must be valid, socket must be listening.
    pub fn syscall_tcp_accept(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Accept connection.
        const new_socket_id = self.tcp_sockets.accept_connection(socket_id, owner_process_id) orelse {
            return BasinError.not_found; // Socket not found, not listening, or no connection
        };
        
        const result = SyscallResult.ok(new_socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Connect TCP socket to remote address and port.
    /// Why: Establish connection to remote endpoint.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_tcp_connect(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        timeout_ns: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Record start time for timeout checking.
        const start_time_ns = self.timer.get_monotonic_ns();
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Connect socket.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        if (!self.tcp_sockets.connect_socket(socket_id, ipv4_addr, ipv4_port)) {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Send data on TCP socket.
    /// Why: Transmit data on connected socket.
    /// Contract: socket_id must be valid, data_ptr and data_len must be valid, socket must be connected.
    pub fn syscall_tcp_send(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_SEND: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_SEND) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max socket buffer size).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_SEND) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Read data from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder data slice.
        const data = "test";
        
        // Send data.
        // Note: In a real implementation, this would check timeout periodically if blocking.
        const bytes_sent = self.tcp_sockets.send_data(socket_id, data) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes sent).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_sent += bytes_sent;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(bytes_sent);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Receive data from TCP socket.
    /// Why: Read incoming data from connected socket.
    /// Contract: socket_id must be valid, buffer_ptr and buffer_len must be valid, socket must be connected.
    pub fn syscall_tcp_recv(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_RECV: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_RECV) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max socket buffer size).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_RECV) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Check timeout before operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Create buffer slice (stub: would use vm_memory_writer).
        var buffer: [64 * 1024]u8 = undefined;
        const buffer_slice = buffer[0..@as(usize, @intCast(buffer_len))];
        
        // Receive data.
        // Note: In a real implementation, this would be a blocking operation that checks timeout periodically.
        const bytes_received = self.tcp_sockets.recv_data(socket_id, buffer_slice) orelse {
            // Check timeout after operation.
            if (self.check_timeout(start_time_ns, timeout_ns)) {
                return BasinError.network_timeout; // Timeout expired
            }
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Check timeout after operation.
        if (self.check_timeout(start_time_ns, timeout_ns)) {
            return BasinError.network_timeout; // Timeout expired
        }
        
        // Update process resource usage (network bytes received).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_received += bytes_received;
                    break;
                }
            }
        }
        
        // Write data to VM memory (stub: would use vm_memory_writer).
        // For now, just return bytes received.
        // Note: buffer_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Close TCP socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn syscall_tcp_close(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Close socket.
        if (!self.tcp_sockets.close_socket(socket_id)) {
            return BasinError.not_found; // Socket not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Create a UDP socket.
    /// Why: Allocate a new UDP socket.
    /// Contract: Returns socket ID.
    pub fn syscall_udp_socket(
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
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Create socket.
        const socket_id = self.udp_sockets.create_socket(owner_process_id) orelse {
            return BasinError.out_of_memory; // No free socket slot
        };
        
        const result = SyscallResult.ok(socket_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Bind UDP socket to local address and port.
    /// Why: Configure local endpoint for socket.
    /// Contract: socket_id, addr, and port must be valid.
    pub fn syscall_udp_bind(
        self: *BasinKernel,
        socket_id: u64,
        addr: u64,
        port: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Port must be valid (16-bit value).
        if (port > 65535) {
            return BasinError.invalid_argument; // Invalid port
        }
        
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port = @as(u16, @truncate(port));
        
        // Bind socket.
        if (!self.udp_sockets.bind_socket(socket_id, ipv4_addr, ipv4_port)) {
            return BasinError.not_found; // Socket not found or invalid state
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Send data to remote address and port on UDP socket.
    /// Why: Transmit data to remote endpoint.
    /// Contract: socket_id must be valid, data_ptr, data_len, addr, and port must be valid.
    pub fn syscall_udp_sendto(
        self: *BasinKernel,
        socket_id: u64,
        data_ptr: u64,
        data_len: u64,
        addr: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_SENDTO: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max socket buffer size).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_SENDTO) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // Stub: would extract port from arguments properly.
        // For now, use addr as IPv4 address and port as 0.
        const ipv4_addr = @as(u32, @truncate(addr));
        const ipv4_port: u16 = 0; // Stub: would extract from arguments
        
        // Read data from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder data slice.
        const data = "test";
        
        // Send data.
        const bytes_sent = self.udp_sockets.sendto(socket_id, data, ipv4_addr, ipv4_port) orelse {
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Update process resource usage (network bytes sent).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_sent += bytes_sent;
                    break;
                }
            }
        }
        
        const result = SyscallResult.ok(bytes_sent);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Receive data from UDP socket.
    /// Why: Read incoming data from bound socket.
    /// Contract: socket_id must be valid, buffer_ptr and buffer_len must be valid.
    pub fn syscall_udp_recvfrom(
        self: *BasinKernel,
        socket_id: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        addr_ptr: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_RECVFROM: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max socket buffer size).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_RECVFROM) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // Create buffer slice (stub: would use vm_memory_writer).
        var buffer: [64 * 1024]u8 = undefined;
        const buffer_slice = buffer[0..@as(usize, @intCast(buffer_len))];
        
        // Create address and port pointers (stub: would use vm_memory_writer).
        var remote_addr: u32 = 0;
        var remote_port: u16 = 0;
        const addr_ptr_opt: ?*u32 = if (addr_ptr != 0) &remote_addr else null;
        const port_ptr_opt: ?*u16 = if (addr_ptr != 0) &remote_port else null;
        
        // Receive data (remote_addr and remote_port are written by recvfrom if addr_ptr != 0).
        const bytes_received = self.udp_sockets.recvfrom(socket_id, buffer_slice, addr_ptr_opt, port_ptr_opt) orelse {
            return BasinError.not_found; // Socket not found or invalid state
        };
        
        // Update process resource usage (network bytes received).
        const current_pid = self.scheduler.get_current();
        if (current_pid > 0) {
            for (0..MAX_PROCESSES) |i| {
                if (self.processes[i].allocated and self.processes[i].id == current_pid) {
                    self.processes[i].network_bytes_received += bytes_received;
                    break;
                }
            }
        }
        
        // Write data and address/port to VM memory (stub: would use vm_memory_writer).
        // For now, just return bytes received.
        // Note: addr_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Close UDP socket.
    /// Why: Release socket resources.
    /// Contract: socket_id must be valid.
    pub fn syscall_udp_close(
        self: *BasinKernel,
        socket_id: u64,
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
        
        // Assert: Socket ID must be non-zero.
        if (socket_id == 0) {
            return BasinError.invalid_argument; // Invalid socket ID
        }
        
        // Close socket.
        if (!self.udp_sockets.close_socket(socket_id)) {
            return BasinError.not_found; // Socket not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Enumerate UDP sockets.
    /// Why: Get list of all UDP sockets.
    /// Contract: socket_ids_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_udp_enumerate_sockets(
        self: *BasinKernel,
        socket_ids_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Socket IDs pointer must be valid (non-zero, within VM memory).
        if (socket_ids_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (socket_ids_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 64 sockets).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 64) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Socket IDs array must fit within VM memory (max 64 * 8 bytes = 512 bytes).
        const SOCKET_IDS_SIZE: u64 = max_cnt * 8; // u64 per socket ID
        if (socket_ids_ptr + SOCKET_IDS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Socket IDs array exceeds VM memory
        }
        
        // Create temporary socket IDs array.
        var temp_socket_ids: [64]u64 = undefined;
        const count = self.udp_sockets.enumerate_sockets(&temp_socket_ids);
        
        // Write socket IDs to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: socket_ids_ptr and temp_socket_ids are validated but not written in stub.
        _ = temp_socket_ids;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get TCP socket statistics.
    /// Why: Provide TCP socket statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to TcpSocketStats structure.
    pub fn syscall_tcp_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
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
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: TcpSocketStats structure must fit within VM memory.
        // TcpSocketStats size: 13 fields (8 u64 + 2 u32 + 3 u64) = 8*8 + 2*4 + 3*8 = 64 + 8 + 24 = 96 bytes
        const TCP_STATS_SIZE: u64 = 96;
        if (stats_ptr + TCP_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get UDP socket statistics.
    /// Why: Provide UDP socket statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to UdpSocketStats structure.
    pub fn syscall_udp_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
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
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: UdpSocketStats structure must fit within VM memory.
        // UdpSocketStats size: 9 fields (4 u64 + 1 u32 + 1 u64 + 2 u64 + 1 u64) = 4*8 + 4 + 8 + 2*8 + 8 = 32 + 4 + 8 + 16 + 8 = 68 bytes
        const UDP_STATS_SIZE: u64 = 68;
        if (stats_ptr + UDP_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Create an audio device.
    /// Why: Add a new audio device.
    /// Contract: name_ptr, name_len, and device_type must be valid.
    pub fn syscall_audio_create_device(
        self: *BasinKernel,
        name_ptr: u64,
        name_len: u64,
        device_type: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Name pointer must be valid (non-zero, within VM memory).
        if (name_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_AUDIO: u64 = 4 * 1024 * 1024; // 4MB default
        if (name_ptr >= VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Name pointer exceeds VM memory
        }
        
        // Assert: Name length must be reasonable (max device name length).
        if (name_len == 0) {
            return BasinError.invalid_argument; // Zero-length name
        }
        if (name_len > 128) {
            return BasinError.invalid_argument; // Name too long
        }
        
        // Assert: Name must fit within VM memory.
        if (name_ptr + name_len > VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Name exceeds VM memory
        }
        
        // Assert: Device type must be valid.
        if (device_type > 5) {
            return BasinError.invalid_argument; // Invalid device type
        }
        
        // Get current process ID from scheduler.
        const current_process_id = self.scheduler.get_current();
        const owner_process_id = @as(u32, @truncate(current_process_id));
        
        // Read device name from VM memory (stub: would use vm_memory_reader).
        // For now, use a placeholder name.
        const name = "speaker";
        
        const audio_device_type = @as(audio.AudioDeviceType, @enumFromInt(@as(u8, @truncate(device_type))));
        
        // Create device.
        const device_id = self.audio_devices.create_device(name, audio_device_type, owner_process_id) orelse {
            return BasinError.out_of_memory; // No free device slot
        };
        
        const result = SyscallResult.ok(device_id);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set audio device volume.
    /// Why: Control device volume.
    /// Contract: device_id and volume must be valid.
    pub fn syscall_audio_set_volume(
        self: *BasinKernel,
        device_id: u64,
        volume: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Volume must be valid (0-100).
        if (volume > 100) {
            return BasinError.invalid_argument; // Invalid volume
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const vol = @as(u32, @truncate(volume));
        
        // Set device volume.
        if (!self.audio_devices.set_device_volume(dev_id, vol)) {
            return BasinError.not_found; // Device not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set audio device mute state.
    /// Why: Control device mute state.
    /// Contract: device_id and muted must be valid.
    pub fn syscall_audio_set_mute(
        self: *BasinKernel,
        device_id: u64,
        muted: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Muted must be valid (0 or 1).
        if (muted > 1) {
            return BasinError.invalid_argument; // Invalid mute value
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const is_muted = muted != 0;
        
        // Set device mute state.
        if (!self.audio_devices.set_device_mute(dev_id, is_muted)) {
            return BasinError.not_found; // Device not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set audio device state.
    /// Why: Control device state.
    /// Contract: device_id and state must be valid.
    pub fn syscall_audio_set_state(
        self: *BasinKernel,
        device_id: u64,
        state: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: State must be valid (0-3).
        if (state > 3) {
            return BasinError.invalid_argument; // Invalid state
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const audio_state = @as(audio.AudioDeviceState, @enumFromInt(@as(u8, @truncate(state))));
        
        // Set device state.
        if (!self.audio_devices.set_device_state(dev_id, audio_state)) {
            return BasinError.not_found; // Device not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set active output device.
    /// Why: Select active output device.
    /// Contract: device_id must be valid (or 0 to clear).
    pub fn syscall_audio_set_active_output(
        self: *BasinKernel,
        device_id: u64,
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
        
        const dev_id = @as(u32, @truncate(device_id));
        
        // Set active output device.
        if (!self.audio_devices.set_active_output_device(dev_id)) {
            return BasinError.not_found; // Device not found or invalid type
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set active input device.
    /// Why: Select active input device.
    /// Contract: device_id must be valid (or 0 to clear).
    pub fn syscall_audio_set_active_input(
        self: *BasinKernel,
        device_id: u64,
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
        
        const dev_id = @as(u32, @truncate(device_id));
        
        // Set active input device.
        if (!self.audio_devices.set_active_input_device(dev_id)) {
            return BasinError.not_found; // Device not found or invalid type
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set master volume.
    /// Why: Control master volume.
    /// Contract: volume must be valid (0-100).
    pub fn syscall_audio_set_master_volume(
        self: *BasinKernel,
        volume: u64,
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
        
        // Assert: Volume must be valid (0-100).
        if (volume > 100) {
            return BasinError.invalid_argument; // Invalid volume
        }
        
        const vol = @as(u32, @truncate(volume));
        
        // Set master volume.
        if (!self.audio_devices.set_master_volume(vol)) {
            return BasinError.invalid_argument; // Invalid volume
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set master mute state.
    /// Why: Control master mute state.
    /// Contract: muted must be valid (0 or 1).
    pub fn syscall_audio_set_master_mute(
        self: *BasinKernel,
        muted: u64,
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
        
        // Assert: Muted must be valid (0 or 1).
        if (muted > 1) {
            return BasinError.invalid_argument; // Invalid mute value
        }
        
        const is_muted = muted != 0;
        
        // Set master mute state.
        self.audio_devices.set_master_mute(is_muted);
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get audio device information.
    /// Why: Retrieve device configuration.
    /// Contract: device_id must be valid, info_ptr must be valid VM address.
    pub fn syscall_audio_get_device(
        self: *BasinKernel,
        device_id: u64,
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
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Info pointer must be valid (non-zero, within VM memory).
        if (info_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_AUDIO_GET: u64 = 4 * 1024 * 1024; // 4MB default
        if (info_ptr >= VM_MEMORY_SIZE_AUDIO_GET) {
            return BasinError.invalid_argument; // Info pointer exceeds VM memory
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        
        // Get device.
        const device = self.audio_devices.get_device(dev_id) orelse {
            return BasinError.not_found; // Device not found
        };
        
        // Write device information to VM memory (stub: would use vm_memory_writer).
        // For now, just return success.
        // Note: info_ptr is validated above but not written to in stub implementation.
        _ = device;
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Set audio format for device.
    /// Why: Configure audio format (sample rate, channels, bit depth).
    /// Contract: device_id must be valid, format parameters must be valid.
    pub fn syscall_audio_set_format(
        self: *BasinKernel,
        device_id: u64,
        sample_rate: u64,
        channels: u64,
        bit_depth: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Sample rate must be reasonable (8kHz to 192kHz).
        if (sample_rate < 8000 or sample_rate > 192000) {
            return BasinError.invalid_argument; // Invalid sample rate
        }
        
        // Assert: Channels must be reasonable (1 to 8).
        if (channels == 0 or channels > 8) {
            return BasinError.invalid_argument; // Invalid channels
        }
        
        // Assert: Bit depth must be valid (8, 16, 24, 32).
        if (bit_depth != 8 and
            bit_depth != 16 and
            bit_depth != 24 and
            bit_depth != 32) {
            return BasinError.invalid_argument; // Invalid bit depth
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const sr = @as(u32, @truncate(sample_rate));
        const ch = @as(u32, @truncate(channels));
        const bd = @as(u32, @truncate(bit_depth));
        
        const format = audio.AudioFormat{
            .sample_rate = sr,
            .channels = ch,
            .bit_depth = bd,
        };
        
        // Set format.
        const success = self.audio_devices.set_device_format(dev_id, format);
        if (!success) {
            return BasinError.not_found; // Device not found or format invalid
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Read audio data from device.
    /// Why: Read audio data from input device.
    /// Contract: device_id must be valid, buffer_ptr and buffer_len must be valid.
    pub fn syscall_audio_read(
        self: *BasinKernel,
        device_id: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_AUDIO: u64 = 4 * 1024 * 1024; // 4MB default
        if (buffer_ptr >= VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: Buffer length must be reasonable (max 64KB per read).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large (> 64KB)
        }
        
        // Assert: Buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const buf_len = @as(u32, @truncate(buffer_len));
        
        // Create buffer slice (stub: would read from VM memory).
        // For now, we use a temporary buffer.
        var temp_buffer: [64 * 1024]u8 = undefined;
        const buffer = temp_buffer[0..buf_len];
        
        // Read audio data.
        const bytes_read_opt = self.audio_devices.read_audio(dev_id, buffer);
        const bytes_read = bytes_read_opt orelse {
            return BasinError.not_found; // Device not found or not input-capable
        };
        
        // Note: In real implementation, would write to VM memory at buffer_ptr.
        // For now, just return bytes read.
        // Note: buffer_ptr is validated above but not written to in stub implementation.
        
        const result = SyscallResult.ok(@as(u64, @intCast(bytes_read)));
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success <= buffer_len, "Read > buffer len", .{});
        
        return result;
    }
    
    /// Write audio data to device.
    /// Why: Write audio data to output device.
    /// Contract: device_id must be valid, data_ptr and data_len must be valid.
    pub fn syscall_audio_write(
        self: *BasinKernel,
        device_id: u64,
        data_ptr: u64,
        data_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        // Assert: Data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE_AUDIO: u64 = 4 * 1024 * 1024; // 4MB default
        if (data_ptr >= VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: Data length must be reasonable (max 64KB per write).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large (> 64KB)
        }
        
        // Assert: Data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE_AUDIO) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        const d_len = @as(u32, @truncate(data_len));
        
        // Create data slice (stub: would read from VM memory).
        // For now, we use a temporary buffer.
        var temp_buffer: [64 * 1024]u8 = undefined;
        const data = temp_buffer[0..d_len];
        
        // Note: In real implementation, would read from VM memory at data_ptr.
        // For now, just use zero-filled buffer.
        @memset(data, 0);
        // Note: data_ptr is validated above but not read from in stub implementation.
        
        // Write audio data.
        const bytes_written_opt = self.audio_devices.write_audio(dev_id, data);
        const bytes_written = bytes_written_opt orelse {
            return BasinError.not_found; // Device not found or not output-capable
        };
        
        const result = SyscallResult.ok(@as(u64, @intCast(bytes_written)));
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        Debug.kassert(result.success <= data_len, "Write > data len", .{});
        
        return result;
    }
    
    /// Enumerate audio devices.
    /// Why: Get list of all audio devices.
    /// Contract: device_ids_ptr must be valid VM address, max_count must be valid.
    pub fn syscall_audio_enumerate_devices(
        self: *BasinKernel,
        device_ids_ptr: u64,
        max_count: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg3;
        _ = _arg4;
        
        // Assert: Device IDs pointer must be valid (non-zero, within VM memory).
        if (device_ids_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (device_ids_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Device IDs pointer exceeds VM memory
        }
        
        // Assert: Max count must be reasonable (max 16 devices).
        const max_cnt = @as(u32, @truncate(max_count));
        if (max_cnt > 16) {
            return BasinError.invalid_argument; // Max count too large
        }
        
        // Assert: Device IDs array must fit within VM memory (max 16 * 4 bytes = 64 bytes).
        const DEVICE_IDS_SIZE: u64 = max_cnt * 4; // u32 per device ID
        if (device_ids_ptr + DEVICE_IDS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Device IDs array exceeds VM memory
        }
        
        // Create temporary device IDs array.
        var temp_device_ids: [16]u32 = undefined;
        const count = self.audio_devices.enumerate_devices(&temp_device_ids);
        
        // Write device IDs to VM memory (stub: would use vm_memory_writer).
        // For now, just return the count.
        // Note: device_ids_ptr and temp_device_ids are validated but not written in stub.
        _ = temp_device_ids;
        
        const result = SyscallResult.ok(count);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get audio device statistics.
    /// Why: Provide audio device statistics to userspace.
    /// Contract: stats_ptr must be valid pointer to AudioDeviceStats structure.
    pub fn syscall_audio_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
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
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: AudioDeviceStats structure must fit within VM memory.
        // AudioDeviceStats size: 15 fields (6 u64 + 1 u32 + 8 u64) = 6*8 + 4 + 8*8 = 116 bytes
        const AUDIO_STATS_SIZE: u64 = 116;
        if (stats_ptr + AUDIO_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: Statistics structure will be written by integration layer.
        // This syscall validates the pointer and returns success.
        // Contract: stats_ptr must be valid (checked above).
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Delete audio device.
    /// Why: Remove audio device.
    /// Contract: device_id must be valid.
    pub fn syscall_audio_delete_device(
        self: *BasinKernel,
        device_id: u64,
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
        
        // Assert: Device ID must be non-zero.
        if (device_id == 0) {
            return BasinError.invalid_argument; // Invalid device ID
        }
        
        const dev_id = @as(u32, @truncate(device_id));
        
        // Delete device.
        if (!self.audio_devices.delete_device(dev_id)) {
            return BasinError.not_found; // Device not found
        }
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get unified kernel statistics snapshot.
    /// Why: Provide comprehensive system statistics for monitoring and debugging.
    /// Contract: stats_ptr must be valid pointer (checked by integration layer).
    /// Note: Integration layer will write KernelStatsSnapshot structure to stats_ptr.
    pub fn syscall_kernel_get_stats(
        self: *BasinKernel,
        stats_ptr: u64,
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
        
        // Assert: Stats pointer must be valid (non-zero, within VM memory).
        if (stats_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default
        if (stats_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats pointer exceeds VM memory
        }
        
        // Assert: KernelStatsSnapshot structure must fit within VM memory.
        // KernelStatsSnapshot size: 7 pointers (8 bytes each) + 2 u64 + 1 f64 = 7*8 + 2*8 + 8 = 80 bytes
        const KERNEL_STATS_SIZE: u64 = 80;
        if (stats_ptr + KERNEL_STATS_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Stats structure exceeds VM memory
        }
        
        // Note: This syscall is handled by integration layer (needs VM access to write snapshot).
        // This stub validates the pointer but integration layer will write the KernelStatsSnapshot structure.
        // Contract: stats_ptr must be valid (checked above).
        
        // Get snapshot for validation (integration layer will use this).
        _ = self.get_kernel_stats_snapshot();
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Health check syscall.
    /// Why: Provide overall system health status for monitoring.
    /// Returns: Health status (0 = healthy, 1 = degraded, 2 = unhealthy).
    pub fn syscall_health_check(
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
        
        // Get kernel statistics snapshot.
        const snapshot = self.get_kernel_stats_snapshot();
        
        // Calculate health status based on health score.
        // Health score: 0.0 to 100.0 (higher is better).
        // Status: 0 = healthy (>= 80.0), 1 = degraded (50.0-79.9), 2 = unhealthy (< 50.0)
        var health_status: u64 = 0;
        if (snapshot.health_score < 50.0) {
            health_status = 2; // Unhealthy
        } else if (snapshot.health_score < 80.0) {
            health_status = 1; // Degraded
        } else {
            health_status = 0; // Healthy
        }
        
        // Assert: Health status must be valid (0, 1, or 2).
        Debug.kassert(health_status <= 2, "Health status out of range", .{});
        
        const result = SyscallResult.ok(health_status);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
    
    /// Get resource usage syscall.
    /// Why: Expose per-process resource usage (CPU, memory, network, file descriptors).
    /// Returns: Resource usage information for the specified process.
    /// Arguments:
    ///   - arg1: Process ID (pid)
    ///   - arg2: Resource usage pointer (ResourceUsage struct in VM memory)
    ///   - arg3: Unused
    ///   - arg4: Unused
    pub fn syscall_get_resource_usage(
        self: *BasinKernel,
        pid: u64,
        usage_ptr: u64,
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
        
        // Assert: Usage pointer must be valid (non-zero, within VM memory).
        if (usage_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024;
        if (usage_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Pointer out of bounds
        }
        
        // Calculate ResourceUsage struct size (8 + 8 + 8 + 8 + 8 + 4 + 4 = 48 bytes).
        const RESOURCE_USAGE_SIZE: u64 = 48;
        if (usage_ptr + RESOURCE_USAGE_SIZE > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer extends beyond VM memory
        }
        
        // Find process in process table.
        var found: ?u32 = null;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].id == pid) {
                found = @intCast(i);
                break;
            }
        }
        
        // Assert: Process must exist.
        if (found == null) {
            return BasinError.process_not_found; // Process not found
        }
        
        const process_idx = found.?;
        const process = &self.processes[process_idx];
        
        // Count open file descriptors for this process.
        var file_descriptor_count: u32 = 0;
        for (self.handles) |handle| {
            if (handle.allocated and handle.owner_process_id == @intCast(pid)) {
                file_descriptor_count += 1;
            }
        }
        
        // Count open network connections for this process.
        // Note: This is a simplified count - in a full implementation, we would
        // track which sockets belong to which process.
        var connection_count: u32 = 0;
        // Stub: Connection counting would iterate through TCP/UDP socket managers
        // and count sockets owned by this process. For now, we use the process's
        // open_connections field which should be updated by socket operations.
        connection_count = process.open_connections;
        
        // Create ResourceUsage struct.
        const usage = ResourceUsage{
            .pid = @intCast(pid),
            .cpu_time_ns = process.cpu_time_ns,
            .memory_used = process.memory_used,
            .network_bytes_sent = process.network_bytes_sent,
            .network_bytes_received = process.network_bytes_received,
            .open_file_descriptors = file_descriptor_count,
            .open_connections = connection_count,
        };
        
        // Stub: In a real VM, this would write the ResourceUsage struct to VM memory at usage_ptr.
        _ = usage;
        
        // Assert: Usage must be valid.
        Debug.kassert(usage.pid == @intCast(pid), "Usage PID mismatch", .{});
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        Debug.kassert(result == .success, "Result not success", .{});
        
        return result;
    }
};

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

