//! Grain Database Transaction: ACID transaction management.
//!
//! Why: Ensure atomicity, consistency, isolation, durability.
//! Architecture: Bounded transactions, iterative algorithms.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-03-163155-pst: Grain Database Agent

const std = @import("std");

// Bounded: Max active transactions.
pub const MAX_TRANSACTIONS: u32 = 10_000;

// Bounded: Max operations per transaction.
pub const MAX_OPERATIONS_PER_TX: u32 = 1_000;

// Transaction state.
pub const TransactionState = enum {
    active,
    committed,
    aborted,
};

// Transaction operation.
pub const TransactionOperation = struct {
    operation_type: OperationType,
    record_id: u64,
    key: []const u8,
    key_len: u32,
    value: []const u8,
    value_len: u64,
    allocator: std.mem.Allocator,

    const OperationType = enum {
        insert,
        update,
        delete,
    };

    // Initialize transaction operation.
    pub fn init(
        allocator: std.mem.Allocator,
        operation_type: OperationType,
        record_id: u64,
        key: []const u8,
        value: []const u8,
    ) !TransactionOperation {
        std.debug.assert(record_id > 0);
        std.debug.assert(key.len <= 1_024);

        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        return TransactionOperation{
            .operation_type = operation_type,
            .record_id = record_id,
            .key = key_copy,
            .key_len = @as(u32, @intCast(key_copy.len)),
            .value = value_copy,
            .value_len = @as(u64, @intCast(value_copy.len)),
            .allocator = allocator,
        };
    }

    // Deinitialize transaction operation and free memory.
    pub fn deinit(self: *TransactionOperation) void {
        _ = self.allocator;
        if (self.key_len > 0) {
            self.allocator.free(self.key);
        }
        if (self.value_len > 0) {
            self.allocator.free(self.value);
        }
        self.* = undefined;
    }
};

// Transaction: ACID transaction management.
pub const Transaction = struct {
    transaction_id: u64,
    state: TransactionState,
    operations: []TransactionOperation,
    operations_len: u32,
    created_at: u64,
    allocator: std.mem.Allocator,

    // Initialize transaction.
    pub fn init(allocator: std.mem.Allocator, transaction_id: u64) !Transaction {
        std.debug.assert(transaction_id > 0);
        _ = allocator;

        const operations = try allocator.alloc(
            TransactionOperation,
            MAX_OPERATIONS_PER_TX,
        );
        errdefer allocator.free(operations);

        const now = std.time.timestamp();

        return Transaction{
            .transaction_id = transaction_id,
            .state = TransactionState.active,
            .operations = operations,
            .operations_len = 0,
            .created_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    // Deinitialize transaction and free memory.
    pub fn deinit(self: *Transaction) void {
        _ = self.allocator;
        var i: u32 = 0;
        while (i < self.operations_len) : (i += 1) {
            self.operations[i].deinit();
        }
        self.allocator.free(self.operations);
        self.* = undefined;
    }

    // Add operation to transaction.
    pub fn add_operation(
        self: *Transaction,
        operation_type: TransactionOperation.OperationType,
        record_id: u64,
        key: []const u8,
        value: []const u8,
    ) !void {
        std.debug.assert(self.state == TransactionState.active);
        std.debug.assert(self.operations_len < MAX_OPERATIONS_PER_TX);

        if (self.operations_len >= MAX_OPERATIONS_PER_TX) {
            return error.TransactionFull;
        }

        var operation = try TransactionOperation.init(
            self.allocator,
            operation_type,
            record_id,
            key,
            value,
        );
        errdefer operation.deinit();

        self.operations[self.operations_len] = operation;
        self.operations_len += 1;

        std.debug.assert(self.operations_len <= MAX_OPERATIONS_PER_TX);
    }

    // Commit transaction.
    pub fn commit(self: *Transaction) void {
        std.debug.assert(self.state == TransactionState.active);
        self.state = TransactionState.committed;
    }

    // Abort transaction.
    pub fn abort(self: *Transaction) void {
        std.debug.assert(self.state == TransactionState.active);
        self.state = TransactionState.aborted;
    }

    // Check if transaction is active.
    pub fn is_active(self: *Transaction) bool {
        return self.state == TransactionState.active;
    }

    // Check if transaction is committed.
    pub fn is_committed(self: *Transaction) bool {
        return self.state == TransactionState.committed;
    }
};

