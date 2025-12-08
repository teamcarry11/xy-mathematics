//! Grain OS Clipboard: System clipboard management for copy/paste.
//!
//! Why: Provide system-wide clipboard for copy/paste operations.
//! Architecture: Clipboard buffer, format support, history.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max clipboard data size (4KB).
pub const MAX_CLIPBOARD_SIZE: u32 = 4096;

// Bounded: Max clipboard history entries.
pub const MAX_HISTORY_ENTRIES: u32 = 16;

// Bounded: Max format name length.
pub const MAX_FORMAT_NAME_LEN: u32 = 32;

// Clipboard format types.
pub const ClipboardFormat = enum(u8) {
    text,
    html,
    image,
    custom,
};

// Clipboard entry: represents clipboard data.
pub const ClipboardEntry = struct {
    format: ClipboardFormat,
    data: [MAX_CLIPBOARD_SIZE]u8,
    data_len: u32,
    format_name: [MAX_FORMAT_NAME_LEN]u8,
    format_name_len: u32,
    timestamp: u64,

    pub fn init() ClipboardEntry {
        var entry = ClipboardEntry{
            .format = ClipboardFormat.text,
            .data = undefined,
            .data_len = 0,
            .format_name = undefined,
            .format_name_len = 0,
            .timestamp = 0,
        };
        var i: u32 = 0;
        while (i < MAX_CLIPBOARD_SIZE) : (i += 1) {
            entry.data[i] = 0;
        }
        i = 0;
        while (i < MAX_FORMAT_NAME_LEN) : (i += 1) {
            entry.format_name[i] = 0;
        }
        return entry;
    }
};

// Clipboard manager: manages system clipboard.
pub const ClipboardManager = struct {
    current_entry: ClipboardEntry,
    history: [MAX_HISTORY_ENTRIES]ClipboardEntry,
    history_len: u32,

    pub fn init() ClipboardManager {
        var manager = ClipboardManager{
            .current_entry = ClipboardEntry.init(),
            .history = undefined,
            .history_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_HISTORY_ENTRIES) : (i += 1) {
            manager.history[i] = ClipboardEntry.init();
        }
        return manager;
    }

    // Set clipboard data.
    pub fn set_data(
        self: *ClipboardManager,
        format: ClipboardFormat,
        data: []const u8,
        format_name: []const u8,
    ) bool {
        if (data.len > MAX_CLIPBOARD_SIZE) {
            return false;
        }
        if (format_name.len > MAX_FORMAT_NAME_LEN) {
            return false;
        }
        // Save current entry to history if not empty.
        if (self.current_entry.data_len > 0) {
            if (self.history_len < MAX_HISTORY_ENTRIES) {
                self.history[self.history_len] = self.current_entry;
                self.history_len += 1;
            } else {
                // Shift history left, remove oldest.
                var i: u32 = 0;
                while (i < MAX_HISTORY_ENTRIES - 1) : (i += 1) {
                    self.history[i] = self.history[i + 1];
                }
                self.history[MAX_HISTORY_ENTRIES - 1] = self.current_entry;
            }
        }
        // Set new clipboard data.
        self.current_entry = ClipboardEntry.init();
        self.current_entry.format = format;
        var i: u32 = 0;
        while (i < MAX_CLIPBOARD_SIZE) : (i += 1) {
            self.current_entry.data[i] = 0;
        }
        i = 0;
        while (i < data.len) : (i += 1) {
            self.current_entry.data[i] = data[i];
        }
        self.current_entry.data_len = @intCast(data.len);
        i = 0;
        while (i < MAX_FORMAT_NAME_LEN) : (i += 1) {
            self.current_entry.format_name[i] = 0;
        }
        const name_len = @min(format_name.len, MAX_FORMAT_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.current_entry.format_name[i] = format_name[i];
        }
        self.current_entry.format_name_len = @intCast(name_len);
        self.current_entry.timestamp = 0; // Would use actual timestamp.
        return true;
    }

    // Get clipboard data.
    pub fn get_data(self: *const ClipboardManager) ?[]const u8 {
        if (self.current_entry.data_len == 0) {
            return null;
        }
        return self.current_entry.data[0..self.current_entry.data_len];
    }

    // Get clipboard format.
    pub fn get_format(self: *const ClipboardManager) ClipboardFormat {
        return self.current_entry.format;
    }

    // Get clipboard format name.
    pub fn get_format_name(self: *const ClipboardManager) []const u8 {
        return self.current_entry.format_name[0..self.current_entry.format_name_len];
    }

    // Check if clipboard is empty.
    pub fn is_empty(self: *const ClipboardManager) bool {
        return self.current_entry.data_len == 0;
    }

    // Clear clipboard.
    pub fn clear(self: *ClipboardManager) void {
        self.current_entry = ClipboardEntry.init();
    }

    // Get history entry.
    pub fn get_history_entry(self: *const ClipboardManager, index: u32) ?*const ClipboardEntry {
        if (index >= self.history_len) {
            return null;
        }
        return &self.history[index];
    }

    // Get history count.
    pub fn get_history_count(self: *const ClipboardManager) u32 {
        return self.history_len;
    }

    // Clear history.
    pub fn clear_history(self: *ClipboardManager) void {
        self.history_len = 0;
    }
};

