//! Tests for Grain OS lock screen and user identity management.
//!
//! Why: Verify lock screen functionality and multi-identity support.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const LockScreenManager = grain_os.lock_screen.LockScreenManager;
const IdentityManager = grain_os.lock_screen.IdentityManager;

test "lock screen manager initialization" {
    const manager = LockScreenManager.init();
    std.debug.assert(!manager.is_locked());
    std.debug.assert(manager.identity_manager.get_identity_count() == 0);
}

test "lock and unlock screen" {
    var manager = LockScreenManager.init();
    std.debug.assert(!manager.is_locked());
    manager.lock();
    std.debug.assert(manager.is_locked());
    manager.unlock();
    std.debug.assert(!manager.is_locked());
}

test "add user identity" {
    var manager = LockScreenManager.init();
    const identity_id_opt = manager.add_identity("bhagavan851c05a", "/Users/bhagavan851c05a");
    std.debug.assert(identity_id_opt != null);
    if (identity_id_opt) |identity_id| {
        std.debug.assert(identity_id == 1);
        std.debug.assert(manager.identity_manager.get_identity_count() == 1);
    }
}

test "find identity by name" {
    var manager = LockScreenManager.init();
    _ = manager.add_identity("bhagavan851c05a", "/Users/bhagavan851c05a");
    _ = manager.add_identity("xz", "/Users/xz");
    const identity_opt = manager.identity_manager.find_identity_by_name("xz");
    std.debug.assert(identity_opt != null);
    if (identity_opt) |identity| {
        std.debug.assert(identity.identity_id == 2);
    }
}

test "authenticate with password" {
    var manager = LockScreenManager.init();
    if (manager.add_identity("bhagavan851c05a", "/Users/bhagavan851c05a")) |identity_id| {
        const result = manager.authenticate_password(identity_id, "password");
        std.debug.assert(result);
        std.debug.assert(!manager.is_locked());
    }
}

test "authenticate with TouchID" {
    var manager = LockScreenManager.init();
    if (manager.add_identity("bhagavan851c05a", "/Users/bhagavan851c05a")) |identity_id| {
        const result = manager.authenticate_touchid(identity_id);
        std.debug.assert(result);
        std.debug.assert(!manager.is_locked());
    }
}

test "compositor lock screen" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(!comp.is_screen_locked());
    comp.lock_compositor_screen();
    std.debug.assert(comp.is_screen_locked());
    comp.unlock_compositor_screen();
    std.debug.assert(!comp.is_screen_locked());
}

test "compositor add user identity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const identity_id_opt = comp.add_user_identity("bhagavan851c05a", "/Users/bhagavan851c05a");
    std.debug.assert(identity_id_opt != null);
    std.debug.assert(comp.get_identity_count() == 1);
}

test "compositor authenticate password" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.lock_compositor_screen();
    if (comp.add_user_identity("bhagavan851c05a", "/Users/bhagavan851c05a")) |identity_id| {
        const result = comp.authenticate_password(identity_id, "password");
        std.debug.assert(result);
        std.debug.assert(!comp.is_screen_locked());
    }
}

test "compositor authenticate TouchID" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.lock_compositor_screen();
    if (comp.add_user_identity("bhagavan851c05a", "/Users/bhagavan851c05a")) |identity_id| {
        const result = comp.authenticate_touchid(identity_id);
        std.debug.assert(result);
        std.debug.assert(!comp.is_screen_locked());
    }
}

test "compositor get current identity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_user_identity("bhagavan851c05a", "/Users/bhagavan851c05a")) |identity_id| {
        _ = comp.authenticate_password(identity_id, "password");
        const identity_opt = comp.get_current_identity();
        std.debug.assert(identity_opt != null);
        if (identity_opt) |identity| {
            std.debug.assert(identity.identity_id == identity_id);
        }
    }
}

test "multiple identities" {
    var manager = LockScreenManager.init();
    _ = manager.add_identity("bhagavan851c05a", "/Users/bhagavan851c05a");
    _ = manager.add_identity("xz", "/Users/xz");
    _ = manager.add_identity("xx", "/Users/xx");
    _ = manager.add_identity("bhagavan58wappo", "/Users/bhagavan58wappo");
    _ = manager.add_identity("Shared", "/Users/Shared");
    std.debug.assert(manager.identity_manager.get_identity_count() == 5);
}

test "lock screen constants" {
    std.debug.assert(grain_os.lock_screen.MAX_IDENTITIES == 16);
    std.debug.assert(grain_os.lock_screen.MAX_IDENTITY_NAME_LEN == 64);
    std.debug.assert(grain_os.lock_screen.MAX_PASSWORD_LEN == 256);
}

