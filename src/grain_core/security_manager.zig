//! Grain OS Security Manager: User permissions and access control.
//!
//! Why: Provide security management for user permissions and access control.
//! Architecture: Permission management, access control, security policies.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max permissions.
pub const MAX_PERMISSIONS: u32 = 64;

// Bounded: Max permission name length.
pub const MAX_PERMISSION_NAME_LEN: u32 = 64;

// Bounded: Max users.
pub const MAX_USERS: u32 = 32;

// Bounded: Max user name length.
pub const MAX_USER_NAME_LEN: u32 = 64;

// Permission type.
pub const PermissionType = enum(u8) {
    none,
    read,
    write,
    execute,
    admin,
    full_control,
};

// User role.
pub const UserRole = enum(u8) {
    guest,
    user,
    admin,
    root,
};

// Permission: represents a permission.
pub const Permission = struct {
    permission_id: u32,
    name: [MAX_PERMISSION_NAME_LEN]u8,
    name_len: u32,
    permission_type: PermissionType,
    active: bool,

    pub fn init() Permission {
        var perm = Permission{
            .permission_id = 0,
            .name = undefined,
            .name_len = 0,
            .permission_type = PermissionType.none,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_PERMISSION_NAME_LEN) : (i += 1) {
            perm.name[i] = 0;
        }
        return perm;
    }
};

// User: represents a system user.
pub const User = struct {
    user_id: u32,
    name: [MAX_USER_NAME_LEN]u8,
    name_len: u32,
    role: UserRole,
    permissions: [MAX_PERMISSIONS]u32, // Permission IDs.
    permissions_len: u32,
    active: bool,

    pub fn init() User {
        var user = User{
            .user_id = 0,
            .name = undefined,
            .name_len = 0,
            .role = UserRole.user,
            .permissions = undefined,
            .permissions_len = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_USER_NAME_LEN) : (i += 1) {
            user.name[i] = 0;
        }
        i = 0;
        while (i < MAX_PERMISSIONS) : (i += 1) {
            user.permissions[i] = 0;
        }
        return user;
    }
};

