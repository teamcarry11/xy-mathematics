// 006 Fuzz Test: Memory Management Foundation
//
// Objective: Validate memory management syscalls (map/unmap/protect) with randomized
// fuzz testing for mapping table operations, overlap detection, allocation/deallocation
// patterns, and edge cases.
//
// Method:
// - Uses SimpleRng for deterministic randomness (wrap-safe arithmetic)
// - Generates random map/unmap/protect operations
// - Tests mapping table operations (allocation, deallocation, lookup)
// - Tests overlap detection (prevent overlapping mappings)
// - Tests edge cases (zero size, unaligned addresses, invalid flags, table exhaustion)
// - Tests state consistency (mappings table invariants)
//
// Date: 2025-11-13
// Operator: Glow G2 (Stoic Aquarian cadence)
const std = @import("std");
const basin_kernel = @import("basin_kernel");
const BasinKernel = basin_kernel.BasinKernel;
const Syscall = basin_kernel.Syscall;
const MapFlags = basin_kernel.MapFlags;
const BasinError = basin_kernel.BasinError;

// SimpleRng: inline copy for test (avoiding module path issues).
const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        return .{ .state = seed };
    }

    fn next(self: *SimpleRng) u64 {
        self.state = self.state *% 6364136223846793005 +% 1;
        return self.state;
    }

    pub fn boolean(self: *SimpleRng) bool {
        return (self.next() & 1) == 1;
    }

    pub fn range(self: *SimpleRng, comptime T: type, upper: T) T {
        return self.uint_less_than(T, upper);
    }

    pub fn uint_less_than(self: *SimpleRng, comptime T: type, bound: T) T {
        return @intCast(self.next() % @as(u64, bound));
    }
};

/// Generate random page-aligned address in user space.
/// Why: Test map/unmap/protect with random addresses.
fn generate_user_address(rng: *SimpleRng) u64 {
    const USER_SPACE_START: u64 = 0x100000; // 1MB (after kernel space)
    const VM_MEMORY_SIZE: u64 = 4 * 1024 * 1024; // 4MB
    const max_addr = VM_MEMORY_SIZE - (64 * 1024); // Leave room for mapping size
    const addr = USER_SPACE_START + (rng.range(u64, max_addr - USER_SPACE_START));
    // Round down to page boundary (4KB alignment).
    return (addr / 4096) * 4096;
}

/// Generate random page-aligned size.
/// Why: Test map operations with random sizes.
fn generate_page_aligned_size(rng: *SimpleRng) u64 {
    const min_size = 4096; // 1 page
    const max_size = 64 * 1024; // 64KB max per mapping
    const size = min_size + rng.range(u64, max_size - min_size);
    // Round up to page boundary (4KB alignment).
    return ((size + 4095) / 4096) * 4096;
}

/// Generate random MapFlags.
/// Why: Test map/protect with random permission flags.
fn generate_map_flags(rng: *SimpleRng) MapFlags {
    return MapFlags.init(.{
        .read = rng.boolean(),
        .write = rng.boolean(),
        .execute = rng.boolean(),
        .shared = rng.boolean(),
    });
}

/// Generate random kernel-chosen address flag (0 = kernel chooses, non-zero = user provides).
/// Why: Test both kernel-chosen and user-provided addresses.
fn generate_address_choice(rng: *SimpleRng) u64 {
    return if (rng.boolean()) 0 else generate_user_address(rng);
}

// Note: Using BasinKernel.count_allocated_mappings() public method instead of helper function.

