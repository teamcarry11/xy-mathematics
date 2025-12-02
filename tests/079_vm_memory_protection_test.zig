//! Tests for VM Memory Protection System
//!
//! Objective: Verify memory protection (page tables, permissions) works correctly.
//! Why: Ensure memory protection accurately enforces access control.
//! GrainStyle: Comprehensive test coverage, deterministic behavior.

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");

test "VM memory protection initialization" {
    const protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    try testing.expect(protection.page_table_len == 0);
}

test "VM memory protection map page" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    const mapped = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ | kernel_vm.memory_protection.MemoryPermissions.WRITE);
    try testing.expect(mapped == true);
    try testing.expect(protection.page_table_len == 1);
    try testing.expect(protection.page_table[0].virtual_address == 0x80000000);
    try testing.expect(protection.page_table[0].physical_address == 0x10000000);
}

test "VM memory protection get permissions" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    _ = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ | kernel_vm.memory_protection.MemoryPermissions.EXECUTE);
    const perms_opt = protection.get_permissions(0x80000001);
    try testing.expect(perms_opt != null);
    if (perms_opt) |perms| {
        try testing.expect((perms & kernel_vm.memory_protection.MemoryPermissions.READ) != 0);
        try testing.expect((perms & kernel_vm.memory_protection.MemoryPermissions.EXECUTE) != 0);
        try testing.expect((perms & kernel_vm.memory_protection.MemoryPermissions.WRITE) == 0);
    }
}

test "VM memory protection check permission" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    _ = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ);
    try testing.expect(protection.check_permission(0x80000000, kernel_vm.memory_protection.MemoryPermissions.READ) == true);
    try testing.expect(protection.check_permission(0x80000000, kernel_vm.memory_protection.MemoryPermissions.WRITE) == false);
    try testing.expect(protection.check_permission(0x90000000, kernel_vm.memory_protection.MemoryPermissions.READ) == false);
}

test "VM memory protection translate address" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    _ = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ);
    const phys_opt = protection.translate_address(0x80000100);
    try testing.expect(phys_opt != null);
    if (phys_opt) |phys| {
        try testing.expect(phys == 0x10000100);
    }
}

test "VM memory protection unmap page" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    _ = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ);
    try testing.expect(protection.page_table_len == 1);
    const unmapped = protection.unmap_page(0x80000000);
    try testing.expect(unmapped == true);
    try testing.expect(protection.page_table[0].present == false);
}

test "VM memory protection protect region" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    const protected = protection.protect_region(0x80000000, 0x80001000, kernel_vm.memory_protection.MemoryPermissions.READ);
    try testing.expect(protected == true);
    try testing.expect(protection.page_table_len >= 1);
}

test "VM memory protection get page count" {
    var protection = kernel_vm.memory_protection.VMMemoryProtection.init();
    _ = protection.map_page(0x80000000, 0x10000000, kernel_vm.memory_protection.MemoryPermissions.READ);
    _ = protection.map_page(0x80001000, 0x10001000, kernel_vm.memory_protection.MemoryPermissions.WRITE);
    try testing.expect(protection.get_page_count() == 2);
}

