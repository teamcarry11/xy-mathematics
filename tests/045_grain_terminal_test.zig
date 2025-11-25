const std = @import("std");
const testing = std.testing;
const grain_terminal = @import("grain_terminal");
const Terminal = grain_terminal.Terminal;
const Renderer = grain_terminal.Renderer;

test "terminal init" {
    const terminal = Terminal.init(80, 24);

    try testing.expect(terminal.width == 80);
    try testing.expect(terminal.height == 24);
    try testing.expect(terminal.cursor_x == 0);
    try testing.expect(terminal.cursor_y == 0);
    try testing.expect(terminal.state == .normal);
}

test "terminal process char" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Process printable character
    terminal.process_char('H', &cells);
    try testing.expect(terminal.cursor_x == 1);
    try testing.expect(terminal.cursor_y == 0);

    // Check cell was written
    const cell = terminal.get_cell(0, 0, &cells);
    try testing.expect(cell != null);
    try testing.expect(cell.?.ch == 'H');
}

test "terminal newline" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    terminal.process_char('\n', &cells);
    try testing.expect(terminal.cursor_x == 0);
    try testing.expect(terminal.cursor_y == 1);
}

test "terminal carriage return" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    terminal.cursor_x = 40;
    terminal.process_char('\r', &cells);
    try testing.expect(terminal.cursor_x == 0);
}

test "terminal clear" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Write some characters
    terminal.process_char('H', &cells);
    terminal.process_char('i', &cells);

    // Clear terminal
    terminal.clear(&cells);

    // Check cursor reset
    try testing.expect(terminal.cursor_x == 0);
    try testing.expect(terminal.cursor_y == 0);

    // Check cells are cleared
    const cell = terminal.get_cell(0, 0, &cells);
    try testing.expect(cell != null);
    try testing.expect(cell.?.ch == ' ');
}

test "terminal escape sequence" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Save cursor
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('7', &cells);
    try testing.expect(terminal.saved_cursor_x == 10);
    try testing.expect(terminal.saved_cursor_y == 5);

    // Move cursor
    terminal.cursor_x = 20;
    terminal.cursor_y = 10;

    // Restore cursor
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('8', &cells);
    try testing.expect(terminal.cursor_x == 10);
    try testing.expect(terminal.cursor_y == 5);
}

test "terminal csi sequence" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to position 5, 10
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('6', &cells);
    terminal.process_char('H', &cells);

    try testing.expect(terminal.cursor_y == 10);
    try testing.expect(terminal.cursor_x == 5);
}

test "terminal scroll" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to bottom
    terminal.cursor_y = terminal.height - 1;
    terminal.cursor_x = 0;

    // Write character that causes scroll
    terminal.process_char('A', &cells);
    terminal.process_char('\n', &cells);

    // Check scrollback incremented
    try testing.expect(terminal.scrollback_lines > 0);
}

test "terminal sgr sequence" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Set bold
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('m', &cells);

    try testing.expect(terminal.current_attrs.bold == true);

    // Reset
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('m', &cells);

    try testing.expect(terminal.current_attrs.bold == false);
}

test "terminal erase display" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Write some characters
    terminal.process_char('H', &cells);
    terminal.process_char('e', &cells);
    terminal.process_char('l', &cells);
    terminal.process_char('l', &cells);
    terminal.process_char('o', &cells);

    // Erase display
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('J', &cells);

    // Check first cell is cleared
    const cell = terminal.get_cell(0, 0, &cells);
    try testing.expect(cell != null);
    try testing.expect(cell.?.ch == ' ');
}

test "renderer ansi colors" {
    try testing.expect(Renderer.ANSI_COLORS.len == 16);
    try testing.expect(Renderer.ANSI_COLORS[0] == 0x000000FF); // Black
    try testing.expect(Renderer.ANSI_COLORS[7] == 0xC0C0C0FF); // White
}

test "renderer char pattern" {
    const space_pattern = Renderer.get_char_pattern(' ');
    try testing.expect(space_pattern == 0x0000000000000000);

    const a_pattern = Renderer.get_char_pattern('A');
    try testing.expect(a_pattern != 0);
}

