const std = @import("std");
const testing = std.testing;
const SlcDagIntegration = @import("grain_skate").SlcDagIntegration;

test "slc dag integration initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    // Assert: Integration initialized
    try testing.expect(integration.dag.nodes_len == 0);
    try testing.expect(integration.dag.edges_len == 0);
}

test "slc dag integration profile node creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const npub = "npub1example";
    const name = "Test Profile";

    const profile_id = try integration.create_profile_node(npub, name);

    // Assert: Profile node created
    try testing.expect(profile_id >= 0);
    try testing.expect(integration.dag.nodes_len == 1);
}

test "slc dag integration profile relationship" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");

    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);

    // Assert: Relationship created
    try testing.expect(integration.dag.edges_len == 1);
    try testing.expect(integration.dag.edges[0].from_node == profile1_id);
    try testing.expect(integration.dag.edges[0].to_node == profile2_id);
}

test "slc dag integration website page creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const title = "About Page";
    const content = "This is the about page content.";
    const url_path = "/about";

    const page_id = try integration.create_website_page_node(title, content, url_path);

    // Assert: Page node created
    try testing.expect(page_id >= 0);
    try testing.expect(integration.dag.nodes_len == 1);
}

test "slc dag integration website link" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");

    try integration.create_website_link(page1_id, page2_id);

    // Assert: Link created
    try testing.expect(integration.dag.edges_len == 1);
    try testing.expect(integration.dag.edges[0].from_node == page1_id);
    try testing.expect(integration.dag.edges[0].to_node == page2_id);
}

test "slc dag integration get following profiles" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");
    const profile3_id = try integration.create_profile_node("npub3", "Profile 3");

    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);
    try integration.create_profile_relationship(profile1_id, profile3_id, .follows);

    var following: [10]u32 = undefined;
    const count = integration.get_following_profiles(profile1_id, &following);

    // Assert: Following profiles retrieved
    try testing.expect(count == 2);
    try testing.expect((following[0] == profile2_id and following[1] == profile3_id) or
                       (following[0] == profile3_id and following[1] == profile2_id));
}

test "slc dag integration get linked pages" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");
    const page3_id = try integration.create_website_page_node("Contact", "Content", "/contact");

    try integration.create_website_link(page1_id, page2_id);
    try integration.create_website_link(page1_id, page3_id);

    var linked: [10]u32 = undefined;
    const count = integration.get_linked_pages(page1_id, &linked);

    // Assert: Linked pages retrieved
    try testing.expect(count == 2);
    try testing.expect((linked[0] == page2_id and linked[1] == page3_id) or
                       (linked[0] == page3_id and linked[1] == page2_id));
}
