//! Tests for Aurora GrainBank module.
//!
//! Why: Verify GrainBank functionality (contracts, payments, actions,
//! deterministic state machine).
//! Architecture: Comprehensive test coverage for micropayments and contracts.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-170706-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const AuroraGrainBank = @import("aurora_grainbank").AuroraGrainBank;
const DagCore = @import("dag_core").DagCore;

test "grainbank constants" {
    // Assert: MAX_ACTIVE_CONTRACTS constant
    std.debug.assert(AuroraGrainBank.MAX_ACTIVE_CONTRACTS == 1_000);
    
    // Assert: MAX_PENDING_PAYMENTS constant
    std.debug.assert(AuroraGrainBank.MAX_PENDING_PAYMENTS == 10_000);
    
    // Assert: MAX_CURRENCIES_PER_USER constant
    std.debug.assert(AuroraGrainBank.MAX_CURRENCIES_PER_USER == 100);
}

test "grainbank contract state enum" {
    // Assert: ContractState enum values
    std.debug.assert(@intFromEnum(AuroraGrainBank.ContractState.pending) == 0);
    std.debug.assert(@intFromEnum(AuroraGrainBank.ContractState.active) == 1);
    std.debug.assert(@intFromEnum(AuroraGrainBank.ContractState.completed) == 2);
    std.debug.assert(@intFromEnum(AuroraGrainBank.ContractState.failed) == 3);
}

test "grainbank payment state enum" {
    // Assert: PaymentState enum values
    std.debug.assert(@intFromEnum(AuroraGrainBank.PaymentState.pending) == 0);
    std.debug.assert(@intFromEnum(AuroraGrainBank.PaymentState.confirmed) == 1);
    std.debug.assert(@intFromEnum(AuroraGrainBank.PaymentState.failed) == 2);
}

test "grainbank policy structure" {
    // Assert: Policy structure
    const policy = AuroraGrainBank.Policy{
        .base_rate_bps = 100,
        .tax_rate_bps = 50,
    };
    
    std.debug.assert(policy.base_rate_bps == 100);
    std.debug.assert(policy.tax_rate_bps == 50);
    std.debug.assert(policy.encoded_len == 8);
}

test "grainbank transfer structure" {
    // Assert: Transfer structure
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x42);
    
    const transfer = AuroraGrainBank.Transfer{
        .amount = 1000,
        .to_npub = to_npub,
    };
    
    std.debug.assert(transfer.amount == 1000);
    std.debug.assert(transfer.to_npub[0] == 0x42);
}

test "grainbank initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    // Assert: GrainBank initialized
    std.debug.assert(grainbank.active_contracts.items.len == 0);
    std.debug.assert(grainbank.pending_payments.items.len == 0);
}

test "grainbank deinitialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    grainbank.deinit();
    
    // Assert: GrainBank deinitialized (no crash)
}

test "grainbank create contract" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Assert: Contract created
    std.debug.assert(contract_id > 0);
    std.debug.assert(grainbank.active_contracts.items.len == 1);
    
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.state == .pending);
    std.debug.assert(contract.?.balance == 0);
}

test "grainbank get contract not found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    const contract = grainbank.get_contract(1);
    
    // Assert: Should return null for non-existent contract
    std.debug.assert(contract == null);
}

test "grainbank execute mint action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Execute mint action
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Assert: Balance increased, contract activated
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.balance == 1000);
    std.debug.assert(contract.?.state == .active);
}

test "grainbank execute burn action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Mint first
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Execute burn action
    try grainbank.execute_action(contract_id, .{ .burn = 500 });
    
    // Assert: Balance decreased
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.balance == 500);
}

test "grainbank execute transfer action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x99);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Mint first
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Execute transfer action
    try grainbank.execute_action(contract_id, .{
        .transfer = .{ .amount = 300, .to_npub = to_npub },
    });
    
    // Assert: Balance decreased, payment created
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.balance == 700);
    std.debug.assert(grainbank.pending_payments.items.len > 0);
}

test "grainbank execute collect tax action" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Mint first
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Execute collect tax action
    try grainbank.execute_action(contract_id, .{ .collect_tax = 100 });
    
    // Assert: Balance decreased
    const contract = grainbank.get_contract(contract_id);
    std.debug.assert(contract != null);
    std.debug.assert(contract.?.balance == 900);
}

