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

test "slc dag integration get follower profiles" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");
    const profile3_id = try integration.create_profile_node("npub3", "Profile 3");

    // Profile 2 and 3 follow Profile 1
    try integration.create_profile_relationship(profile2_id, profile1_id, .follows);
    try integration.create_profile_relationship(profile3_id, profile1_id, .follows);

    var followers: [10]u32 = undefined;
    const count = integration.get_follower_profiles(profile1_id, &followers);

    // Assert: Follower profiles retrieved
    try testing.expect(count == 2);
    try testing.expect((followers[0] == profile2_id and followers[1] == profile3_id) or
                       (followers[0] == profile3_id and followers[1] == profile2_id));
}

test "slc dag integration get backlink pages" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");
    const page3_id = try integration.create_website_page_node("Contact", "Content", "/contact");

    // Page 2 and 3 link to Page 1
    try integration.create_website_link(page2_id, page1_id);
    try integration.create_website_link(page3_id, page1_id);

    var backlinks: [10]u32 = undefined;
    const count = integration.get_backlink_pages(page1_id, &backlinks);

    // Assert: Backlink pages retrieved
    try testing.expect(count == 2);
    try testing.expect((backlinks[0] == page2_id and backlinks[1] == page3_id) or
                       (backlinks[0] == page3_id and backlinks[1] == page2_id));
}

test "slc dag integration profile relationship count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");
    const profile3_id = try integration.create_profile_node("npub3", "Profile 3");

    // Profile 1 follows Profile 2 and 3
    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);
    try integration.create_profile_relationship(profile1_id, profile3_id, .follows);
    
    // Profile 2 follows Profile 1
    try integration.create_profile_relationship(profile2_id, profile1_id, .follows);

    const count = integration.get_profile_relationship_count(profile1_id);

    // Assert: Total relationship count (2 outgoing + 1 incoming = 3)
    try testing.expect(count == 3);
}

test "slc dag integration page link count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");
    const page3_id = try integration.create_website_page_node("Contact", "Content", "/contact");

    // Page 1 links to Page 2 and 3
    try integration.create_website_link(page1_id, page2_id);
    try integration.create_website_link(page1_id, page3_id);
    
    // Page 2 links back to Page 1
    try integration.create_website_link(page2_id, page1_id);

    const count = integration.get_page_link_count(page1_id);

    // Assert: Total link count (2 outgoing + 1 incoming = 3)
    try testing.expect(count == 3);
}

test "slc dag integration get profile data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const npub = "npub1example";
    const name = "Test Profile";
    const profile_id = try integration.create_profile_node(npub, name);

    const data = integration.get_profile_data(profile_id);

    // Assert: Profile data retrieved
    try testing.expect(data != null);
    try testing.expect(data.?.len > 0);
    
    // Data should contain npub and name
    const data_str = data.?;
    try testing.expect(std.mem.indexOf(u8, data_str, npub) != null);
    try testing.expect(std.mem.indexOf(u8, data_str, name) != null);
}

test "slc dag integration get page data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const title = "About Page";
    const content = "This is content";
    const url_path = "/about";
    const page_id = try integration.create_website_page_node(title, content, url_path);

    const data = integration.get_page_data(page_id);

    // Assert: Page data retrieved
    try testing.expect(data != null);
    try testing.expect(data.?.len > 0);
    
    // Data should contain title, content, and url_path
    const data_str = data.?;
    try testing.expect(std.mem.indexOf(u8, data_str, title) != null);
    try testing.expect(std.mem.indexOf(u8, data_str, url_path) != null);
}

test "slc dag integration has profile relationship" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const profile1_id = try integration.create_profile_node("npub1", "Profile 1");
    const profile2_id = try integration.create_profile_node("npub2", "Profile 2");

    // No relationship initially
    try testing.expect(!integration.has_profile_relationship(profile1_id, profile2_id));

    // Create relationship
    try integration.create_profile_relationship(profile1_id, profile2_id, .follows);

    // Relationship should exist
    try testing.expect(integration.has_profile_relationship(profile1_id, profile2_id));
    
    // Reverse relationship should not exist
    try testing.expect(!integration.has_profile_relationship(profile2_id, profile1_id));
}

test "slc dag integration has website link" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    const allocator = gpa.allocator();

    var integration = try SlcDagIntegration.init(allocator);
    defer integration.deinit();

    const page1_id = try integration.create_website_page_node("Home", "Content", "/");
    const page2_id = try integration.create_website_page_node("About", "Content", "/about");

    // No link initially
    try testing.expect(!integration.has_website_link(page1_id, page2_id));

    // Create link
    try integration.create_website_link(page1_id, page2_id);

    // Link should exist
    try testing.expect(integration.has_website_link(page1_id, page2_id));
    
    // Reverse link should not exist
    try testing.expect(!integration.has_website_link(page2_id, page1_id));
}
