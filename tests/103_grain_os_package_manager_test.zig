//! Tests for Grain OS package management system.
//!
//! Why: Verify package management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const PackageManager = grain_os.package_manager.PackageManager;
const PackageState = grain_os.package_manager.PackageState;

test "package manager initialization" {
    const manager = PackageManager.init();
    std.debug.assert(manager.packages_len == 0);
    std.debug.assert(manager.next_package_id == 1);
}

test "add package" {
    var manager = PackageManager.init();
    const package_id_opt = manager.add_package(
        "test_package",
        "1.0.0",
        "Test package description",
        1024 * 1024,
    );
    std.debug.assert(package_id_opt != null);
    if (package_id_opt) |package_id| {
        std.debug.assert(package_id == 1);
        std.debug.assert(manager.get_package_count() == 1);
    }
}

test "install package" {
    var manager = PackageManager.init();
    if (manager.add_package("test_package", "1.0.0", "Test", 1024)) |package_id| {
        const result = manager.install_package(package_id, 1000);
        std.debug.assert(result);
        if (manager.find_package(package_id)) |pkg| {
            std.debug.assert(pkg.state == PackageState.installed);
            std.debug.assert(pkg.installed_timestamp == 1000);
        }
    }
}

test "remove package" {
    var manager = PackageManager.init();
    if (manager.add_package("test_package", "1.0.0", "Test", 1024)) |package_id| {
        _ = manager.install_package(package_id, 1000);
        const result = manager.remove_package(package_id);
        std.debug.assert(result);
        if (manager.find_package(package_id)) |pkg| {
            std.debug.assert(pkg.state == PackageState.not_installed);
            std.debug.assert(pkg.installed_timestamp == 0);
        }
    }
}

test "add dependency" {
    var manager = PackageManager.init();
    if (manager.add_package("package1", "1.0.0", "Package 1", 1024)) |package_id_1| {
        if (manager.add_package("package2", "1.0.0", "Package 2", 2048)) |package_id_2| {
            const result = manager.add_dependency(package_id_2, package_id_1);
            std.debug.assert(result);
        }
    }
}

test "remove dependency" {
    var manager = PackageManager.init();
    if (manager.add_package("package1", "1.0.0", "Package 1", 1024)) |package_id_1| {
        if (manager.add_package("package2", "1.0.0", "Package 2", 2048)) |package_id_2| {
            _ = manager.add_dependency(package_id_2, package_id_1);
            const result = manager.remove_dependency(package_id_2, package_id_1);
            std.debug.assert(result);
        }
    }
}

test "remove package entry" {
    var manager = PackageManager.init();
    if (manager.add_package("test_package", "1.0.0", "Test", 1024)) |package_id| {
        const result = manager.remove_package_entry(package_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_package_count() == 0);
    }
}

test "get installed package count" {
    var manager = PackageManager.init();
    if (manager.add_package("package1", "1.0.0", "Package 1", 1024)) |package_id_1| {
        if (manager.add_package("package2", "1.0.0", "Package 2", 2048)) |package_id_2| {
            _ = manager.install_package(package_id_1, 1000);
            _ = manager.install_package(package_id_2, 2000);
            const count = manager.get_installed_package_count();
            std.debug.assert(count == 2);
        }
    }
}

test "compositor add package" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const package_id_opt = comp.add_package(
        "test_package",
        "1.0.0",
        "Test package description",
        1024 * 1024,
    );
    std.debug.assert(package_id_opt != null);
}

test "compositor install package" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_package("test_package", "1.0.0", "Test", 1024)) |package_id| {
        const result = comp.install_package(package_id, 1000);
        std.debug.assert(result);
    }
}

test "compositor remove package" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_package("test_package", "1.0.0", "Test", 1024)) |package_id| {
        _ = comp.install_package(package_id, 1000);
        const result = comp.remove_package(package_id);
        std.debug.assert(result);
    }
}

test "compositor add dependency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_package("package1", "1.0.0", "Package 1", 1024)) |package_id_1| {
        if (comp.add_package("package2", "1.0.0", "Package 2", 2048)) |package_id_2| {
            const result = comp.add_package_dependency(package_id_2, package_id_1);
            std.debug.assert(result);
        }
    }
}

test "package states" {
    std.debug.assert(@intFromEnum(PackageState.not_installed) == 0);
    std.debug.assert(@intFromEnum(PackageState.installing) == 1);
    std.debug.assert(@intFromEnum(PackageState.installed) == 2);
    std.debug.assert(@intFromEnum(PackageState.removing) == 3);
    std.debug.assert(@intFromEnum(PackageState.failed) == 4);
}

test "package manager constants" {
    std.debug.assert(grain_os.package_manager.MAX_PACKAGES == 256);
    std.debug.assert(grain_os.package_manager.MAX_PACKAGE_NAME_LEN == 128);
    std.debug.assert(grain_os.package_manager.MAX_PACKAGE_VERSION_LEN == 32);
    std.debug.assert(grain_os.package_manager.MAX_PACKAGE_DESC_LEN == 256);
    std.debug.assert(grain_os.package_manager.MAX_DEPENDENCIES == 16);
}

