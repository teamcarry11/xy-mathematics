//! Tests for Grain OS security management system.
//!
//! Why: Verify security management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const SecurityManager = grain_os.security_manager.SecurityManager;
const PermissionType = grain_os.security_manager.PermissionType;
const UserRole = grain_os.security_manager.UserRole;

test "security manager initialization" {
    const manager = SecurityManager.init();
    std.debug.assert(manager.permissions_len == 0);
    std.debug.assert(manager.users_len == 0);
    std.debug.assert(manager.next_permission_id == 1);
    std.debug.assert(manager.next_user_id == 1);
    std.debug.assert(manager.current_user_id == 0);
}

test "add permission" {
    var manager = SecurityManager.init();
    const permission_id_opt = manager.add_permission("read_files", PermissionType.read);
    std.debug.assert(permission_id_opt != null);
    if (permission_id_opt) |permission_id| {
        std.debug.assert(permission_id == 1);
        std.debug.assert(manager.get_permission_count() == 1);
    }
}

test "add user" {
    var manager = SecurityManager.init();
    const user_id_opt = manager.add_user("test_user", UserRole.user);
    std.debug.assert(user_id_opt != null);
    if (user_id_opt) |user_id| {
        std.debug.assert(user_id == 1);
        std.debug.assert(manager.get_user_count() == 1);
        std.debug.assert(manager.current_user_id == user_id);
    }
}

test "grant permission to user" {
    var manager = SecurityManager.init();
    if (manager.add_user("test_user", UserRole.user)) |user_id| {
        if (manager.add_permission("read_files", PermissionType.read)) |permission_id| {
            const result = manager.grant_permission(user_id, permission_id);
            std.debug.assert(result);
            const has_perm = manager.has_permission(user_id, permission_id);
            std.debug.assert(has_perm);
        }
    }
}

test "revoke permission from user" {
    var manager = SecurityManager.init();
    if (manager.add_user("test_user", UserRole.user)) |user_id| {
        if (manager.add_permission("read_files", PermissionType.read)) |permission_id| {
            _ = manager.grant_permission(user_id, permission_id);
            const result = manager.revoke_permission(user_id, permission_id);
            std.debug.assert(result);
            const has_perm = manager.has_permission(user_id, permission_id);
            std.debug.assert(!has_perm);
        }
    }
}

test "root user has all permissions" {
    var manager = SecurityManager.init();
    if (manager.add_user("root", UserRole.root)) |user_id| {
        if (manager.add_permission("read_files", PermissionType.read)) |permission_id| {
            const has_perm = manager.has_permission(user_id, permission_id);
            std.debug.assert(has_perm);
        }
    }
}

test "set current user" {
    var manager = SecurityManager.init();
    if (manager.add_user("test_user", UserRole.user)) |user_id| {
        const result = manager.set_current_user(user_id);
        std.debug.assert(result);
        std.debug.assert(manager.current_user_id == user_id);
    }
}

test "get current user" {
    var manager = SecurityManager.init();
    if (manager.add_user("test_user", UserRole.user)) |user_id| {
        _ = manager.set_current_user(user_id);
        const user_opt = manager.get_current_user();
        std.debug.assert(user_opt != null);
        if (user_opt) |user| {
            std.debug.assert(user.user_id == user_id);
        }
    }
}

test "remove user" {
    var manager = SecurityManager.init();
    if (manager.add_user("test_user", UserRole.user)) |user_id| {
        const result = manager.remove_user(user_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_user_count() == 0);
    }
}

test "compositor add permission" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const permission_id_opt = comp.add_permission("read_files", PermissionType.read);
    std.debug.assert(permission_id_opt != null);
}

test "compositor add user" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const user_id_opt = comp.add_user("test_user", UserRole.user);
    std.debug.assert(user_id_opt != null);
}

test "compositor grant permission" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_user("test_user", UserRole.user)) |user_id| {
        if (comp.add_permission("read_files", PermissionType.read)) |permission_id| {
            const result = comp.grant_permission(user_id, permission_id);
            std.debug.assert(result);
        }
    }
}

test "compositor check permission" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_user("test_user", UserRole.user)) |user_id| {
        if (comp.add_permission("read_files", PermissionType.read)) |permission_id| {
            _ = comp.grant_permission(user_id, permission_id);
            const has_perm = comp.has_permission(user_id, permission_id);
            std.debug.assert(has_perm);
        }
    }
}

test "compositor set current user" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_user("test_user", UserRole.user)) |user_id| {
        const result = comp.set_current_user(user_id);
        std.debug.assert(result);
    }
}

test "permission types" {
    std.debug.assert(@intFromEnum(PermissionType.none) == 0);
    std.debug.assert(@intFromEnum(PermissionType.read) == 1);
    std.debug.assert(@intFromEnum(PermissionType.write) == 2);
    std.debug.assert(@intFromEnum(PermissionType.execute) == 3);
    std.debug.assert(@intFromEnum(PermissionType.admin) == 4);
}

test "user roles" {
    std.debug.assert(@intFromEnum(UserRole.guest) == 0);
    std.debug.assert(@intFromEnum(UserRole.user) == 1);
    std.debug.assert(@intFromEnum(UserRole.admin) == 2);
    std.debug.assert(@intFromEnum(UserRole.root) == 3);
}

test "security manager constants" {
    std.debug.assert(grain_os.security_manager.MAX_PERMISSIONS == 64);
    std.debug.assert(grain_os.security_manager.MAX_PERMISSION_NAME_LEN == 64);
    std.debug.assert(grain_os.security_manager.MAX_USERS == 32);
    std.debug.assert(grain_os.security_manager.MAX_USER_NAME_LEN == 64);
}

