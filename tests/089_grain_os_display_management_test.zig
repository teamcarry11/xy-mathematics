//! Tests for Grain OS display management system.
//!
//! Why: Verify multi-monitor support and display configuration.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const DisplayManager = grain_os.display_management.DisplayManager;
const DisplayConnection = grain_os.display_management.DisplayConnection;
const DisplayState = grain_os.display_management.DisplayState;

test "display manager initialization" {
    const manager = DisplayManager.init();
    std.debug.assert(manager.displays_len == 0);
    std.debug.assert(manager.next_display_id == 1);
    std.debug.assert(manager.primary_display_id == 0);
}

test "add display" {
    var manager = DisplayManager.init();
    const display_id_opt = manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi);
    std.debug.assert(display_id_opt != null);
    if (display_id_opt) |display_id| {
        std.debug.assert(display_id == 1);
        std.debug.assert(manager.get_display_count() == 1);
        std.debug.assert(manager.primary_display_id == display_id);
    }
}

test "find display by ID" {
    var manager = DisplayManager.init();
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        const display_opt = manager.find_display(display_id);
        std.debug.assert(display_opt != null);
        if (display_opt) |display| {
            std.debug.assert(display.display_id == display_id);
            std.debug.assert(display.width == 1920);
            std.debug.assert(display.height == 1080);
        }
    }
}

test "remove display" {
    var manager = DisplayManager.init();
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        const result = manager.remove_display(display_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_display_count() == 0);
    }
}

test "set display position" {
    var manager = DisplayManager.init();
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        const result = manager.set_display_position(display_id, 1920, 0);
        std.debug.assert(result);
        if (manager.find_display(display_id)) |display| {
            std.debug.assert(display.x == 1920);
            std.debug.assert(display.y == 0);
        }
    }
}

test "set primary display" {
    var manager = DisplayManager.init();
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id_1| {
        if (manager.add_display("Display 2", 2560, 1440, DisplayConnection.displayport)) |display_id_2| {
            _ = display_id_1;
            const result = manager.set_primary_display(display_id_2);
            std.debug.assert(result);
            std.debug.assert(manager.primary_display_id == display_id_2);
            if (manager.find_display(display_id_2)) |display| {
                std.debug.assert(display.primary);
            }
        }
    }
}

test "enable and disable display" {
    var manager = DisplayManager.init();
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        std.debug.assert(manager.get_active_display_count() == 1);
        _ = manager.disable_display(display_id);
        std.debug.assert(manager.get_active_display_count() == 0);
        _ = manager.enable_display(display_id);
        std.debug.assert(manager.get_active_display_count() == 1);
    }
}

test "get primary display" {
    var manager = DisplayManager.init();
    std.debug.assert(manager.get_primary_display() == null);
    if (manager.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        const primary_opt = manager.get_primary_display();
        std.debug.assert(primary_opt != null);
        if (primary_opt) |primary| {
            std.debug.assert(primary.display_id == display_id);
        }
    }
}

test "compositor add display" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const display_id_opt = comp.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi);
    std.debug.assert(display_id_opt != null);
}

test "compositor remove display" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id| {
        const result = comp.remove_display(display_id);
        std.debug.assert(result);
    }
}

test "compositor set primary display" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi)) |display_id_1| {
        if (comp.add_display("Display 2", 2560, 1440, DisplayConnection.displayport)) |display_id_2| {
            _ = display_id_1;
            const result = comp.set_primary_display(display_id_2);
            std.debug.assert(result);
        }
    }
}

test "compositor get display count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_display_count() == 0);
    _ = comp.add_display("Display 1", 1920, 1080, DisplayConnection.hdmi);
    std.debug.assert(comp.get_display_count() == 1);
}

test "display connection types" {
    std.debug.assert(@intFromEnum(DisplayConnection.unknown) == 0);
    std.debug.assert(@intFromEnum(DisplayConnection.hdmi) == 2);
    std.debug.assert(@intFromEnum(DisplayConnection.displayport) == 3);
}

test "display state types" {
    std.debug.assert(@intFromEnum(DisplayState.disconnected) == 0);
    std.debug.assert(@intFromEnum(DisplayState.connected) == 1);
    std.debug.assert(@intFromEnum(DisplayState.active) == 2);
}

test "display constants" {
    std.debug.assert(grain_os.display_management.MAX_DISPLAYS == 8);
    std.debug.assert(grain_os.display_management.MAX_DISPLAY_NAME_LEN == 64);
}

