//! Framebuffer Address Translation Tests
//! Why: Verify that all memory access functions correctly translate framebuffer addresses
//! GrainStyle: Comprehensive test coverage, explicit assertions, deterministic behavior

const std = @import("std");
const testing = std.testing;
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
// Framebuffer module - will be added to build.zig
const framebuffer_mod = @import("framebuffer");
const FRAMEBUFFER_BASE = framebuffer_mod.FRAMEBUFFER_BASE;
const FRAMEBUFFER_SIZE = framebuffer_mod.FRAMEBUFFER_SIZE;
const FRAMEBUFFER_WIDTH = framebuffer_mod.FRAMEBUFFER_WIDTH;
const FRAMEBUFFER_HEIGHT = framebuffer_mod.FRAMEBUFFER_HEIGHT;

// Helper: Encode RISC-V SB instruction
// Format: SB rs2, offset(rs1)
// Encoding: imm[11:5] | rs2 | rs1 | 000 | imm[4:0] | 0100011
fn encode_sb(rs1: u5, rs2: u5, imm: i12) u32 {
    const imm_11_5: u7 = @truncate(@as(u12, @bitCast(imm)) >> 5);
    const imm_4_0: u5 = @truncate(@as(u12, @bitCast(imm)));
    return (@as(u32, imm_11_5) << 25) | (@as(u32, rs2) << 20) | (@as(u32, rs1) << 15) | (@as(u32, imm_4_0) << 7) | 0x23;
}

// Helper: Encode RISC-V SH instruction
// Format: SH rs2, offset(rs1)
// Encoding: imm[11:5] | rs2 | rs1 | 001 | imm[4:0] | 0100011
fn encode_sh(rs1: u5, rs2: u5, imm: i12) u32 {
    const imm_11_5: u7 = @truncate(@as(u12, @bitCast(imm)) >> 5);
    const imm_4_0: u5 = @truncate(@as(u12, @bitCast(imm)));
    return (@as(u32, imm_11_5) << 25) | (@as(u32, rs2) << 20) | (@as(u32, rs1) << 15) | (1 << 12) | (@as(u32, imm_4_0) << 7) | 0x23;
}

// Helper: Encode RISC-V SW instruction
// Format: SW rs2, offset(rs1)
// Encoding: imm[11:5] | rs2 | rs1 | 010 | imm[4:0] | 0100011
fn encode_sw(rs1: u5, rs2: u5, imm: i12) u32 {
    const imm_11_5: u7 = @truncate(@as(u12, @bitCast(imm)) >> 5);
    const imm_4_0: u5 = @truncate(@as(u12, @bitCast(imm)));
    return (@as(u32, imm_11_5) << 25) | (@as(u32, rs2) << 20) | (@as(u32, rs1) << 15) | (2 << 12) | (@as(u32, imm_4_0) << 7) | 0x23;
}

// Helper: Encode RISC-V SD instruction
// Format: SD rs2, offset(rs1)
// Encoding: imm[11:5] | rs2 | rs1 | 011 | imm[4:0] | 0100011
fn encode_sd(rs1: u5, rs2: u5, imm: i12) u32 {
    const imm_11_5: u7 = @truncate(@as(u12, @bitCast(imm)) >> 5);
    const imm_4_0: u5 = @truncate(@as(u12, @bitCast(imm)));
    return (@as(u32, imm_11_5) << 25) | (@as(u32, rs2) << 20) | (@as(u32, rs1) << 15) | (3 << 12) | (@as(u32, imm_4_0) << 7) | 0x23;
}

// Helper: Encode RISC-V LB instruction
// Format: LB rd, offset(rs1)
// Encoding: imm[11:0] | rs1 | 000 | rd | 0000011
fn encode_lb(rd: u5, rs1: u5, imm: i12) u32 {
    const imm_11_0: u12 = @bitCast(imm);
    return (@as(u32, imm_11_0) << 20) | (@as(u32, rs1) << 15) | (@as(u32, rd) << 7) | 0x03;
}

// Helper: Encode RISC-V LW instruction
// Format: LW rd, offset(rs1)
// Encoding: imm[11:0] | rs1 | 010 | rd | 0000011
fn encode_lw(rd: u5, rs1: u5, imm: i12) u32 {
    const imm_11_0: u12 = @bitCast(imm);
    return (@as(u32, imm_11_0) << 20) | (@as(u32, rs1) << 15) | (2 << 12) | (@as(u32, rd) << 7) | 0x03;
}

