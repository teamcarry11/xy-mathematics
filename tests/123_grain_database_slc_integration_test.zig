//! Tests for Grain Database SLC Product Integration Helpers
//! 2025-12-20-161207-pst: Grain Silo Agent

const std = @import("std");
const testing = std.testing;
const grain_database = @import("grain_database");
const StorageEngine = grain_database.StorageEngine;
const Graph = grain_database.Graph;
const NostrProfileStorage = grain_database.NostrProfileStorage;
const DagWebsiteStorage = grain_database.DagWebsiteStorage;
const WorkspaceFileStorage = grain_database.WorkspaceFileStorage;

test "nostr_profile_storage_init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var g = try Graph.init(allocator);
    defer g.deinit();
    var profile_storage = NostrProfileStorage.init(&storage, &g);
    std.debug.assert(profile_storage.storage_engine != null);
    std.debug.assert(profile_storage.graph != null);
}

test "nostr_profile_storage_store_and_retrieve" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var g = try Graph.init(allocator);
    defer g.deinit();
    var profile_storage = NostrProfileStorage.init(&storage, &g);
    const npub = "npub1test123";
    const profile_data = "{\"name\":\"Test User\",\"bio\":\"Test bio\"}";
    const record_id = try profile_storage.store_profile(npub, profile_data);
    std.debug.assert(record_id > 0);
    const retrieved = profile_storage.get_profile(npub);
    std.debug.assert(retrieved != null);
    std.debug.assert(retrieved.?.record_id == record_id);
}

test "dag_website_storage_init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var g = try Graph.init(allocator);
    defer g.deinit();
    var website_storage = DagWebsiteStorage.init(&storage, &g);
    std.debug.assert(website_storage.storage_engine != null);
    std.debug.assert(website_storage.graph != null);
}

test "dag_website_storage_store_node" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var g = try Graph.init(allocator);
    defer g.deinit();
    var website_storage = DagWebsiteStorage.init(&storage, &g);
    const node_id = "node1";
    const content = "<h1>Hello World</h1>";
    const record_id = try website_storage.store_node(node_id, content);
    std.debug.assert(record_id > 0);
    const retrieved = website_storage.get_node(node_id);
    std.debug.assert(retrieved != null);
    std.debug.assert(retrieved.?.record_id == record_id);
}

test "dag_website_storage_store_edge" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var g = try Graph.init(allocator);
    defer g.deinit();
    var website_storage = DagWebsiteStorage.init(&storage, &g);
    const node1_id = "node1";
    const node2_id = "node2";
    const content1 = "<h1>Page 1</h1>";
    const content2 = "<h1>Page 2</h1>";
    _ = try website_storage.store_node(node1_id, content1);
    _ = try website_storage.store_node(node2_id, content2);
    const graph_node1_id = try g.add_node("dag_website", content1);
    const graph_node2_id = try g.add_node("dag_website", content2);
    const edge_id = try website_storage.store_edge(graph_node1_id, graph_node2_id, "link");
    std.debug.assert(edge_id > 0);
}

test "workspace_file_storage_init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var file_storage = WorkspaceFileStorage.init(&storage);
    std.debug.assert(file_storage.storage_engine != null);
}

test "workspace_file_storage_store_and_retrieve" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deallocate();
    const allocator = gpa.allocator();
    var storage = try StorageEngine.init(allocator, 1024);
    defer storage.deinit();
    var file_storage = WorkspaceFileStorage.init(&storage);
    const file_path = "/home/user/document.txt";
    const metadata = "{\"size\":1024,\"modified\":1234567890}";
    const record_id = try file_storage.store_file_metadata(file_path, metadata);
    std.debug.assert(record_id > 0);
    const retrieved = file_storage.get_file_metadata(file_path);
    std.debug.assert(retrieved != null);
    std.debug.assert(retrieved.?.record_id == record_id);
}
