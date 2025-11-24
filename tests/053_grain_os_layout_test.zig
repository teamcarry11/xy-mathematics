//! Tests for Grain OS layout generators.
//!
//! Why: Verify layout calculation for different layout types.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const TilingEngine = grain_os.tiling.TilingEngine;
const ContainerType = grain_os.tiling.ContainerType;
const LayoutRegistry = grain_os.layout.LayoutRegistry;
const LayoutType = grain_os.layout.LayoutType;

test "layout registry initialization" {
    var registry = LayoutRegistry.init();
    std.debug.assert(registry.generators_len == 4);
    std.debug.assert(registry.get_layout(.tall) != null);
    std.debug.assert(registry.get_layout(.wide) != null);
    std.debug.assert(registry.get_layout(.grid) != null);
    std.debug.assert(registry.get_layout(.monocle) != null);
}

test "tall layout calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const container_id = try engine.create_container(.vertical);
    const view1_id = try engine.create_view(1);
    const view2_id = try engine.create_view(2);
    const container = engine.get_container(container_id).?;
    container.add_child(view1_id);
    container.add_child(view2_id);
    container.is_view = true;

    const layout_fn = LayoutRegistry.init().get_layout(.tall).?;
    layout_fn(&engine, container_id, 0, 0, 1024, 768);

    const view1 = engine.get_view(view1_id).?;
    const view2 = engine.get_view(view2_id).?;
    std.debug.assert(view1.width == 682); // 1024 * 2 / 3
    std.debug.assert(view1.height == 768);
    std.debug.assert(view2.width == 342); // 1024 - 682
    std.debug.assert(view2.height == 384); // 768 / 2
}

test "grid layout calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const container_id = try engine.create_container(.horizontal);
    var i: u32 = 0;
    while (i < 4) : (i += 1) {
        const view_id = try engine.create_view(i + 1);
        const container = engine.get_container(container_id).?;
        container.add_child(view_id);
    }
    const container = engine.get_container(container_id).?;
    container.is_view = true;

    const layout_fn = LayoutRegistry.init().get_layout(.grid).?;
    layout_fn(&engine, container_id, 0, 0, 1024, 768);

    const view1 = engine.get_view(1).?;
    std.debug.assert(view1.width == 512); // 1024 / 2
    std.debug.assert(view1.height == 384); // 768 / 2
}

test "monocle layout calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const container_id = try engine.create_container(.horizontal);
    const view1_id = try engine.create_view(1);
    const view2_id = try engine.create_view(2);
    const container = engine.get_container(container_id).?;
    container.add_child(view1_id);
    container.add_child(view2_id);
    container.is_view = true;

    const view1 = engine.get_view(view1_id).?;
    view1.focused = true;

    const layout_fn = LayoutRegistry.init().get_layout(.monocle).?;
    layout_fn(&engine, container_id, 0, 0, 1024, 768);

    std.debug.assert(view1.visible == true);
    std.debug.assert(view1.width == 1024);
    std.debug.assert(view1.height == 768);
    const view2 = engine.get_view(view2_id).?;
    std.debug.assert(view2.visible == false);
}

