const std = @import("std");
const kernel_vm = @import("kernel_vm");
const VM = kernel_vm.VM;
const loadKernel = kernel_vm.loadKernel;
const SerialOutput = kernel_vm.SerialOutput;

/// Test RISC-V VM functionality.
/// Tiger Style: Comprehensive test coverage, deterministic behavior.
pub fn main() !void {
    std.debug.print("[kernel_vm_test] Testing RISC-V VM...\n", .{});

    // Test 1: VM initialization.
    std.debug.print("[kernel_vm_test] Test 1: VM initialization\n", .{});
    var vm = VM.init(&[_]u8{0x13, 0x00, 0x00, 0x00}, 0x1000); // NOP instruction.
    std.debug.assert(vm.regs.pc == 0x1000);
    std.debug.assert(vm.state == .halted);
    std.debug.print("[kernel_vm_test] ✓ VM initialized correctly\n", .{});

    // Test 2: Register file (x0 hardwired to zero).
    std.debug.print("[kernel_vm_test] Test 2: Register file (x0 hardwired)\n", .{});
    vm.regs.set(0, 0x12345678);
    const x0_value = vm.regs.get(0);
    std.debug.assert(x0_value == 0); // x0 must always be zero.
    std.debug.print("[kernel_vm_test] ✓ x0 hardwired to zero\n", .{});

    // Test 3: Memory read/write.
    std.debug.print("[kernel_vm_test] Test 3: Memory read/write\n", .{});
    try vm.write64(0x2000, 0xDEADBEEFCAFEBABE);
    const read_value = try vm.read64(0x2000);
    std.debug.assert(read_value == 0xDEADBEEFCAFEBABE);
    std.debug.print("[kernel_vm_test] ✓ Memory read/write works\n", .{});

    // Test 4: Instruction fetch.
    std.debug.print("[kernel_vm_test] Test 4: Instruction fetch\n", .{});
    vm.regs.pc = 0x1000;
    const inst = try vm.fetch_instruction();
    std.debug.assert(inst == 0x00000013); // NOP (ADDI x0, x0, 0).
    std.debug.print("[kernel_vm_test] ✓ Instruction fetch works\n", .{});

    // Test 5: Serial output.
    std.debug.print("[kernel_vm_test] Test 5: Serial output\n", .{});
    var serial = SerialOutput{};
    serial.writeString("Hello, RISC-V!\n");
    const output = serial.getOutput();
    std.debug.assert(output.len > 0);
    std.debug.print("[kernel_vm_test] ✓ Serial output works\n", .{});

    // Test 6: ADD instruction.
    std.debug.print("[kernel_vm_test] Test 6: ADD instruction\n", .{});
    // ADD x1, x2, x3: x1 = x2 + x3
    // Encoding: funct7(0) | rs2(3) | rs1(2) | 000 | rd(1) | 0110011
    // 0x00000000 | 0x00018000 | 0x00001000 | 0x00000080 | 0x00000033
    // = 0x003100B3
    vm = VM.init(&[_]u8{ 0xB3, 0x00, 0x31, 0x00 }, 0x1000);
    vm.regs.set(2, 10); // x2 = 10
    vm.regs.set(3, 20); // x3 = 20
    vm.start();
    try vm.step();
    const add_result = vm.regs.get(1);
    std.debug.assert(add_result == 30); // x1 = 10 + 20 = 30
    std.debug.print("[kernel_vm_test] ✓ ADD instruction works\n", .{});

    // Test 7: SUB instruction.
    std.debug.print("[kernel_vm_test] Test 7: SUB instruction\n", .{});
    // SUB x1, x2, x3: x1 = x2 - x3
    // Encoding: funct7(0x20) | rs2(3) | rs1(2) | 000 | rd(1) | 0110011
    // 0x40000000 | 0x00018000 | 0x00001000 | 0x00000080 | 0x00000033
    // = 0x403100B3
    vm = VM.init(&[_]u8{ 0xB3, 0x00, 0x31, 0x40 }, 0x1000);
    vm.regs.set(2, 30); // x2 = 30
    vm.regs.set(3, 10); // x3 = 10
    vm.start();
    try vm.step();
    const sub_result = vm.regs.get(1);
    std.debug.assert(sub_result == 20); // x1 = 30 - 10 = 20
    std.debug.print("[kernel_vm_test] ✓ SUB instruction works\n", .{});

    // Test 8: SLT instruction (signed comparison).
    std.debug.print("[kernel_vm_test] Test 8: SLT instruction\n", .{});
    // SLT x1, x2, x3: x1 = (x2 < x3) ? 1 : 0
    // Encoding: funct7(0) | rs2(3) | rs1(2) | 010 | rd(1) | 0110011
    // 0x00000000 | 0x00018000 | 0x00002000 | 0x00000080 | 0x00000033
    // = 0x003120B3
    vm = VM.init(&[_]u8{ 0xB3, 0x20, 0x31, 0x00 }, 0x1000);
    vm.regs.set(2, 10); // x2 = 10
    vm.regs.set(3, 20); // x3 = 20
    vm.start();
    try vm.step();
    const slt_result_lt = vm.regs.get(1);
    std.debug.assert(slt_result_lt == 1); // 10 < 20, so x1 = 1
    std.debug.print("[kernel_vm_test] ✓ SLT instruction works (10 < 20)\n", .{});

    // Test SLT with reversed operands (should return 0).
    vm = VM.init(&[_]u8{ 0xB3, 0x20, 0x31, 0x00 }, 0x1000);
    vm.regs.set(2, 20); // x2 = 20
    vm.regs.set(3, 10); // x3 = 10
    vm.start();
    try vm.step();
    const slt_result_gt = vm.regs.get(1);
    std.debug.assert(slt_result_gt == 0); // 20 < 10 is false, so x1 = 0
    std.debug.print("[kernel_vm_test] ✓ SLT instruction works (20 < 10)\n", .{});

    // Test SLT with negative numbers (signed comparison).
    vm = VM.init(&[_]u8{ 0xB3, 0x20, 0x31, 0x00 }, 0x1000);
    vm.regs.set(2, @as(u64, @bitCast(@as(i64, -10)))); // x2 = -10 (signed)
    vm.regs.set(3, 10); // x3 = 10
    vm.start();
    try vm.step();
    const slt_result_neg = vm.regs.get(1);
    std.debug.assert(slt_result_neg == 1); // -10 < 10, so x1 = 1
    std.debug.print("[kernel_vm_test] ✓ SLT instruction works (signed comparison)\n", .{});

    std.debug.print("[kernel_vm_test] All tests passed!\n", .{});
}

