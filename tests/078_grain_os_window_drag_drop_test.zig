//! Tests for Grain OS window drag and drop system.
//!
//! Why: Verify drag and drop functionality and drop zone management.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const DropZoneManager = grain_os.window_drag_drop.DropZoneManager;
const DropZoneType = grain_os.window_drag_drop.DropZoneType;

test "drop zone manager initialization" {
    const manager = DropZoneManager.init();
    std.debug.assert(manager.zones_len == 0);
    std.debug.assert(manager.next_zone_id == 1);
}

test "add drop zone" {
    var manager = DropZoneManager.init();
    const zone_id_opt = manager.add_drop_zone(
        DropZoneType.workspace,
        100,
        200,
        300,
        400,
        1,
    );
    std.debug.assert(zone_id_opt != null);
    if (zone_id_opt) |zone_id| {
        std.debug.assert(zone_id == 1);
        std.debug.assert(manager.zones_len == 1);
    }
}

test "find drop zone at point" {
    var manager = DropZoneManager.init();
    _ = manager.add_drop_zone(DropZoneType.workspace, 100, 200, 300, 400, 1);
    const zone_opt = manager.find_drop_zone_at(250, 400);
    std.debug.assert(zone_opt != null);
    if (zone_opt) |zone| {
        std.debug.assert(zone.zone_type == DropZoneType.workspace);
    }
}

test "remove drop zone" {
    var manager = DropZoneManager.init();
    if (manager.add_drop_zone(DropZoneType.workspace, 100, 200, 300, 400, 1)) |zone_id| {
        const result = manager.remove_drop_zone(zone_id);
        std.debug.assert(result);
        std.debug.assert(manager.zones_len == 0);
    }
}

test "can drag window" {
    std.debug.assert(grain_os.window_drag_drop.can_drag_window(1, false) == true);
    std.debug.assert(grain_os.window_drag_drop.can_drag_window(1, true) == false);
}

test "can drop window" {
    var manager = DropZoneManager.init();
    _ = manager.add_drop_zone(DropZoneType.workspace, 100, 200, 300, 400, 1);
    if (manager.find_drop_zone_at(250, 400)) |zone| {
        const result = grain_os.window_drag_drop.can_drop_window(1, zone);
        std.debug.assert(result);
    }
}

test "compositor add drop zone" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const zone_id_opt = comp.add_drop_zone(
        DropZoneType.workspace,
        100,
        200,
        300,
        400,
        1,
    );
    std.debug.assert(zone_id_opt != null);
}

test "compositor find drop zone" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_drop_zone(DropZoneType.workspace, 100, 200, 300, 400, 1);
    const zone_opt = comp.find_drop_zone_at(250, 400);
    std.debug.assert(zone_opt != null);
}

test "compositor drag and drop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);

    _ = comp.add_drop_zone(DropZoneType.workspace, 100, 200, 300, 400, 1);
    comp.start_drag(window_id, 150, 250);
    // Simulate drag to drop zone.
    comp.handle_mouse_move(250, 400);
    comp.end_drag();
    // Window should have been processed for drop.
}

test "drop zone constants" {
    std.debug.assert(grain_os.window_drag_drop.MAX_DROP_ZONES == 16);
}