test "Address translation: kernel address (0x80000000) via SW" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Test translation of kernel base address by writing and reading
    vm.regs.set(3, 0x80000000);
    vm.regs.set(5, 0x12345678);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Verify value appears at physical offset 0
    const value = std.mem.readInt(u32, vm.memory[0..4], .little);
    try testing.expectEqual(@as(u32, 0x12345678), value);
    
    // Test translation of kernel address with offset
    vm.regs.set(3, 0x80001000);
    vm.regs.set(5, 0xDEADBEEF);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Verify value appears at physical offset 0x1000
    const value2 = std.mem.readInt(u32, vm.memory[0x1000..][0..4], .little);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), value2);
}

test "Address translation: framebuffer address (0x90000000) via SW" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Test translation of framebuffer base address by writing
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xFF0000FF);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Verify value appears in framebuffer memory (at end of VM memory)
    const fb_memory = vm.get_framebuffer_memory();
    const pixel = std.mem.readInt(u32, fb_memory[0..4], .little);
    try testing.expectEqual(@as(u32, 0xFF0000FF), pixel);
    
    // Test translation of framebuffer address with offset
    vm.regs.set(3, FRAMEBUFFER_BASE + 4);
    vm.regs.set(5, 0x00FF00FF);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Verify value appears at offset 4 in framebuffer
    const pixel2 = std.mem.readInt(u32, fb_memory[4..8], .little);
    try testing.expectEqual(@as(u32, 0x00FF00FF), pixel2);
}

test "Address translation: out of bounds framebuffer" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Address beyond framebuffer size should fail
    vm.regs.set(3, FRAMEBUFFER_BASE + FRAMEBUFFER_SIZE);
    vm.regs.set(5, 0xFF0000FF);
    
    const inst = encode_sw(3, 5, 0);
    const result = vm.execute_sw(inst);
    try testing.expectError(kernel_vm.VMError.invalid_memory_access, result);
}

test "SB to framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base, x5 = 0xFF (red component)
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xFF);
    
    // Encode SB x5, 0(x3) - store byte to framebuffer
    const inst = encode_sb(3, 5, 0);
    try vm.execute_sb(inst);
    
    // Verify byte written to framebuffer memory
    const fb_memory = vm.get_framebuffer_memory();
    try testing.expectEqual(@as(u8, 0xFF), fb_memory[0]);
}

test "SH to framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base, x5 = 0xFF00 (halfword)
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xFF00);
    
    // Encode SH x5, 0(x3) - store halfword to framebuffer
    const inst = encode_sh(3, 5, 0);
    try vm.execute_sh(inst);
    
    // Verify halfword written to framebuffer memory
    const fb_memory = vm.get_framebuffer_memory();
    const halfword = std.mem.readInt(u16, fb_memory[0..2], .little);
    try testing.expectEqual(@as(u16, 0xFF00), halfword);
}

test "SW to framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base, x5 = 0xFF0000FF (red pixel RGBA)
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xFF0000FF);
    
    // Encode SW x5, 0(x3) - store word to framebuffer
    const inst = encode_sw(3, 5, 0);
    try vm.execute_sw(inst);
    
    // Verify word written to framebuffer memory
    const fb_memory = vm.get_framebuffer_memory();
    const pixel = std.mem.readInt(u32, fb_memory[0..4], .little);
    try testing.expectEqual(@as(u32, 0xFF0000FF), pixel);
}

test "SD to framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base, x5 = 0xFFFFFFFFFFFFFFFF
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xFFFFFFFFFFFFFFFF);
    
    // Encode SD x5, 0(x3) - store doubleword to framebuffer
    const inst = encode_sd(3, 5, 0);
    try vm.execute_sd(inst);
    
    // Verify doubleword written to framebuffer memory
    const fb_memory = vm.get_framebuffer_memory();
    const doubleword = std.mem.readInt(u64, fb_memory[0..8], .little);
    try testing.expectEqual(@as(u64, 0xFFFFFFFFFFFFFFFF), doubleword);
}

