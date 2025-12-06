const std = @import("std");
const testing = std.testing;
const wal_manager = @import("grain_core").wal_manager;

test "wal manager init" {
    const manager = wal_manager.WalManager.init();
    std.debug.assert(manager.entries_len == 0);
    std.debug.assert(manager.next_entry_id == 1);
    std.debug.assert(manager.file_size == 0);
}

test "wal entry init" {
    const entry = wal_manager.WalEntry.init();
    std.debug.assert(entry.entry_id == 0);
    std.debug.assert(entry.data_len == 0);
    std.debug.assert(entry.timestamp == 0);
}

test "wal manager add entry" {
    var manager = wal_manager.WalManager.init();
    const data = "test data";
    const entry = manager.add_entry(
        wal_manager.WalEntryType.insert,
        1,
        100,
        data,
        1000,
    );
    std.debug.assert(entry != null);
    std.debug.assert(manager.entries_len == 1);
    std.debug.assert(entry.?.entry_id == 1);
    std.debug.assert(entry.?.table_id == 1);
    std.debug.assert(entry.?.record_id == 100);
}

test "wal entry checksum" {
    var entry = wal_manager.WalEntry.init();
    entry.entry_type = wal_manager.WalEntryType.insert;
    entry.table_id = 1;
    entry.record_id = 100;
    const test_data = "test data";
    var i: u32 = 0;
    while (i < test_data.len) : (i += 1) {
        entry.data[i] = test_data[i];
    }
    entry.data_len = @intCast(test_data.len);
    entry.calculate_checksum();
    const verified = entry.verify_checksum();
    std.debug.assert(verified);
}

test "wal manager needs checkpoint" {
    var manager = wal_manager.WalManager.init();
    const data = "test";
    var i: u32 = 0;
    while (i < wal_manager.WAL_CHECKPOINT_INTERVAL) : (i += 1) {
        _ = manager.add_entry(
            wal_manager.WalEntryType.insert,
            1,
            @as(u64, i),
            data,
            1000 + i,
        );
    }
    const needs_checkpoint = manager.needs_checkpoint();
    std.debug.assert(needs_checkpoint);
}

test "wal manager checkpoint" {
    var manager = wal_manager.WalManager.init();
    const data = "test";
    _ = manager.add_entry(
        wal_manager.WalEntryType.insert,
        1,
        100,
        data,
        1000,
    );
    const checkpointed = manager.checkpoint(2000);
    std.debug.assert(checkpointed);
    std.debug.assert(manager.entries_len == 0);
    std.debug.assert(manager.checkpoint_count == 1);
}

test "wal manager get recovery entries" {
    var manager = wal_manager.WalManager.init();
    const data = "test";
    _ = manager.add_entry(
        wal_manager.WalEntryType.insert,
        1,
        100,
        data,
        1000,
    );
    var recovery_entries: [wal_manager.MAX_WAL_ENTRIES]wal_manager.WalEntry = undefined;
    const count = manager.get_recovery_entries(&recovery_entries);
    std.debug.assert(count == 1);
    std.debug.assert(recovery_entries[0].entry_id == 1);
}

test "wal manager clear all" {
    var manager = wal_manager.WalManager.init();
    const data = "test";
    _ = manager.add_entry(
        wal_manager.WalEntryType.insert,
        1,
        100,
        data,
        1000,
    );
    manager.clear_all();
    std.debug.assert(manager.entries_len == 0);
    std.debug.assert(manager.file_size == 0);
}