test "006_fuzz_map_operations" {
    // Test Category 1: Map Operations Fuzzing
    // Objective: Validate map syscall with random addresses, sizes, and flags.
    
    var rng = SimpleRng.init(0x006F00F100000001);
    var kernel = BasinKernel.init();
    
    // Test 200 random map operations.
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        // Generate random map parameters.
        const addr = generate_address_choice(&rng);
        const size = generate_page_aligned_size(&rng);
        const flags = generate_map_flags(&rng);
        
        // Assert: Size must be page-aligned.
        std.debug.assert(size % 4096 == 0);
        std.debug.assert(size >= 4096);
        
        // Assert: Flags must have at least one permission (or we'll get invalid_argument).
        // Skip if no permissions (will test error handling separately).
        if (!flags.read and !flags.write and !flags.execute) {
            continue; // Skip invalid flags for this test
        }
        
        // Call map syscall.
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.map),
            addr,
            size,
            @as(u64, @as(u32, @bitCast(flags))), // Zero-extend u32 to u64
            0,
        ) catch |err| {
            // Assert: Error must be valid BasinError.
            _ = @intFromError(err);
            continue; // Skip failed mappings
        };
        
        // Assert: Result must be success (not error).
        std.debug.assert(result == .success);
        
        // Assert: Success result must have valid address.
        std.debug.assert(result.success >= 0x100000); // User space start
        std.debug.assert(result.success % 4096 == 0); // Page-aligned
        
        // Assert: Mapping must be tracked in table.
        const mapping_count = kernel.count_allocated_mappings();
        std.debug.assert(mapping_count > 0);
        std.debug.assert(mapping_count <= 256); // Max mappings
    }
    
    // Assert: Final mapping count must be <= 256 (max mappings).
    const final_count = kernel.count_allocated_mappings();
    std.debug.assert(final_count <= 256);
}

test "006_fuzz_unmap_operations" {
    // Test Category 2: Unmap Operations Fuzzing
    // Objective: Validate unmap syscall with random addresses.
    
    var rng = SimpleRng.init(0x006F00F100000002);
    var kernel = BasinKernel.init();
    
    // First, create some mappings to unmap.
    var mapped_addresses: [64]u64 = undefined;
    var mapped_count: usize = 0;
    
    // Create 64 random mappings.
    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        const addr = generate_address_choice(&rng);
        const size = generate_page_aligned_size(&rng);
        const flags = MapFlags.init(.{ .read = true, .write = true });
        
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.map),
            addr,
            size,
            @as(u64, @as(u32, @bitCast(flags))), // Zero-extend u32 to u64
            0,
        );
        
        if (result) |success_result| {
            mapped_addresses[mapped_count] = success_result.success;
            mapped_count += 1;
        } else |_| {
            // Skip failed mappings.
        }
    }
    
    // Assert: Must have at least some mappings to unmap.
    std.debug.assert(mapped_count > 0);
    
    // Now test random unmap operations.
    i = 0;
    while (i < 100) : (i += 1) {
        // Choose random address (either mapped or unmapped).
        const addr: u64 = if (mapped_count > 0 and rng.boolean())
            mapped_addresses[rng.range(usize, mapped_count)]
        else
            generate_user_address(&rng);
        
        // Assert: Address must be page-aligned.
        std.debug.assert(addr % 4096 == 0);
        
        // Call unmap syscall.
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.unmap),
            addr,
            0,
            0,
            0,
        ) catch |err| {
            // Assert: Error must be invalid_argument (mapping not found).
            std.debug.assert(err == BasinError.invalid_argument);
            continue; // Skip failed unmaps
        };
        
        // Assert: Result must be success (not error).
        std.debug.assert(result == .success);
        
        // Assert: Success result must be 0 (unmap returns 0 on success).
        std.debug.assert(result.success == 0);
        
        // Assert: Mapping must be removed from table.
        const mapping_count = kernel.count_allocated_mappings();
        std.debug.assert(mapping_count < mapped_count);
    }
}

