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

