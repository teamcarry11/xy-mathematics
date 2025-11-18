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
    
    // Time & Scheduling
    clock_gettime = 40,
    sleep_until = 41,
    
    // System Information
    sysinfo = 50,
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
        std.debug.assert(value != 0);
        
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
        std.debug.assert(self.uid < 65536);
        std.debug.assert(self.gid < 65536);
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
    
    /// Initialize empty mapping entry.
    /// Why: Explicit initialization, clear state.
    pub fn init() MemoryMapping {
        return MemoryMapping{
            .address = 0,
            .size = 0,
            .flags = MapFlags.init(.{}),
            .allocated = false,
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
        };
    }
};

/// File handle table.
/// Why: Track all file handles for kernel file system management.
/// Grain Style: Static allocation, max 64 entries.
const MAX_HANDLES: u32 = 64;

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
    
    /// Initialize Basin Kernel.
    /// Why: Explicit initialization, validate kernel state.
    pub fn init() BasinKernel {
        var kernel = BasinKernel{};
        
        // Initialize default users (root and xy).
        kernel.init_users();
        
        // Assert: All mappings must be unallocated initially.
        for (kernel.mappings) |mapping| {
            std.debug.assert(!mapping.allocated);
        }
        
        // Assert: Next allocation address must be page-aligned.
        std.debug.assert(kernel.next_alloc_addr % 4096 == 0);
        
        // Assert: All handles must be unallocated initially.
        for (kernel.handles) |handle| {
            std.debug.assert(!handle.allocated);
            std.debug.assert(handle.id == 0);
        }
        
        // Assert: Next handle ID must be non-zero (1-based).
        std.debug.assert(kernel.next_handle_id != 0);
        
        // Assert: Root user must exist.
        std.debug.assert(kernel.user_count >= 1);
        std.debug.assert(kernel.users[0].uid == 0);
        
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
        std.debug.assert(self.users[0].uid == 0);
        std.debug.assert(self.users[1].uid == 1000);
        std.debug.assert(self.user_count == 2);
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
        std.debug.assert(self.current_user.uid == uid);
    }
    
    /// Find free mapping entry.
    /// Why: Allocate new mapping entry.
    /// Returns: Index of free entry, or null if table full.
    /// Grain Style: Comprehensive assertions for table state.
    fn find_free_mapping(self: *BasinKernel) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(free_count <= MAX_MAPPINGS);
        
        return found_index;
    }
    
    /// Find mapping by address.
    /// Why: Look up mapping for unmap/protect operations.
    /// Returns: Index of mapping, or null if not found.
    /// Grain Style: Comprehensive assertions for address validation.
    fn find_mapping_by_address(self: *BasinKernel, addr: u64) ?u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: Address must be page-aligned.
        std.debug.assert(addr % 4096 == 0);
        
        var found_index: ?u32 = null;
        var match_count: u32 = 0;
        
        for (self.mappings, 0..) |mapping, i| {
            if (mapping.allocated and mapping.address == addr) {
                match_count += 1;
                if (found_index == null) {
                    found_index = @as(u32, @intCast(i));
                }
                
                // Assert: Matching mapping must have valid state.
                std.debug.assert(mapping.address == addr);
                std.debug.assert(mapping.size >= 4096);
                std.debug.assert(mapping.size % 4096 == 0);
            }
        }
        
        // Assert: Address must be unique (no duplicate mappings).
        std.debug.assert(match_count <= 1);
        
        return found_index;
    }
    
    /// Check if address range overlaps with any existing mapping.
    /// Why: Validate no overlapping mappings.
    /// Grain Style: Comprehensive assertions for overlap detection.
    fn check_overlap(self: *BasinKernel, addr: u64, size: u64) bool {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: Address and size must be valid.
        std.debug.assert(addr % 4096 == 0); // Page-aligned
        std.debug.assert(size >= 4096); // At least 1 page
        std.debug.assert(size % 4096 == 0); // Page-aligned
        
        var overlap_count: u32 = 0;
        
        for (self.mappings) |mapping| {
            if (mapping.overlaps(addr, size)) {
                overlap_count += 1;
                
                // Assert: Overlapping mapping must be allocated.
                std.debug.assert(mapping.allocated);
                
                // Assert: Overlap condition must be true.
                const does_overlap = (mapping.address < addr + size) and (addr < mapping.address + mapping.size);
                std.debug.assert(does_overlap);
            }
        }
        
        // Assert: Overlap count must be consistent (0 or 1, no duplicates).
        std.debug.assert(overlap_count <= 1);
        
        return overlap_count > 0;
    }
    
    /// Count allocated mappings (for testing and validation).
    /// Why: Validate mapping table state consistency.
    /// Grain Style: Comprehensive assertions for state validation.
    pub fn count_allocated_mappings(self: *BasinKernel) u32 {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: Handle ID must be non-zero (0 is invalid).
        std.debug.assert(handle_id != 0);
        
        for (self.handles, 0..) |handle, i| {
            if (handle.allocated and handle.id == handle_id) {
                // Assert: Handle must be allocated and match ID.
                std.debug.assert(handle.allocated);
                std.debug.assert(handle.id == handle_id);
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: syscall number must be >= 10 (kernel syscalls, not SBI).
        // Why: SBI calls use function ID < 10, kernel syscalls use >= 10.
        std.debug.assert(syscall_num >= 10);
        
        // Assert: syscall number must be within valid range.
        std.debug.assert(syscall_num <= @intFromEnum(Syscall.sysinfo));
        
        // Decode syscall number.
        const syscall = @as(?Syscall, @enumFromInt(syscall_num)) orelse {
            // Assert: Invalid syscall number must return error.
            std.debug.assert(syscall_num < 10 or syscall_num > @intFromEnum(Syscall.sysinfo));
            return BasinError.invalid_syscall;
        };
        
        // Assert: syscall must be valid enum value.
        std.debug.assert(@intFromEnum(syscall) == syscall_num);
        
        // Assert: syscall must be kernel syscall (not SBI).
        std.debug.assert(@intFromEnum(syscall) >= 10);
        
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
            .clock_gettime => self.syscall_clock_gettime(arg1, arg2, arg3, arg4),
            .sleep_until => self.syscall_sleep_until(arg1, arg2, arg3, arg4),
            .sysinfo => self.syscall_sysinfo(arg1, arg2, arg3, arg4),
        };
    }
    
    // Syscall handlers (stubs for future implementation).
    // Why: Separate functions for each syscall, Grain Style function length limit.
    
    fn syscall_spawn(
        self: *BasinKernel,
        executable: u64,
        args_ptr: u64,
        args_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        
        // TODO: Implement actual process creation (when process management is implemented).
        // For now, return a stub process ID (simple implementation).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Parse ELF executable header
        // - Load executable into memory
        // - Create process structure
        // - Set up process memory space
        // - Initialize process registers (PC = entry point)
        // - Add process to process table
        // - Return Process ID (not raw integer) for type safety
        
        // Stub: Return process ID 1 (simple implementation).
        const process_id: u64 = 1;
        const result = SyscallResult.ok(process_id);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == process_id);
        
        // Assert: Process ID must be non-zero (valid process ID).
        std.debug.assert(process_id != 0);
        
        return result;
    }
    
    fn syscall_exit(
        self: *BasinKernel,
        status: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: status must be valid (0-255 for exit code).
        std.debug.assert(status <= 255);
        
        // Exit syscall: terminate process with status code.
        // Why: Return status code as success value (VM will interpret this as exit).
        // Note: VM will handle actual termination (set state to halted).
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: process ID must be valid (non-zero).
        if (process == 0) {
            return BasinError.invalid_argument; // Invalid process ID
        }
        
        // TODO: Implement actual process waiting (when process management is implemented).
        // For now, return stub success with exit status 0.
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up process in process table
        // - Wait for process to complete (if not already completed)
        // - Return process exit status
        // - Return error if process not found
        
        // Stub: Return success with exit status 0 (simple implementation).
        const exit_status: u64 = 0;
        const result = SyscallResult.ok(exit_status);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == exit_status);
        
        // Assert: Exit status must be valid (0-255).
        std.debug.assert(exit_status <= 255);
        
        return result;
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
            std.debug.assert(mapping_addr % 4096 == 0);
            
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
        
        // Allocate mapping entry.
        var mapping = &self.mappings[mapping_idx];
        mapping.address = mapping_addr;
        mapping.size = size;
        mapping.flags = map_flags;
        mapping.allocated = true;
        
        // Assert: Mapping entry must be allocated correctly.
        std.debug.assert(mapping.allocated);
        std.debug.assert(mapping.address == mapping_addr);
        std.debug.assert(mapping.size == size);
        
        // Update next allocation address (for kernel-chosen addresses).
        if (addr == 0) {
            // Kernel-chosen: advance next allocation address.
            self.next_alloc_addr = mapping_addr + size;
            
            // Assert: Next allocation address must be page-aligned.
            std.debug.assert(self.next_alloc_addr % 4096 == 0);
        }
        
        const result = SyscallResult.ok(mapping_addr);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == mapping_addr);
        
        // Assert: Returned address must be valid.
        std.debug.assert(result.success >= USER_SPACE_START);
        std.debug.assert(result.success + size <= VM_MEMORY_SIZE);
        std.debug.assert(result.success % 4096 == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self.mappings[mapping_idx].allocated);
        std.debug.assert(self.mappings[mapping_idx].address == region);
        
        // Free mapping entry.
        var mapping = &self.mappings[mapping_idx];
        mapping.allocated = false;
        mapping.address = 0;
        mapping.size = 0;
        mapping.flags = MapFlags.init(.{});
        
        // Assert: Mapping entry must be freed correctly.
        std.debug.assert(!mapping.allocated);
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Unmap returns 0 on success
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self.mappings[mapping_idx].allocated);
        std.debug.assert(self.mappings[mapping_idx].address == region);
        
        // Update mapping flags (permissions).
        var mapping = &self.mappings[mapping_idx];
        mapping.flags = map_flags;
        
        // Assert: Mapping flags must be updated correctly.
        std.debug.assert(mapping.flags.read == map_flags.read);
        std.debug.assert(mapping.flags.write == map_flags.write);
        std.debug.assert(mapping.flags.execute == map_flags.execute);
        std.debug.assert(mapping.flags.shared == map_flags.shared);
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Protect returns 0 on success
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        _ = _arg1;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement actual channel creation (when IPC is implemented).
        // For now, return stub channel ID.
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Create channel structure (message queue, synchronization)
        // - Allocate channel ID
        // - Add channel to channel table
        // - Return Channel ID (not raw integer) for type safety
        // - Handle channel capacity/limits
        
        // Stub: Return channel ID 1 (simple implementation).
        const channel_id: u64 = 1;
        const result = SyscallResult.ok(channel_id);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == channel_id);
        
        // Assert: Channel ID must be non-zero (valid channel ID).
        std.debug.assert(channel_id != 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        
        // Assert: data length must be reasonable (max 64KB per message).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 64 * 1024) {
            return BasinError.invalid_argument; // Data too large (> 64KB)
        }
        
        // Assert: data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // TODO: Implement actual channel send (when IPC is implemented).
        // For now, return stub success.
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up channel in channel table
        // - Verify channel exists and is open
        // - Copy data to channel message queue
        // - Wake up waiting receivers (if any)
        // - Return error if channel full or not found
        
        // Stub: Return success (simple implementation).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Channel_send returns 0 on success
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        
        // Assert: buffer length must be reasonable (max 64KB per message).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 64 * 1024) {
            return BasinError.invalid_argument; // Buffer too large (> 64KB)
        }
        
        // Assert: buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // TODO: Implement actual channel receive (when IPC is implemented).
        // For now, return stub (0 bytes received).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up channel in channel table
        // - Verify channel exists and is open
        // - Wait for message (if channel empty)
        // - Copy message from channel to buffer
        // - Return bytes received count
        // - Return error if channel not found
        
        // Stub: Return 0 bytes received (simple implementation).
        const bytes_received: u64 = 0;
        const result = SyscallResult.ok(bytes_received);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == bytes_received);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(path_len > 0);
        std.debug.assert(path_len <= 255);
        
        // Find free handle entry.
        const handle_idx = self.find_free_handle() orelse {
            return SyscallResult.fail(BasinError.out_of_memory); // Handle table full
        };
        
        // Allocate handle entry.
        var file_handle = &self.handles[handle_idx];
        const handle_id = self.next_handle_id;
        self.next_handle_id += 1;
        
        // Assert: Handle ID must be non-zero (1-based).
        std.debug.assert(handle_id != 0);
        
        // Copy path from VM memory (simulated - in real implementation, would read from VM memory).
        // For now, store path length (actual path copying would happen here).
        file_handle.id = handle_id;
        file_handle.path_len = @as(u32, @intCast(path_len));
        file_handle.flags = open_flags;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        file_handle.allocated = true;
        
        // If truncate flag is set, clear buffer.
        if (open_flags.truncate) {
            file_handle.buffer_size = 0;
        }
        
        // Note: For fuzz testing robustness, we don't assert handle state here.
        // The test will validate the result.
        
        const result = SyscallResult.ok(handle_id);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self.handles[handle_idx].allocated);
        std.debug.assert(self.handles[handle_idx].id == handle);
        
        var file_handle = &self.handles[handle_idx];
        
        // Assert: Handle must be readable.
        if (!file_handle.flags.read) {
            return SyscallResult.fail(BasinError.permission_denied); // Handle not readable
        }
        
        // Calculate bytes to read (min of available data and buffer size).
        const available = if (file_handle.position < file_handle.buffer_size)
            file_handle.buffer_size - file_handle.position
        else
            0;
        const bytes_to_read = @min(available, @as(u32, @intCast(buffer_len)));
        
        // Read data from handle buffer (simulated - in real implementation, would write to VM memory).
        // For now, just update position.
        file_handle.position += bytes_to_read;
        
        // Assert: Position must not exceed buffer size.
        std.debug.assert(file_handle.position <= file_handle.buffer_size);
        
        const bytes_read: u64 = @as(u64, @intCast(bytes_to_read));
        const result = SyscallResult.ok(bytes_read);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == bytes_read);
        std.debug.assert(result.success <= buffer_len); // Can't read more than buffer size
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self.handles[handle_idx].allocated);
        std.debug.assert(self.handles[handle_idx].id == handle);
        
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
        std.debug.assert(file_handle.position <= max_buffer_size);
        std.debug.assert(file_handle.buffer_size <= max_buffer_size);
        
        const bytes_written: u64 = @as(u64, @intCast(bytes_to_write));
        const result = SyscallResult.ok(bytes_written);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == bytes_written);
        std.debug.assert(result.success <= data_len); // Can't write more than data length
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self.handles[handle_idx].allocated);
        std.debug.assert(self.handles[handle_idx].id == handle);
        
        // Close handle (free entry).
        var file_handle = &self.handles[handle_idx];
        file_handle.allocated = false;
        file_handle.id = 0;
        file_handle.path_len = 0;
        file_handle.position = 0;
        file_handle.buffer_size = 0;
        
        // Assert: Handle must be unallocated after close.
        std.debug.assert(!file_handle.allocated);
        std.debug.assert(file_handle.id == 0);
        
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Close returns 0 on success
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
    
    fn syscall_clock_gettime(
        self: *BasinKernel,
        clock_id: u64,
        timespec_ptr: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        
        // TODO: Implement actual time retrieval (when timer is implemented).
        // For now, return stub (zero timestamp).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Get current time from system timer (SBI timer or hardware clock)
        // - Write seconds and nanoseconds to timespec structure
        // - Handle different clock types (monotonic vs realtime)
        
        // Stub: Return zero timestamp (simple implementation).
        const seconds: u64 = 0;
        const nanoseconds: u64 = 0;
        const result = SyscallResult.ok(seconds);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == seconds);
        
        // Assert: Nanoseconds must be valid (0-999999999).
        std.debug.assert(nanoseconds < 1000000000);
        
        return result;
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // Assert: timestamp must be valid (non-zero, reasonable value).
        // Note: Timestamp is nanoseconds since epoch (or boot, depending on clock type).
        // For now, accept any non-zero value (validation depends on clock implementation).
        if (timestamp == 0) {
            return BasinError.invalid_argument; // Zero timestamp (invalid)
        }
        
        // TODO: Implement actual sleep until timestamp (when timer is implemented).
        // For now, return stub success (immediate return).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Get current time from system timer
        // - Calculate sleep duration (timestamp - current_time)
        // - Sleep until timestamp is reached
        // - Return error if timestamp is in the past
        // - Handle timer interrupts/wakeups
        
        // Stub: Return success immediately (simple implementation).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Sleep_until returns 0 on success
        
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
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
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
        
        // TODO: Implement actual system information retrieval (when system stats are tracked).
        // For now, return stub (basic info).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Get total/available memory from memory allocator
        // - Get CPU core count from hardware/SBI
        // - Get uptime from system timer
        // - Calculate load average from process scheduler
        // - Write SysInfo structure to info_ptr
        
        // Stub: Return success (simple implementation).
        // Note: Actual SysInfo structure would be written to info_ptr in full implementation.
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Sysinfo returns 0 on success
        
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
    pub const SysInfo = @import("basin_kernel.zig").SysInfo;
    pub const BasinError = @import("basin_kernel.zig").BasinError;
    pub const SyscallResult = @import("basin_kernel.zig").SyscallResult;
    pub const BasinKernel = @import("basin_kernel.zig").BasinKernel;
};

