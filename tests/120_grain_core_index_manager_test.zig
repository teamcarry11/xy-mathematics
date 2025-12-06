const std = @import("std");
const testing = std.testing;
const index_manager = @import("grain_core").index_manager;

test "index manager init" {
    const manager = index_manager.IndexManager.init();
    std.debug.assert(manager.indexes_len == 0);
    std.debug.assert(manager.next_index_id == 1);
}

test "index entry init" {
    const entry = index_manager.IndexEntry.init();
    std.debug.assert(entry.key_len == 0);
    std.debug.assert(entry.value_len == 0);
    std.debug.assert(entry.record_id == 0);
}

test "index init" {
    const index = index_manager.Index.init(1, 1, index_manager.IndexType.btree);
    std.debug.assert(index.index_id == 1);
    std.debug.assert(index.table_id == 1);
    std.debug.assert(index.index_type == index_manager.IndexType.btree);
    std.debug.assert(index.entries_len == 0);
}

test "index set name" {
    var index = index_manager.Index.init(1, 1, index_manager.IndexType.btree);
    const name = "test_index";
    const set = index.set_name(name);
    std.debug.assert(set);
    std.debug.assert(index.name_len == name.len);
}

test "index add entry" {
    var index = index_manager.Index.init(1, 1, index_manager.IndexType.btree);
    const key = "test_key";
    const value = "test_value";
    const added = index.add_entry(key, value, 100, 1000);
    std.debug.assert(added);
    std.debug.assert(index.entries_len == 1);
    std.debug.assert(index.entries[0].record_id == 100);
}

test "index find entry" {
    var index = index_manager.Index.init(1, 1, index_manager.IndexType.btree);
    const key = "test_key";
    const value = "test_value";
    _ = index.add_entry(key, value, 100, 1000);
    const found = index.find_entry(key);
    std.debug.assert(found != null);
    std.debug.assert(found.?.record_id == 100);
}

test "index manager create index" {
    var manager = index_manager.IndexManager.init();
    const index = manager.create_index(
        1,
        index_manager.IndexType.btree,
        "test_index",
        1000,
    );
    std.debug.assert(index != null);
    std.debug.assert(manager.indexes_len == 1);
    std.debug.assert(index.?.index_id == 1);
}

test "index manager find index" {
    var manager = index_manager.IndexManager.init();
    _ = manager.create_index(
        1,
        index_manager.IndexType.btree,
        "test_index",
        1000,
    );
    const found = manager.find_index(1, "test_index");
    std.debug.assert(found != null);
    std.debug.assert(found.?.index_id == 1);
}

test "index manager delete index" {
    var manager = index_manager.IndexManager.init();
    _ = manager.create_index(
        1,
        index_manager.IndexType.btree,
        "test_index",
        1000,
    );
    const deleted = manager.delete_index(1, "test_index");
    std.debug.assert(deleted);
    const found = manager.find_index(1, "test_index");
    std.debug.assert(found == null);
}

