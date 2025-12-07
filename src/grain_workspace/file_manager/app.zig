//! Grain File Manager: Graphical file system browser.
//!
//! Why: Provide GUI for file browsing and operations.
//! Architecture: File browsing, operations, preview, search.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-092542-pst: Active implementation
//! 2025-12-07-025947-pst: Phase 10.4 WebSocket integration for real-time file system notifications

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

// File Manager UI application state.
// 2025-12-04-092542-pst: Active struct
// 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
pub const FileManagerUI = struct {
    file_manager: *grain_core.file_manager.FileManager,
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
    allocator: std.mem.Allocator,

    /// Initialize file manager UI.
    // 2025-12-04-092542-pst: Active function
    // 2025-12-07-025947-pst: Phase 10.4 WebSocket integration
    pub fn init(
        allocator: std.mem.Allocator,
        fm: *grain_core.file_manager.FileManager,
        ws_manager: *grain_core.websocket.WebSocketManager,
    ) FileManagerUI {
        // Precondition: Allocator and managers must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(fm) != 0);
        std.debug.assert(@intFromPtr(ws_manager) != 0);

        var ui = FileManagerUI{
            .file_manager = fm,
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

        // Postcondition: UI must be valid
        std.debug.assert(ui.search_query_len == 0);
        std.debug.assert(ui.clipboard_len == 0);
        std.debug.assert(ui.websocket_clients_len == 0);

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
};

