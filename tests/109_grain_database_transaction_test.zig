//! Tests for Grain Database Transaction (ACID).
//!
//! Why: Verify transaction operations (add, commit, abort) for ACID guarantees.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const Transaction = grain_database.Transaction;
const TransactionState = grain_database.TransactionState;
const OperationType = grain_database.Transaction.TransactionOperation.OperationType;

test "transaction initialization" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try testing.expect(tx.transaction_id == 1);
    try testing.expect(tx.state == TransactionState.active);
    try testing.expect(tx.operations_len == 0);
    try testing.expect(tx.is_active());
}

test "transaction add operation" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    try testing.expect(tx.operations_len == 1);
    try testing.expect(tx.is_active());
}

test "transaction multiple operations" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    try tx.add_operation(OperationType.update, 1, "key1", "value2");
    try tx.add_operation(OperationType.delete, 1, "key1", "");
    try testing.expect(tx.operations_len == 3);
}

test "transaction commit" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    tx.commit();
    try testing.expect(tx.state == TransactionState.committed);
    try testing.expect(tx.is_committed());
    try testing.expect(!tx.is_active());
}

test "transaction abort" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    tx.abort();
    try testing.expect(tx.state == TransactionState.aborted);
    try testing.expect(!tx.is_active());
    try testing.expect(!tx.is_committed());
}

test "transaction operations after commit" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    tx.commit();
    // After commit, transaction is no longer active
    try testing.expect(!tx.is_active());
}

test "transaction operations after abort" {
    const allocator = testing.allocator;
    var tx = try Transaction.init(allocator, 1);
    defer tx.deinit();

    try tx.add_operation(OperationType.insert, 1, "key1", "value1");
    tx.abort();
    // After abort, transaction is no longer active
    try testing.expect(!tx.is_active());
}