test "LB from framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Write test byte to framebuffer memory directly
    const fb_memory = vm.get_framebuffer_memory();
    fb_memory[0] = 0xAB;
    
    // Set up: x3 = framebuffer base, x4 = destination register
    vm.regs.set(3, FRAMEBUFFER_BASE);
    
    // Encode LB x4, 0(x3) - load byte from framebuffer
    const inst = encode_lb(4, 3, 0);
    try vm.execute_lb(inst);
    
    // Verify byte loaded (sign-extended)
    const value = vm.regs.get(4);
    try testing.expectEqual(@as(u64, 0xFFFFFFFFFFFFFFAB), value); // Sign-extended
}

test "LW from framebuffer address" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Write test word to framebuffer memory directly
    const fb_memory = vm.get_framebuffer_memory();
    std.mem.writeInt(u32, fb_memory[0..4], 0xDEADBEEF, .little);
    
    // Set up: x3 = framebuffer base, x4 = destination register
    vm.regs.set(3, FRAMEBUFFER_BASE);
    
    // Encode LW x4, 0(x3) - load word from framebuffer
    const inst = encode_lw(4, 3, 0);
    try vm.execute_lw(inst);
    
    // Verify word loaded (sign-extended)
    const value = vm.regs.get(4);
    try testing.expectEqual(@as(u64, 0xFFFFFFFFDEADBEEF), value); // Sign-extended
}

test "Framebuffer write pattern: multiple pixels" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base
    vm.regs.set(3, FRAMEBUFFER_BASE);
    
    // Write multiple pixels using SW instructions
    // Pixel 0: Red (0xFF0000FF)
    vm.regs.set(5, 0xFF0000FF);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Pixel 1: Green (0x00FF00FF) at offset 4
    vm.regs.set(5, 0x00FF00FF);
    try vm.execute_sw(encode_sw(3, 5, 4));
    
    // Pixel 2: Blue (0x0000FFFF) at offset 8
    vm.regs.set(5, 0x0000FFFF);
    try vm.execute_sw(encode_sw(3, 5, 8));
    
    // Verify pixels written correctly
    const fb_memory = vm.get_framebuffer_memory();
    const pixel0 = std.mem.readInt(u32, fb_memory[0..4], .little);
    const pixel1 = std.mem.readInt(u32, fb_memory[4..8], .little);
    const pixel2 = std.mem.readInt(u32, fb_memory[8..12], .little);
    
    try testing.expectEqual(@as(u32, 0xFF0000FF), pixel0);
    try testing.expectEqual(@as(u32, 0x00FF00FF), pixel1);
    try testing.expectEqual(@as(u32, 0x0000FFFF), pixel2);
}

test "Framebuffer bounds checking: out of bounds write" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base + size (out of bounds)
    vm.regs.set(3, FRAMEBUFFER_BASE + FRAMEBUFFER_SIZE);
    vm.regs.set(5, 0xFF0000FF);
    
    // Encode SW x5, 0(x3) - should fail
    const inst = encode_sw(3, 5, 0);
    const result = vm.execute_sw(inst);
    try testing.expectError(kernel_vm.VMError.invalid_memory_access, result);
    try testing.expect(vm.state == .errored);
}

test "Framebuffer alignment checking: unaligned write" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Set up: x3 = framebuffer base + 1 (unaligned for word)
    vm.regs.set(3, FRAMEBUFFER_BASE + 1);
    vm.regs.set(5, 0xFF0000FF);
    
    // Encode SW x5, 0(x3) - should fail (unaligned)
    const inst = encode_sw(3, 5, 0);
    const result = vm.execute_sw(inst);
    try testing.expectError(kernel_vm.VMError.unaligned_memory_access, result);
    try testing.expect(vm.state == .errored);
}

test "Kernel and framebuffer address separation" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Write to kernel address
    vm.regs.set(3, 0x80000000);
    vm.regs.set(5, 0x12345678);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Write to framebuffer address
    vm.regs.set(3, FRAMEBUFFER_BASE);
    vm.regs.set(5, 0xDEADBEEF);
    try vm.execute_sw(encode_sw(3, 5, 0));
    
    // Verify they don't interfere
    const kernel_word = std.mem.readInt(u32, vm.memory[0..4], .little);
    const fb_memory = vm.get_framebuffer_memory();
    const fb_word = std.mem.readInt(u32, fb_memory[0..4], .little);
    
    try testing.expectEqual(@as(u32, 0x12345678), kernel_word);
    try testing.expectEqual(@as(u32, 0xDEADBEEF), fb_word);
}

