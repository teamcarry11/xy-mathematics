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
        move_word_forward, // Move to start of next word (w)
        move_word_backward, // Move to start of previous word (b)
        move_word_end, // Move to end of current/next word (e)
        move_line_start, // Move to beginning of line (0)
        move_line_end, // Move to end of line ($)
        move_line_start_nonblank, // Move to first non-whitespace (^)
        move_file_start, // Move to beginning of file (gg)
        move_file_end, // Move to end of file (G)
        insert_mode, // Enter insert mode (i)
        normal_mode, // Enter normal mode (Esc)
        visual_mode, // Enter visual mode (v)
        visual_line_mode, // Enter visual line mode (V)
        visual_block_mode, // Enter visual block mode (Ctrl+v)
        command_mode, // Enter command mode (:)
        search_mode, // Enter search mode (/)
        search_backward_mode, // Enter search backward mode (?)
        find_next, // Find next occurrence (n)
        find_previous, // Find previous occurrence (N)
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
    key_sequence: [MAX_KEY_SEQUENCE]u32, // Key sequence buffer for multi-key commands
    key_sequence_len: u32, // Current key sequence length
    key_sequence_timeout: u64, // Timestamp for key sequence timeout
    last_command_result: CommandResult, // Last command execution result
    allocator: std.mem.Allocator,

    /// Initialize modal editor.
    // 2025-11-23-170000-pst: Active function
    pub fn init(allocator: std.mem.Allocator, editor: *Editor.EditorState) !ModalEditor {
        // Assert: Editor must be valid
        // Parameters are used in struct initialization below

        return ModalEditor{
            .editor = editor,
            .command_buffer = undefined,
            .command_buffer_len = 0,
            .key_sequence = undefined,
            .key_sequence_len = 0,
            .key_sequence_timeout = 0,
            .last_command_result = .none,
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
            .visual_line => try self.handle_visual_line_mode(event),
            .command => try self.handle_command_mode(event),
            .search => try self.handle_search_mode(event),
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
            .move_word_forward => {
                // Move to start of next word (w)
                self.editor.move_word_forward();
            },
            .move_word_backward => {
                // Move to start of previous word (b)
                self.editor.move_word_backward();
            },
            .move_word_end => {
                // Move to end of current/next word (e)
                self.editor.move_word_end();
            },
            .move_line_start => {
                // Move to beginning of line (0)
                self.editor.move_line_start();
            },
            .move_line_end => {
                // Move to end of line ($)
                self.editor.move_line_end();
            },
            .move_line_start_nonblank => {
                // Move to first non-whitespace (^)
                self.editor.move_line_start_nonblank();
            },
            .move_file_start => {
                // Move to beginning of file (gg)
                self.editor.move_file_start();
            },
            .move_file_end => {
                // Move to end of file (G)
                self.editor.move_file_end();
            },
            .insert_mode => {
                // Enter insert mode (i)
                self.editor.enter_insert_mode();
            },
            .visual_mode => {
                // Enter visual mode (v)
                self.editor.enter_visual_mode();
            },
            .visual_line_mode => {
                // Enter visual line mode (V)
                self.editor.enter_visual_line_mode();
            },
            .visual_block_mode => {
                // Enter visual block mode (Ctrl+v)
                self.editor.enter_visual_block_mode();
            },
            .search_mode => {
                // Enter search mode (/)
                self.editor.enter_search_mode();
            },
            .search_backward_mode => {
                // Enter search backward mode (?)
                self.editor.enter_search_backward_mode();
            },
            .find_next => {
                // Find next occurrence (n)
                _ = self.editor.find_next();
            },
            .find_previous => {
                // Find previous occurrence (N)
                _ = self.editor.find_previous();
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
                self.editor.undo() catch |err| {
                    // Handle undo error (e.g., out of memory)
                    _ = err;
                };
            },
            .redo => {
                // Redo (Ctrl+r)
                self.editor.redo() catch |err| {
                    // Handle redo error (e.g., out of memory)
                    _ = err;
                };
            },
            .yank => {
                // Yank (copy) line (y)
                self.editor.yank_line() catch |err| {
                    // Handle yank error (e.g., out of memory)
                    _ = err;
                };
            },
            .paste => {
                // Paste (p)
                self.editor.paste() catch |err| {
                    // Handle paste error (e.g., out of memory)
                    _ = err;
                };
            },
            .delete_line => {
                // Delete line (dd)
                self.editor.delete_line() catch |err| {
                    // Handle delete line error (e.g., out of memory)
                    _ = err;
                };
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

    /// Handle visual block mode key event.
    // 2025-12-02-135701-pst: Active function
    fn handle_visual_block_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Visual block mode: similar to visual mode but with column-based selection
        if (event.key_code == 27) {
            // Escape key: return to normal mode
            self.editor.exit_visual_mode();
        } else {
            // Map key to action
            const action = self.map_key_to_action(event);
            // Execute action (movement extends block selection)
            switch (action) {
                .move_left => self.editor.move_left(),
                .move_right => self.editor.move_right(),
                .move_up => self.editor.move_up(),
                .move_down => self.editor.move_down(),
                .move_word_forward => self.editor.move_word_forward(),
                .move_word_backward => self.editor.move_word_backward(),
                .move_word_end => self.editor.move_word_end(),
                .move_line_start => self.editor.move_line_start(),
                .move_line_end => self.editor.move_line_end(),
                .move_line_start_nonblank => self.editor.move_line_start_nonblank(),
                .move_file_start => self.editor.move_file_start(),
                .move_file_end => self.editor.move_file_end(),
                .yank => {
                    // Yank selected block (y)
                    self.editor.yank_selection() catch |err| {
                        _ = err;
                    };
                    self.editor.exit_visual_mode();
                },
                .delete_char => {
                    // Delete selected block (x)
                    self.editor.delete_selection() catch |err| {
                        _ = err;
                    };
                },
                .paste => {
                    // Paste (replace selection with yank buffer) (p)
                    self.editor.paste_selection() catch |err| {
                        _ = err;
                    };
                },
                .normal_mode => {
                    // Return to normal mode
                    self.editor.exit_visual_mode();
                },
                else => {
                    // Other actions not handled in visual block mode
                },
            }
        }
    }

    /// Handle visual line mode key event.
    // 2025-12-02-130235-pst: Active function
    fn handle_visual_line_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Visual line mode: similar to visual mode but selects entire lines
        if (event.key_code == 27) {
            // Escape key: return to normal mode
            self.editor.exit_visual_mode();
        } else {
            // Map key to action
            const action = self.map_key_to_action(event);
            // Execute action (movement extends line selection)
            switch (action) {
                .move_up => {
                    self.editor.move_up();
                    // Ensure column is 0 for line selection
                    self.editor.cursor_column = 0;
                },
                .move_down => {
                    self.editor.move_down();
                    // Ensure column is 0 for line selection
                    self.editor.cursor_column = 0;
                },
                .yank => {
                    // Yank selected lines (y)
                    self.editor.yank_selection() catch |err| {
                        _ = err;
                    };
                    self.editor.exit_visual_mode();
                },
                .delete_char => {
                    // Delete selected lines (x)
                    self.editor.delete_selection() catch |err| {
                        _ = err;
                    };
                },
                .paste => {
                    // Paste (replace selection with yank buffer) (p)
                    self.editor.paste_selection() catch |err| {
                        _ = err;
                    };
                },
                .normal_mode => {
                    // Return to normal mode
                    self.editor.exit_visual_mode();
                },
                else => {
                    // Other actions not handled in visual line mode
                },
            }
        }
    }

    /// Handle visual mode key event.
    // 2025-12-02-121512-pst: Active function
    fn handle_visual_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Visual mode: similar to normal mode but with selection
        if (event.key_code == 27) {
            // Escape key: return to normal mode
            self.editor.exit_visual_mode();
        } else {
            // Map key to action
            const action = self.map_key_to_action(event);
            // Execute action (movement extends selection)
            switch (action) {
                .move_left => self.editor.move_left(),
                .move_right => self.editor.move_right(),
                .move_up => self.editor.move_up(),
                .move_down => self.editor.move_down(),
                .move_word_forward => self.editor.move_word_forward(),
                .move_word_backward => self.editor.move_word_backward(),
                .move_word_end => self.editor.move_word_end(),
                .move_line_start => self.editor.move_line_start(),
                .move_line_end => self.editor.move_line_end(),
                .move_line_start_nonblank => self.editor.move_line_start_nonblank(),
                .move_file_start => self.editor.move_file_start(),
                .move_file_end => self.editor.move_file_end(),
                .yank => {
                    // Yank selected text (y)
                    self.editor.yank_selection() catch |err| {
                        _ = err;
                    };
                    self.editor.exit_visual_mode();
                },
                .delete_char => {
                    // Delete selected text (x)
                    self.editor.delete_selection() catch |err| {
                        _ = err;
                    };
                },
                .paste => {
                    // Paste (replace selection with yank buffer) (p)
                    self.editor.paste_selection() catch |err| {
                        _ = err;
                    };
                },
                .normal_mode => {
                    // Return to normal mode
                    self.editor.exit_visual_mode();
                },
                else => {
                    // Other actions not handled in visual mode
                },
            }
        }
    }

    /// Handle search mode key event.
    // 2025-12-02-133808-pst: Active function
    fn handle_search_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Search mode: build search pattern, Enter to search
        if (event.key_code == 27) {
            // Escape key: cancel search, return to normal mode
            self.editor.exit_search_mode();
        } else if (event.key_code == 13) {
            // Enter key: execute search
            if (self.editor.search_pattern_len > 0) {
                if (self.editor.search_direction == .forward) {
                    _ = self.editor.find_next();
                } else {
                    _ = self.editor.find_previous();
                }
            }
            self.editor.exit_search_mode();
        } else if (event.key_code == 8 or event.key_code == 127) {
            // Backspace: remove last character from search pattern
            self.editor.remove_search_char();
        } else if (event.key_code >= 32 and event.key_code < 127) {
            // Printable ASCII character: add to search pattern
            const char = @as(u8, @intCast(event.key_code));
            self.editor.add_search_char(char);
        }
    }

    /// Command execution result.
    // 2025-11-24-193000-pst: Active enum
    pub const CommandResult = enum(u8) {
        none, // No action needed
        save, // Save block (w, wq)
        quit, // Quit (q, q!)
        save_quit, // Save and quit (wq)
        force_quit, // Force quit without saving (q!)
        command_error, // Command error
    };

    /// Handle command mode key event.
    // 2025-11-24-193000-pst: Active function
    fn handle_command_mode(self: *ModalEditor, event: events.KeyboardEvent) !void {
        // Command mode: collect command string
        if (event.key_code == 13) {
            // Enter key: execute command
            const result = self.parse_and_execute_command();
            self.last_command_result = result; // Store result for caller
            self.editor.mode = .normal;
            self.command_buffer_len = 0;
        } else if (event.key_code == 27) {
            // Escape key: cancel command
            self.editor.mode = .normal;
            self.command_buffer_len = 0;
        } else if (event.key_code == 8) {
            // Backspace: remove last character
            if (self.command_buffer_len > 0) {
                self.command_buffer_len -= 1;
            }
        } else if (event.key_code >= 32 and event.key_code < 127) {
            // Printable ASCII character: add to command buffer
            if (self.command_buffer_len < MAX_COMMAND_BUFFER - 1) {
                const char = @as(u8, @intCast(event.key_code));
                self.command_buffer[self.command_buffer_len] = char;
                self.command_buffer_len += 1;
            }
        }
    }

    /// Parse and execute command from buffer.
    // 2025-11-24-193000-pst: Active function
    fn parse_and_execute_command(self: *ModalEditor) CommandResult {
        if (self.command_buffer_len == 0) {
            return .none;
        }

        // Get command string (trim whitespace)
        const cmd_start = self.find_command_start();
        const cmd_end = self.find_command_end(cmd_start);
        if (cmd_start >= cmd_end) {
            return .command_error;
        }

        const cmd = self.command_buffer[cmd_start..cmd_end];

        // Parse command (simple string matching for common Vim commands)
        if (std.mem.eql(u8, cmd, "w")) {
            // Write (save)
            return .save;
        } else if (std.mem.eql(u8, cmd, "q")) {
            // Quit
            return .quit;
        } else if (std.mem.eql(u8, cmd, "wq")) {
            // Write and quit
            return .save_quit;
        } else if (std.mem.eql(u8, cmd, "q!")) {
            // Force quit without saving
            return .force_quit;
        } else if (std.mem.eql(u8, cmd, "x")) {
            // Write and quit (same as wq)
            return .save_quit;
        } else if (cmd.len > 2 and cmd[0] == 's' and cmd[1] == '/') {
            // Substitute command: s/pattern/replacement/ or s/pattern/replacement/g
            return self.parse_substitute_command(cmd);
        } else {
            // Unknown command
            return .command_error;
        }
    }

    /// Parse substitute command (s/pattern/replacement/ or s/pattern/replacement/g).
    // 2025-12-02-140535-pst: Active function
    fn parse_substitute_command(self: *ModalEditor, cmd: []const u8) CommandResult {
        // Format: s/pattern/replacement/ or s/pattern/replacement/g
        // Skip 's/'
        if (cmd.len < 4) {
            return .command_error;
        }
        var i: u32 = 2; // Skip 's/'
        // Find pattern end (next '/')
        var pattern_start: u32 = i;
        var pattern_end: u32 = 0;
        while (i < cmd.len) : (i += 1) {
            if (cmd[i] == '/') {
                pattern_end = i;
                break;
            }
        }
        if (pattern_end == 0 or pattern_end == pattern_start) {
            return .command_error;
        }
        // Find replacement end (next '/' or end)
        i += 1; // Skip '/'
        var replacement_start: u32 = i;
        var replacement_end: u32 = 0;
        var global: bool = false;
        while (i < cmd.len) : (i += 1) {
            if (cmd[i] == '/') {
                replacement_end = i;
                // Check for 'g' flag after '/'
                if (i + 1 < cmd.len and cmd[i + 1] == 'g') {
                    global = true;
                }
                break;
            }
        }
        if (replacement_end == 0) {
            // No closing '/', use end of command
            replacement_end = cmd.len;
        }
        if (replacement_end == replacement_start) {
            // Empty replacement is valid
        }
        const pattern = cmd[pattern_start..pattern_end];
        const replacement = if (replacement_end > replacement_start)
            cmd[replacement_start..replacement_end]
        else
            "";
        // Execute replace
        if (global) {
            // Replace all on current line
            const count = self.editor.replace_all_on_line(pattern, replacement) catch |err| {
                _ = err;
                return .command_error;
            };
            _ = count; // Can be used for feedback
        } else {
            // Replace first occurrence on current line
            const found = self.editor.replace_on_line(pattern, replacement) catch |err| {
                _ = err;
                return .command_error;
            };
            if (!found) {
                // Pattern not found
                return .command_error;
            }
        }
        return .none;
    }

    /// Find start of command (skip leading whitespace).
    // 2025-11-24-193000-pst: Active function
    fn find_command_start(self: *const ModalEditor) u32 {
        var i: u32 = 0;
        while (i < self.command_buffer_len) : (i += 1) {
            const ch = self.command_buffer[i];
            if (ch != ' ' and ch != '\t') {
                return i;
            }
        }
        return self.command_buffer_len;
    }

    /// Find end of command (find first whitespace or end of buffer).
    // 2025-11-24-193000-pst: Active function
    fn find_command_end(self: *const ModalEditor, start: u32) u32 {
        var i: u32 = start;
        while (i < self.command_buffer_len) : (i += 1) {
            const ch = self.command_buffer[i];
            if (ch == ' ' or ch == '\t') {
                return i;
            }
        }
        return self.command_buffer_len;
    }

    /// Get current command string (for display).
    // 2025-11-24-193000-pst: Active function
    pub fn get_command_string(self: *const ModalEditor) []const u8 {
        return self.command_buffer[0..self.command_buffer_len];
    }

    /// Get last command result and clear it.
    // 2025-12-02-153505-pst: Active function
    pub fn get_last_command_result(self: *ModalEditor) CommandResult {
        const result = self.last_command_result;
        self.last_command_result = .none; // Clear after reading
        return result;
    }

    /// Map key code to action.
    // 2025-11-23-170000-pst: Active function
    fn map_key_to_action(self: *ModalEditor, event: events.KeyboardEvent) Action {
        // Check for Ctrl+v (visual block mode)
        // Ctrl+v is typically key_code 22 (0x16) or 'v' with Ctrl modifier
        if (event.key_code == 22 or (event.key_code == 'v' and event.modifiers.control)) {
            self.key_sequence_len = 0; // Clear sequence
            return .visual_block_mode;
        }

        // Handle key sequences (e.g., 'gg' for move to file start)
        if (event.key_code == 'g') {
            if (self.key_sequence_len > 0 and self.key_sequence[self.key_sequence_len - 1] == 'g') {
                // 'gg' sequence: move to file start
                self.key_sequence_len = 0;
                return .move_file_start;
            } else {
                // First 'g', add to sequence
                if (self.key_sequence_len < MAX_KEY_SEQUENCE) {
                    self.key_sequence[self.key_sequence_len] = 'g';
                    self.key_sequence_len += 1;
                }
                // Return no_action for now, wait for second 'g'
                return .no_action;
            }
        } else {
            // Clear key sequence if not continuing 'g'
            self.key_sequence_len = 0;
        }

        // Map single key codes to actions
        switch (event.key_code) {
            'h' => return .move_left,
            'l' => return .move_right,
            'k' => return .move_up,
            'j' => return .move_down,
            'w' => return .move_word_forward,
            'b' => return .move_word_backward,
            'e' => return .move_word_end,
            '0' => return .move_line_start,
            '$' => return .move_line_end,
            '^' => return .move_line_start_nonblank,
            'G' => return .move_file_end,
            'i' => return .insert_mode,
            'v' => return .visual_mode,
            'V' => return .visual_line_mode,
            '/' => return .search_mode,
            '?' => return .search_backward_mode,
            'n' => return .find_next,
            'N' => return .find_previous,
            ':' => return .command_mode,
            'x' => return .delete_char,
            'u' => return .undo,
            'y' => return .yank,
            'p' => return .paste,
            'd' => return .delete_line,
            else => return .no_action,
        }
    }
};