test "terminal scrollback navigation" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    try testing.expect(terminal.get_scrollback_offset() == 0);
    try testing.expect(terminal.get_scrollback_lines() == 0);

    // Scroll up (should stay at 0 when no scrollback)
    terminal.scrollback_up();
    try testing.expect(terminal.get_scrollback_offset() == 0);

    // Scroll down (should stay at 0)
    terminal.scrollback_down();
    try testing.expect(terminal.get_scrollback_offset() == 0);

    // Jump to top/bottom
    terminal.scrollback_to_top();
    try testing.expect(terminal.get_scrollback_offset() == 0);
    terminal.scrollback_to_bottom();
    try testing.expect(terminal.get_scrollback_offset() == 0);

    // Create some scrollback
    terminal.cursor_y = terminal.height - 1;
    terminal.process_char('A', &cells);
    terminal.process_char('\n', &cells);

    // Now we have scrollback
    try testing.expect(terminal.get_scrollback_lines() > 0);
    try testing.expect(terminal.get_scrollback_offset() == 0);

    // Scroll up
    terminal.scrollback_up();
    try testing.expect(terminal.get_scrollback_offset() == 1);

    // Scroll down
    terminal.scrollback_down();
    try testing.expect(terminal.get_scrollback_offset() == 0);

    // Jump to top
    terminal.scrollback_to_top();
    try testing.expect(terminal.get_scrollback_offset() == terminal.get_scrollback_lines());

    // Jump to bottom
    terminal.scrollback_to_bottom();
    try testing.expect(terminal.get_scrollback_offset() == 0);
}

test "terminal csi cursor position f" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to position 5, 10 using 'f' (same as 'H')
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('6', &cells);
    terminal.process_char('f', &cells);

    try testing.expect(terminal.cursor_y == 10);
    try testing.expect(terminal.cursor_x == 5);
}

test "terminal csi save restore cursor" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Save cursor using CSI 's'
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('s', &cells);
    try testing.expect(terminal.saved_cursor_x == 10);
    try testing.expect(terminal.saved_cursor_y == 5);

    // Move cursor
    terminal.cursor_x = 20;
    terminal.cursor_y = 10;

    // Restore cursor using CSI 'u'
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('u', &cells);
    try testing.expect(terminal.cursor_x == 10);
    try testing.expect(terminal.cursor_y == 5);
}

test "terminal bell character" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Process BEL character (should not crash)
    terminal.process_char(0x07, &cells);
    // Bell is handled (no visible effect in test, but should not crash)
}

test "terminal osc window title" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Set window title via OSC 0 (window title and icon name)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char(']', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('T', &cells);
    terminal.process_char('e', &cells);
    terminal.process_char('s', &cells);
    terminal.process_char('t', &cells);
    terminal.process_char(' ', &cells);
    terminal.process_char('T', &cells);
    terminal.process_char('i', &cells);
    terminal.process_char('t', &cells);
    terminal.process_char('l', &cells);
    terminal.process_char('e', &cells);
    terminal.process_char(0x07, &cells); // BEL

    // Check window title was set
    const title = terminal.get_window_title();
    try testing.expect(title.len > 0);
    try testing.expect(std.mem.eql(u8, title, "Test Title"));
}

test "terminal 256 color foreground" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Set 256-color foreground: ESC[38;5;100m
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('3', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('m', &cells);

    // Check foreground color was set to 100
    try testing.expect(terminal.current_attrs.fg_color == 100);
}

test "terminal 256 color background" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Set 256-color background: ESC[48;5;200m
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('4', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('m', &cells);

    // Check background color was set to 200
    try testing.expect(terminal.current_attrs.bg_color == 200);
}

test "terminal csi cursor next line" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to column 10
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Cursor Next Line: ESC[E (move to beginning of next line)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('E', &cells);

    try testing.expect(terminal.cursor_y == 6);
    try testing.expect(terminal.cursor_x == 0);
}

test "terminal csi cursor previous line" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to column 10
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Cursor Previous Line: ESC[F (move to beginning of previous line)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('F', &cells);

    try testing.expect(terminal.cursor_y == 4);
    try testing.expect(terminal.cursor_x == 0);
}

test "terminal csi cursor horizontal absolute" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to column 10
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Cursor Horizontal Absolute: ESC[20G (move to column 20)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('G', &cells);

    try testing.expect(terminal.cursor_x == 19);
    try testing.expect(terminal.cursor_y == 5);
}

test "terminal csi cursor vertical absolute" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;

    // Move cursor to row 5
    terminal.cursor_x = 10;
    terminal.cursor_y = 5;

    // Cursor Vertical Absolute: ESC[10d (move to row 10)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('0', &cells);
    terminal.process_char('d', &cells);

    try testing.expect(terminal.cursor_y == 9);
    try testing.expect(terminal.cursor_x == 10);
}

test "terminal csi insert character" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Write some text
    terminal.process_char('A', &cells);
    terminal.process_char('B', &cells);
    terminal.process_char('C', &cells);
    terminal.cursor_x = 1; // Move cursor to position 1

    // Insert 2 characters: ESC[2@
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('@', &cells);

    // Check that characters were inserted (B and C should be shifted right)
    const cell1 = terminal.get_cell(1, 0, &cells).?;
    try testing.expect(cell1.ch == ' ');
    const cell2 = terminal.get_cell(2, 0, &cells).?;
    try testing.expect(cell2.ch == ' ');
    const cell3 = terminal.get_cell(3, 0, &cells).?;
    try testing.expect(cell3.ch == 'B');
}

