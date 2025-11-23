const std = @import("std");
const testing = std.testing;
const grain_terminal = @import("grain_terminal");
const Session = grain_terminal.Session;
const GrainscriptIntegration = grain_terminal.GrainscriptIntegration;
const Plugin = grain_terminal.Plugin;
const Config = grain_terminal.Config;

test "session create" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var session_mgr = try Session.init(allocator);
    defer session_mgr.deinit();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    const session_id = try session_mgr.create_session("test-session", &config);
    try testing.expect(session_id > 0);

    const session = session_mgr.get_session(session_id);
    try testing.expect(session != null);
    try testing.expect(std.mem.eql(u8, session.?.name, "test-session"));
    try testing.expect(session.?.state == .active);
}

test "session save restore" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var session_mgr = try Session.init(allocator);
    defer session_mgr.deinit();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    const session_id = try session_mgr.create_session("test-session", &config);
    try session_mgr.save_session(session_id);

    const session = session_mgr.get_session(session_id);
    try testing.expect(session != null);
    try testing.expect(session.?.state == .saved);

    try session_mgr.restore_session(session_id);
    try testing.expect(session.?.state == .restored);
}

test "session tab management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var session_mgr = try Session.init(allocator);
    defer session_mgr.deinit();

    var config = try Config.init(allocator);
    defer config.deinit(allocator);

    const session_id = try session_mgr.create_session("test-session", &config);
    try session_mgr.add_tab(session_id, 1);
    try session_mgr.add_tab(session_id, 2);
    try session_mgr.set_active_tab(session_id, 1);

    const session = session_mgr.get_session(session_id);
    try testing.expect(session != null);
    try testing.expect(session.?.tab_ids_len == 2);
    try testing.expect(session.?.active_tab_id == 1);
}

test "grainscript execute command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = "echo \"Hello, World!\"";
    var capture = try GrainscriptIntegration.execute_command(allocator, source);
    defer capture.deinit();

    try testing.expect(capture.exit_code == 0);
}

test "grainscript output capture" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var capture = try GrainscriptIntegration.OutputCapture.init(allocator);
    defer capture.deinit();

    try capture.append_stdout("Hello");
    try capture.append_stdout(" World");
    try testing.expect(capture.stdout_len == 11);
}

test "repl state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var repl = try GrainscriptIntegration.ReplState.init(allocator);
    defer repl.deinit();

    try repl.add_command("echo hello");
    try repl.add_command("cd /tmp");

    const prev = repl.get_previous();
    try testing.expect(prev != null);
    try testing.expect(std.mem.eql(u8, prev.?, "cd /tmp"));
}

test "plugin load" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var plugin_mgr = try Plugin.init(allocator);
    defer plugin_mgr.deinit();

    const plugin_id = try plugin_mgr.load_plugin("test-plugin", "/path/to/plugin", 0x00010000); // v1.0.0
    try testing.expect(plugin_id > 0);

    const plugin = plugin_mgr.get_plugin(plugin_id);
    try testing.expect(plugin != null);
    try testing.expect(std.mem.eql(u8, plugin.?.name, "test-plugin"));
    try testing.expect(plugin.?.state == .loaded);
}

test "plugin unload" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var plugin_mgr = try Plugin.init(allocator);
    defer plugin_mgr.deinit();

    const plugin_id = try plugin_mgr.load_plugin("test-plugin", "/path/to/plugin", 0x00010000);
    try plugin_mgr.unload_plugin(plugin_id);

    const plugin = plugin_mgr.get_plugin(plugin_id);
    try testing.expect(plugin != null);
    try testing.expect(plugin.?.state == .unloaded);
}