// Security manager: manages permissions and users.
pub const SecurityManager = struct {
    permissions: [MAX_PERMISSIONS]Permission,
    permissions_len: u32,
    next_permission_id: u32,
    users: [MAX_USERS]User,
    users_len: u32,
    next_user_id: u32,
    current_user_id: u32,

    pub fn init() SecurityManager {
        var manager = SecurityManager{
            .permissions = undefined,
            .permissions_len = 0,
            .next_permission_id = 1,
            .users = undefined,
            .users_len = 0,
            .next_user_id = 1,
            .current_user_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_PERMISSIONS) : (i += 1) {
            manager.permissions[i] = Permission.init();
        }
        i = 0;
        while (i < MAX_USERS) : (i += 1) {
            manager.users[i] = User.init();
        }
        return manager;
    }

    // Add permission.
    pub fn add_permission(
        self: *SecurityManager,
        name: []const u8,
        permission_type: PermissionType,
    ) ?u32 {
        if (self.permissions_len >= MAX_PERMISSIONS) {
            return null;
        }
        if (name.len > MAX_PERMISSION_NAME_LEN) {
            return null;
        }
        const permission_id = self.next_permission_id;
        self.next_permission_id += 1;
        self.permissions[self.permissions_len] = Permission.init();
        self.permissions[self.permissions_len].permission_id = permission_id;
        self.permissions[self.permissions_len].permission_type = permission_type;
        self.permissions[self.permissions_len].active = true;
        var i: u32 = 0;
        while (i < MAX_PERMISSION_NAME_LEN) : (i += 1) {
            self.permissions[self.permissions_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_PERMISSION_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.permissions[self.permissions_len].name[i] = name[i];
        }
        self.permissions[self.permissions_len].name_len = @intCast(name_len);
        self.permissions_len += 1;
        return permission_id;
    }

    // Find permission by ID.
    pub fn find_permission(
        self: *SecurityManager,
        permission_id: u32,
    ) ?*Permission {
        std.debug.assert(permission_id > 0);
        var i: u32 = 0;
        while (i < self.permissions_len) : (i += 1) {
            if (self.permissions[i].permission_id == permission_id and self.permissions[i].active) {
                return &self.permissions[i];
            }
        }
        return null;
    }

    // Add user.
    pub fn add_user(
        self: *SecurityManager,
        name: []const u8,
        role: UserRole,
    ) ?u32 {
        if (self.users_len >= MAX_USERS) {
            return null;
        }
        if (name.len > MAX_USER_NAME_LEN) {
            return null;
        }
        const user_id = self.next_user_id;
        self.next_user_id += 1;
        self.users[self.users_len] = User.init();
        self.users[self.users_len].user_id = user_id;
        self.users[self.users_len].role = role;
        self.users[self.users_len].active = true;
        var i: u32 = 0;
        while (i < MAX_USER_NAME_LEN) : (i += 1) {
            self.users[self.users_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_USER_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.users[self.users_len].name[i] = name[i];
        }
        self.users[self.users_len].name_len = @intCast(name_len);
        if (self.current_user_id == 0) {
            self.current_user_id = user_id;
        }
        self.users_len += 1;
        return user_id;
    }

    // Find user by ID.
    pub fn find_user(
        self: *SecurityManager,
        user_id: u32,
    ) ?*User {
        std.debug.assert(user_id > 0);
        var i: u32 = 0;
        while (i < self.users_len) : (i += 1) {
            if (self.users[i].user_id == user_id and self.users[i].active) {
                return &self.users[i];
            }
        }
        return null;
    }

    // Grant permission to user.
    pub fn grant_permission(
        self: *SecurityManager,
        user_id: u32,
        permission_id: u32,
    ) bool {
        std.debug.assert(user_id > 0);
        std.debug.assert(permission_id > 0);
        if (self.find_user(user_id)) |user| {
            if (user.permissions_len >= MAX_PERMISSIONS) {
                return false;
            }
            var i: u32 = 0;
            while (i < user.permissions_len) : (i += 1) {
                if (user.permissions[i] == permission_id) {
                    return false; // Already granted.
                }
            }
            user.permissions[user.permissions_len] = permission_id;
            user.permissions_len += 1;
            return true;
        }
        return false;
    }

    // Revoke permission from user.
    pub fn revoke_permission(
        self: *SecurityManager,
        user_id: u32,
        permission_id: u32,
    ) bool {
        std.debug.assert(user_id > 0);
        std.debug.assert(permission_id > 0);
        if (self.find_user(user_id)) |user| {
            var i: u32 = 0;
            var found: bool = false;
            while (i < user.permissions_len) : (i += 1) {
                if (user.permissions[i] == permission_id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
            while (i < user.permissions_len - 1) : (i += 1) {
                user.permissions[i] = user.permissions[i + 1];
            }
            user.permissions_len -= 1;
            return true;
        }
        return false;
    }

    // Check if user has permission.
    pub fn has_permission(
        self: *SecurityManager,
        user_id: u32,
        permission_id: u32,
    ) bool {
        std.debug.assert(user_id > 0);
        std.debug.assert(permission_id > 0);
        if (self.find_user(user_id)) |user| {
            if (user.role == UserRole.root) {
                return true; // Root has all permissions.
            }
            var i: u32 = 0;
            while (i < user.permissions_len) : (i += 1) {
                if (user.permissions[i] == permission_id) {
                    return true;
                }
            }
        }
        return false;
    }

    // Set current user.
    pub fn set_current_user(self: *SecurityManager, user_id: u32) bool {
        std.debug.assert(user_id > 0);
        if (self.find_user(user_id)) |_| {
            self.current_user_id = user_id;
            return true;
        }
        return false;
    }

    // Get current user.
    pub fn get_current_user(self: *const SecurityManager) ?*const User {
        if (self.current_user_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.users_len) : (i += 1) {
            if (self.users[i].user_id == self.current_user_id) {
                return &self.users[i];
            }
        }
        return null;
    }

    // Remove user.
    pub fn remove_user(self: *SecurityManager, user_id: u32) bool {
        std.debug.assert(user_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.users_len) : (i += 1) {
            if (self.users[i].user_id == user_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        if (self.current_user_id == user_id) {
            self.current_user_id = 0;
        }
        while (i < self.users_len - 1) : (i += 1) {
            self.users[i] = self.users[i + 1];
        }
        self.users_len -= 1;
        return true;
    }

    // Get permission count.
    pub fn get_permission_count(self: *const SecurityManager) u32 {
        return self.permissions_len;
    }

    // Get user count.
    pub fn get_user_count(self: *const SecurityManager) u32 {
        return self.users_len;
    }
};

