const std = @import("std");
const testing = std.testing;
const file_storage = @import("grain_core").file_storage;

test "file storage manager init" {
    const manager = file_storage.FileStorageManager.init();
    std.debug.assert(manager.handles_len == 0);
    std.debug.assert(manager.next_handle_id == 1);
}

test "database file header init" {
    const header = file_storage.DatabaseFileHeader.init();
    std.debug.assert(header.version == 1);
    std.debug.assert(header.page_size == file_storage.PAGE_SIZE);
    std.debug.assert(header.total_pages == 0);
}

test "database file header validate" {
    var header = file_storage.DatabaseFileHeader.init();
    const valid = header.validate();
    std.debug.assert(valid);
}

test "file page init" {
    const page = file_storage.FilePage.init(0);
    std.debug.assert(page.page_id == 0);
    std.debug.assert(page.is_dirty == false);
}

test "file page checksum" {
    var page = file_storage.FilePage.init(0);
    const test_data = "Hello, World!";
    var i: u32 = 0;
    while (i < test_data.len and i < file_storage.PAGE_SIZE) : (i += 1) {
        page.data[i] = test_data[i];
    }
    page.calculate_checksum();
    const verified = page.verify_checksum();
    std.debug.assert(verified);
}

test "file storage manager open file" {
    var manager = file_storage.FileStorageManager.init();
    const filename = "test.db";
    const handle = manager.open_file(
        filename,
        file_storage.FileMode.read_write,
        1000,
    );
    std.debug.assert(handle != null);
    std.debug.assert(manager.handles_len == 1);
    std.debug.assert(handle.?.handle_id == 1);
    std.debug.assert(handle.?.state == file_storage.FileHandleState.open);
}

test "file storage manager close file" {
    var manager = file_storage.FileStorageManager.init();
    const filename = "test.db";
    const handle = manager.open_file(
        filename,
        file_storage.FileMode.read_write,
        1000,
    );
    std.debug.assert(handle != null);
    const handle_id = handle.?.handle_id;
    const closed = manager.close_file(handle_id);
    std.debug.assert(closed);
    std.debug.assert(manager.handles_len == 0);
}

test "file storage manager lock file" {
    var manager = file_storage.FileStorageManager.init();
    const filename = "test.db";
    const handle = manager.open_file(
        filename,
        file_storage.FileMode.read_write,
        1000,
    );
    std.debug.assert(handle != null);
    const handle_id = handle.?.handle_id;
    const locked = manager.lock_file(handle_id);
    std.debug.assert(locked);
    std.debug.assert(handle.?.state == file_storage.FileHandleState.locked);
}

test "file storage manager unlock file" {
    var manager = file_storage.FileStorageManager.init();
    const filename = "test.db";
    const handle = manager.open_file(
        filename,
        file_storage.FileMode.read_write,
        1000,
    );
    std.debug.assert(handle != null);
    const handle_id = handle.?.handle_id;
    _ = manager.lock_file(handle_id);
    const unlocked = manager.unlock_file(handle_id);
    std.debug.assert(unlocked);
    std.debug.assert(handle.?.state == file_storage.FileHandleState.open);
}

