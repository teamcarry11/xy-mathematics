//! Grain Notes: Block-based note-taking application.
//!
//! Why: Provide note-taking with knowledge graph integration for Grain OS.
//! Architecture: Block-based notes, Grain Silo storage, Grain Skate graph rendering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-162518-pst: Active implementation

const std = @import("std");
const grain_silo = @import("grain_silo");
const grain_skate = @import("grain_skate");
const grain_core = @import("grain_core");

// Bounded: Max notes (explicit limit)
// 2025-12-03-154648-pst: Active constant
pub const MAX_NOTES: u32 = 10_000;

// Bounded: Max note title length (explicit limit, in bytes)
// 2025-12-03-154648-pst: Active constant
pub const MAX_NOTE_TITLE_LEN: u32 = 512;

// Bounded: Max note content length (explicit limit, in bytes)
// 2025-12-03-154648-pst: Active constant
pub const MAX_NOTE_CONTENT_LEN: u32 = 1_048_576; // 1 MB

// Bounded: Max links per note (explicit limit)
// 2025-12-03-154648-pst: Active constant
pub const MAX_LINKS_PER_NOTE: u32 = 256;

// Note state enumeration.
// 2025-12-03-154648-pst: Active enum
pub const NoteState = enum(u8) {
    draft, // Draft note (not saved)
    saved, // Saved note
    archived, // Archived note
};