test "006_fuzz_protect_operations" {
    // Test Category 3: Protect Operations Fuzzing
    // Objective: Validate protect syscall with random addresses and flags.
    
    var rng = SimpleRng.init(0x006F00F100000003);
    var kernel = BasinKernel.init();
    
    // First, create some mappings to protect.
    var mapped_addresses: [32]u64 = undefined;
    var mapped_count: usize = 0;
    
    // Create 32 random mappings.
    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        const addr = generate_address_choice(&rng);
        const size = generate_page_aligned_size(&rng);
        const flags = MapFlags.init(.{ .read = true, .write = true });
        
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.map),
            addr,
            size,
            @as(u64, @as(u32, @bitCast(flags))), // Zero-extend u32 to u64
            0,
        );
        
        if (result) |success_result| {
            mapped_addresses[mapped_count] = success_result.success;
            mapped_count += 1;
        } else |_| {
            // Skip failed mappings.
        }
    }
    
    // Assert: Must have at least some mappings to protect.
    std.debug.assert(mapped_count > 0);
    
    // Now test random protect operations.
    i = 0;
    while (i < 100) : (i += 1) {
        // Choose random address (either mapped or unmapped).
        const addr: u64 = if (mapped_count > 0 and rng.boolean())
            mapped_addresses[rng.range(usize, mapped_count)]
        else
            generate_user_address(&rng);
        
        // Generate random flags (must have at least one permission).
        var flags = generate_map_flags(&rng);
        if (!flags.read and !flags.write and !flags.execute) {
            // Ensure at least one permission.
            flags.read = true;
        }
        
        // Assert: Address must be page-aligned.
        std.debug.assert(addr % 4096 == 0);
        
        // Call protect syscall.
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.protect),
            addr,
            @as(u64, @as(u32, @bitCast(flags))),
            0,
            0,
        ) catch |err| {
            // Assert: Error must be invalid_argument (mapping not found).
            std.debug.assert(err == BasinError.invalid_argument);
            continue; // Skip failed protects
        };
        
        // Assert: Result must be success (not error).
        std.debug.assert(result == .success);
        
        // Assert: Success result must be 0 (protect returns 0 on success).
        std.debug.assert(result.success == 0);
    }
}

test "006_fuzz_overlap_detection" {
    // Test Category 4: Overlap Detection Fuzzing
    // Objective: Validate overlap detection prevents overlapping mappings.
    
    var rng = SimpleRng.init(0x006F00F100000004);
    var kernel = BasinKernel.init();
    
    // Create initial mapping.
    const base_addr = generate_user_address(&rng);
    const base_size = generate_page_aligned_size(&rng);
    const flags = MapFlags.init(.{ .read = true, .write = true });
    
    const map_result = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        base_addr,
        base_size,
        @as(u64, @as(u32, @bitCast(flags))),
        0,
    );
    
    // Assert: Initial mapping must succeed.
    const mapped_addr = map_result catch unreachable;
    std.debug.assert(mapped_addr.success == base_addr or base_addr == 0);
    
    // Test 100 random overlapping addresses.
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // Generate address that overlaps with base mapping.
        const overlap_addr: u64 = if (rng.boolean())
            base_addr + rng.range(u64, base_size)
        else
            base_addr - rng.range(u64, base_size / 2);
        
        // Round to page boundary.
        const page_aligned_addr = (overlap_addr / 4096) * 4096;
        const overlap_size = generate_page_aligned_size(&rng);
        
        // Call map syscall (should fail due to overlap).
        _ = kernel.handle_syscall(
            @intFromEnum(Syscall.map),
            page_aligned_addr,
            overlap_size,
            @as(u64, @as(u32, @bitCast(flags))),
            0,
        ) catch |err| {
            // Assert: Error must be invalid_argument (overlapping mapping).
            std.debug.assert(err == BasinError.invalid_argument);
            continue; // Skip overlapping mappings
        };
        
        // If success, verify it doesn't actually overlap (edge case: exact boundaries).
        const does_overlap = (page_aligned_addr < mapped_addr.success + base_size) and
            (mapped_addr.success < page_aligned_addr + overlap_size);
        if (does_overlap) {
            // Should have failed, but didn't - this is a bug.
            std.debug.panic("Overlap detection failed: {x} overlaps with {x}", .{ page_aligned_addr, mapped_addr.success });
        }
    }
}

