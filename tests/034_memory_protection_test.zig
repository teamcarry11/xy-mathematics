//! Memory Protection Enforcement Tests
//! Why: Comprehensive TigerStyle tests for memory protection and permission checking.
//! Grain Style: Explicit types (u32/u64 not usize), minimum 2 assertions per function.

const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.basin_kernel.BasinKernel;
const MapFlags = basin_kernel.basin_kernel.MapFlags;

// Test memory protection read-only mapping.
test "memory protection read only" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Create read-only mapping.
    const map_addr: u64 = 0x100000; // User space
    const map_size: u64 = 4096; // 1 page
    const flags = MapFlags.init(.{ .read = true, .write = false, .execute = false });
    const flags_u32 = @as(u32, @bitCast(flags));
    
    const map_result = kernel.handle_syscall(10, map_addr, map_size, flags_u32, 0);
    _ = map_result catch {};
    
    // Check permissions for read-only mapping.
    const permissions = kernel.check_memory_permission(map_addr);
    
    // Assert: Read-only mapping must have read permission only (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |perm_flags| {
        try std.testing.expect(perm_flags.read == true);
        try std.testing.expect(perm_flags.write == false);
        try std.testing.expect(perm_flags.execute == false);
    }
    
    // Assert: Permissions must be consistent (postcondition).
    const permissions2 = kernel.check_memory_permission(map_addr + 100);
    try std.testing.expect(permissions2 != null);
}

// Test memory protection write-only mapping.
test "memory protection write only" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Create write-only mapping.
    const map_addr: u64 = 0x100000; // User space
    const map_size: u64 = 4096; // 1 page
    const flags = MapFlags.init(.{ .read = false, .write = true, .execute = false });
    const flags_u32 = @as(u32, @bitCast(flags));
    
    const map_result = kernel.handle_syscall(10, map_addr, map_size, flags_u32, 0);
    _ = map_result catch {};
    
    // Check permissions for write-only mapping.
    const permissions = kernel.check_memory_permission(map_addr);
    
    // Assert: Write-only mapping must have write permission only (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |perm_flags| {
        try std.testing.expect(perm_flags.read == false);
        try std.testing.expect(perm_flags.write == true);
        try std.testing.expect(perm_flags.execute == false);
    }
}

// Test memory protection execute-only mapping.
test "memory protection execute only" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Create execute-only mapping.
    const map_addr: u64 = 0x100000; // User space
    const map_size: u64 = 4096; // 1 page
    const flags = MapFlags.init(.{ .read = false, .write = false, .execute = true });
    const flags_u32 = @as(u32, @bitCast(flags));
    
    const map_result = kernel.handle_syscall(10, map_addr, map_size, flags_u32, 0);
    _ = map_result catch {};
    
    // Check permissions for execute-only mapping.
    const permissions = kernel.check_memory_permission(map_addr);
    
    // Assert: Execute-only mapping must have execute permission only (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |perm_flags| {
        try std.testing.expect(perm_flags.read == false);
        try std.testing.expect(perm_flags.write == false);
        try std.testing.expect(perm_flags.execute == true);
    }
}

// Test memory protection kernel space always accessible.
test "memory protection kernel space" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Kernel space (0x80000000+) should always be readable/writable/executable.
    const kernel_addr: u64 = 0x80000000;
    
    // Check permissions for kernel address.
    const permissions = kernel.check_memory_permission(kernel_addr);
    
    // Assert: Kernel space must have all permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |flags| {
        try std.testing.expect(flags.read == true);
        try std.testing.expect(flags.write == true);
        try std.testing.expect(flags.execute == true);
    }
}

// Test memory protection framebuffer always readable/writable.
test "memory protection framebuffer" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Framebuffer space (0x90000000+) should always be readable/writable.
    const fb_addr: u64 = 0x90000000;
    
    // Check permissions for framebuffer address.
    const permissions = kernel.check_memory_permission(fb_addr);
    
    // Assert: Framebuffer must have read/write permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |flags| {
        try std.testing.expect(flags.read == true);
        try std.testing.expect(flags.write == true);
        try std.testing.expect(flags.execute == false); // Framebuffer not executable
    }
}

// Test memory protection unmapped address.
test "memory protection unmapped address" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Unmapped address in user space should return null.
    const unmapped_addr: u64 = 0x200000; // User space, not mapped
    
    // Check permissions for unmapped address.
    const permissions = kernel.check_memory_permission(unmapped_addr);
    
    // Assert: Unmapped address must return null (postcondition).
    try std.testing.expect(permissions == null);
}

// Test memory protection read-write-execute mapping.
test "memory protection read write execute" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Create read-write-execute mapping.
    const map_addr: u64 = 0x100000; // User space
    const map_size: u64 = 4096; // 1 page
    const flags = MapFlags.init(.{ .read = true, .write = true, .execute = true });
    const flags_u32 = @as(u32, @bitCast(flags));
    
    const map_result = kernel.handle_syscall(10, map_addr, map_size, flags_u32, 0);
    _ = map_result catch {};
    
    // Check permissions for read-write-execute mapping.
    const permissions = kernel.check_memory_permission(map_addr);
    
    // Assert: Read-write-execute mapping must have all permissions (postcondition).
    try std.testing.expect(permissions != null);
    if (permissions) |perm_flags| {
        try std.testing.expect(perm_flags.read == true);
        try std.testing.expect(perm_flags.write == true);
        try std.testing.expect(perm_flags.execute == true);
    }
}

// Test memory protection multiple mappings.
test "memory protection multiple mappings" {
    var kernel = BasinKernel.init();
    
    // Assert: Kernel must be initialized (precondition).
    try std.testing.expect(kernel.scheduler.initialized);
    
    // Create multiple mappings with different permissions.
    const map1_addr: u64 = 0x100000; // User space
    const map2_addr: u64 = 0x101000; // User space, next page
    const map_size: u64 = 4096; // 1 page
    
    const flags1 = MapFlags.init(.{ .read = true, .write = false, .execute = false });
    const flags2 = MapFlags.init(.{ .read = false, .write = true, .execute = false });
    const flags1_u32 = @as(u32, @bitCast(flags1));
    const flags2_u32 = @as(u32, @bitCast(flags2));
    
    const map1_result = kernel.handle_syscall(10, map1_addr, map_size, flags1_u32, 0);
    _ = map1_result catch {};
    const map2_result = kernel.handle_syscall(10, map2_addr, map_size, flags2_u32, 0);
    _ = map2_result catch {};
    
    // Check permissions for both mappings.
    const permissions1 = kernel.check_memory_permission(map1_addr);
    const permissions2 = kernel.check_memory_permission(map2_addr);
    
    // Assert: Both mappings must have correct permissions (postcondition).
    try std.testing.expect(permissions1 != null);
    try std.testing.expect(permissions2 != null);
    if (permissions1) |perm1| {
        try std.testing.expect(perm1.read == true);
        try std.testing.expect(perm1.write == false);
    }
    if (permissions2) |perm2| {
        try std.testing.expect(perm2.read == false);
        try std.testing.expect(perm2.write == true);
    }
}