test "Framebuffer initialization: host-side init" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Initialize framebuffer from host-side
    vm.init_framebuffer();
    
    // Verify framebuffer memory contains test pattern
    const fb_memory = vm.get_framebuffer_memory();
    
    // Check background color (dark background)
    // First pixel should be dark background (0x1E1E2EFF)
    const first_pixel = std.mem.readInt(u32, fb_memory[0..4], .little);
    try testing.expectEqual(@as(u32, 0x1E1E2EFF), first_pixel);
    
    // Check red rectangle (top-left corner at spacing, spacing)
    const spacing: u32 = 20;
    const rect_size: u32 = 100;
    const red_offset: u32 = (spacing * FRAMEBUFFER_WIDTH + spacing) * 4;
    const red_pixel = std.mem.readInt(u32, fb_memory[red_offset..][0..4], .little);
    // Red pixel should be 0xFF0000FF (RGBA format: R=0xFF, G=0x00, B=0x00, A=0xFF)
    try testing.expectEqual(@as(u32, 0xFF0000FF), red_pixel);
    
    // Check green rectangle (top-right corner)
    const green_offset: u32 = (spacing * FRAMEBUFFER_WIDTH + (FRAMEBUFFER_WIDTH - rect_size - spacing)) * 4;
    const green_pixel = std.mem.readInt(u32, fb_memory[green_offset..][0..4], .little);
    try testing.expectEqual(@as(u32, 0x00FF00FF), green_pixel);
    
    // Check blue rectangle (bottom-left corner)
    const blue_y: u32 = FRAMEBUFFER_HEIGHT - rect_size - spacing;
    const blue_offset: u32 = (blue_y * FRAMEBUFFER_WIDTH + spacing) * 4;
    const blue_pixel = std.mem.readInt(u32, fb_memory[blue_offset..][0..4], .little);
    try testing.expectEqual(@as(u32, 0x0000FFFF), blue_pixel);
    
    // Check white rectangle (bottom-right corner)
    const white_offset: u32 = (blue_y * FRAMEBUFFER_WIDTH + (FRAMEBUFFER_WIDTH - rect_size - spacing)) * 4;
    const white_pixel = std.mem.readInt(u32, fb_memory[white_offset..][0..4], .little);
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), white_pixel);
}

test "Framebuffer initialization: memory layout verification" {
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    // Initialize framebuffer
    vm.init_framebuffer();
    
    // Verify framebuffer is at correct offset in VM memory
    const fb_memory = vm.get_framebuffer_memory();
    const expected_offset = vm.memory_size - FRAMEBUFFER_SIZE;
    
    // Check that framebuffer memory slice points to correct location
    const fb_ptr = @intFromPtr(fb_memory.ptr);
    const memory_ptr = @intFromPtr(&vm.memory[0]);
    const actual_offset = fb_ptr - memory_ptr;
    
    try testing.expectEqual(expected_offset, actual_offset);
    try testing.expectEqual(FRAMEBUFFER_SIZE, fb_memory.len);
}

test "Integration: framebuffer initialization via finish_init" {
    const kernel_vm_mod = @import("kernel_vm");
    const Integration = kernel_vm_mod.Integration;
    const BasinKernel = @import("basin_kernel").BasinKernel;
    
    // Create VM and kernel instances
    var vm: VM = undefined;
    VM.init(&vm, &[_]u8{}, 0x80000000);
    
    var kernel = BasinKernel.init();
    
    // Create integration instance
    var integration = Integration.init_with_kernel(&vm, &kernel);
    
    // Finish initialization (should initialize framebuffer)
    integration.finish_init();
    
    // Verify framebuffer is initialized with test pattern
    const fb_memory = vm.get_framebuffer_memory();
    
    // Check background color (dark background)
    const first_pixel = std.mem.readInt(u32, fb_memory[0..4], .little);
    try testing.expectEqual(@as(u32, 0x1E1E2EFF), first_pixel);
    
    // Check red rectangle (top-left corner)
    const spacing: u32 = 20;
    const red_offset: u32 = (spacing * FRAMEBUFFER_WIDTH + spacing) * 4;
    const red_pixel = std.mem.readInt(u32, fb_memory[red_offset..][0..4], .little);
    try testing.expectEqual(@as(u32, 0xFF0000FF), red_pixel);
    
    // Verify integration is initialized
    try testing.expect(integration.initialized);
}

