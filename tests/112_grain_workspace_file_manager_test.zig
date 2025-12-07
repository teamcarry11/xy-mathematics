//! Tests for Grain File Manager application.
//!
//! Why: Verify file browsing, operations, and preview functionality.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-092542-pst: Active implementation
//! 2025-12-07-025947-pst: Phase 10.4 WebSocket integration tests
//! 2025-12-07-071409-pst: Phase 13 File Storage integration tests
//! 2025-12-07-084440-pst: Phase 14 Backup Manager integration tests

const std = @import("std");
const testing = std.testing;
const FileManagerUI = @import("../src/grain_workspace/file_manager/app.zig").FileManagerUI;
const grain_core = @import("grain_core");

test "file manager ui initialization" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();

    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);

    try testing.expect(ui.search_query_len == 0);
    try testing.expect(ui.selected_entry_id == 0);
    try testing.expect(ui.clipboard_len == 0);
    try testing.expect(ui.websocket_clients_len == 0);
    try testing.expect(ui.database_file_handles_len == 0);
    try testing.expect(ui.backup_operations_len == 0);
}

test "set search query" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    ui.set_search_query("test");

    try testing.expect(ui.search_query_len == 4);
    try testing.expect(std.mem.eql(u8, ui.search_query[0..4], "test"));
}

test "navigate to directory" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const result = ui.navigate_to_directory("/home");

    try testing.expect(result == true);
    try testing.expect(std.mem.eql(u8, ui.get_current_directory(), "/home"));
}

test "get current directory" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const current_dir = ui.get_current_directory();

    try testing.expect(std.mem.eql(u8, current_dir, "/"));
}

test "get file entries" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    _ = fm.add_file_entry("file1.txt", "/file1.txt", .regular, 1024, 0);
    _ = fm.add_file_entry("dir1", "/dir1", .directory, 0, 0);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);

    var entries: [10]*grain_core.file_manager.FileEntry = undefined;
    var entries_len: u32 = 0;
    ui.get_file_entries(&entries, &entries_len);

    try testing.expect(entries_len == 2);
    try testing.expect(entries[0].entry_id > 0);
    try testing.expect(entries[1].entry_id > 0);
}

test "search files" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    _ = fm.add_file_entry("test-file.txt", "/test-file.txt", .regular, 1024, 0);
    _ = fm.add_file_entry("other-file.txt", "/other-file.txt", .regular, 2048, 0);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    ui.set_search_query("test");

    var results: [10]u32 = undefined;
    var results_len: u32 = 0;
    ui.search_files(&results, &results_len);

    try testing.expect(results_len == 1);
    try testing.expect(results[0] > 0);
}

test "copy to clipboard" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const result = ui.copy_to_clipboard(entry_id.?);

    try testing.expect(result == true);
    try testing.expect(ui.clipboard_len == 1);
    try testing.expect(ui.clipboard[0] != null);
    try testing.expect(ui.clipboard[0].?.operation == .copy);
}

test "move to clipboard" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const result = ui.move_to_clipboard(entry_id.?);

    try testing.expect(result == true);
    try testing.expect(ui.clipboard_len == 1);
    try testing.expect(ui.clipboard[0] != null);
    try testing.expect(ui.clipboard[0].?.operation == .move);
}

test "paste from clipboard" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    _ = ui.copy_to_clipboard(entry_id.?);

    const pasted_count = ui.paste_from_clipboard("/dest");

    try testing.expect(pasted_count == 1);
    try testing.expect(ui.clipboard_len == 0);
}

test "delete file" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const result = ui.delete_file(entry_id.?);

    try testing.expect(result == true);
    try testing.expect(fm.find_file_entry(entry_id.?) == null);
}

test "rename file" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("old-name.txt", "/old-name.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    const result = ui.rename_file(entry_id.?, "new-name.txt");

    try testing.expect(result == true);
    const entry = fm.find_file_entry(entry_id.?);
    try testing.expect(entry != null);
    try testing.expect(std.mem.eql(u8, entry.?.name[0..entry.?.name_len], "new-name.txt"));
}

test "get file preview" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);

    var preview: [100]u8 = undefined;
    var preview_len: u32 = 0;
    const result = ui.get_file_preview(entry_id.?, &preview, &preview_len);

    try testing.expect(result == true);
}

test "clear clipboard" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();

    const entry_id = fm.add_file_entry("file.txt", "/file.txt", .regular, 1024, 0);
    try testing.expect(entry_id != null);

    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);
    _ = ui.copy_to_clipboard(entry_id.?);
    try testing.expect(ui.clipboard_len == 1);

    ui.clear_clipboard();
    try testing.expect(ui.clipboard_len == 0);
}

test "websocket client management" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();

    var storage_mgr = grain_core.file_storage.FileStorageManager.init();
    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);

    // Add WebSocket client
    const conn1 = ws_manager.add_connection(1);
    try testing.expect(conn1 != null);
    if (conn1) |conn| {
        conn.state = grain_core.websocket.ConnectionState.open;
        const added = ui.add_websocket_client(conn.connection_id);
        try testing.expect(added == true);
        try testing.expect(ui.websocket_clients_len == 1);
    }

    // Add another client
    const conn2 = ws_manager.add_connection(2);
    try testing.expect(conn2 != null);
    if (conn2) |conn| {
        conn.state = grain_core.websocket.ConnectionState.open;
        const added = ui.add_websocket_client(conn.connection_id);
        try testing.expect(added == true);
        try testing.expect(ui.websocket_clients_len == 2);
    }

    // Remove client
    if (conn1) |conn| {
        const removed = ui.remove_websocket_client(conn.connection_id);
        try testing.expect(removed == true);
        try testing.expect(ui.websocket_clients_len == 1);
    }
}

test "database file management" {
    const allocator = testing.allocator;
    var fm = grain_core.file_manager.FileManager.init();
    var ws_manager = grain_core.websocket.WebSocketManager.init();
    var storage_mgr = grain_core.file_storage.FileStorageManager.init();

    const entry_id = fm.add_file_entry("database.db", "/database.db", .regular, 4096, 0);
    try testing.expect(entry_id != null);

    var backup_mgr = grain_core.backup_manager.BackupManager.init();
    var ui = FileManagerUI.init(allocator, &fm, &ws_manager, &storage_mgr, &backup_mgr);

    // Check if file is a database file
    const is_db = ui.is_database_file(entry_id.?);
    try testing.expect(is_db == true);

    // Open database file
    const handle_id = ui.open_database_file(entry_id.?, .read_write);
    try testing.expect(handle_id != null);
    try testing.expect(ui.database_file_handles_len == 1);

    // Get database file handle
    const db_handle = ui.get_database_file_handle(entry_id.?);
    try testing.expect(db_handle != null);
    try testing.expect(db_handle.?.handle_id == handle_id.?);
    try testing.expect(db_handle.?.entry_id == entry_id.?);

    // Get all database file handles
    var handles: [10]?*const FileManagerUI.DatabaseFileHandle = undefined;
    var handles_len: u32 = 0;
    ui.get_all_database_file_handles(&handles, &handles_len);
    try testing.expect(handles_len == 1);

    // Close database file
    const closed = ui.close_database_file(handle_id.?);
    try testing.expect(closed == true);
    try testing.expect(ui.database_file_handles_len == 0);
}

