//! Tests for Grain Notes application.
//!
//! Why: Verify note creation, linking, search, and deletion functionality.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-154648-pst: Active implementation

const std = @import("std");
const testing = std.testing;
const NotesApp = @import("../src/grain_workspace/notes/app.zig").NotesApp;
const Note = @import("../src/grain_workspace/notes/app.zig").Note;
const MAX_NOTES = @import("../src/grain_workspace/notes/app.zig").MAX_NOTES;
const MAX_NOTE_TITLE_LEN = @import("../src/grain_workspace/notes/app.zig").MAX_NOTE_TITLE_LEN;
const MAX_NOTE_CONTENT_LEN = @import("../src/grain_workspace/notes/app.zig").MAX_NOTE_CONTENT_LEN;
const MAX_LINKS_PER_NOTE = @import("../src/grain_workspace/notes/app.zig").MAX_LINKS_PER_NOTE;

test "notes app initialization" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    try testing.expect(app.notes_len == 0);
    try testing.expect(app.next_note_id == 1);
    try testing.expect(app.storage == null);
}

test "create note" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id = try app.create_note("Test Note", "This is test content");
    try testing.expect(note_id == 1);
    try testing.expect(app.notes_len == 1);
    try testing.expect(app.next_note_id == 2);

    const note = app.get_note(note_id);
    try testing.expect(note != null);
    try testing.expect(note.?.id == 1);
    try testing.expect(std.mem.eql(u8, note.?.title[0..note.?.title_len], "Test Note"));
    try testing.expect(std.mem.eql(u8, note.?.content[0..note.?.content_len], "This is test content"));
    try testing.expect(note.?.state == .draft);
    try testing.expect(note.?.links_len == 0);
    try testing.expect(note.?.backlinks_len == 0);

    // Cleanup
    if (note) |n| {
        n.deinit();
    }
}

test "get note by id" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id1 = try app.create_note("Note 1", "Content 1");
    const note_id2 = try app.create_note("Note 2", "Content 2");

    const note1 = app.get_note(note_id1);
    try testing.expect(note1 != null);
    try testing.expect(note1.?.id == note_id1);

    const note2 = app.get_note(note_id2);
    try testing.expect(note2 != null);
    try testing.expect(note2.?.id == note_id2);

    const note3 = app.get_note(999);
    try testing.expect(note3 == null);

    // Cleanup
    if (note1) |n| n.deinit();
    if (note2) |n| n.deinit();
}

test "delete note" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id = try app.create_note("Test Note", "Content");
    try testing.expect(app.notes_len == 1);

    app.delete_note(note_id);
    try testing.expect(app.notes_len == 0);

    const note = app.get_note(note_id);
    try testing.expect(note == null);
}

test "note linking" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id1 = try app.create_note("Note 1", "Content 1");
    const note_id2 = try app.create_note("Note 2", "Content 2");

    const note1 = app.get_note(note_id1);
    try testing.expect(note1 != null);

    try note1.?.add_link(note_id2);
    try testing.expect(note1.?.links_len == 1);
    try testing.expect(note1.?.links[0] == note_id2);

    // Test duplicate link (should not add)
    try note1.?.add_link(note_id2);
    try testing.expect(note1.?.links_len == 1);

    // Test self-link (should fail assertion in debug)
    // note1.?.add_link(note_id1); // Would fail assertion

    // Cleanup
    if (note1) |n| n.deinit();
    const note2 = app.get_note(note_id2);
    if (note2) |n| n.deinit();
}

test "remove link" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id1 = try app.create_note("Note 1", "Content 1");
    const note_id2 = try app.create_note("Note 2", "Content 2");

    const note1 = app.get_note(note_id1);
    try testing.expect(note1 != null);

    try note1.?.add_link(note_id2);
    try testing.expect(note1.?.links_len == 1);

    note1.?.remove_link(note_id2);
    try testing.expect(note1.?.links_len == 0);

    // Cleanup
    if (note1) |n| n.deinit();
    const note2 = app.get_note(note_id2);
    if (note2) |n| n.deinit();
}

test "update note content" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id = try app.create_note("Test Note", "Original content");
    const note = app.get_note(note_id);
    try testing.expect(note != null);

    try note.?.update_content("Updated content");
    try testing.expect(std.mem.eql(u8, note.?.content[0..note.?.content_len], "Updated content"));
    try testing.expect(note.?.updated_at > note.?.created_at);

    // Cleanup
    if (note) |n| n.deinit();
}

test "search notes" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    _ = try app.create_note("Zig Programming", "Learn Zig");
    _ = try app.create_note("Rust Programming", "Learn Rust");
    _ = try app.create_note("Python Scripts", "Python content");

    var results: [10]u32 = undefined;
    var results_len: u32 = 0;

    app.search_notes("Programming", &results, &results_len);
    try testing.expect(results_len == 2);

    app.search_notes("Python", &results, &results_len);
    try testing.expect(results_len == 1);
    try testing.expect(results[0] > 0);

    // Cleanup
    var i: u32 = 0;
    while (i < app.notes_len) : (i += 1) {
        if (app.notes[i]) |*note| {
            note.deinit();
        }
    }
}

test "bounds checking - max notes" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    // Create notes up to limit
    var i: u32 = 0;
    while (i < MAX_NOTES) : (i += 1) {
        var title_buf: [32]u8 = undefined;
        _ = try std.fmt.bufPrint(&title_buf, "Note {d}", .{i});
        _ = try app.create_note(&title_buf, "Content");
    }

    try testing.expect(app.notes_len == MAX_NOTES);

    // Cleanup
    i = 0;
    while (i < app.notes_len) : (i += 1) {
        if (app.notes[i]) |*note| {
            note.deinit();
        }
    }
}

test "note initialization bounds" {
    const allocator = testing.allocator;

    // Test max title length
    var long_title: [MAX_NOTE_TITLE_LEN + 1]u8 = undefined;
    var i: u32 = 0;
    while (i < long_title.len) : (i += 1) {
        long_title[i] = 'A';
    }
    const note1 = Note.init(allocator, 1, &long_title, "Content");
    try testing.expectError(error.AssertionFailure, note1);

    // Test max content length (skip for now - too large for test)
    // var long_content: [MAX_NOTE_CONTENT_LEN + 1]u8 = undefined;
    // i = 0;
    // while (i < long_content.len) : (i += 1) {
    //     long_content[i] = 'B';
    // }
    // const note2 = Note.init(allocator, 1, "Title", &long_content);
    // try testing.expectError(error.AssertionFailure, note2);
}

test "multiple links per note" {
    const allocator = testing.allocator;
    var app = NotesApp.init(allocator);

    const note_id1 = try app.create_note("Note 1", "Content 1");
    const note_id2 = try app.create_note("Note 2", "Content 2");
    const note_id3 = try app.create_note("Note 3", "Content 3");

    const note1 = app.get_note(note_id1);
    try testing.expect(note1 != null);

    try note1.?.add_link(note_id2);
    try note1.?.add_link(note_id3);
    try testing.expect(note1.?.links_len == 2);
    try testing.expect(note1.?.links[0] == note_id2);
    try testing.expect(note1.?.links[1] == note_id3);

    // Cleanup
    if (note1) |n| n.deinit();
    const note2 = app.get_note(note_id2);
    if (note2) |n| n.deinit();
    const note3 = app.get_note(note_id3);
    if (note3) |n| n.deinit();
}

