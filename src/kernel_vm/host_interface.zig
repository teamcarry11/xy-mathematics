//! Host Interface Abstraction
//! Why: Abstract host system operations for Vantage VM adaptation.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const builtin = @import("builtin");
const Debug = @import("../kernel/debug.zig");
const host_macos = @import("host_macos.zig");

/// Host memory protection flags.
/// Why: Abstract memory protection flags across host systems.
pub const HostMemoryProtection = struct {
    /// Read permission.
    read: bool,
    /// Write permission.
    write: bool,
    /// Execute permission.
    execute: bool,
    
    /// Create protection flags from bitmask.
    /// Why: Convert bitmask to structured flags.
    pub fn from_bits(bits: u32) HostMemoryProtection {
        return HostMemoryProtection{
            .read = (bits & 0x1) != 0,
            .write = (bits & 0x2) != 0,
            .execute = (bits & 0x4) != 0,
        };
    }
    
    /// Convert to bitmask.
    /// Why: Convert structured flags to bitmask.
    pub fn to_bits(self: *const HostMemoryProtection) u32 {
        var bits: u32 = 0;
        if (self.read) bits |= 0x1;
        if (self.write) bits |= 0x2;
        if (self.execute) bits |= 0x4;
        return bits;
    }
};

/// Host memory allocation result.
/// Why: Type-safe memory allocation result.
pub const HostMemoryResult = union(enum) {
    /// Memory allocated successfully.
    success: []align(16384) u8,
    /// Allocation failed.
    failed: void,
};

/// Host JIT write protection state.
/// Why: Abstract JIT write protection across host systems.
pub const HostJitWriteProtection = enum(u32) {
    /// Write protection enabled (JIT code is read-only).
    enabled = 0,
    /// Write protection disabled (JIT code is writable).
    disabled = 1,
};

/// Host interface function pointer types.
/// Why: Type-safe function pointers for host operations.
pub const HostInterface = struct {
    /// Allocate executable memory for JIT.
    /// Why: Abstract memory allocation for JIT code.
    /// Contract: size must be valid, alignment must be 16KB.
    allocate_jit_memory: *const fn (size: u32) HostMemoryResult,
    
    /// Free JIT memory.
    /// Why: Abstract memory deallocation for JIT code.
    /// Contract: memory must be valid JIT memory.
    free_jit_memory: *const fn (memory: []align(16384) u8) void,
    
    /// Set JIT write protection.
    /// Why: Abstract JIT write protection for code signing.
    /// Contract: state must be valid.
    set_jit_write_protection: *const fn (state: HostJitWriteProtection) void,
    
    /// Get performance counter value.
    /// Why: Abstract performance counter access.
    /// Contract: counter_id must be valid.
    get_performance_counter: *const fn (counter_id: u32) u64,
    
    /// Initialize performance counters.
    /// Why: Abstract performance counter initialization.
    /// Contract: Must be called before using performance counters.
    init_performance_counters: *const fn () void,
    
    /// Whether host interface is initialized.
    initialized: bool,
    
    /// Initialize host interface.
    /// Why: Set up host interface with platform-specific implementation.
    /// Contract: Must be called once at VM initialization.
    pub fn init() HostInterfaceResult {
        // Detect macOS host.
        const macos_host_result = host_macos.MacOSHost.init();
        
        switch (macos_host_result) {
            .success => |macos_host| {
                // Create macOS-specific host interface.
                return .{ .success = create_macos_host_interface(macos_host) };
            },
            .failed => {
                // Not macOS or unsupported - return failed.
                return .failed;
            },
        }
    }
    
    /// Allocate executable memory for JIT.
    /// Why: Platform-agnostic JIT memory allocation.
    /// Contract: size must be valid, alignment must be 16KB.
    pub fn allocate_jit_memory_wrapper(self: *const HostInterface, size: u32) HostMemoryResult {
        // Assert: Host interface must be initialized.
        Debug.kassert(self.initialized, "Host interface not initialized", .{});
        
        // Assert: Size must be valid (max 64MB).
        const MAX_JIT_MEMORY: u32 = 64 * 1024 * 1024;
        Debug.kassert(size <= MAX_JIT_MEMORY, "JIT memory size too large", .{});
        
        // Call platform-specific allocation.
        return self.allocate_jit_memory(size);
    }
    
    /// Free JIT memory.
    /// Why: Platform-agnostic JIT memory deallocation.
    /// Contract: memory must be valid JIT memory.
    pub fn free_jit_memory_wrapper(self: *const HostInterface, memory: []align(16384) u8) void {
        // Assert: Host interface must be initialized.
        Debug.kassert(self.initialized, "Host interface not initialized", .{});
        
        // Assert: Memory must be valid.
        Debug.kassert(memory.len > 0, "JIT memory is empty", .{});
        
        // Call platform-specific deallocation.
        self.free_jit_memory(memory);
    }
    
    /// Set JIT write protection.
    /// Why: Platform-agnostic JIT write protection.
    /// Contract: state must be valid.
    pub fn set_jit_write_protection_wrapper(self: *const HostInterface, state: HostJitWriteProtection) void {
        // Assert: Host interface must be initialized.
        Debug.kassert(self.initialized, "Host interface not initialized", .{});
        
        // Call platform-specific write protection.
        self.set_jit_write_protection(state);
    }
    
    /// Get performance counter value.
    /// Why: Platform-agnostic performance counter access.
    /// Contract: counter_id must be valid.
    pub fn get_performance_counter_wrapper(self: *const HostInterface, counter_id: u32) u64 {
        // Assert: Host interface must be initialized.
        Debug.kassert(self.initialized, "Host interface not initialized", .{});
        
        // Call platform-specific performance counter.
        return self.get_performance_counter(counter_id);
    }
    
    /// Initialize performance counters.
    /// Why: Platform-agnostic performance counter initialization.
    pub fn init_performance_counters_wrapper(self: *const HostInterface) void {
        // Assert: Host interface must be initialized.
        Debug.kassert(self.initialized, "Host interface not initialized", .{});
        
        // Call platform-specific initialization.
        self.init_performance_counters();
    }
};

