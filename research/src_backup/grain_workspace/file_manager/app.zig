//! Grain File Manager: Graphical file system browser.
//!
//! Why: Provide GUI for file browsing and operations.
//! Architecture: File browsing, operations, preview, search.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-092542-pst: Active implementation
//! 2025-12-07-025947-pst: Phase 10.4 WebSocket integration for real-time file system notifications
//! 2025-12-07-071409-pst: Phase 13 File Storage integration for database file support
//! 2025-12-07-084440-pst: Phase 14 Backup Manager integration for data protection

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max search results (explicit limit)
// 2025-12-04-092542-pst: Active constant
pub const MAX_SEARCH_RESULTS: u32 = 256;

// Bounded: Max preview size (explicit limit, in bytes)
// 2025-12-04-092542-pst: Active constant
pub const MAX_PREVIEW_SIZE: u32 = 8192;

// Bounded: Max clipboard entries (explicit limit)
// 2025-12-04-092542-pst: Active constant
pub const MAX_CLIPBOARD_ENTRIES: u32 = 16;

// Bounded: Max WebSocket clients (explicit limit)
// 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
pub const MAX_WEBSOCKET_CLIENTS: u32 = 32;

// Bounded: Max database file handles (explicit limit)
// 2025-12-07-071409-pst: Phase 13 File Storage integration
pub const MAX_DATABASE_FILE_HANDLES: u32 = 32;

// Bounded: Max backup operations (explicit limit)
// 2025-12-07-084440-pst: Phase 14 Backup Manager integration
pub const MAX_BACKUP_OPERATIONS: u32 = 16;

// File operation type.
// 2025-12-04-092542-pst: Active enum
pub const FileOperation = enum(u8) {
    copy, // Copy file
    move, // Move file
    delete, // Delete file
    rename, // Rename file
};

// Clipboard entry for copy/move operations.
// 2025-12-04-092542-pst: Active struct
pub const ClipboardEntry = struct {
    entry_id: u32,
    operation: FileOperation,
    path: [grain_core.file_manager.MAX_PATH_LEN]u8,
    path_len: u32,
};

// Database file handle tracking.
// 2025-12-07-071409-pst: Phase 13 File Storage integration
pub const DatabaseFileHandle = struct {
    handle_id: u32,
    entry_id: u32,
    filename: [grain_core.file_storage.MAX_FILENAME_LEN]u8,
    filename_len: u32,
    active: bool,
};

// Backup operation tracking.
// 2025-12-07-084440-pst: Phase 14 Backup Manager integration
pub const BackupOperation = struct {
    operation_id: u32,
    entry_id: u32,
    backup_id: u32,
    backup_type: grain_core.backup_manager.BackupType,
    state: grain_core.backup_manager.BackupState,
    active: bool,
};