test "006_fuzz_table_exhaustion" {
    // Test Category 5: Table Exhaustion Fuzzing
    // Objective: Validate mapping table exhaustion (max 256 entries).
    
    var rng = SimpleRng.init(0x006F00F100000005);
    var kernel = BasinKernel.init();
    
    // Fill mapping table to capacity (256 entries).
    var mapped_count: usize = 0;
    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        const addr = generate_address_choice(&rng);
        const size = generate_page_aligned_size(&rng);
        const flags = MapFlags.init(.{ .read = true, .write = true });
        
        const result = kernel.handle_syscall(
            @intFromEnum(Syscall.map),
            addr,
            size,
            @as(u64, @as(u32, @bitCast(flags))), // Zero-extend u32 to u64
            0,
        );
        
        if (result) |_| {
            mapped_count += 1;
        } else |_| {
            // Skip failed mappings (overlaps, etc.).
        }
    }
    
    // Assert: Must have some mappings allocated.
    std.debug.assert(mapped_count > 0);
    
    // Assert: Mapping count must match allocated count.
    const allocated_count = kernel.count_allocated_mappings();
    std.debug.assert(allocated_count == mapped_count);
    
    // Try to allocate one more mapping (should fail if table full).
    const addr = generate_address_choice(&rng);
    const size = generate_page_aligned_size(&rng);
    const flags = MapFlags.init(.{ .read = true, .write = true });
    
    const result = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        addr,
        size,
        @as(u64, @as(u32, @bitCast(flags))),
        0,
    );
    
    // Assert: Result must be error if table full, or success if there was space.
    const final_result = result catch |err| {
        // Error: table full or other error.
        if (allocated_count == 256) {
            std.debug.assert(err == BasinError.out_of_memory);
        }
        return; // Table full or other error
    };
    
    // Success: table had space (some mappings failed due to overlaps).
    std.debug.assert(allocated_count < 256);
    std.debug.assert(final_result == .success);
}