// Note structure.
// 2025-12-03-154648-pst: Active struct
pub const Note = struct {
    id: u32, // Note ID (unique identifier)
    title: []const u8, // Note title (bounded)
    title_len: u32,
    content: []const u8, // Note content (bounded, Markdown)
    content_len: u32,
    state: NoteState, // Note state
    created_at: u64, // Creation timestamp (Unix epoch)
    updated_at: u64, // Last update timestamp (Unix epoch)
    links: []u32, // Linked note IDs (bounded)
    links_len: u32,
    backlinks: []u32, // Notes that link to this note (bounded)
    backlinks_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize note.
    // 2025-12-03-154648-pst: Active function
    pub fn init(allocator: std.mem.Allocator, id: u32, title: []const u8, content: []const u8) !Note {
        // Precondition: Title and content must be bounded
        std.debug.assert(title.len <= MAX_NOTE_TITLE_LEN);
        std.debug.assert(content.len <= MAX_NOTE_CONTENT_LEN);
        std.debug.assert(id > 0);
        std.debug.assert(allocator.ptr != null);

        // Get current timestamp
        const now = @as(u64, @intCast(std.time.timestamp()));

        // Allocate title
        const title_copy = try allocator.dupe(u8, title);
        errdefer allocator.free(title_copy);

        // Allocate content
        const content_copy = try allocator.dupe(u8, content);
        errdefer allocator.free(content_copy);

        // Pre-allocate links buffer
        const links = try allocator.alloc(u32, MAX_LINKS_PER_NOTE);
        errdefer allocator.free(links);

        // Pre-allocate backlinks buffer
        const backlinks = try allocator.alloc(u32, MAX_LINKS_PER_NOTE);
        errdefer allocator.free(backlinks);

        const note = Note{
            .id = id,
            .title = title_copy,
            .title_len = @as(u32, @intCast(title_copy.len)),
            .content = content_copy,
            .content_len = @as(u32, @intCast(content_copy.len)),
            .state = .draft,
            .created_at = now,
            .updated_at = now,
            .links = links,
            .links_len = 0,
            .backlinks = backlinks,
            .backlinks_len = 0,
            .allocator = allocator,
        };

        // Postcondition: Note must be valid
        std.debug.assert(note.id > 0);
        std.debug.assert(note.title_len <= MAX_NOTE_TITLE_LEN);
        std.debug.assert(note.content_len <= MAX_NOTE_CONTENT_LEN);

        return note;
    }

    /// Deinitialize note and free memory.
    // 2025-12-03-154648-pst: Active function
    pub fn deinit(self: *Note) void {
        // Precondition: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Free title
        if (self.title_len > 0) {
            self.allocator.free(self.title);
        }

        // Free content
        if (self.content_len > 0) {
            self.allocator.free(self.content);
        }

        // Free links
        if (self.links_len > 0) {
            self.allocator.free(self.links);
        }

        // Free backlinks
        if (self.backlinks_len > 0) {
            self.allocator.free(self.backlinks);
        }
    }

    /// Update note content.
    // 2025-12-03-154648-pst: Active function
    pub fn update_content(self: *Note, new_content: []const u8) !void {
        // Precondition: Content must be bounded
        std.debug.assert(new_content.len <= MAX_NOTE_CONTENT_LEN);
        std.debug.assert(self.allocator.ptr != null);

        // Free old content
        if (self.content_len > 0) {
            self.allocator.free(self.content);
        }

        // Allocate new content
        const content_copy = try self.allocator.dupe(u8, new_content);
        self.content = content_copy;
        self.content_len = @as(u32, @intCast(content_copy.len));
        self.updated_at = @as(u64, @intCast(std.time.timestamp()));

        // Postcondition: Content must be valid
        std.debug.assert(self.content_len <= MAX_NOTE_CONTENT_LEN);
    }

    /// Add link to another note.
    // 2025-12-03-154648-pst: Active function
    pub fn add_link(self: *Note, target_note_id: u32) !void {
        // Precondition: Must have space for link
        std.debug.assert(self.links_len < MAX_LINKS_PER_NOTE);
        std.debug.assert(target_note_id > 0);
        std.debug.assert(self.id != target_note_id); // No self-links

        // Check if link already exists
        var i: u32 = 0;
        while (i < self.links_len) : (i += 1) {
            if (self.links[i] == target_note_id) {
                return; // Link already exists
            }
        }

        // Add link
        self.links[self.links_len] = target_note_id;
        self.links_len += 1;

        // Postcondition: Link count increased
        std.debug.assert(self.links_len > 0);
        std.debug.assert(self.links_len <= MAX_LINKS_PER_NOTE);
    }

    /// Remove link to another note.
    // 2025-12-03-154648-pst: Active function
    pub fn remove_link(self: *Note, target_note_id: u32) void {
        // Precondition: Target ID must be valid
        std.debug.assert(target_note_id > 0);

        // Find and remove link
        var i: u32 = 0;
        while (i < self.links_len) : (i += 1) {
            if (self.links[i] == target_note_id) {
                // Shift remaining links left
                var j: u32 = i;
                while (j + 1 < self.links_len) : (j += 1) {
                    self.links[j] = self.links[j + 1];
                }
                self.links_len -= 1;
                return;
            }
        }
    }

    /// Remove backlink from another note.
    // 2025-12-03-154648-pst: Active function
    pub fn remove_backlink(self: *Note, backlink_id: u32) void {
        // Precondition: Backlink ID must be valid
        std.debug.assert(backlink_id > 0);

        var i: u32 = 0;
        while (i < self.backlinks_len) : (i += 1) {
            if (self.backlinks[i] == backlink_id) {
                // Shift remaining backlinks left
                var j: u32 = i;
                while (j + 1 < self.backlinks_len) : (j += 1) {
                    self.backlinks[j] = self.backlinks[j + 1];
                }
                self.backlinks_len -= 1;
                return;
            }
        }
    }
};

