//! Grain Bubble Undo/Redo: Command pattern for canvas operations.
//!
//! Why: Enable undo/redo for design operations.
//! Architecture: Command pattern with bounded history stacks.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-062930-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");

// Bounded: Max undo history entries.
pub const MAX_UNDO_HISTORY: u32 = 256;

// Bounded: Max redo history entries.
pub const MAX_REDO_HISTORY: u32 = 256;

// Command type: what operation was performed.
pub const CommandType = enum(u8) {
    add_shape,
    delete_shape,
    move_shape,
    resize_shape,
    change_shape_color,
    change_shape_stroke,
    add_text,
    delete_text,
    move_text,
};

// Command: represents a single operation for undo/redo.
pub const Command = struct {
    command_type: CommandType,
    shape_id: u32,
    text_id: u32,
    old_x: f64,
    old_y: f64,
    old_width: f64,
    old_height: f64,
    old_color: u32,
    old_stroke_width: f64,
    old_stroke_color: u32,
    new_x: f64,
    new_y: f64,
    new_width: f64,
    new_height: f64,
    new_color: u32,
    new_stroke_width: f64,
    new_stroke_color: u32,
    layer_id: u32,
    shape_data: canvas.Shape,
    text_data: canvas.Text,

    pub fn init() Command {
        return Command{
            .command_type = .add_shape,
            .shape_id = 0,
            .text_id = 0,
            .old_x = 0.0,
            .old_y = 0.0,
            .old_width = 0.0,
            .old_height = 0.0,
            .old_color = 0,
            .old_stroke_width = 0.0,
            .old_stroke_color = 0,
            .new_x = 0.0,
            .new_y = 0.0,
            .new_width = 0.0,
            .new_height = 0.0,
            .new_color = 0,
            .new_stroke_width = 0.0,
            .new_stroke_color = 0,
            .layer_id = 0,
            .shape_data = undefined,
            .text_data = undefined,
        };
    }
};

// Undo/redo manager: manages command history.
pub const UndoRedoManager = struct {
    undo_stack: [MAX_UNDO_HISTORY]Command,
    undo_stack_len: u32,
    redo_stack: [MAX_REDO_HISTORY]Command,
    redo_stack_len: u32,

    pub fn init() UndoRedoManager {
        std.debug.assert(MAX_UNDO_HISTORY > 0);
        std.debug.assert(MAX_REDO_HISTORY > 0);
        var manager = UndoRedoManager{
            .undo_stack = undefined,
            .undo_stack_len = 0,
            .redo_stack = undefined,
            .redo_stack_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_UNDO_HISTORY) : (i += 1) {
            manager.undo_stack[i] = Command.init();
        }
        i = 0;
        while (i < MAX_REDO_HISTORY) : (i += 1) {
            manager.redo_stack[i] = Command.init();
        }
        std.debug.assert(manager.undo_stack_len == 0);
        std.debug.assert(manager.redo_stack_len == 0);
        return manager;
    }

    // Push command to undo stack.
    pub fn push_undo(self: *UndoRedoManager, command: Command) void {
        std.debug.assert(self.undo_stack_len <= MAX_UNDO_HISTORY);
        if (self.undo_stack_len >= MAX_UNDO_HISTORY) {
            // Shift stack left, remove oldest.
            var i: u32 = 0;
            while (i < MAX_UNDO_HISTORY - 1) : (i += 1) {
                self.undo_stack[i] = self.undo_stack[i + 1];
            }
            self.undo_stack[MAX_UNDO_HISTORY - 1] = command;
        } else {
            self.undo_stack[self.undo_stack_len] = command;
            self.undo_stack_len += 1;
        }
        // Clear redo stack on new operation.
        self.redo_stack_len = 0;
        std.debug.assert(self.undo_stack_len <= MAX_UNDO_HISTORY);
        std.debug.assert(self.redo_stack_len == 0);
    }

    // Pop command from undo stack.
    pub fn pop_undo(self: *UndoRedoManager) ?Command {
        std.debug.assert(self.undo_stack_len <= MAX_UNDO_HISTORY);
        if (self.undo_stack_len == 0) {
            return null;
        }
        self.undo_stack_len -= 1;
        const command = self.undo_stack[self.undo_stack_len];
        std.debug.assert(self.undo_stack_len < MAX_UNDO_HISTORY);
        return command;
    }

    // Push command to redo stack.
    pub fn push_redo(self: *UndoRedoManager, command: Command) void {
        std.debug.assert(self.redo_stack_len <= MAX_REDO_HISTORY);
        if (self.redo_stack_len >= MAX_REDO_HISTORY) {
            // Shift stack left, remove oldest.
            var i: u32 = 0;
            while (i < MAX_REDO_HISTORY - 1) : (i += 1) {
                self.redo_stack[i] = self.redo_stack[i + 1];
            }
            self.redo_stack[MAX_REDO_HISTORY - 1] = command;
        } else {
            self.redo_stack[self.redo_stack_len] = command;
            self.redo_stack_len += 1;
        }
        std.debug.assert(self.redo_stack_len <= MAX_REDO_HISTORY);
    }

    // Pop command from redo stack.
    pub fn pop_redo(self: *UndoRedoManager) ?Command {
        std.debug.assert(self.redo_stack_len <= MAX_REDO_HISTORY);
        if (self.redo_stack_len == 0) {
            return null;
        }
        self.redo_stack_len -= 1;
        const command = self.redo_stack[self.redo_stack_len];
        std.debug.assert(self.redo_stack_len < MAX_REDO_HISTORY);
        return command;
    }

    // Check if undo is available.
    pub fn can_undo(self: *const UndoRedoManager) bool {
        return self.undo_stack_len > 0;
    }

    // Check if redo is available.
    pub fn can_redo(self: *const UndoRedoManager) bool {
        return self.redo_stack_len > 0;
    }

    // Clear all history.
    pub fn clear(self: *UndoRedoManager) void {
        self.undo_stack_len = 0;
        self.redo_stack_len = 0;
        std.debug.assert(self.undo_stack_len == 0);
        std.debug.assert(self.redo_stack_len == 0);
    }
};

