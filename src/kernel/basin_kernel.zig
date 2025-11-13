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

/// Basin Kernel syscall interface (stub for future implementation).
/// Why: Define interface early, implement incrementally.
pub const BasinKernel = struct {
    /// Initialize Basin Kernel.
    /// Why: Explicit initialization, validate kernel state.
    pub fn init() BasinKernel {
        // TODO: Initialize kernel structures, memory management, process table, etc.
        return BasinKernel{};
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
        _ = self;
        _ = executable;
        _ = args_ptr;
        _ = args_len;
        _ = _arg4;
        
        // TODO: Implement spawn syscall.
        return BasinError.invalid_syscall;
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
        _ = self;
        _ = process;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement wait syscall.
        return BasinError.invalid_syscall;
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
            // Kernel chooses: allocate from user space.
            mapping_addr = USER_SPACE_START;
            
            // Assert: Kernel-chosen address must be page-aligned.
            std.debug.assert(mapping_addr % 4096 == 0);
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
        
        // For now, return address as handle (simple implementation).
        // TODO: Implement actual memory mapping (allocate pages, set permissions, track mappings).
        // Why: Simple implementation - VM will handle actual memory access.
        // Note: In full implementation, we would:
        // - Allocate pages from a page allocator
        // - Set page permissions based on flags
        // - Track mappings in a data structure
        // - Return a Handle (not raw address) for type safety
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
        _ = self;
        _ = region;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement unmap syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_protect(
        self: *BasinKernel,
        region: u64,
        flags: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = region;
        _ = flags;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement protect syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_channel_create(
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
        
        // TODO: Implement channel_create syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_channel_send(
        self: *BasinKernel,
        channel: u64,
        data_ptr: u64,
        data_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = channel;
        _ = data_ptr;
        _ = data_len;
        _ = _arg4;
        
        // TODO: Implement channel_send syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_channel_recv(
        self: *BasinKernel,
        channel: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = channel;
        _ = buffer_ptr;
        _ = buffer_len;
        _ = _arg4;
        
        // TODO: Implement channel_recv syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_open(
        self: *BasinKernel,
        path_ptr: u64,
        path_len: u64,
        flags: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = path_ptr;
        _ = path_len;
        _ = flags;
        _ = _arg4;
        
        // TODO: Implement open syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_read(
        self: *BasinKernel,
        handle: u64,
        buffer_ptr: u64,
        buffer_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = handle;
        _ = buffer_ptr;
        _ = buffer_len;
        _ = _arg4;
        
        // TODO: Implement read syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_write(
        self: *BasinKernel,
        handle: u64,
        data_ptr: u64,
        data_len: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = handle;
        _ = data_ptr;
        _ = data_len;
        _ = _arg4;
        
        // TODO: Implement write syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_close(
        self: *BasinKernel,
        handle: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = handle;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement close syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_clock_gettime(
        self: *BasinKernel,
        clock_id: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = clock_id;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement clock_gettime syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_sleep_until(
        self: *BasinKernel,
        timestamp: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = timestamp;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement sleep_until syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscall_sysinfo(
        self: *BasinKernel,
        info_ptr: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = info_ptr;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement sysinfo syscall.
        return BasinError.invalid_syscall;
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

