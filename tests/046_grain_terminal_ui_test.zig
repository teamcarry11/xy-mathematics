const std = @import("std");
const testing = std.testing;
const grain_terminal = @import("grain_terminal");
const Config = grain_terminal.Config;
const Tab = grain_terminal.Tab;
const Pane = grain_terminal.Pane;

test "config init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    try testing.expect(config.get_theme() == .dark);
    try testing.expect(config.get_font_size() == .medium);
    try testing.expect(config.get_font_size_points() == 12);
}

test "config set get" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    try config.set(allocator, "key1", "value1");
    try config.set(allocator, "key2", "value2");

    const value1 = config.get("key1");
    try testing.expect(value1 != null);
    try testing.expect(std.mem.eql(u8, value1.?, "value1"));

    const value2 = config.get("key2");
    try testing.expect(value2 != null);
    try testing.expect(std.mem.eql(u8, value2.?, "value2"));
}

test "config theme" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    config.set_theme(.light);
    try testing.expect(config.get_theme() == .light);

    config.set_theme(.solarized_dark);
    try testing.expect(config.get_theme() == .solarized_dark);
}

test "config font size" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    config.set_font_size(.small);
    try testing.expect(config.get_font_size() == .small);
    try testing.expect(config.get_font_size_points() == 8);

    config.set_font_size(.large);
    try testing.expect(config.get_font_size() == .large);
    try testing.expect(config.get_font_size_points() == 16);
}

test "tab init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tab = try Tab.init(allocator, 1, 80, 24, "Test Tab");
    defer tab.deinit();

    try testing.expect(tab.id == 1);
    try testing.expect(std.mem.eql(u8, tab.title, "Test Tab"));
    try testing.expect(tab.get_state() == .inactive);
}

test "tab process char" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tab = try Tab.init(allocator, 1, 80, 24, "Test Tab");
    defer tab.deinit();

    tab.process_char('H');
    tab.process_char('i');

    const cells = tab.get_cells();
    const cell = tab.get_terminal().get_cell(0, 0, cells);
    try testing.expect(cell != null);
    try testing.expect(cell.?.ch == 'H');
}

test "tab set title" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tab = try Tab.init(allocator, 1, 80, 24, "Old Title");
    defer tab.deinit();

    try tab.set_title("New Title");
    try testing.expect(std.mem.eql(u8, tab.title, "New Title"));
}

test "pane init leaf" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pane = try Pane.init_leaf(allocator, 1, 0, 0, 800, 600);
    defer pane.deinit();

    try testing.expect(pane.id == 1);
    try testing.expect(pane.x == 0);
    try testing.expect(pane.y == 0);
    try testing.expect(pane.width == 800);
    try testing.expect(pane.height == 600);
    try testing.expect(pane.is_leaf() == true);
}

test "pane split horizontal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tab = try Tab.init(allocator, 1, 80, 24, "Test Tab");
    defer tab.deinit();

    var pane = try Pane.init_leaf(allocator, 1, 0, 0, 800, 600);
    pane.set_tab(&tab);
    defer pane.deinit();

    var pane_mut = pane;
    const split_pane = try pane_mut.split(allocator, .horizontal, 400);
    defer split_pane.deinit();

    try testing.expect(split_pane.is_leaf() == false);
    try testing.expect(split_pane.children_len == 2);
    try testing.expect(split_pane.children[0].width == 400);
    try testing.expect(split_pane.children[1].width == 400);
}

test "pane split vertical" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tab = try Tab.init(allocator, 1, 80, 24, "Test Tab");
    defer tab.deinit();

    var pane = try Pane.init_leaf(allocator, 1, 0, 0, 800, 600);
    pane.set_tab(&tab);
    defer pane.deinit();

    var pane_mut = pane;
    const split_pane = try pane_mut.split(allocator, .vertical, 300);
    defer split_pane.deinit();

    try testing.expect(split_pane.is_leaf() == false);
    try testing.expect(split_pane.children_len == 2);
    try testing.expect(split_pane.children[0].height == 300);
    try testing.expect(split_pane.children[1].height == 300);
}

test "pane get pane at" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pane = try Pane.init_leaf(allocator, 1, 0, 0, 800, 600);
    defer pane.deinit();

    const found_pane = pane.get_pane_at(100, 100);
    try testing.expect(found_pane != null);
    try testing.expect(found_pane.?.id == 1);

    const not_found = pane.get_pane_at(1000, 1000);
    try testing.expect(not_found == null);
}