// Notes application state.
// 2025-12-03-154648-pst: Active struct
pub const NotesApp = struct {
    notes: [MAX_NOTES]?Note,
    notes_len: u32,
    next_note_id: u32,
    storage: ?*grain_silo.Storage.ObjectStorage,
    allocator: std.mem.Allocator,

    /// Initialize notes application.
    // 2025-12-03-154648-pst: Active function
    pub fn init(allocator: std.mem.Allocator) NotesApp {
        // Precondition: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        var app = NotesApp{
            .notes = undefined,
            .notes_len = 0,
            .next_note_id = 1,
            .storage = null,
            .allocator = allocator,
        };

        // Initialize notes array
        var i: u32 = 0;
        while (i < MAX_NOTES) : (i += 1) {
            app.notes[i] = null;
        }

        // Postcondition: App must be valid
        std.debug.assert(app.notes_len == 0);
        std.debug.assert(app.next_note_id > 0);

        return app;
    }

    /// Create new note.
    // 2025-12-03-154648-pst: Active function
    pub fn create_note(self: *NotesApp, title: []const u8, content: []const u8) !u32 {
        // Precondition: Must have space for note
        std.debug.assert(self.notes_len < MAX_NOTES);
        std.debug.assert(title.len <= MAX_NOTE_TITLE_LEN);
        std.debug.assert(content.len <= MAX_NOTE_CONTENT_LEN);

        const note_id = self.next_note_id;
        self.next_note_id += 1;

        const note = try Note.init(self.allocator, note_id, title, content);
        self.notes[self.notes_len] = note;
        self.notes_len += 1;

        // Postcondition: Note count increased
        std.debug.assert(self.notes_len > 0);
        std.debug.assert(self.notes_len <= MAX_NOTES);

        return note_id;
    }

    /// Get note by ID.
    // 2025-12-03-154648-pst: Active function
    pub fn get_note(self: *const NotesApp, note_id: u32) ?*Note {
        // Precondition: Note ID must be valid
        std.debug.assert(note_id > 0);

        var i: u32 = 0;
        while (i < self.notes_len) : (i += 1) {
            if (self.notes[i]) |*note| {
                if (note.id == note_id) {
                    return note;
                }
            }
        }

        return null;
    }

    /// Delete note by ID.
    // 2025-12-03-154648-pst: Active function
    pub fn delete_note(self: *NotesApp, note_id: u32) void {
        // Precondition: Note ID must be valid
        std.debug.assert(note_id > 0);

        var i: u32 = 0;
        while (i < self.notes_len) : (i += 1) {
            if (self.notes[i]) |*note| {
                if (note.id == note_id) {
                    // Remove backlinks from linked notes
                    var j: u32 = 0;
                    while (j < note.links_len) : (j += 1) {
                        const target_id = note.links[j];
                        if (self.get_note(target_id)) |target| {
                            target.remove_backlink(note_id);
                        }
                    }

                    // Deinitialize and remove note
                    note.deinit();
                    self.notes[i] = null;

                    // Shift remaining notes left
                    var k: u32 = i;
                    while (k + 1 < self.notes_len) : (k += 1) {
                        self.notes[k] = self.notes[k + 1];
                    }
                    self.notes_len -= 1;
                    return;
                }
            }
        }
    }

    /// Search notes by title or content.
    // 2025-12-03-155158-pst: Active function
    pub fn search_notes(
        self: *const NotesApp,
        query: []const u8,
        results: []u32,
        results_len: *u32,
    ) void {
        // Precondition: Results buffer must be valid
        std.debug.assert(results.len > 0);
        std.debug.assert(results_len != null);

        results_len.* = 0;

        var i: u32 = 0;
        while (i < self.notes_len and results_len.* < results.len) : (i += 1) {
            if (self.notes[i]) |*note| {
                // Search in title
                const title_slice = note.title[0..note.title_len];
                if (std.mem.indexOf(u8, title_slice, query) != null) {
                    results[results_len.*] = note.id;
                    results_len.* += 1;
                    continue;
                }

                // Search in content
                const content_slice = note.content[0..note.content_len];
                if (std.mem.indexOf(u8, content_slice, query) != null) {
                    results[results_len.*] = note.id;
                    results_len.* += 1;
                }
            }
        }
    }

    /// Initialize storage for notes persistence.
    // 2025-12-03-155158-pst: Active function
    pub fn init_storage(
        self: *NotesApp,
        storage: *grain_silo.Storage.ObjectStorage,
    ) void {
        // Precondition: Storage must be valid
        std.debug.assert(@intFromPtr(storage) != 0);
        std.debug.assert(self.storage == null);

        self.storage = storage;

        // Postcondition: Storage must be set
        std.debug.assert(self.storage != null);
    }

    /// Save note to storage.
    // 2025-12-03-155158-pst: Active function
    pub fn save_note(self: *NotesApp, note_id: u32) !void {
        // Precondition: Storage and note must exist
        std.debug.assert(note_id > 0);
        std.debug.assert(self.storage != null);

        const note_opt = self.get_note(note_id);
        if (note_opt) |note| {
            const key = try serialize_note_key(note_id, self.allocator);
            defer self.allocator.free(key);

            const data = try serialize_note_data(note, self.allocator);
            defer self.allocator.free(data);

            const metadata = try serialize_note_metadata(note, self.allocator);
            defer self.allocator.free(metadata);

            try self.storage.?.store_object(key, data, metadata);
            note.state = .saved;
        } else {
            return error.NoteNotFound;
        }
    }

    /// Load note from storage.
    // 2025-12-03-155158-pst: Active function
    pub fn load_note(self: *NotesApp, note_id: u32) !void {
        // Precondition: Storage must exist
        std.debug.assert(note_id > 0);
        std.debug.assert(self.storage != null);

        const key = try serialize_note_key(note_id, self.allocator);
        defer self.allocator.free(key);

        if (self.storage.?.get_object(key)) |object| {
            const note = try deserialize_note_data(
                note_id,
                object.data,
                self.allocator,
            );
            self.notes[self.notes_len] = note;
            self.notes_len += 1;
        } else {
            return error.NoteNotFound;
        }
    }

    /// Export note to Markdown format.
    // 2025-12-03-162518-pst: Active function
    pub fn export_note_markdown(
        self: *const NotesApp,
        note_id: u32,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        // Precondition: Note ID must be valid
        std.debug.assert(note_id > 0);
        std.debug.assert(allocator.ptr != null);

        const note_opt = self.get_note(note_id);
        if (note_opt) |note| {
            return export_note_to_markdown(note, allocator);
        } else {
            return error.NoteNotFound;
        }
    }

    /// Import note from Markdown format.
    // 2025-12-03-162518-pst: Active function
    pub fn import_note_markdown(
        self: *NotesApp,
        markdown: []const u8,
    ) !u32 {
        // Precondition: Markdown must be valid
        std.debug.assert(markdown.len > 0);
        std.debug.assert(self.notes_len < MAX_NOTES);

        const note = try import_note_from_markdown(
            markdown,
            self.next_note_id,
            self.allocator,
        );
        self.notes[self.notes_len] = note;
        self.notes_len += 1;
        const note_id = self.next_note_id;
        self.next_note_id += 1;

        // Postcondition: Note count increased
        std.debug.assert(self.notes_len > 0);

        return note_id;
    }

    /// Export note to JSON format.
    // 2025-12-03-162518-pst: Active function
    pub fn export_note_json(
        self: *const NotesApp,
        note_id: u32,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        // Precondition: Note ID must be valid
        std.debug.assert(note_id > 0);
        std.debug.assert(allocator.ptr != null);

        const note_opt = self.get_note(note_id);
        if (note_opt) |note| {
            return export_note_to_json(note, allocator);
        } else {
            return error.NoteNotFound;
        }
    }

    /// Import note from JSON format.
    // 2025-12-03-162518-pst: Active function
    pub fn import_note_json(
        self: *NotesApp,
        json: []const u8,
    ) !u32 {
        // Precondition: JSON must be valid
        std.debug.assert(json.len > 0);
        std.debug.assert(self.notes_len < MAX_NOTES);

        const note = try import_note_from_json(
            json,
            self.next_note_id,
            self.allocator,
        );
        self.notes[self.notes_len] = note;
        self.notes_len += 1;
        const note_id = self.next_note_id;
        self.next_note_id += 1;

        // Postcondition: Note count increased
        std.debug.assert(self.notes_len > 0);

        return note_id;
    }
};

