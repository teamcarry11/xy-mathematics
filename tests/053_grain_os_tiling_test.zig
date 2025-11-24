const std = @import("std");
const testing = std.testing;
const grain_os = @import("grain_os");
const TilingEngine = grain_os.tiling.TilingEngine;
const ContainerType = grain_os.tiling.ContainerType;

test "tiling engine init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    try testing.expect(engine.views_len == 0);
    try testing.expect(engine.containers_len == 0);
    try testing.expect(engine.next_view_id == 1);
    try testing.expect(engine.next_container_id == 1);
}

test "tiling engine create view" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const view_id = try engine.create_view(1);
    try testing.expect(view_id > 0);
    try testing.expect(engine.views_len == 1);

    const view = engine.get_view(view_id);
    try testing.expect(view != null);
    try testing.expect(view.?.id == view_id);
    try testing.expect(view.?.surface_id == 1);
}

test "tiling engine view tags" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const view_id = try engine.create_view(1);
    const view = engine.get_view(view_id).?;

    // Add tag 0
    view.add_tag(0);
    try testing.expect(view.has_tag(0) == true);
    try testing.expect(view.has_tag(1) == false);

    // Add tag 1
    view.add_tag(1);
    try testing.expect(view.has_tag(0) == true);
    try testing.expect(view.has_tag(1) == true);

    // Remove tag 0
    view.remove_tag(0);
    try testing.expect(view.has_tag(0) == false);
    try testing.expect(view.has_tag(1) == true);
}

test "tiling engine create container" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);
    const container_id = try engine.create_container(.horizontal);
    try testing.expect(container_id > 0);
    try testing.expect(engine.containers_len == 1);

    const container = engine.get_container(container_id);
    try testing.expect(container != null);
    try testing.expect(container.?.id == container_id);
    try testing.expect(container.?.container_type == .horizontal);
}

test "tiling engine layout calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);

    // Create root container (horizontal split)
    const root_id = try engine.create_container(.horizontal);
    const root = engine.get_container(root_id).?;

    // Create two views
    const view1_id = try engine.create_view(1);
    const view2_id = try engine.create_view(2);

    // Add views to root container
    root.add_child(view1_id);
    root.add_child(view2_id);

    // Calculate layout (800x600 output)
    engine.calculate_layout(root_id, 0, 0, 800, 600);

    // Check view positions
    const view1 = engine.get_view(view1_id).?;
    const view2 = engine.get_view(view2_id).?;

    // Horizontal split: views should be side by side
    try testing.expect(view1.x == 0);
    try testing.expect(view1.y == 0);
    try testing.expect(view1.width == 400); // 800 / 2
    try testing.expect(view1.height == 600);

    try testing.expect(view2.x == 400);
    try testing.expect(view2.y == 0);
    try testing.expect(view2.width == 400); // 800 / 2
    try testing.expect(view2.height == 600);
}

test "tiling engine vertical layout" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);

    // Create root container (vertical split)
    const root_id = try engine.create_container(.vertical);
    const root = engine.get_container(root_id).?;

    // Create two views
    const view1_id = try engine.create_view(1);
    const view2_id = try engine.create_view(2);

    // Add views to root container
    root.add_child(view1_id);
    root.add_child(view2_id);

    // Calculate layout (800x600 output)
    engine.calculate_layout(root_id, 0, 0, 800, 600);

    // Check view positions
    const view1 = engine.get_view(view1_id).?;
    const view2 = engine.get_view(view2_id).?;

    // Vertical split: views should be stacked
    try testing.expect(view1.x == 0);
    try testing.expect(view1.y == 0);
    try testing.expect(view1.width == 800);
    try testing.expect(view1.height == 300); // 600 / 2

    try testing.expect(view2.x == 0);
    try testing.expect(view2.y == 300);
    try testing.expect(view2.width == 800);
    try testing.expect(view2.height == 300); // 600 / 2
}

test "tiling engine nested containers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var engine = TilingEngine.init(allocator);

    // Create root container (horizontal)
    const root_id = try engine.create_container(.horizontal);
    const root = engine.get_container(root_id).?;

    // Create nested container (vertical)
    const nested_id = try engine.create_container(.vertical);
    const nested = engine.get_container(nested_id).?;

    // Create views
    const view1_id = try engine.create_view(1);
    const view2_id = try engine.create_view(2);
    const view3_id = try engine.create_view(3);

    // Add view1 and nested container to root
    root.add_child(view1_id);
    root.is_view = false; // Next child is a container
    root.add_child(nested_id);

    // Add view2 and view3 to nested container
    nested.add_child(view2_id);
    nested.add_child(view3_id);

    // Calculate layout (800x600 output)
    engine.calculate_layout(root_id, 0, 0, 800, 600);

    // Check view positions
    const view1 = engine.get_view(view1_id).?;
    const view2 = engine.get_view(view2_id).?;
    const view3 = engine.get_view(view3_id).?;

    // Root horizontal split: view1 on left, nested on right
    try testing.expect(view1.x == 0);
    try testing.expect(view1.y == 0);
    try testing.expect(view1.width == 400); // 800 / 2
    try testing.expect(view1.height == 600);

    // Nested vertical split: view2 on top, view3 on bottom
    try testing.expect(view2.x == 400);
    try testing.expect(view2.y == 0);
    try testing.expect(view2.width == 400); // 800 / 2
    try testing.expect(view2.height == 300); // 600 / 2

    try testing.expect(view3.x == 400);
    try testing.expect(view3.y == 300);
    try testing.expect(view3.width == 400); // 800 / 2
    try testing.expect(view3.height == 300); // 600 / 2
}

