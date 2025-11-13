//! Grain Basin kernel — The foundation that holds everything
//!
//! Grain Basin kernel is a Zig monolith kernel for RISC-V64, designed for the next 30 years.
//! Non-POSIX, type-safe, minimal syscall surface, Tiger Style safety.
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
/// Tiger Style: Static allocation, explicit state tracking.
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
/// Tiger Style: Static allocation, max 256 entries (sufficient for 4MB VM).
const MAX_MAPPINGS: usize = 256;

/// Basin Kernel syscall interface (stub for future implementation).
/// Why: Define interface early, implement incrementally.
pub const BasinKernel = struct {
    /// Memory mapping table (static allocation).
    /// Why: Track memory mappings for map/unmap/protect syscalls.
    /// Tiger Style: Static allocation, max 256 entries.
    mappings: [MAX_MAPPINGS]MemoryMapping = [_]MemoryMapping{MemoryMapping.init()} ** MAX_MAPPINGS,
    
    /// Next address for kernel-chosen allocations (simple allocator).
    /// Why: Track allocation position for kernel-chosen addresses.
    next_alloc_addr: u64 = 0x100000, // Start after kernel space (1MB)
    
    /// Initialize Basin Kernel.
    /// Why: Explicit initialization, validate kernel state.
    pub fn init() BasinKernel {
        const kernel = BasinKernel{};
        
        // Assert: All mappings must be unallocated initially.
        for (kernel.mappings) |mapping| {
            std.debug.assert(!mapping.allocated);
        }
        
        // Assert: Next allocation address must be page-aligned.
        std.debug.assert(kernel.next_alloc_addr % 4096 == 0);
        
        return kernel;
    }
    
    /// Find free mapping entry.
    /// Why: Allocate new mapping entry.
    /// Returns: Index of free entry, or null if table full.
    /// Tiger Style: Comprehensive assertions for table state.
    fn find_free_mapping(self: *BasinKernel) ?usize {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        var found_index: ?usize = null;
        var free_count: usize = 0;
        
        for (self.mappings, 0..) |mapping, i| {
            if (!mapping.allocated) {
                free_count += 1;
                if (found_index == null) {
                    found_index = i;
                }
                
                // Assert: Unallocated mapping must have zero address and size.
                std.debug.assert(mapping.address == 0);
                std.debug.assert(mapping.size == 0);
            } else {
                // Assert: Allocated mapping must have valid address and size.
                std.debug.assert(mapping.address >= 0x100000); // User space start
                std.debug.assert(mapping.address % 4096 == 0); // Page-aligned
                std.debug.assert(mapping.size >= 4096); // At least 1 page
                std.debug.assert(mapping.size % 4096 == 0); // Page-aligned
            }
        }
        
        // Assert: Free count must be <= MAX_MAPPINGS.
        std.debug.assert(free_count <= MAX_MAPPINGS);
        
        return found_index;
    }
    
    /// Find mapping by address.
    /// Why: Look up mapping for unmap/protect operations.
    /// Returns: Index of mapping, or null if not found.
    /// Tiger Style: Comprehensive assertions for address validation.
    fn find_mapping_by_address(self: *BasinKernel, addr: u64) ?usize {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: Address must be page-aligned.
        std.debug.assert(addr % 4096 == 0);
        
        var found_index: ?usize = null;
        var match_count: usize = 0;
        
        for (self.mappings, 0..) |mapping, i| {
            if (mapping.allocated and mapping.address == addr) {
                match_count += 1;
                if (found_index == null) {
                    found_index = i;
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
    /// Tiger Style: Comprehensive assertions for overlap detection.
    fn check_overlap(self: *BasinKernel, addr: u64, size: u64) bool {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        // Assert: Address and size must be valid.
        std.debug.assert(addr % 4096 == 0); // Page-aligned
        std.debug.assert(size >= 4096); // At least 1 page
        std.debug.assert(size % 4096 == 0); // Page-aligned
        
        var overlap_count: usize = 0;
        
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
    /// Tiger Style: Comprehensive assertions for state validation.
    pub fn count_allocated_mappings(self: *BasinKernel) usize {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self_ptr % @alignOf(BasinKernel) == 0);
        
        var count: usize = 0;
        
        for (self.mappings) |mapping| {
            if (mapping.allocated) {
                count += 1;
                
                // Assert: Allocated mapping must have valid state.
                std.debug.assert(mapping.address >= 0x100000); // User space start
                std.debug.assert(mapping.address % 4096 == 0); // Page-aligned
                std.debug.assert(mapping.size >= 4096); // At least 1 page
                std.debug.assert(mapping.size % 4096 == 0); // Page-aligned
            }
        }
        
        // Assert: Count must be <= MAX_MAPPINGS.
        std.debug.assert(count <= MAX_MAPPINGS);
        
        return count;
    }
    
    /// Handle syscall from user space.
    /// Why: Central syscall entry point, validate syscall number and arguments.
    /// Tiger Style: Comprehensive assertions for all syscall parameters and state.
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
            .clock_gettime => self.syscall_clock_gettime(arg1, arg2, arg3, arg4),
            .sleep_until => self.syscall_sleep_until(arg1, arg2, arg3, arg4),
            .sysinfo => self.syscall_sysinfo(arg1, arg2, arg3, arg4),
        };
    }
    
    // Syscall handlers (stubs for future implementation).
    // Why: Separate functions for each syscall, Tiger Style function length limit.
    
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
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (path_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Path pointer exceeds VM memory
        }
        
        // Assert: path length must be reasonable (max 4096 bytes).
        if (path_len == 0) {
            return BasinError.invalid_argument; // Empty path
        }
        if (path_len > 4096) {
            return BasinError.invalid_argument; // Path too long
        }
        
        // Assert: path must fit within VM memory.
        if (path_ptr + path_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Path exceeds VM memory
        }
        
        // Decode flags (OpenFlags packed struct).
        const open_flags = @as(OpenFlags, @bitCast(@as(u32, @truncate(flags))));
        
        // Assert: flags padding must be zero (no reserved bits set).
        if (open_flags._padding != 0) {
            return BasinError.invalid_argument; // Reserved bits set
        }
        
        // TODO: Implement actual file opening (when file system is implemented).
        // For now, return a stub handle (simple implementation).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Validate path string (null-terminated, valid UTF-8)
        // - Look up file in file system
        // - Create file handle
        // - Return Handle (not raw integer) for type safety
        // - Set handle permissions based on flags
        
        // Stub: Return handle value 1 (simple implementation).
        const handle: u64 = 1;
        const result = SyscallResult.ok(handle);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == handle);
        
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
            return BasinError.invalid_argument; // Invalid handle
        }
        
        // Assert: buffer pointer must be valid (non-zero, within VM memory).
        if (buffer_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (buffer_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer pointer exceeds VM memory
        }
        
        // Assert: buffer length must be reasonable (max 1MB per read).
        if (buffer_len == 0) {
            return BasinError.invalid_argument; // Zero-length buffer
        }
        if (buffer_len > 1024 * 1024) {
            return BasinError.invalid_argument; // Buffer too large (> 1MB)
        }
        
        // Assert: buffer must fit within VM memory.
        if (buffer_ptr + buffer_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Buffer exceeds VM memory
        }
        
        // TODO: Implement actual file reading (when file system is implemented).
        // For now, return stub (0 bytes read).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up handle in handle table
        // - Verify handle is open and readable
        // - Read data from file into buffer
        // - Return bytes read count
        
        // Stub: Return 0 bytes read (simple implementation).
        const bytes_read: u64 = 0;
        const result = SyscallResult.ok(bytes_read);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == bytes_read);
        
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
            return BasinError.invalid_argument; // Invalid handle
        }
        
        // Assert: data pointer must be valid (non-zero, within VM memory).
        if (data_ptr == 0) {
            return BasinError.invalid_argument; // Null pointer
        }
        
        const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB default (matches syscall_map)
        if (data_ptr >= VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Data pointer exceeds VM memory
        }
        
        // Assert: data length must be reasonable (max 1MB per write).
        if (data_len == 0) {
            return BasinError.invalid_argument; // Zero-length data
        }
        if (data_len > 1024 * 1024) {
            return BasinError.invalid_argument; // Data too large (> 1MB)
        }
        
        // Assert: data must fit within VM memory.
        if (data_ptr + data_len > VM_MEMORY_SIZE) {
            return BasinError.invalid_argument; // Data exceeds VM memory
        }
        
        // TODO: Implement actual file writing (when file system is implemented).
        // For now, return stub (0 bytes written).
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up handle in handle table
        // - Verify handle is open and writable
        // - Write data from buffer to file
        // - Return bytes written count
        
        // Stub: Return 0 bytes written (simple implementation).
        const bytes_written: u64 = 0;
        const result = SyscallResult.ok(bytes_written);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == bytes_written);
        
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
            return BasinError.invalid_argument; // Invalid handle
        }
        
        // TODO: Implement actual file closing (when file system is implemented).
        // For now, return stub success.
        // Why: Simple stub - matches current kernel development stage.
        // Note: In full implementation, we would:
        // - Look up handle in handle table
        // - Verify handle is open
        // - Close file and free handle
        // - Remove handle from table
        // - Return error if handle not found
        
        // Stub: Return success (simple implementation).
        const result = SyscallResult.ok(0);
        
        // Assert: result must be success (not error).
        std.debug.assert(result == .success);
        std.debug.assert(result.success == 0); // Close returns 0 on success
        
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

