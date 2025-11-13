//! Basin Kernel — The foundation that holds everything
//!
//! Basin Kernel is a Zig monolith kernel for RISC-V64, designed for the next 30 years.
//! Non-POSIX, type-safe, minimal syscall surface, Tiger Style safety.
//!
//! **Vision**: Modern kernel design inspired by seL4 (minimal), Theseus OS (type-safe),
//! and Fuchsia (capability-based), but built in pure Zig for RISC-V.
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
    pub fn isValid(self: Handle) bool {
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
    pub fn handleSyscall(
        self: *BasinKernel,
        syscall_num: u32,
        arg1: u64,
        arg2: u64,
        arg3: u64,
        arg4: u64,
    ) BasinError!SyscallResult {
        _ = self; // TODO: Use kernel state
        
        // Decode syscall number.
        const syscall = @as(?Syscall, @enumFromInt(syscall_num)) orelse {
            return BasinError.invalid_syscall;
        };
        
        // Assert: syscall must be valid enum value.
        std.debug.assert(@intFromEnum(syscall) == syscall_num);
        
        // Route to appropriate syscall handler.
        // Why: Explicit routing, type-safe syscall handling.
        return switch (syscall) {
            .spawn => self.syscallSpawn(arg1, arg2, arg3, arg4),
            .exit => self.syscallExit(arg1, arg2, arg3, arg4),
            .yield => self.syscallYield(arg1, arg2, arg3, arg4),
            .wait => self.syscallWait(arg1, arg2, arg3, arg4),
            .map => self.syscallMap(arg1, arg2, arg3, arg4),
            .unmap => self.syscallUnmap(arg1, arg2, arg3, arg4),
            .protect => self.syscallProtect(arg1, arg2, arg3, arg4),
            .channel_create => self.syscallChannelCreate(arg1, arg2, arg3, arg4),
            .channel_send => self.syscallChannelSend(arg1, arg2, arg3, arg4),
            .channel_recv => self.syscallChannelRecv(arg1, arg2, arg3, arg4),
            .open => self.syscallOpen(arg1, arg2, arg3, arg4),
            .read => self.syscallRead(arg1, arg2, arg3, arg4),
            .write => self.syscallWrite(arg1, arg2, arg3, arg4),
            .close => self.syscallClose(arg1, arg2, arg3, arg4),
            .clock_gettime => self.syscallClockGettime(arg1, arg2, arg3, arg4),
            .sleep_until => self.syscallSleepUntil(arg1, arg2, arg3, arg4),
            .sysinfo => self.syscallSysinfo(arg1, arg2, arg3, arg4),
        };
    }
    
    // Syscall handlers (stubs for future implementation).
    // Why: Separate functions for each syscall, Tiger Style function length limit.
    
    fn syscallSpawn(
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
    
    fn syscallExit(
        self: *BasinKernel,
        status: u64,
        _arg2: u64,
        _arg3: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = status;
        _ = _arg2;
        _ = _arg3;
        _ = _arg4;
        
        // TODO: Implement exit syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscallYield(
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
        
        // TODO: Implement yield syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscallWait(
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
    
    fn syscallMap(
        self: *BasinKernel,
        addr: u64,
        size: u64,
        flags: u64,
        _arg4: u64,
    ) BasinError!SyscallResult {
        _ = self;
        _ = addr;
        _ = size;
        _ = flags;
        _ = _arg4;
        
        // TODO: Implement map syscall.
        return BasinError.invalid_syscall;
    }
    
    fn syscallUnmap(
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
    
    fn syscallProtect(
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
    
    fn syscallChannelCreate(
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
    
    fn syscallChannelSend(
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
    
    fn syscallChannelRecv(
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
    
    fn syscallOpen(
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
    
    fn syscallRead(
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
    
    fn syscallWrite(
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
    
    fn syscallClose(
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
    
    fn syscallClockGettime(
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
    
    fn syscallSleepUntil(
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
    
    fn syscallSysinfo(
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

