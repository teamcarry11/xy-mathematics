//! Tests for Grain Package Manager UI application.
//!
//! Why: Verify package browsing, installation, and dependency management.
//! Architecture: Comprehensive test coverage for all public APIs.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-173505-pst: Active implementation

const std = @import("std");
const testing = std.testing;
const PackageManagerUI = @import("../src/grain_workspace/package_manager_ui/app.zig").PackageManagerUI;
const PackageCategory = @import("../src/grain_workspace/package_manager_ui/app.zig").PackageCategory;
const grain_core = @import("grain_core");

test "package manager ui initialization" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);

    try testing.expect(ui.search_query_len == 0);
    try testing.expect(ui.selected_category == .all);
    try testing.expect(ui.selected_package_id == 0);
}

test "set search query" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    ui.set_search_query("test");

    try testing.expect(ui.search_query_len == 4);
    try testing.expect(std.mem.eql(u8, ui.search_query[0..4], "test"));
}

test "set category" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    ui.set_category(.development);

    try testing.expect(ui.selected_category == .development);
}

test "get all packages" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    _ = pkg_mgr.add_package("test-pkg", "1.0.0", "Test package", 1024);
    _ = pkg_mgr.add_package("dev-tool", "2.0.0", "Dev tool", 2048);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);

    var packages: [10]PackageManagerUI.PackageInfo = undefined;
    var packages_len: u32 = 0;
    ui.get_packages(&packages, &packages_len);

    try testing.expect(packages_len == 2);
    try testing.expect(packages[0].package_id > 0);
    try testing.expect(packages[1].package_id > 0);
}

test "get package info" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    const pkg_id = pkg_mgr.add_package("test-pkg", "1.0.0", "Test package", 1024);
    try testing.expect(pkg_id != null);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);

    var info: PackageManagerUI.PackageInfo = undefined;
    const found = ui.get_package_info(pkg_id.?, &info);

    try testing.expect(found == true);
    try testing.expect(info.package_id == pkg_id.?);
    try testing.expect(std.mem.eql(u8, info.name[0..info.name_len], "test-pkg"));
    try testing.expect(std.mem.eql(u8, info.version[0..info.version_len], "1.0.0"));
}

test "search packages" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    _ = pkg_mgr.add_package("test-pkg", "1.0.0", "Test package", 1024);
    _ = pkg_mgr.add_package("other-pkg", "2.0.0", "Other package", 2048);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    ui.set_search_query("test");

    var results: [10]u32 = undefined;
    var results_len: u32 = 0;
    ui.search_packages(&results, &results_len);

    try testing.expect(results_len == 1);
    try testing.expect(results[0] > 0);
}

test "install package" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    const pkg_id = pkg_mgr.add_package("test-pkg", "1.0.0", "Test package", 1024);
    try testing.expect(pkg_id != null);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    try ui.install_package(pkg_id.?);

    const pkg = pkg_mgr.find_package(pkg_id.?);
    try testing.expect(pkg != null);
    try testing.expect(pkg.?.state == .installed);
}

test "remove package" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    const pkg_id = pkg_mgr.add_package("test-pkg", "1.0.0", "Test package", 1024);
    try testing.expect(pkg_id != null);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    try ui.install_package(pkg_id.?);
    try ui.remove_package(pkg_id.?);

    const pkg = pkg_mgr.find_package(pkg_id.?);
    try testing.expect(pkg != null);
    try testing.expect(pkg.?.state == .not_installed);
}

test "get package dependencies" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    const pkg_id1 = pkg_mgr.add_package("pkg1", "1.0.0", "Package 1", 1024);
    const pkg_id2 = pkg_mgr.add_package("pkg2", "2.0.0", "Package 2", 2048);
    try testing.expect(pkg_id1 != null);
    try testing.expect(pkg_id2 != null);

    _ = pkg_mgr.add_dependency(pkg_id1.?, pkg_id2.?);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);

    var deps: [10]u32 = undefined;
    var deps_len: u32 = 0;
    const found = ui.get_package_dependencies(pkg_id1.?, &deps, &deps_len);

    try testing.expect(found == true);
    try testing.expect(deps_len == 1);
    try testing.expect(deps[0] == pkg_id2.?);
}

test "build dependency graph" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    const pkg_id1 = pkg_mgr.add_package("pkg1", "1.0.0", "Package 1", 1024);
    const pkg_id2 = pkg_mgr.add_package("pkg2", "2.0.0", "Package 2", 2048);
    try testing.expect(pkg_id1 != null);
    try testing.expect(pkg_id2 != null);

    _ = pkg_mgr.add_dependency(pkg_id1.?, pkg_id2.?);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);

    var nodes: [10]PackageManagerUI.DependencyNode = undefined;
    var nodes_len: u32 = 0;
    ui.build_dependency_graph(pkg_id1.?, &nodes, &nodes_len);

    try testing.expect(nodes_len >= 1);
    try testing.expect(nodes[0].package_id == pkg_id1.?);
    try testing.expect(nodes[0].level == 0);
}

test "category filtering" {
    const allocator = testing.allocator;
    var pkg_mgr = grain_core.package_manager.PackageManager.init();

    _ = pkg_mgr.add_package("kernel-module", "1.0.0", "Kernel module", 1024);
    _ = pkg_mgr.add_package("dev-tool", "2.0.0", "Dev tool", 2048);

    var ui = PackageManagerUI.init(allocator, &pkg_mgr);
    ui.set_category(.system);

    var packages: [10]PackageManagerUI.PackageInfo = undefined;
    var packages_len: u32 = 0;
    ui.get_packages(&packages, &packages_len);

    try testing.expect(packages_len == 1);
    try testing.expect(packages[0].category == .system);
}

