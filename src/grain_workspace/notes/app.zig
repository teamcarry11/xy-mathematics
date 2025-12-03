//! Grain Notes: Block-based note-taking application.
//!
//! Why: Provide note-taking with knowledge graph integration for Grain OS.
//! Architecture: Block-based notes, Grain Silo storage, Grain Skate graph rendering.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-154648-pst: Active implementation

const std = @import("std");
const grain_silo = @import("grain_silo");
const grain_skate = @import("grain_skate");
const grain_os = @import("grain_os");

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
    // 2025-12-03-154648-pst: Active function
    pub fn search_notes(self: *const NotesApp, query: []const u8, results: []u32, results_len: *u32) void {
        // Precondition: Results buffer must be valid
        std.debug.assert(results.len > 0);
        std.debug.assert(results_len != null);

        results_len.* = 0;

        var i: u32 = 0;
        while (i < self.notes_len and results_len.* < results.len) : (i += 1) {
            if (self.notes[i]) |*note| {
                // Search in title
                if (std.mem.indexOf(u8, note.title[0..note.title_len], query) != null) {
                    results[results_len.*] = note.id;
                    results_len.* += 1;
                    continue;
                }

                // Search in content
                if (std.mem.indexOf(u8, note.content[0..note.content_len], query) != null) {
                    results[results_len.*] = note.id;
                    results_len.* += 1;
                }
            }
        }
    }
};