test "grainbank create payment" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x99);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Activate contract
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Create payment
    const payment_id = try grainbank.create_payment(
        contract_id,
        500,
        npub,
        to_npub,
    );
    
    // Assert: Payment created and confirmed
    std.debug.assert(payment_id > 0);
    std.debug.assert(grainbank.pending_payments.items.len > 0);
    
    const payment = grainbank.get_payment(payment_id);
    std.debug.assert(payment != null);
    std.debug.assert(payment.?.amount == 500);
    std.debug.assert(payment.?.state == .confirmed);
}

test "grainbank get payment not found" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    const payment = grainbank.get_payment(1);
    
    // Assert: Should return null for non-existent payment
    std.debug.assert(payment == null);
}

test "grainbank get active contracts" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    // Create multiple contracts
    _ = try grainbank.create_contract(
        npub,
        "Currency1",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    _ = try grainbank.create_contract(
        npub,
        "Currency2",
        .{ .base_rate_bps = 200, .tax_rate_bps = 75 },
    );
    
    // Assert: Get all active contracts
    const contracts = grainbank.get_active_contracts();
    std.debug.assert(contracts.len == 2);
}

test "grainbank get pending payments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x99);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Activate contract
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Create payments
    _ = try grainbank.create_payment(contract_id, 100, npub, to_npub);
    _ = try grainbank.create_payment(contract_id, 200, npub, to_npub);
    
    // Assert: Get all pending payments
    const payments = grainbank.get_pending_payments();
    std.debug.assert(payments.len >= 2);
}

test "grainbank process pending payments" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    var dag = try DagCore.init(arena.allocator());
    defer dag.deinit();
    
    var grainbank = try AuroraGrainBank.init(arena.allocator(), &dag);
    defer grainbank.deinit();
    
    var npub: [32]u8 = undefined;
    @memset(&npub, 0x42);
    
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x99);
    
    const contract_id = try grainbank.create_contract(
        npub,
        "TestCurrency",
        .{ .base_rate_bps = 100, .tax_rate_bps = 50 },
    );
    
    // Activate contract
    try grainbank.execute_action(contract_id, .{ .mint = 1000 });
    
    // Create payments
    _ = try grainbank.create_payment(contract_id, 100, npub, to_npub);
    _ = try grainbank.create_payment(contract_id, 200, npub, to_npub);
    
    // Process pending payments
    try grainbank.process_pending_payments();
    
    // Assert: Payments processed (all confirmed)
    const payments = grainbank.get_pending_payments();
    for (payments) |payment| {
        std.debug.assert(payment.state == .confirmed);
    }
}

test "grainbank bounds checking contracts" {
    // Assert: MAX_ACTIVE_CONTRACTS is bounded
    std.debug.assert(AuroraGrainBank.MAX_ACTIVE_CONTRACTS > 0);
    std.debug.assert(AuroraGrainBank.MAX_ACTIVE_CONTRACTS <= 100_000);
}

test "grainbank bounds checking payments" {
    // Assert: MAX_PENDING_PAYMENTS is bounded
    std.debug.assert(AuroraGrainBank.MAX_PENDING_PAYMENTS > 0);
    std.debug.assert(AuroraGrainBank.MAX_PENDING_PAYMENTS <= 1_000_000);
}

test "grainbank contract state coverage" {
    // Assert: All ContractState variants exist
    const states = [_]AuroraGrainBank.ContractState{
        .pending,
        .active,
        .completed,
        .failed,
    };
    
    std.debug.assert(states.len == 4);
}

test "grainbank payment state coverage" {
    // Assert: All PaymentState variants exist
    const states = [_]AuroraGrainBank.PaymentState{
        .pending,
        .confirmed,
        .failed,
    };
    
    std.debug.assert(states.len == 3);
}

test "grainbank action types" {
    // Assert: Action union types exist
    var to_npub: [32]u8 = undefined;
    @memset(&to_npub, 0x42);
    
    const mint_action = AuroraGrainBank.Action{ .mint = 1000 };
    const burn_action = AuroraGrainBank.Action{ .burn = 500 };
    const transfer_action = AuroraGrainBank.Action{
        .transfer = .{ .amount = 300, .to_npub = to_npub },
    };
    const tax_action = AuroraGrainBank.Action{ .collect_tax = 100 };
    
    // Assert: Actions created (check union tags)
    std.debug.assert(@as(std.meta.Tag(AuroraGrainBank.Action), mint_action) == .mint);
    std.debug.assert(@as(std.meta.Tag(AuroraGrainBank.Action), burn_action) == .burn);
    std.debug.assert(@as(std.meta.Tag(AuroraGrainBank.Action), transfer_action) == .transfer);
    std.debug.assert(@as(std.meta.Tag(AuroraGrainBank.Action), tax_action) == .collect_tax);
}
