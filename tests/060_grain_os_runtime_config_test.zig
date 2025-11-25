//! Tests for Grain OS runtime configuration system.
//!
//! Why: Verify runtime configuration commands work correctly.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ConfigParser = grain_os.runtime_config.ConfigParser;
const ConfigCommand = grain_os.runtime_config.ConfigCommand;
const RuntimeConfig = grain_os.runtime_config.RuntimeConfig;

test "config parser parse command" {
    const cmd1 = ConfigParser.parse_command("set-layout");
    std.debug.assert(cmd1 == ConfigCommand.set_layout);

    const cmd2 = ConfigParser.parse_command("get-layout");
    std.debug.assert(cmd2 == ConfigCommand.get_layout);

    const cmd3 = ConfigParser.parse_command("unknown-command");
    std.debug.assert(cmd3 == ConfigCommand.unknown);
}

test "config parser parse layout type" {
    const layout1 = ConfigParser.parse_layout_type("tall");
    std.debug.assert(layout1 != null);
    std.debug.assert(layout1.? == grain_os.layout_generator.LayoutType.tall);

    const layout2 = ConfigParser.parse_layout_type("wide");
    std.debug.assert(layout2 != null);
    std.debug.assert(layout2.? == grain_os.layout_generator.LayoutType.wide);

    const layout3 = ConfigParser.parse_layout_type("invalid");
    std.debug.assert(layout3 == null);
}

test "runtime config initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    const channel_id: u32 = 1;
    compositor.init_runtime_config(channel_id);
    std.debug.assert(compositor.config_manager != null);
}

test "runtime config process set layout command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.init_runtime_config(1);
    const result = compositor.process_config_command("set-layout tall");
    std.debug.assert(result);
}

test "runtime config process get layout command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.init_runtime_config(1);
    const result = compositor.process_config_command("get-layout");
    std.debug.assert(result);
}

test "runtime config process invalid command" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var compositor = Compositor.init(allocator);
    compositor.init_runtime_config(1);
    const result = compositor.process_config_command("invalid-command");
    std.debug.assert(!result);
}