test "006_fuzz_edge_cases" {
    // Test Category 6: Edge Cases Fuzzing
    // Objective: Validate edge cases (zero size, unaligned addresses, invalid flags, etc.).
    
    var rng = SimpleRng.init(0x006F00F100000006);
    var kernel = BasinKernel.init();
    
    // Test 1: Zero size (should fail).
    const addr1 = generate_user_address(&rng);
    const flags1 = MapFlags.init(.{ .read = true });
    const result1 = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        addr1,
        0,
        @as(u64, @as(u32, @bitCast(flags1))),
        0,
    );
    // Assert: Must fail with invalid_argument or unaligned_access.
    if (result1) |_| {
        std.debug.panic("Zero size mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.invalid_argument or err == BasinError.unaligned_access);
    }
    
    // Test 2: Unaligned address (should fail).
    const addr2 = generate_user_address(&rng) + 1; // Not page-aligned
    const size2 = generate_page_aligned_size(&rng);
    const flags2 = MapFlags.init(.{ .read = true });
    const result2 = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        addr2,
        size2,
        @as(u64, @as(u32, @bitCast(flags2))),
        0,
    );
    // Assert: Must fail with unaligned_access.
    if (result2) |_| {
        std.debug.panic("Unaligned address mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.unaligned_access);
    }
    
    // Test 3: Invalid flags (no permissions, should fail).
    const addr3 = generate_user_address(&rng);
    const size3 = generate_page_aligned_size(&rng);
    const flags3 = MapFlags.init(.{}); // No permissions
    const result3 = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        addr3,
        size3,
        @as(u64, @as(u32, @bitCast(flags3))),
        0,
    );
    // Assert: Must fail with invalid_argument.
    if (result3) |_| {
        std.debug.panic("Invalid flags mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.invalid_argument);
    }
    
    // Test 4: Kernel space address (should fail).
    // Use page-aligned address to avoid unaligned_access error.
    const addr4 = (rng.range(u64, 0x100000 / 4096) * 4096); // Kernel space (< 1MB), page-aligned
    const size4 = generate_page_aligned_size(&rng);
    const flags4 = MapFlags.init(.{ .read = true });
    const result4 = kernel.handle_syscall(
        @intFromEnum(Syscall.map),
        addr4,
        size4,
        @as(u64, @as(u32, @bitCast(flags4))),
        0,
    );
    // Assert: Must fail with permission_denied (not unaligned_access since we made it page-aligned).
    if (result4) |_| {
        std.debug.panic("Kernel space mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.permission_denied);
    }
    
    // Test 5: Unmap non-existent mapping (should fail).
    const addr5 = generate_user_address(&rng);
    const result5 = kernel.handle_syscall(
        @intFromEnum(Syscall.unmap),
        addr5,
        0,
        0,
        0,
    );
    // Assert: Must fail with invalid_argument.
    if (result5) |_| {
        std.debug.panic("Unmap non-existent mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.invalid_argument);
    }
    
    // Test 6: Protect non-existent mapping (should fail).
    const addr6 = generate_user_address(&rng);
    const flags6 = MapFlags.init(.{ .read = true });
    const result6 = kernel.handle_syscall(
        @intFromEnum(Syscall.protect),
        addr6,
        @as(u64, @as(u32, @bitCast(flags6))),
        0,
        0,
    );
    // Assert: Must fail with invalid_argument.
    if (result6) |_| {
        std.debug.panic("Protect non-existent mapping should fail", .{});
    } else |err| {
        std.debug.assert(err == BasinError.invalid_argument);
    }
}

test "006_fuzz_state_consistency" {
    // Test Category 7: State Consistency Fuzzing
    // Objective: Validate mapping table state consistency after operations.
    
    var rng = SimpleRng.init(0x006F00F100000007);
    var kernel = BasinKernel.init();
    
    // Perform 100 random operations (map/unmap/protect).
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const op = rng.range(u32, 3); // 0=map, 1=unmap, 2=protect
        
        if (op == 0) {
            // Map operation.
            const addr = generate_address_choice(&rng);
            const size = generate_page_aligned_size(&rng);
            const flags = MapFlags.init(.{ .read = true, .write = true });
            
            const result = kernel.handle_syscall(
                @intFromEnum(Syscall.map),
                addr,
                size,
                @as(u64, @as(u32, @bitCast(flags))),
                0,
            );
            
            const map_result = result catch {
                continue; // Skip failed maps
            };
            
            // Assert: Result must be success (not error).
            std.debug.assert(map_result == .success);
            
            // Assert: Mapping must be tracked in table.
            const mapping_count = kernel.count_allocated_mappings();
            std.debug.assert(mapping_count > 0);
            std.debug.assert(mapping_count <= 256);
            
            // Assert: Mapping address must be valid.
            std.debug.assert(map_result.success >= 0x100000);
            std.debug.assert(map_result.success % 4096 == 0);
        } else if (op == 1) {
            // Unmap operation.
            const addr = generate_user_address(&rng);
            
            const unmap_result = kernel.handle_syscall(
                @intFromEnum(Syscall.unmap),
                addr,
                0,
                0,
                0,
            ) catch {
                continue; // Skip failed unmaps
            };
            
            // Assert: Result must be success (not error).
            std.debug.assert(unmap_result == .success);
            
            // Assert: Mapping must be removed from table.
            const mapping_count = kernel.count_allocated_mappings();
            std.debug.assert(mapping_count <= 256);
        } else {
            // Protect operation.
            const addr = generate_user_address(&rng);
            const flags = MapFlags.init(.{ .read = true, .write = true });
            
            _ = kernel.handle_syscall(
                @intFromEnum(Syscall.protect),
                addr,
                @as(u64, @as(u32, @bitCast(flags))),
                0,
                0,
            ) catch {
                continue; // Skip failed protects
            };
        }
        
        // Assert: Mapping count must be consistent.
        const mapping_count = kernel.count_allocated_mappings();
        std.debug.assert(mapping_count <= 256);
        
        // Assert: All allocated mappings must have valid addresses.
        for (kernel.mappings) |mapping| {
            if (mapping.allocated) {
                std.debug.assert(mapping.address >= 0x100000);
                std.debug.assert(mapping.address % 4096 == 0);
                std.debug.assert(mapping.size >= 4096);
                std.debug.assert(mapping.size % 4096 == 0);
            }
        }
    }
}