// Serialize note key for storage.
// 2025-12-03-155158-pst: Active function
fn serialize_note_key(note_id: u32, allocator: std.mem.Allocator) ![]u8 {
    // Precondition: Note ID must be valid
    std.debug.assert(note_id > 0);
    std.debug.assert(allocator.ptr != null);

    var key_buf: [64]u8 = undefined;
    const key_str = try std.fmt.bufPrint(
        &key_buf,
        "grain_notes:{d}",
        .{note_id},
    );
    const key = try allocator.dupe(u8, key_str);

    // Postcondition: Key must be valid
    std.debug.assert(key.len > 0);

    return key;
}

// Serialize note data for storage.
// 2025-12-03-155158-pst: Active function
fn serialize_note_data(
    note: *Note,
    allocator: std.mem.Allocator,
) ![]u8 {
    // Precondition: Note must be valid
    std.debug.assert(note.id > 0);
    std.debug.assert(allocator.ptr != null);

    // Simple JSON-like format: id|title|content|state|created|updated
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try std.fmt.format(buf.writer(), "{d}|", .{note.id});
    try buf.writer().writeAll(note.title[0..note.title_len]);
    try buf.writer().writeAll("|");
    try buf.writer().writeAll(note.content[0..note.content_len]);
    try std.fmt.format(buf.writer(), "|{d}|{d}|{d}", .{
        @intFromEnum(note.state),
        note.created_at,
        note.updated_at,
    });

    const data = try buf.toOwnedSlice();

    // Postcondition: Data must be valid
    std.debug.assert(data.len > 0);

    return data;
}

