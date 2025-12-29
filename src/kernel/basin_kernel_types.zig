//! Basin Kernel Type Definitions
//! Why: Centralized type definitions for kernel API and internal structures.
//! Grain Style: Explicit types (u32/u64 not usize), static allocation, comprehensive assertions.

const std = @import("std");
const Debug = @import("debug.zig");
const SignalTable = @import("signal.zig").SignalTable;
const ProcessContext = @import("process.zig").ProcessContext;

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
    
    // UDP Socket Operations with Timeout
    udp_sendto_with_timeout = 138,
    udp_recvfrom_with_timeout = 139,
    
    // Resource Limits
    set_resource_limit = 140,
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

// Internal types (used by BasinKernel struct)

/// Memory mapping entry.
/// Why: Track memory mappings for map/unmap/protect syscalls.
/// Grain Style: Static allocation, explicit state tracking.
pub const MemoryMapping = struct {
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

/// File handle entry.
/// Why: Track file handles for open/read/write/close syscalls.
/// Grain Style: Static allocation, explicit state tracking.
pub const FileHandle = struct {
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
pub const DirectoryHandle = struct {
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

// Constants

/// Memory mapping table.
/// Why: Track all memory mappings for kernel memory management.
/// Grain Style: Static allocation, max 256 entries (sufficient for 4MB VM).
pub const MAX_MAPPINGS: u32 = 256;

/// File handle table.
/// Why: Track all file handles for kernel file system management.
/// Grain Style: Static allocation, max 64 entries.
pub const MAX_HANDLES: u32 = 64;

/// Directory handle table.
/// Why: Track all directory handles for kernel directory operations.
/// Grain Style: Static allocation, max 32 entries.
pub const MAX_DIR_HANDLES: u32 = 32;

/// Process table.
/// Why: Track all processes for kernel process management.
/// Grain Style: Static allocation, max 16 entries.
pub const MAX_PROCESSES: u32 = 16;

/// User table (static allocation).
/// Why: Fixed-size user table, no dynamic allocation
/// Grain Style: Static array, max 256 users
pub const MAX_USERS: u32 = 256;

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
    /// Maximum CPU time allowed (nanoseconds, 0 = unlimited).
    /// Why: Enforce CPU time limits per process.
    max_cpu_time_ns: u64,
    /// Maximum memory allowed (bytes, 0 = unlimited).
    /// Why: Enforce memory limits per process.
    max_memory_bytes: u64,
    /// Maximum number of open file descriptors (0 = unlimited).
    /// Why: Enforce file descriptor limits per process.
    max_file_descriptors: u32,
    /// Maximum number of open network connections (0 = unlimited).
    /// Why: Enforce network connection limits per process.
    max_connections: u32,
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
            .max_cpu_time_ns = 0, // Unlimited by default
            .max_memory_bytes = 0, // Unlimited by default
            .max_file_descriptors = 0, // Unlimited by default
            .max_connections = 0, // Unlimited by default
            .parent_pid = 0,
            .priority = 0, // Default priority (nice value 0)
            .time_slice_quantum = 1000, // Default time slice (1000 instruction steps)
            .pgid = 0, // No process group by default
            .sid = 0, // No session by default
            .allocated = false,
        };
    }
};
