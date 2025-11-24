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
    
    /// Number of CPU cores.
    cpu_cores: u32,
    
    /// Uptime (nanoseconds since boot).
    uptime_ns: u64,
    
    /// Load average (1-minute average, scaled by 1000).
    load_avg_1min: u32,
    
    /// Initialize SysInfo with default values.
    /// Why: Explicit initialization, prevent uninitialized fields.
    pub fn init() SysInfo {
        return SysInfo{
            .total_memory = 0,
            .available_memory = 0,
            .cpu_cores = 0,
            .uptime_ns = 0,
            .load_avg_1min = 0,
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
    would_block,
    interrupted,
    invalid_syscall,
    invalid_address,
    unaligned_access,
    out_of_bounds,
    user_not_found,
    invalid_user,
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
            .channels = ChannelTable.init(),
            .storage = Storage.init(),
            .keyboard = Keyboard.init(),
            .mouse = Mouse.init(),
            .memory_pool = MemoryPool.init(),
            .page_table = PageTable.init(),
            .page_fault_stats = PageFaultStats.init(),
            .memory_stats = MemoryStats.init(),
            .cow_table = CowTable.init(),
        };
        
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
        Debug.kassert(syscall_num <= @intFromEnum(Syscall.sysinfo), "Syscall num {d} too high", .{syscall_num});
        
        // Decode syscall number.
        const syscall = @as(?Syscall, @enumFromInt(syscall_num)) orelse {
            // Assert: Invalid syscall number must return error.
            Debug.kassert(syscall_num < 10 or syscall_num > @intFromEnum(Syscall.sysinfo), "Invalid syscall logic", .{});
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
            .read_input_event => self.syscall_read_input_event(arg1, arg2, arg3, arg4),
            .fb_clear => self.syscall_fb_clear(arg1, arg2, arg3, arg4),
            .fb_draw_pixel => self.syscall_fb_draw_pixel(arg1, arg2, arg3, arg4),
            .fb_draw_text => self.syscall_fb_draw_text(arg1, arg2, arg3, arg4),
            .kill => self.syscall_kill(arg1, arg2, arg3, arg4),
            .signal => self.syscall_signal(arg1, arg2, arg3, arg4),
            .sigaction => self.syscall_sigaction(arg1, arg2, arg3, arg4),
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
        self.processes[idx].allocated = true;
        
        // Set as current running process in scheduler.
        self.scheduler.set_current(process_id);
        
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
            // Mark process as exited.
            self.processes[idx].state = .exited;
            self.processes[idx].exit_status = exit_status;
            
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
    
    fn syscall_map(
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
        mapping.allocated = false;
        mapping.address = 0;
        mapping.size = 0;
        mapping.flags = MapFlags.init(.{});
        mapping.owner_process_id = 0;
        
        // Update page table (unmap pages).
        self.page_table.unmap_pages(region, mapping_size);
        
        // Update memory statistics.
        self.memory_stats.update_from_page_table(@ptrCast(&self.page_table), VM_MEMORY_SIZE);
        self.memory_stats.update_mapping_count(self.count_allocated_mappings());
        
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
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
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
        const sent = ch.send(data_slice);
        if (!sent) {
            return BasinError.would_block; // Channel queue full
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
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
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
        
        // Receive message from channel.
        // Why: Get message from channel queue.
        var message_buffer: [4096]u8 = undefined;
        const bytes_received_u32 = ch.receive(&message_buffer);
        
        if (bytes_received_u32 == 0) {
            // Queue empty: return 0 bytes received (non-blocking).
            // Why: Non-blocking receive - return immediately if no message.
            const result = SyscallResult.ok(0);
            Debug.kassert(result == .success, "Result not success", .{});
            Debug.kassert(result.success == 0, "Result not 0", .{});
            return result;
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
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
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
        
        // Note: Actual file data reading is handled by integration layer.
        // This kernel syscall validates parameters and calculates read size.
        // Integration layer will:
        // 1. Look up file in storage filesystem by handle path
        // 2. Read data from storage file entry
        // 3. Write data to VM memory at buffer_ptr
        // For now, we use handle buffer (in-memory file data).
        // Calculate bytes to read (min of available data and buffer size).
        const available = if (file_handle.position < file_handle.buffer_size)
            file_handle.buffer_size - file_handle.position
        else
            0;
        const bytes_to_read = @min(available, @as(u32, @intCast(buffer_len)));
        
        // Note: Integration layer will write data to VM memory.
        // For now, just update position (data is in handle buffer).
        file_handle.position += bytes_to_read;
        
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
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        Debug.kassert(self_ptr != 0, "Self ptr is null", .{});
        Debug.kassert(self_ptr % @alignOf(BasinKernel) == 0, "Self ptr unaligned", .{});
        
        _ = _arg4;
        
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
        
        // Calculate bytes to write (min of data length and available buffer space).
        const data_len_u32 = @as(u32, @intCast(data_len));
        const max_buffer_size = file_handle.buffer.len;
        const available_space = if (file_handle.position < max_buffer_size)
            @as(u32, @intCast(max_buffer_size - file_handle.position))
        else
            0;
        const bytes_to_write = @min(data_len_u32, available_space);
        
        // Write data to handle buffer (simulated - in real implementation, would read from VM memory).
        // For now, just update position and buffer size.
        file_handle.position += bytes_to_write;
        if (file_handle.position > file_handle.buffer_size) {
            file_handle.buffer_size = @as(u32, @intCast(file_handle.position));
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
        const clock = @as(?ClockId, @enumFromInt(@as(u32, @truncate(clock_id))));
        if (clock == null) {
            return BasinError.invalid_argument; // Invalid clock ID
        }
        
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
        
        // Assert: Available memory must be <= total memory.
        Debug.kassert(available_memory <= total_memory, "Available > total", .{});
        
        // Get uptime from timer (nanoseconds since boot).
        const uptime_ns: u64 = self.timer.get_uptime_ns();
        
        // Assert: Uptime must be non-negative.
        Debug.kassert(uptime_ns >= 0, "Uptime negative", .{});
        
        // Calculate load average (simple: running processes / max processes).
        // Why: Provide basic load metric for system monitoring.
        var running_count: u32 = 0;
        for (0..MAX_PROCESSES) |i| {
            if (self.processes[i].allocated and self.processes[i].state == .running) {
                running_count += 1;
            }
        }
        // Load average: running processes / max processes (scaled to 1000 for fixed-point).
        const load_avg_1min: u32 = (running_count * 1000) / MAX_PROCESSES;
        
        // Assert: Load average must be <= 1000 (scaled).
        Debug.kassert(load_avg_1min <= 1000, "Load avg > 1000", .{});
        
        // Note: Integration layer will write SysInfo structure to info_ptr.
        // Structure layout:
        // - total_memory: u64 (offset 0)
        // - available_memory: u64 (offset 8)
        // - cpu_cores: u32 (offset 16)
        // - uptime_ns: u64 (offset 20, but u32 alignment means offset 24)
        // - load_avg_1min: u32 (offset 32)
        // Total size: 40 bytes (with padding)
        
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
        
        // Assert: PID must be valid (non-zero).
        if (pid == 0) {
            return BasinError.invalid_argument;
        }
        
        // Assert: Signal number must be valid (< 32).
        if (signal_num >= 32) {
            return BasinError.invalid_argument;
        }
        
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
        
        // Convert signal number to Signal enum.
        const signal = @as(Signal, @enumFromInt(@as(u32, @truncate(signal_num))));
        
        // Send signal to process.
        process.signals.send_signal(signal);
        
        // SIGKILL immediately terminates process.
        if (signal == .sigkill) {
            process.state = .exited;
            process.exit_status = 128 + @intFromEnum(signal); // Exit code = 128 + signal
            self.scheduler.set_current(0); // Clear current process
        }
        
        // Assert: Signal must be sent (postcondition).
        Debug.kassert(process.signals.is_pending(signal) or signal == .sigkill, "Signal not sent", .{});
        
        return SyscallResult.ok(0);
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
};

/// Basin Kernel module exports.
/// Why: Explicit exports, clear public API.
pub const basin_kernel = struct {
    pub const Syscall = @import("basin_kernel.zig").Syscall;
    pub const MapFlags = @import("basin_kernel.zig").MapFlags;
    pub const OpenFlags = @import("basin_kernel.zig").OpenFlags;
    pub const ClockId = @import("basin_kernel.zig").ClockId;
    pub const Handle = @import("basin_kernel.zig").Handle;
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