// Serialize note metadata for storage.
// 2025-12-03-155158-pst: Active function
fn serialize_note_metadata(
    note: *Note,
    allocator: std.mem.Allocator,
) ![]u8 {
    // Precondition: Note must be valid
    std.debug.assert(note.id > 0);
    std.debug.assert(allocator.ptr != null);

    // Metadata: links and backlinks
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try std.fmt.format(buf.writer(), "{d}:", .{note.links_len});
    var i: u32 = 0;
    while (i < note.links_len) : (i += 1) {
        if (i > 0) {
            try buf.writer().writeAll(",");
        }
        try std.fmt.format(buf.writer(), "{d}", .{note.links[i]});
    }
    try buf.writer().writeAll("|");
    try std.fmt.format(buf.writer(), "{d}:", .{note.backlinks_len});
    i = 0;
    while (i < note.backlinks_len) : (i += 1) {
        if (i > 0) {
            try buf.writer().writeAll(",");
        }
        try std.fmt.format(buf.writer(), "{d}", .{note.backlinks[i]});
    }

    const metadata = try buf.toOwnedSlice();

    // Postcondition: Metadata must be valid
    std.debug.assert(metadata.len >= 0);

    return metadata;
}

// Deserialize note data from storage.
// 2025-12-03-155158-pst: Active function
fn deserialize_note_data(
    note_id: u32,
    data: []const u8,
    allocator: std.mem.Allocator,
) !Note {
    // Precondition: Data must be valid
    std.debug.assert(note_id > 0);
    std.debug.assert(data.len > 0);
    std.debug.assert(allocator.ptr != null);

    // Parse format: id|title|content|state|created|updated
    var parts = std.mem.split(u8, data, "|");
    _ = parts.next(); // Skip ID (already known)

    const title_part = parts.next() orelse return error.InvalidFormat;
    const content_part = parts.next() orelse return error.InvalidFormat;
    const state_part = parts.next() orelse return error.InvalidFormat;
    const created_part = parts.next() orelse return error.InvalidFormat;
    _ = parts.next(); // Skip updated (we'll use current time)

    const state_val = try std.fmt.parseInt(u8, state_part, 10);
    const state = @as(NoteState, @enumFromInt(state_val));
    _ = try std.fmt.parseInt(u64, created_part, 10);

    var note = try Note.init(allocator, note_id, title_part, content_part);
    note.state = state;

    // Postcondition: Note must be valid
    std.debug.assert(note.id == note_id);

    return note;
}