/// Host interface initialization result.
/// Why: Type-safe host interface initialization result.
pub const HostInterfaceResult = union(enum) {
    /// Host interface initialized successfully.
    success: HostInterface,
    /// Initialization failed (unsupported platform).
    failed: void,
};

/// Create macOS-specific host interface.
/// Why: Implement macOS host interface with version-specific adaptations.
/// Contract: macos_host must be initialized.
fn create_macos_host_interface(macos_host: host_macos.MacOSHost) HostInterface {
    // Assert: macOS host must be initialized.
    Debug.kassert(macos_host.initialized, "macOS host not initialized", .{});
    
    // Create macOS-specific function implementations.
    return HostInterface{
        .allocate_jit_memory = macos_allocate_jit_memory,
        .free_jit_memory = macos_free_jit_memory,
        .set_jit_write_protection = macos_set_jit_write_protection,
        .get_performance_counter = macos_get_performance_counter,
        .init_performance_counters = macos_init_performance_counters,
        .initialized = true,
    };
}

/// macOS JIT memory allocation implementation.
/// Why: macOS-specific JIT memory allocation with version adaptation.
fn macos_allocate_jit_memory(size: u32) HostMemoryResult {
    // Assert: Must be running on macOS.
    if (builtin.os.tag != .macos) {
        return .failed;
    }
    
    // Assert: Size must be valid.
    const MAX_JIT_MEMORY: u32 = 64 * 1024 * 1024;
    Debug.kassert(size <= MAX_JIT_MEMORY, "JIT memory size too large", .{});
    
    // Use macOS mmap with JIT flags.
    const PROT_READ = 0x1;
    const PROT_WRITE = 0x2;
    const PROT_EXEC = 0x4;
    
    const ptr = std.posix.mmap(
        null,
        size,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .JIT = true },
        -1,
        0,
    ) catch {
        return .failed;
    };
    
    const buffer = @as([]align(16384) u8, @alignCast(ptr[0..size]));
    
    // Set JIT write protection (disable for initialization).
    macos_set_jit_write_protection(.disabled);
    @memset(buffer, 0);
    macos_set_jit_write_protection(.enabled);
    
    return .{ .success = buffer };
}

/// macOS JIT memory deallocation implementation.
/// Why: macOS-specific JIT memory deallocation.
fn macos_free_jit_memory(memory: []align(16384) u8) void {
    // Assert: Memory must be valid.
    Debug.kassert(memory.len > 0, "JIT memory is empty", .{});
    
    // Use macOS munmap.
    _ = std.posix.munmap(memory);
}

// External function for macOS JIT write protection.
extern fn pthread_jit_write_protect_np(enabled: c_int) void;

/// macOS JIT write protection implementation.
/// Why: macOS-specific JIT write protection with version adaptation.
fn macos_set_jit_write_protection(state: HostJitWriteProtection) void {
    // Assert: Must be running on macOS.
    if (builtin.os.tag != .macos) {
        return;
    }
    
    // Use macOS pthread_jit_write_protect_np.
    // Note: This function is available on macOS 11.0+ (Big Sur and later).
    // For macOS Tahoe 26.3 Beta, this is definitely available.
    const enabled: c_int = if (state == .enabled) 1 else 0;
    pthread_jit_write_protect_np(enabled);
}

/// macOS performance counter implementation.
/// Why: macOS-specific performance counter access.
/// Note: VM statistics use simple counters (platform-agnostic).
/// This function is for future integration with macOS hardware performance counters.
fn macos_get_performance_counter(counter_id: u32) u64 {
    // Assert: Counter ID must be valid.
    Debug.kassert(counter_id < 16, "Invalid performance counter ID", .{});
    
    // Use macOS performance counters.
    // Note: Current VM statistics use simple counters (platform-agnostic).
    // This function is for future integration with macOS hardware performance counters
    // (e.g., via mach_absolute_time, Instruments integration).
    // For now, return 0 (VM statistics track counters directly).
    _ = counter_id;
    return 0;
}

/// macOS performance counter initialization implementation.
/// Why: macOS-specific performance counter initialization.
/// Note: VM statistics use simple counters (platform-agnostic).
/// This function is for future integration with macOS hardware performance counters.
fn macos_init_performance_counters() void {
    // Initialize macOS performance counters.
    // Note: Current VM statistics use simple counters (platform-agnostic).
    // This function is for future integration with macOS hardware performance counters
    // (e.g., via mach_absolute_time, Instruments integration).
    // For now, no initialization needed (VM statistics track counters directly).
}

/// Global host interface instance.
/// Why: Single host interface instance for VM use.
var global_host_interface: ?HostInterface = null;

/// Set global host interface instance.
/// Why: Initialize host interface for VM use.
/// Contract: interface must be initialized.
pub fn set_host_interface(interface: HostInterface) void {
    // Assert: Interface must be initialized.
    Debug.kassert(interface.initialized, "Host interface not initialized", .{});
    
    global_host_interface = interface;
}

/// Get global host interface instance.
/// Why: Access host interface from VM code.
/// Contract: Interface must be set before use.
pub fn get_host_interface() ?*const HostInterface {
    return if (global_host_interface) |*interface| interface else null;
}
