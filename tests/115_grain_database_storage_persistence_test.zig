//! Tests for Grain Database Storage Persistence Integration.
//!
//! Why: Verify integration between StorageEngine and PersistenceManager.
//! Architecture: Comprehensive test coverage for storage persistence module.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020414-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const StoragePersistence = grain_database.StoragePersistence;
const PersistenceManager = grain_database.PersistenceManager;
const StorageEngine = grain_database.StorageEngine;

test "storage persistence init" {
    var persistence_manager = PersistenceManager.init("test_integration.db");
    _ = persistence_manager.create_database_file();
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var storage_persistence = StoragePersistence.init(
        &persistence_manager,
        &storage_engine,
        1,
    );
    try testing.expect(storage_persistence.table_id == 1);
}

test "create record with wal" {
    var persistence_manager = PersistenceManager.init("test_create_wal.db");
    _ = persistence_manager.create_database_file();
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var storage_persistence = StoragePersistence.init(
        &persistence_manager,
        &storage_engine,
        1,
    );
    const record_id = try storage_persistence.create_record_with_wal("test_key", "test_value");
    try testing.expect(record_id > 0);
    const record = storage_engine.read_record_by_key("test_key");
    try testing.expect(record != null);
    try testing.expect(std.mem.eql(u8, record.?.value, "test_value"));
}

test "update record with wal" {
    var persistence_manager = PersistenceManager.init("test_update_wal.db");
    _ = persistence_manager.create_database_file();
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var storage_persistence = StoragePersistence.init(
        &persistence_manager,
        &storage_engine,
        1,
    );
    _ = try storage_persistence.create_record_with_wal("test_key", "old_value");
    try storage_persistence.update_record_with_wal("test_key", "new_value");
    const record = storage_engine.read_record_by_key("test_key");
    try testing.expect(record != null);
    try testing.expect(std.mem.eql(u8, record.?.value, "new_value"));
}

test "delete record with wal" {
    var persistence_manager = PersistenceManager.init("test_delete_wal.db");
    _ = persistence_manager.create_database_file();
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var storage_persistence = StoragePersistence.init(
        &persistence_manager,
        &storage_engine,
        1,
    );
    _ = try storage_persistence.create_record_with_wal("test_key", "test_value");
    try storage_persistence.delete_record_with_wal("test_key");
    const record = storage_engine.read_record_by_key("test_key");
    try testing.expect(record == null);
}

test "checkpoint if needed" {
    var persistence_manager = PersistenceManager.init("test_checkpoint.db");
    _ = persistence_manager.create_database_file();
    var storage_engine = try StorageEngine.init(testing.allocator, 1024);
    defer storage_engine.deinit();
    var storage_persistence = StoragePersistence.init(
        &persistence_manager,
        &storage_engine,
        1,
    );
    _ = try storage_persistence.create_record_with_wal("test_key", "test_value");
    const checkpointed = storage_persistence.checkpoint_if_needed();
    try testing.expect(!checkpointed);
}