// Export note to Markdown format.
// 2025-12-03-162518-pst: Active function
fn export_note_to_markdown(
    note: *Note,
    allocator: std.mem.Allocator,
) ![]u8 {
    // Precondition: Note must be valid
    std.debug.assert(note.id > 0);
    std.debug.assert(allocator.ptr != null);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // Title as H1
    try buf.writer().writeAll("# ");
    try buf.writer().writeAll(note.title[0..note.title_len]);
    try buf.writer().writeAll("\n\n");

    // Metadata as frontmatter
    try buf.writer().writeAll("---\n");
    try std.fmt.format(buf.writer(), "id: {d}\n", .{note.id});
    try std.fmt.format(
        buf.writer(),
        "state: {s}\n",
        .{@tagName(note.state)},
    );
    try std.fmt.format(
        buf.writer(),
        "created: {d}\n",
        .{note.created_at},
    );
    try std.fmt.format(
        buf.writer(),
        "updated: {d}\n",
        .{note.updated_at},
    );

    // Links
    if (note.links_len > 0) {
        try buf.writer().writeAll("links: [");
        var i: u32 = 0;
        while (i < note.links_len) : (i += 1) {
            if (i > 0) {
                try buf.writer().writeAll(", ");
            }
            try std.fmt.format(buf.writer(), "{d}", .{note.links[i]});
        }
        try buf.writer().writeAll("]\n");
    }

    try buf.writer().writeAll("---\n\n");

    // Content
    try buf.writer().writeAll(note.content[0..note.content_len]);
    try buf.writer().writeAll("\n");

    const markdown = try buf.toOwnedSlice();

    // Postcondition: Markdown must be valid
    std.debug.assert(markdown.len > 0);

    return markdown;
}

// Import note from Markdown format.
// 2025-12-03-162518-pst: Active function
fn import_note_from_markdown(
    markdown: []const u8,
    note_id: u32,
    allocator: std.mem.Allocator,
) !Note {
    // Precondition: Markdown must be valid
    std.debug.assert(markdown.len > 0);
    std.debug.assert(note_id > 0);
    std.debug.assert(allocator.ptr != null);

    // Find frontmatter section
    const frontmatter_start = std.mem.indexOf(u8, markdown, "---\n");
    if (frontmatter_start == null) {
        return error.InvalidFormat;
    }
    const frontmatter_end = std.mem.indexOfPos(
        u8,
        markdown,
        frontmatter_start.? + 4,
        "---\n",
    ) orelse return error.InvalidFormat;

    // Find title (first line after frontmatter)
    const title_start = frontmatter_end.? + 4;
    const title_end = std.mem.indexOfPos(
        u8,
        markdown,
        title_start,
        "\n",
    ) orelse return error.InvalidFormat;

    // Extract title (skip "# " prefix)
    var title_slice = markdown[title_start..title_end];
    if (title_slice.len >= 2 and title_slice[0] == '#' and title_slice[1] == ' ') {
        title_slice = title_slice[2..];
    }

    // Find content (after title and blank line)
    const content_start = std.mem.indexOfPos(
        u8,
        markdown,
        title_end + 1,
        "\n\n",
    ) orelse return error.InvalidFormat;
    const content_slice = markdown[content_start + 2..];

    // Create note
    const note = try Note.init(allocator, note_id, title_slice, content_slice);

    // Postcondition: Note must be valid
    std.debug.assert(note.id == note_id);

    return note;
}

