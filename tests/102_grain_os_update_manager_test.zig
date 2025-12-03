//! Tests for Grain OS update management system.
//!
//! Why: Verify update management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const UpdateManager = grain_os.update_manager.UpdateManager;
const UpdateType = grain_os.update_manager.UpdateType;
const UpdateState = grain_os.update_manager.UpdateState;

test "update manager initialization" {
    const manager = UpdateManager.init();
    std.debug.assert(manager.updates_len == 0);
    std.debug.assert(manager.next_update_id == 1);
    std.debug.assert(manager.current_version_len > 0);
    std.debug.assert(manager.auto_update_enabled == false);
    std.debug.assert(manager.current_update_id == 0);
}

test "add update" {
    var manager = UpdateManager.init();
    const update_id_opt = manager.add_update(
        "1.1.0",
        "Bug fixes and improvements",
        "https://example.com/update",
        UpdateType.bugfix,
        1024 * 1024,
        2000,
    );
    std.debug.assert(update_id_opt != null);
    if (update_id_opt) |update_id| {
        std.debug.assert(update_id == 1);
        std.debug.assert(manager.get_update_count() == 1);
    }
}

test "start download" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        const result = manager.start_download(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.downloading);
            std.debug.assert(manager.get_current_update_id() == update_id);
        }
    }
}

test "complete download" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = manager.start_download(update_id);
        const result = manager.complete_download(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.downloaded);
        }
    }
}

test "start installation" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = manager.start_download(update_id);
        _ = manager.complete_download(update_id);
        const result = manager.start_installation(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.installing);
        }
    }
}

test "complete installation" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = manager.start_download(update_id);
        _ = manager.complete_download(update_id);
        _ = manager.start_installation(update_id);
        const result = manager.complete_installation(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.installed);
        }
        const version = manager.get_current_version();
        std.debug.assert(std.mem.eql(u8, version, "1.1.0"));
    }
}

test "fail update" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = manager.start_download(update_id);
        const result = manager.fail_update(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.failed);
        }
    }
}

test "cancel update" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = manager.start_download(update_id);
        const result = manager.cancel_update(update_id);
        std.debug.assert(result);
        if (manager.find_update(update_id)) |update| {
            std.debug.assert(update.state == UpdateState.cancelled);
        }
    }
}

test "remove update" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        const result = manager.remove_update(update_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_update_count() == 0);
    }
}

test "set current version" {
    var manager = UpdateManager.init();
    const result = manager.set_current_version("2.0.0");
    std.debug.assert(result);
    const version = manager.get_current_version();
    std.debug.assert(std.mem.eql(u8, version, "2.0.0"));
}

test "enable auto-update" {
    var manager = UpdateManager.init();
    manager.enable_auto_update();
    std.debug.assert(manager.is_auto_update_enabled());
}

test "get available update count" {
    var manager = UpdateManager.init();
    if (manager.add_update("1.1.0", "Test 1", "https://example.com/1", UpdateType.minor, 1024, 1000)) |update_id_1| {
        if (manager.add_update("1.2.0", "Test 2", "https://example.com/2", UpdateType.minor, 2048, 2000)) |_update_id_2| {
            const count = manager.get_available_update_count();
            std.debug.assert(count == 2);
        }
    }
}

test "compositor add update" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const update_id_opt = comp.add_update(
        "1.1.0",
        "Bug fixes and improvements",
        "https://example.com/update",
        UpdateType.bugfix,
        1024 * 1024,
        2000,
    );
    std.debug.assert(update_id_opt != null);
}

test "compositor start download" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        const result = comp.start_update_download(update_id);
        std.debug.assert(result);
    }
}

test "compositor complete installation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_update("1.1.0", "Test", "https://example.com", UpdateType.minor, 1024, 1000)) |update_id| {
        _ = comp.start_update_download(update_id);
        _ = comp.complete_update_download(update_id);
        _ = comp.start_update_installation(update_id);
        const result = comp.complete_update_installation(update_id);
        std.debug.assert(result);
    }
}

test "compositor set current version" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.set_current_version("2.0.0");
    std.debug.assert(result);
    const version = comp.get_current_version();
    std.debug.assert(std.mem.eql(u8, version, "2.0.0"));
}

test "compositor enable auto-update" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.enable_auto_update();
    std.debug.assert(comp.is_auto_update_enabled());
}

test "update types" {
    std.debug.assert(@intFromEnum(UpdateType.security) == 0);
    std.debug.assert(@intFromEnum(UpdateType.bugfix) == 1);
    std.debug.assert(@intFromEnum(UpdateType.feature) == 2);
    std.debug.assert(@intFromEnum(UpdateType.major) == 3);
    std.debug.assert(@intFromEnum(UpdateType.minor) == 4);
}

test "update states" {
    std.debug.assert(@intFromEnum(UpdateState.available) == 0);
    std.debug.assert(@intFromEnum(UpdateState.downloading) == 1);
    std.debug.assert(@intFromEnum(UpdateState.downloaded) == 2);
    std.debug.assert(@intFromEnum(UpdateState.installing) == 3);
    std.debug.assert(@intFromEnum(UpdateState.installed) == 4);
    std.debug.assert(@intFromEnum(UpdateState.failed) == 5);
    std.debug.assert(@intFromEnum(UpdateState.cancelled) == 6);
}

test "update manager constants" {
    std.debug.assert(grain_os.update_manager.MAX_UPDATES == 16);
    std.debug.assert(grain_os.update_manager.MAX_VERSION_LEN == 32);
    std.debug.assert(grain_os.update_manager.MAX_UPDATE_DESC_LEN == 256);
    std.debug.assert(grain_os.update_manager.MAX_UPDATE_URL_LEN == 512);
}