// File Manager UI application state.
// 2025-12-04-092542-pst: Active struct
// 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
// 2025-12-07-071409-pst: Phase 13 File Storage integration
// 2025-12-07-084440-pst: Phase 14 Backup Manager integration
pub const FileManagerUI = struct {
    file_manager: *grain_core.file_manager.FileManager,
    file_storage_manager: *grain_core.file_storage.FileStorageManager,
    backup_manager: *grain_core.backup_manager.BackupManager,
    search_query: [grain_core.file_manager.MAX_NAME_LEN]u8,
    search_query_len: u32,
    selected_entry_id: u32,
    clipboard: [MAX_CLIPBOARD_ENTRIES]?ClipboardEntry,
    clipboard_len: u32,
    preview_buffer: [MAX_PREVIEW_SIZE]u8,
    preview_size: u32,
    websocket_manager: *grain_core.websocket.WebSocketManager,
    websocket_clients: [MAX_WEBSOCKET_CLIENTS]u32,
    websocket_clients_len: u32,
    database_file_handles: [MAX_DATABASE_FILE_HANDLES]?DatabaseFileHandle,
    database_file_handles_len: u32,
    backup_operations: [MAX_BACKUP_OPERATIONS]?BackupOperation,
    backup_operations_len: u32,
    next_backup_operation_id: u32,
    allocator: std.mem.Allocator,

    /// Initialize file manager UI.
    // 2025-12-04-092542-pst: Active function
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn init(
        allocator: std.mem.Allocator,
        fm: *grain_core.file_manager.FileManager,
        ws_manager: *grain_core.websocket.WebSocketManager,
        storage_mgr: *grain_core.file_storage.FileStorageManager,
        backup_mgr: *grain_core.backup_manager.BackupManager,
    ) FileManagerUI {
        // Precondition: Allocator and managers must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(fm) != 0);
        std.debug.assert(@intFromPtr(ws_manager) != 0);
        std.debug.assert(@intFromPtr(storage_mgr) != 0);
        std.debug.assert(@intFromPtr(backup_mgr) != 0);

        var ui = FileManagerUI{
            .file_manager = fm,
            .file_storage_manager = storage_mgr,
            .backup_manager = backup_mgr,
            .search_query = undefined,
            .search_query_len = 0,
            .selected_entry_id = 0,
            .clipboard = undefined,
            .clipboard_len = 0,
            .preview_buffer = undefined,
            .preview_size = 0,
            .websocket_manager = ws_manager,
            .websocket_clients = undefined,
            .websocket_clients_len = 0,
            .database_file_handles = undefined,
            .database_file_handles_len = 0,
            .backup_operations = undefined,
            .backup_operations_len = 0,
            .next_backup_operation_id = 1,
            .allocator = allocator,
        };

        // Initialize search query
        @memset(&ui.search_query, 0);

        // Initialize clipboard
        var i: u32 = 0;
        while (i < MAX_CLIPBOARD_ENTRIES) : (i += 1) {
            ui.clipboard[i] = null;
        }

        // Initialize preview buffer
        @memset(&ui.preview_buffer, 0);

        // Initialize WebSocket clients array
        i = 0;
        while (i < MAX_WEBSOCKET_CLIENTS) : (i += 1) {
            ui.websocket_clients[i] = 0;
        }

        // Initialize database file handles array
        i = 0;
        while (i < MAX_DATABASE_FILE_HANDLES) : (i += 1) {
            ui.database_file_handles[i] = null;
        }

        // Initialize backup operations array
        i = 0;
        while (i < MAX_BACKUP_OPERATIONS) : (i += 1) {
            ui.backup_operations[i] = null;
        }

        // Postcondition: UI must be valid
        std.debug.assert(ui.search_query_len == 0);
        std.debug.assert(ui.clipboard_len == 0);
        std.debug.assert(ui.websocket_clients_len == 0);
        std.debug.assert(ui.database_file_handles_len == 0);
        std.debug.assert(ui.backup_operations_len == 0);

        return ui;
    }

    /// Set search query.
    // 2025-12-04-092542-pst: Active function
    pub fn set_search_query(
        self: *FileManagerUI,
        query: []const u8,
    ) void {
        // Precondition: Query must be bounded
        std.debug.assert(query.len <= grain_core.file_manager.MAX_NAME_LEN);

        @memset(&self.search_query, 0);
        const query_len = @min(query.len, grain_core.file_manager.MAX_NAME_LEN);
        if (query_len > 0) {
            @memcpy(self.search_query[0..query_len], query[0..query_len]);
        }
        self.search_query_len = @as(u32, @intCast(query_len));

        // Postcondition: Query must be valid
        std.debug.assert(self.search_query_len <= grain_core.file_manager.MAX_NAME_LEN);
    }

    /// Navigate to directory.
    // 2025-12-04-092542-pst: Active function
    pub fn navigate_to_directory(
        self: *FileManagerUI,
        path: []const u8,
    ) bool {
        // Precondition: Path must be valid
        std.debug.assert(path.len > 0);

        const result = self.file_manager.set_current_directory(path);
        if (result) {
            self.selected_entry_id = 0;
            // Broadcast directory change to WebSocket clients
            self.broadcast_directory_change(path);
        }

        // Postcondition: Directory must be set if successful
        std.debug.assert(!result or self.file_manager.current_directory_len > 0);

        return result;
    }

    /// Get current directory.
    // 2025-12-04-092542-pst: Active function
    pub fn get_current_directory(self: *const FileManagerUI) []const u8 {
        // Precondition: File manager must be valid
        std.debug.assert(@intFromPtr(self.file_manager) != 0);

        return self.file_manager.get_current_directory();
    }

    /// Get file entries in current directory.
    // 2025-12-04-092542-pst: Active function
    pub fn get_file_entries(
        self: *const FileManagerUI,
        entries: []*grain_core.file_manager.FileEntry,
        entries_len: *u32,
    ) void {
        // Precondition: Entries buffer must be valid
        std.debug.assert(entries.len > 0);
        std.debug.assert(entries_len != null);

        entries_len.* = 0;

        var i: u32 = 0;
        while (i < self.file_manager.files_len and entries_len.* < entries.len) : (i += 1) {
            const entry = &self.file_manager.files[i];
            if (entry.active) {
                entries[entries_len.*] = entry;
                entries_len.* += 1;
            }
        }
    }

    /// Search files by name.
    // 2025-12-04-092542-pst: Active function
    pub fn search_files(
        self: *const FileManagerUI,
        results: []u32,
        results_len: *u32,
    ) void {
        // Precondition: Results buffer must be valid
        std.debug.assert(results.len > 0);
        std.debug.assert(results_len != null);

        results_len.* = 0;

        if (self.search_query_len == 0) {
            return;
        }

        const query_slice = self.search_query[0..self.search_query_len];
        var i: u32 = 0;
        while (i < self.file_manager.files_len and results_len.* < results.len) : (i += 1) {
            const entry = &self.file_manager.files[i];
            if (!entry.active) {
                continue;
            }

            // Search in name
            const name_slice = entry.name[0..entry.name_len];
            if (std.mem.indexOf(u8, name_slice, query_slice) != null) {
                results[results_len.*] = entry.entry_id;
                results_len.* += 1;
            }
        }
    }

    /// Copy file to clipboard.
    // 2025-12-04-092542-pst: Active function
    pub fn copy_to_clipboard(
        self: *FileManagerUI,
        entry_id: u32,
    ) bool {
        // Precondition: Entry ID and clipboard space must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(self.clipboard_len < MAX_CLIPBOARD_ENTRIES);

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return false;
        }

        const path_slice = entry.?.path[0..entry.?.path_len];
        var clipboard_entry = ClipboardEntry{
            .entry_id = entry_id,
            .operation = .copy,
            .path = undefined,
            .path_len = @as(u32, @intCast(path_slice.len)),
        };

        @memset(&clipboard_entry.path, 0);
        @memcpy(clipboard_entry.path[0..path_slice.len], path_slice);

        self.clipboard[self.clipboard_len] = clipboard_entry;
        self.clipboard_len += 1;

        // Postcondition: Clipboard must have entry
        std.debug.assert(self.clipboard_len > 0);

        return true;
    }

    /// Move file to clipboard.
    // 2025-12-04-092542-pst: Active function
    pub fn move_to_clipboard(
        self: *FileManagerUI,
        entry_id: u32,
    ) bool {
        // Precondition: Entry ID and clipboard space must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(self.clipboard_len < MAX_CLIPBOARD_ENTRIES);

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return false;
        }

        const path_slice = entry.?.path[0..entry.?.path_len];
        var clipboard_entry = ClipboardEntry{
            .entry_id = entry_id,
            .operation = .move,
            .path = undefined,
            .path_len = @as(u32, @intCast(path_slice.len)),
        };

        @memset(&clipboard_entry.path, 0);
        @memcpy(clipboard_entry.path[0..path_slice.len], path_slice);

        self.clipboard[self.clipboard_len] = clipboard_entry;
        self.clipboard_len += 1;

        // Postcondition: Clipboard must have entry
        std.debug.assert(self.clipboard_len > 0);

        return true;
    }

    /// Paste files from clipboard.
    // 2025-12-04-092542-pst: Active function
    pub fn paste_from_clipboard(
        self: *FileManagerUI,
        destination_path: []const u8,
    ) u32 {
        // Precondition: Destination path must be valid
        std.debug.assert(destination_path.len > 0);
        std.debug.assert(destination_path.len <= grain_core.file_manager.MAX_PATH_LEN);

        var pasted_count: u32 = 0;

        var i: u32 = 0;
        while (i < self.clipboard_len) : (i += 1) {
            if (self.clipboard[i]) |clip_entry| {
                const source_path = clip_entry.path[0..clip_entry.path_len];
                if (clip_entry.operation == .copy) {
                    // Copy operation (would implement actual file copy)
                    pasted_count += 1;
                } else if (clip_entry.operation == .move) {
                    // Move operation (would implement actual file move)
                    pasted_count += 1;
                }
            }
        }

        // Clear clipboard after paste
        self.clipboard_len = 0;
        var j: u32 = 0;
        while (j < MAX_CLIPBOARD_ENTRIES) : (j += 1) {
            self.clipboard[j] = null;
        }

        // Postcondition: Clipboard must be cleared
        std.debug.assert(self.clipboard_len == 0);

        return pasted_count;
    }

    /// Delete file.
    // 2025-12-04-092542-pst: Active function
    pub fn delete_file(
        self: *FileManagerUI,
        entry_id: u32,
    ) bool {
        // Precondition: Entry ID must be valid
        std.debug.assert(entry_id > 0);

        const result = self.file_manager.remove_file_entry(entry_id);
        if (result) {
            if (self.selected_entry_id == entry_id) {
                self.selected_entry_id = 0;
            }
            // Broadcast file deletion to WebSocket clients
            self.broadcast_file_event("delete", entry_id);
        }

        // Postcondition: Entry must be removed if successful
        std.debug.assert(!result or self.file_manager.find_file_entry(entry_id) == null);

        return result;
    }

    /// Rename file.
    // 2025-12-04-092542-pst: Active function
    pub fn rename_file(
        self: *FileManagerUI,
        entry_id: u32,
        new_name: []const u8,
    ) bool {
        // Precondition: Entry ID and name must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(new_name.len > 0);
        std.debug.assert(new_name.len <= grain_core.file_manager.MAX_NAME_LEN);

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return false;
        }

        // Update name
        @memset(&entry.?.name, 0);
        const name_len = @min(new_name.len, grain_core.file_manager.MAX_NAME_LEN);
        @memcpy(entry.?.name[0..name_len], new_name[0..name_len]);
        entry.?.name_len = @as(u32, @intCast(name_len));

        // Postcondition: Name must be updated
        std.debug.assert(entry.?.name_len == name_len);

        // Broadcast file rename to WebSocket clients
        self.broadcast_file_event("rename", entry_id);

        return true;
    }

    /// Get file preview (text files only).
    // 2025-12-04-092542-pst: Active function
    pub fn get_file_preview(
        self: *FileManagerUI,
        entry_id: u32,
        preview: []u8,
        preview_len: *u32,
    ) bool {
        // Precondition: Preview buffer must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(preview.len > 0);
        std.debug.assert(preview_len != null);

        preview_len.* = 0;

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return false;
        }

        // Only preview regular files
        if (entry.?.file_type != .regular) {
            return false;
        }

        // Limit preview size
        const max_preview = @min(preview.len, MAX_PREVIEW_SIZE);
        const file_size = @min(entry.?.size, @as(u64, max_preview));

        // In full implementation, would read file content here
        // For now, return empty preview
        preview_len.* = 0;

        return true;
    }

    /// Clear clipboard.
    // 2025-12-04-092542-pst: Active function
    pub fn clear_clipboard(self: *FileManagerUI) void {
        // Precondition: Clipboard must be valid
        std.debug.assert(@intFromPtr(self) != 0);

        self.clipboard_len = 0;
        var i: u32 = 0;
        while (i < MAX_CLIPBOARD_ENTRIES) : (i += 1) {
            self.clipboard[i] = null;
        }

        // Postcondition: Clipboard must be cleared
        std.debug.assert(self.clipboard_len == 0);
    }

    /// Add WebSocket client for real-time file system notifications.
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    pub fn add_websocket_client(
        self: *FileManagerUI,
        connection_id: u32,
    ) bool {
        // Precondition: Connection ID must be valid
        std.debug.assert(connection_id > 0);
        std.debug.assert(self.websocket_clients_len < MAX_WEBSOCKET_CLIENTS);

        if (self.websocket_clients_len >= MAX_WEBSOCKET_CLIENTS) {
            return false;
        }

        self.websocket_clients[self.websocket_clients_len] = connection_id;
        self.websocket_clients_len += 1;

        // Postcondition: Client count increased
        std.debug.assert(self.websocket_clients_len > 0);
        std.debug.assert(self.websocket_clients_len <= MAX_WEBSOCKET_CLIENTS);

        return true;
    }

    /// Remove WebSocket client.
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    pub fn remove_websocket_client(
        self: *FileManagerUI,
        connection_id: u32,
    ) bool {
        // Precondition: Connection ID must be valid
        std.debug.assert(connection_id > 0);

        var i: u32 = 0;
        while (i < self.websocket_clients_len) : (i += 1) {
            if (self.websocket_clients[i] == connection_id) {
                var j: u32 = i;
                while (j < self.websocket_clients_len - 1) : (j += 1) {
                    self.websocket_clients[j] = self.websocket_clients[j + 1];
                }
                self.websocket_clients_len -= 1;
                return true;
            }
        }

        return false;
    }

    /// Broadcast directory change to WebSocket clients (internal).
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    fn broadcast_directory_change(
        self: *FileManagerUI,
        path: []const u8,
    ) void {
        // Precondition: Path must be valid
        std.debug.assert(path.len > 0);

        if (self.websocket_clients_len == 0) {
            return;
        }

        // Serialize directory change to JSON-like format (simplified)
        var json_buf: [512]u8 = undefined;
        const json_len = self.serialize_directory_change_json(path, &json_buf);
        if (json_len == 0) {
            return;
        }

        // Create WebSocket frame
        var frame = grain_core.websocket.WebSocketFrame.init();
        frame.flags.opcode = grain_core.websocket.FrameOpcode.text;
        frame.flags.fin = true;
        frame.flags.masked = false;
        frame.payload_len = @intCast(json_len);

        var i: u32 = 0;
        while (i < json_len and i < grain_core.websocket.MAX_FRAME_SIZE) : (i += 1) {
            frame.payload[i] = json_buf[i];
        }

        // Broadcast to all clients
        i = 0;
        while (i < self.websocket_clients_len) : (i += 1) {
            const conn_id = self.websocket_clients[i];
            const conn = self.websocket_manager.find_connection(conn_id);
            if (conn != null and conn.?.state == grain_core.websocket.ConnectionState.open) {
                // Frame would be sent here (actual send via socket not implemented)
                _ = frame;
            }
        }
    }

    /// Broadcast file event to WebSocket clients (internal).
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    fn broadcast_file_event(
        self: *FileManagerUI,
        event_type: []const u8,
        entry_id: u32,
    ) void {
        // Precondition: Event type and entry ID must be valid
        std.debug.assert(event_type.len > 0);
        std.debug.assert(entry_id > 0);

        if (self.websocket_clients_len == 0) {
            return;
        }

        // Serialize file event to JSON-like format (simplified)
        var json_buf: [256]u8 = undefined;
        const json_len = self.serialize_file_event_json(event_type, entry_id, &json_buf);
        if (json_len == 0) {
            return;
        }

        // Create WebSocket frame
        var frame = grain_core.websocket.WebSocketFrame.init();
        frame.flags.opcode = grain_core.websocket.FrameOpcode.text;
        frame.flags.fin = true;
        frame.flags.masked = false;
        frame.payload_len = @intCast(json_len);

        var i: u32 = 0;
        while (i < json_len and i < grain_core.websocket.MAX_FRAME_SIZE) : (i += 1) {
            frame.payload[i] = json_buf[i];
        }

        // Broadcast to all clients
        i = 0;
        while (i < self.websocket_clients_len) : (i += 1) {
            const conn_id = self.websocket_clients[i];
            const conn = self.websocket_manager.find_connection(conn_id);
            if (conn != null and conn.?.state == grain_core.websocket.ConnectionState.open) {
                // Frame would be sent here (actual send via socket not implemented)
                _ = frame;
            }
        }
    }

    /// Serialize directory change to JSON format (simplified).
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    fn serialize_directory_change_json(
        self: *const FileManagerUI,
        path: []const u8,
        buf: []u8,
    ) u32 {
        // Precondition: Buffer must be valid
        std.debug.assert(buf.len >= 512);
        std.debug.assert(path.len > 0);

        _ = self; // Suppress unused warning

        // Simplified JSON serialization (escape path for JSON)
        const path_len = @min(path.len, 200);
        var path_buf: [200]u8 = undefined;
        var path_idx: u32 = 0;
        var i: u32 = 0;
        while (i < path_len and path_idx < 200) : (i += 1) {
            const c = path[i];
            if (c == '"' or c == '\\') {
                if (path_idx + 1 < 200) {
                    path_buf[path_idx] = '\\';
                    path_idx += 1;
                    path_buf[path_idx] = c;
                    path_idx += 1;
                }
            } else {
                path_buf[path_idx] = c;
                path_idx += 1;
            }
        }
        const json_fmt = 
            \\{"event":"directory_change","path":"%.*s"}
        ;
        const written = std.fmt.bufPrint(buf, json_fmt, .{
            path_idx,
            &path_buf,
        }) catch return 0;

        return @intCast(written.len);
    }

    /// Serialize file event to JSON format (simplified).
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    fn serialize_file_event_json(
        self: *const FileManagerUI,
        event_type: []const u8,
        entry_id: u32,
        buf: []u8,
    ) u32 {
        // Precondition: Buffer must be valid
        std.debug.assert(buf.len >= 256);
        std.debug.assert(event_type.len > 0);
        std.debug.assert(entry_id > 0);

        _ = self; // Suppress unused warning

        // Simplified JSON serialization
        const event_len = @min(event_type.len, 32);
        const json_fmt = 
            \\{"event":"%.*s","entry_id":%d}
        ;
        const written = std.fmt.bufPrint(buf, json_fmt, .{
            event_len,
            event_type.ptr,
            entry_id,
        }) catch return 0;

        return @intCast(written.len);
    }

    /// Open database file for storage operations.
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    pub fn open_database_file(
        self: *FileManagerUI,
        entry_id: u32,
        mode: grain_core.file_storage.FileMode,
    ) ?u32 {
        // Precondition: Entry ID must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(self.database_file_handles_len < MAX_DATABASE_FILE_HANDLES);

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return null;
        }

        if (self.database_file_handles_len >= MAX_DATABASE_FILE_HANDLES) {
            return null;
        }

        const path_slice = entry.?.path[0..entry.?.path_len];
        const current_time = @as(u64, @intCast(std.time.timestamp()));
        const handle = self.file_storage_manager.open_file(path_slice, mode, current_time);
        if (handle == null) {
            return null;
        }

        var db_handle = DatabaseFileHandle{
            .handle_id = handle.?.handle_id,
            .entry_id = entry_id,
            .filename = undefined,
            .filename_len = handle.?.filename_len,
            .active = true,
        };

        @memset(&db_handle.filename, 0);
        const filename_len = @min(handle.?.filename_len, grain_core.file_storage.MAX_FILENAME_LEN);
        @memcpy(db_handle.filename[0..filename_len], handle.?.filename[0..filename_len]);

        var i: u32 = 0;
        while (i < MAX_DATABASE_FILE_HANDLES) : (i += 1) {
            if (self.database_file_handles[i] == null) {
                self.database_file_handles[i] = db_handle;
                self.database_file_handles_len += 1;
                break;
            }
        }

        // Postcondition: Database file handle must be added
        std.debug.assert(self.database_file_handles_len > 0);

        return handle.?.handle_id;
    }

    /// Close database file.
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    pub fn close_database_file(
        self: *FileManagerUI,
        handle_id: u32,
    ) bool {
        // Precondition: Handle ID must be valid
        std.debug.assert(handle_id > 0);

        const closed = self.file_storage_manager.close_file(handle_id);
        if (!closed) {
            return false;
        }

        var i: u32 = 0;
        while (i < self.database_file_handles_len) : (i += 1) {
            if (self.database_file_handles[i]) |*db_handle| {
                if (db_handle.handle_id == handle_id) {
                    db_handle.active = false;
                    self.database_file_handles_len -= 1;
                    return true;
                }
            }
        }

        return false;
    }

    /// Get database file handle by entry ID.
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    pub fn get_database_file_handle(
        self: *const FileManagerUI,
        entry_id: u32,
    ) ?*const DatabaseFileHandle {
        // Precondition: Entry ID must be valid
        std.debug.assert(entry_id > 0);

        var i: u32 = 0;
        while (i < self.database_file_handles_len) : (i += 1) {
            if (self.database_file_handles[i]) |*db_handle| {
                if (db_handle.entry_id == entry_id and db_handle.active) {
                    return db_handle;
                }
            }
        }

        return null;
    }

    /// Get all open database file handles.
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    pub fn get_all_database_file_handles(
        self: *const FileManagerUI,
        handles: []?*const DatabaseFileHandle,
        handles_len: *u32,
    ) void {
        // Precondition: Handles buffer must be valid
        std.debug.assert(handles.len > 0);
        std.debug.assert(handles_len != null);

        handles_len.* = 0;

        var i: u32 = 0;
        while (i < self.database_file_handles_len and handles_len.* < handles.len) : (i += 1) {
            if (self.database_file_handles[i]) |*db_handle| {
                if (db_handle.active) {
                    handles[handles_len.*] = db_handle;
                    handles_len.* += 1;
                }
            }
        }
    }

    /// Check if file is a database file (by extension).
    // 2025-12-07-071409-pst: Phase 13 File Storage integration
    pub fn is_database_file(
        self: *const FileManagerUI,
        entry_id: u32,
    ) bool {
        // Precondition: Entry ID must be valid
        std.debug.assert(entry_id > 0);

        _ = self; // Suppress unused warning

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return false;
        }

        const name_slice = entry.?.name[0..entry.?.name_len];
        if (std.mem.endsWith(u8, name_slice, ".db") or std.mem.endsWith(u8, name_slice, ".sqlite")) {
            return true;
        }

        return false;
    }

    /// Create backup for database file.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn create_file_backup(
        self: *FileManagerUI,
        entry_id: u32,
        backup_type: grain_core.backup_manager.BackupType,
    ) ?u32 {
        // Precondition: Entry ID must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(self.backup_operations_len < MAX_BACKUP_OPERATIONS);

        if (self.backup_operations_len >= MAX_BACKUP_OPERATIONS) {
            return null;
        }

        const entry = self.file_manager.find_file_entry(entry_id);
        if (entry == null) {
            return null;
        }

        if (!self.is_database_file(entry_id)) {
            return null;
        }

        const path_slice = entry.?.path[0..entry.?.path_len];
        const timestamp = @as(u64, @intCast(std.time.timestamp()));
        const backup = self.backup_manager.create_backup(backup_type, path_slice, timestamp);
        if (backup == null) {
            return null;
        }

        const operation_id = self.next_backup_operation_id;
        self.next_backup_operation_id += 1;

        var backup_op = BackupOperation{
            .operation_id = operation_id,
            .entry_id = entry_id,
            .backup_id = backup.?.backup_id,
            .backup_type = backup_type,
            .state = backup.?.state,
            .active = true,
        };

        var i: u32 = 0;
        while (i < MAX_BACKUP_OPERATIONS) : (i += 1) {
            if (self.backup_operations[i] == null) {
                self.backup_operations[i] = backup_op;
                self.backup_operations_len += 1;
                break;
            }
        }

        // Postcondition: Backup operation must be added
        std.debug.assert(self.backup_operations_len > 0);

        return operation_id;
    }

    /// Get backup operation by operation ID.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn get_backup_operation(
        self: *const FileManagerUI,
        operation_id: u32,
    ) ?*const BackupOperation {
        // Precondition: Operation ID must be valid
        std.debug.assert(operation_id > 0);

        var i: u32 = 0;
        while (i < self.backup_operations_len) : (i += 1) {
            if (self.backup_operations[i]) |*op| {
                if (op.operation_id == operation_id and op.active) {
                    return op;
                }
            }
        }

        return null;
    }

    /// Get all backup operations for an entry.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn get_entry_backup_operations(
        self: *const FileManagerUI,
        entry_id: u32,
        operations: []?*const BackupOperation,
        operations_len: *u32,
    ) void {
        // Precondition: Operations buffer must be valid
        std.debug.assert(entry_id > 0);
        std.debug.assert(operations.len > 0);
        std.debug.assert(operations_len != null);

        operations_len.* = 0;

        var i: u32 = 0;
        while (i < self.backup_operations_len and operations_len.* < operations.len) : (i += 1) {
            if (self.backup_operations[i]) |*op| {
                if (op.entry_id == entry_id and op.active) {
                    operations[operations_len.*] = op;
                    operations_len.* += 1;
                }
            }
        }
    }

    /// Restore file from backup.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn restore_file_from_backup(
        self: *FileManagerUI,
        backup_id: u32,
    ) bool {
        // Precondition: Backup ID must be valid
        std.debug.assert(backup_id > 0);

        const backup = self.backup_manager.find_backup(backup_id);
        if (backup == null) {
            return false;
        }

        if (backup.?.state != grain_core.backup_manager.BackupState.completed) {
            return false;
        }

        // Restore would be implemented here (actual restore via file storage)
        // For now, just verify backup exists and is completed
        return true;
    }

    /// Get backup metadata by backup ID.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn get_backup_metadata(
        self: *const FileManagerUI,
        backup_id: u32,
    ) ?*const grain_core.backup_manager.BackupMetadata {
        // Precondition: Backup ID must be valid
        std.debug.assert(backup_id > 0);

        _ = self; // Suppress unused warning

        return self.backup_manager.find_backup(backup_id);
    }

    /// Get all backups for database files.
    // 2025-12-07-084440-pst: Phase 14 Backup Manager integration
    pub fn get_all_backups(
        self: *const FileManagerUI,
        backups: []?*const grain_core.backup_manager.BackupMetadata,
        backups_len: *u32,
    ) void {
        // Precondition: Backups buffer must be valid
        std.debug.assert(backups.len > 0);
        std.debug.assert(backups_len != null);

        backups_len.* = 0;

        var i: u32 = 0;
        while (i < self.backup_manager.backups_len and backups_len.* < backups.len) : (i += 1) {
            const backup = &self.backup_manager.backups[i];
            if (backup.backup_id > 0) {
                backups[backups_len.*] = backup;
                backups_len.* += 1;
            }
        }
    }
};