test "terminal csi delete character" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Write some text
    terminal.process_char('A', &cells);
    terminal.process_char('B', &cells);
    terminal.process_char('C', &cells);
    terminal.cursor_x = 1; // Move cursor to position 1

    // Delete 1 character: ESC[1P
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('P', &cells);

    // Check that character was deleted (C should move to position 1)
    const cell1 = terminal.get_cell(1, 0, &cells).?;
    try testing.expect(cell1.ch == 'C');
}

test "terminal csi insert line" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Write text on line 0 and line 1
    terminal.process_char('A', &cells);
    terminal.cursor_x = 0;
    terminal.cursor_y = 1;
    terminal.process_char('B', &cells);
    terminal.cursor_y = 0; // Move cursor back to line 0

    // Insert 1 line: ESC[1L
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('L', &cells);

    // Check that line was inserted (B should move to line 2)
    const cell_line0 = terminal.get_cell(0, 0, &cells).?;
    try testing.expect(cell_line0.ch == ' ');
    const cell_line2 = terminal.get_cell(0, 2, &cells).?;
    try testing.expect(cell_line2.ch == 'B');
}

test "terminal csi delete line" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Write text on line 0 and line 1
    terminal.process_char('A', &cells);
    terminal.cursor_x = 0;
    terminal.cursor_y = 1;
    terminal.process_char('B', &cells);
    terminal.cursor_y = 0; // Move cursor back to line 0

    // Delete 1 line: ESC[1M
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('M', &cells);

    // Check that line was deleted (B should move to line 0)
    const cell_line0 = terminal.get_cell(0, 0, &cells).?;
    try testing.expect(cell_line0.ch == 'B');
}

test "terminal true color foreground" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Set true color foreground: ESC[38;2;255;128;64m (orange)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('3', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('6', &cells);
    terminal.process_char('4', &cells);
    terminal.process_char('m', &cells);

    // Check foreground RGB was set
    try testing.expect(terminal.current_attrs.fg_rgb != null);
    if (terminal.current_attrs.fg_rgb) |rgb| {
        try testing.expect(rgb[0] == 255);
        try testing.expect(rgb[1] == 128);
        try testing.expect(rgb[2] == 64);
    }
}

test "terminal true color background" {
    var terminal = Terminal.init(80, 24);
    var cells: [80 * 24]Terminal.Cell = undefined;
    terminal.clear(&cells);

    // Set true color background: ESC[48;2;64;128;255m (blue)
    terminal.process_char(0x1B, &cells); // ESC
    terminal.process_char('[', &cells);
    terminal.process_char('4', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('6', &cells);
    terminal.process_char('4', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('1', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('8', &cells);
    terminal.process_char(';', &cells);
    terminal.process_char('2', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char('5', &cells);
    terminal.process_char('m', &cells);

    // Check background RGB was set
    try testing.expect(terminal.current_attrs.bg_rgb != null);
    if (terminal.current_attrs.bg_rgb) |rgb| {
        try testing.expect(rgb[0] == 64);
        try testing.expect(rgb[1] == 128);
        try testing.expect(rgb[2] == 255);
    }
}