// Export note to JSON format.
// 2025-12-03-162518-pst: Active function
fn export_note_to_json(
    note: *Note,
    allocator: std.mem.Allocator,
) ![]u8 {
    // Precondition: Note must be valid
    std.debug.assert(note.id > 0);
    std.debug.assert(allocator.ptr != null);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.writer().writeAll("{\n");
    try std.fmt.format(buf.writer(), "  \"id\": {d},\n", .{note.id});
    try buf.writer().writeAll("  \"title\": \"");
    // Escape JSON string
    var i: u32 = 0;
    while (i < note.title_len) : (i += 1) {
        const ch = note.title[i];
        if (ch == '"' or ch == '\\') {
            try buf.writer().writeAll("\\");
        }
        try buf.writer().writeByte(ch);
    }
    try buf.writer().writeAll("\",\n");
    try buf.writer().writeAll("  \"content\": \"");
    i = 0;
    while (i < note.content_len) : (i += 1) {
        const ch = note.content[i];
        if (ch == '"' or ch == '\\') {
            try buf.writer().writeAll("\\");
        }
        try buf.writer().writeByte(ch);
    }
    try buf.writer().writeAll("\",\n");
    try std.fmt.format(
        buf.writer(),
        "  \"state\": \"{s}\",\n",
        .{@tagName(note.state)},
    );
    try std.fmt.format(
        buf.writer(),
        "  \"created_at\": {d},\n",
        .{note.created_at},
    );
    try std.fmt.format(
        buf.writer(),
        "  \"updated_at\": {d},\n",
        .{note.updated_at},
    );
    try buf.writer().writeAll("  \"links\": [");
    i = 0;
    while (i < note.links_len) : (i += 1) {
        if (i > 0) {
            try buf.writer().writeAll(", ");
        }
        try std.fmt.format(buf.writer(), "{d}", .{note.links[i]});
    }
    try buf.writer().writeAll("],\n");
    try buf.writer().writeAll("  \"backlinks\": [");
    i = 0;
    while (i < note.backlinks_len) : (i += 1) {
        if (i > 0) {
            try buf.writer().writeAll(", ");
        }
        try std.fmt.format(buf.writer(), "{d}", .{note.backlinks[i]});
    }
    try buf.writer().writeAll("]\n");
    try buf.writer().writeAll("}\n");

    const json = try buf.toOwnedSlice();

    // Postcondition: JSON must be valid
    std.debug.assert(json.len > 0);

    return json;
}

// Import note from JSON format.
// 2025-12-03-162518-pst: Active function
fn import_note_from_json(
    json: []const u8,
    note_id: u32,
    allocator: std.mem.Allocator,
) !Note {
    // Precondition: JSON must be valid
    std.debug.assert(json.len > 0);
    std.debug.assert(note_id > 0);
    std.debug.assert(allocator.ptr != null);

    // Simple JSON parsing (extract title and content)
    // Find "title": "value"
    const title_label = "\"title\": \"";
    const title_start = std.mem.indexOf(u8, json, title_label);
    if (title_start == null) {
        return error.InvalidFormat;
    }
    var title_end = title_start.? + title_label.len;
    while (title_end < json.len and json[title_end] != '"') : (title_end += 1) {
        if (json[title_end] == '\\') {
            title_end += 1; // Skip escaped char
        }
    }
    const title_slice = json[title_start.? + title_label.len..title_end];

    // Find "content": "value"
    const content_label = "\"content\": \"";
    const content_start = std.mem.indexOfPos(
        u8,
        json,
        title_end,
        content_label,
    );
    if (content_start == null) {
        return error.InvalidFormat;
    }
    var content_end = content_start.? + content_label.len;
    while (content_end < json.len and json[content_end] != '"') : (content_end += 1) {
        if (json[content_end] == '\\') {
            content_end += 1; // Skip escaped char
        }
    }
    const content_slice = json[content_start.? + content_label.len..content_end];

    // Create note
    const note = try Note.init(allocator, note_id, title_slice, content_slice);

    // Postcondition: Note must be valid
    std.debug.assert(note.id == note_id);

    return note;
}

