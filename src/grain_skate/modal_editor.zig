const std = @import("std");
const Editor = @import("editor.zig").Editor;
const events = @import("events");

/// Grain Skate Modal Editor: Vim/Kakoune keybindings for block editing.
/// ~<~ Glow Airbend: explicit keybinding state, bounded command buffers.
/// ~~~~ Glow Waterbend: deterministic key handling, iterative command processing.
///
/// 2025-11-23-170000-pst: Active implementation
pub const ModalEditor = struct {
    // Bounded: Max command buffer size (explicit limit, in bytes)
    // 2025-11-23-170000-pst: Active constant
    pub const MAX_COMMAND_BUFFER: u32 = 256;

    // Bounded: Max key sequence length (explicit limit)
    // 2025-11-23-170000-pst: Active constant
    pub const MAX_KEY_SEQUENCE: u32 = 16;

    /// Keybinding action enumeration.
    // 2025-11-23-170000-pst: Active enum
    pub const Action = enum(u8) {
        move_left, // Move cursor left (h)
        move_right, // Move cursor right (l)
        move_up, // Move cursor up (k)
        move_down, // Move cursor down (j)
        insert_mode, // Enter insert mode (i)
        normal_mode, // Enter normal mode (Esc)
        visual_mode, // Enter visual mode (v)
        command_mode, // Enter command mode (:)
        delete_char, // Delete character (x)
        delete_line, // Delete line (dd)
        yank, // Yank (copy) (y)
        paste, // Paste (p)
        undo, // Undo (u)
        redo, // Redo (Ctrl+r)
        save, // Save block (w)
        quit, // Quit (q)
        no_action, // No action
    };

    /// Modal editor state.
    // 2025-11-23-170000-pst: Active struct
    editor: *Editor.EditorState,
    command_buffer: [MAX_COMMAND_BUFFER]u8,
    command_buffer_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize modal editor.
    // 2025-11-23-170000-pst: Active function
    pub fn init(allocator: std.mem.Allocator, editor: *Editor.EditorState) !ModalEditor {
        // Assert: Editor must be valid
        _ = allocator; // Allocator is stored but not used yet
        _ = editor.allocator; // Editor allocator is used by editor

        return ModalEditor{
            .editor = editor,
            .command_buffer = undefined,
            .command_buffer_len = 0,
            .allocator = allocator,
        };
    }

    /// Deinitialize modal editor.
    // 2025-11-23-170000-pst: Active function
    pub fn deinit(self: *ModalEditor) void {
        // Editor is owned by caller, don't deinit here
        self.* = undefined;
    }

    /// Handle keyboard event.
    // 2025-11-23-170000-pst: Active function
    pub fn handle_key_event(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Assert: Event must be valid
        std.debug.assert(event.key_code < 256);

        // Get current editor mode
        const mode = self.editor.mode;

        // Handle key based on mode
        switch (mode) {
            .normal => try self.handle_normal_mode(event),
            .insert => try self.handle_insert_mode(event),
            .visual => try self.handle_visual_mode(event),
            .command => try self.handle_command_mode(event),
        }
    }

    /// Handle normal mode key event.
    // 2025-11-23-170000-pst: Active function
    fn handle_normal_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Map key to action
        const action = self.map_key_to_action(event);

        // Execute action
        switch (action) {
            .move_left => {
                // Move cursor left (h)
                self.editor.move_left();
            },
            .move_right => {
                // Move cursor right (l)
                self.editor.move_right();
            },
            .move_up => {
                // Move cursor up (k)
                self.editor.move_up();
            },
            .move_down => {
                // Move cursor down (j)
                self.editor.move_down();
            },
            .insert_mode => {
                // Enter insert mode (i)
                self.editor.enter_insert_mode();
            },
            .visual_mode => {
                // Enter visual mode (v)
                self.editor.mode = .visual;
            },
            .command_mode => {
                // Enter command mode (:)
                self.editor.mode = .command;
            },
            .delete_char => {
                // Delete character (x)
                self.editor.delete_char();
            },
            .undo => {
                // Undo (u)
                self.editor.undo();
            },
            .redo => {
                // Redo (Ctrl+r)
                self.editor.redo();
            },
            .no_action => {
                // No action
            },
            else => {
                // Other actions not yet implemented
            },
        }
    }

    /// Handle insert mode key event.
    // 2025-11-23-170000-pst: Active function
    fn handle_insert_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // In insert mode, most keys insert characters
        if (event.key_code == 27) {
            // Escape key: return to normal mode
            self.editor.switch_mode(.normal);
        } else if (event.key_code >= 32 and event.key_code < 127) {
            // Printable ASCII character: insert it
            const char = @as(u8, @intCast(event.key_code));
            self.editor.insert_char(char);
        }
    }

    /// Handle visual mode key event.
    // 2025-11-23-170000-pst: Active function
    fn handle_visual_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Visual mode: similar to normal mode but with selection
        if (event.key_code == 27) {
            // Escape key: return to normal mode
            self.editor.exit_insert_mode();
        } else {
            // Use normal mode handling for movement
            try self.handle_normal_mode(event);
        }
    }

    /// Handle command mode key event.
    // 2025-11-23-170000-pst: Active function
    fn handle_command_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Command mode: collect command string
        if (event.key_code == 13) {
            // Enter key: execute command
            // TODO: Parse and execute command
            self.editor.exit_insert_mode();
            self.command_buffer_len = 0;
        } else if (event.key_code == 27) {
            // Escape key: cancel command
            self.editor.exit_insert_mode();
            self.command_buffer_len = 0;
        } else if (event.key_code >= 32 and event.key_code < 127) {
            // Printable ASCII character: add to command buffer
            if (self.command_buffer_len < MAX_COMMAND_BUFFER - 1) {
                const char = @as(u8, @intCast(event.key_code));
                self.command_buffer[self.command_buffer_len] = char;
                self.command_buffer_len += 1;
            }
        }
    }

    /// Map key code to action.
    // 2025-11-23-170000-pst: Active function
    fn map_key_to_action(self: *ModalEditor, event: events.KeyboardEvent) Action {
        _ = self; // Will be used for key sequence handling in full implementation

        // Map single key codes to actions
        switch (event.key_code) {
            'h' => return .move_left,
            'l' => return .move_right,
            'k' => return .move_up,
            'j' => return .move_down,
            'i' => return .insert_mode,
            'v' => return .visual_mode,
            ':' => return .command_mode,
            'x' => return .delete_char,
            'u' => return .undo,
            else => return .no_action,
        }
    }
};

