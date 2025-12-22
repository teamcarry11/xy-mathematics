//! Grain Database User Storage: Helper for mobile app user data storage.
//!
//! Why: Simplify database usage for mobile app user storage (Carry Agent integration).
//! Architecture: Helper functions for common user storage patterns.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-21-185000-pst: Grain Silo Agent

const std = @import("std");
const storage_engine = @import("storage_engine.zig");

// User storage errors.
pub const UserStorageError = error{
    InvalidUserId,
    InvalidEmail,
    UserNotFound,
};

// Bounded: Max user ID length (hex string: 64 chars).
pub const MAX_USER_ID_LEN: u32 = 64;

// Bounded: Max email length.
pub const MAX_EMAIL_LEN: u32 = 256;

// Bounded: Max user key length.
pub const MAX_USER_KEY_LEN: u32 = 128;

// Validate user ID format (hex string: 0-9a-f, max 64 chars).
pub fn validate_user_id(user_id: []const u8) bool {
    std.debug.assert(user_id.len > 0);
    if (user_id.len == 0 or user_id.len > MAX_USER_ID_LEN) {
        return false;
    }
    var i: u32 = 0;
    while (i < user_id.len) : (i += 1) {
        const c = user_id[i];
        if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F'))) {
            return false;
        }
    }
    return true;
}

// Validate email format (basic check: contains @ and .).
pub fn validate_email(email: []const u8) bool {
    std.debug.assert(email.len > 0);
    if (email.len == 0 or email.len > MAX_EMAIL_LEN) {
        return false;
    }
    var has_at: bool = false;
    var has_dot: bool = false;
    var i: u32 = 0;
    while (i < email.len) : (i += 1) {
        const c = email[i];
        if (c == '@') {
            has_at = true;
        }
        if (c == '.') {
            has_dot = true;
        }
    }
    return has_at and has_dot;
}

// User storage helper.
pub const UserStorage = struct {
    storage_engine: *storage_engine.StorageEngine,

    // Initialize user storage.
    pub fn init(
        storage: *storage_engine.StorageEngine,
    ) UserStorage {
        std.debug.assert(storage != null);
        return UserStorage{
            .storage_engine = storage,
        };
    }

    // Store user data.
    pub fn store_user(
        self: *UserStorage,
        user_id: []const u8,
        user_data: []const u8,
    ) !u64 {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        std.debug.assert(user_data.len > 0);
        if (!validate_user_id(user_id)) {
            return error.InvalidUserId;
        }
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "user:{s}",
            .{user_id},
        );
        defer self.storage_engine.allocator.free(key);
        const record_id = try self.storage_engine.create_record(key, user_data);
        std.debug.assert(record_id > 0);
        return record_id;
    }

    // Retrieve user data by user ID.
    pub fn get_user(
        self: *UserStorage,
        user_id: []const u8,
    ) ?*storage_engine.Record {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        const key = std.fmt.allocPrint(
            self.storage_engine.allocator,
            "user:{s}",
            .{user_id},
        ) catch return null;
        defer self.storage_engine.allocator.free(key);
        return self.storage_engine.read_record_by_key(key);
    }

    // Update user data.
    pub fn update_user(
        self: *UserStorage,
        user_id: []const u8,
        user_data: []const u8,
    ) !void {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        std.debug.assert(user_data.len > 0);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "user:{s}",
            .{user_id},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.update_record(key, user_data);
    }

    // Delete user data.
    pub fn delete_user(
        self: *UserStorage,
        user_id: []const u8,
    ) !void {
        std.debug.assert(user_id.len > 0);
        std.debug.assert(user_id.len <= MAX_USER_ID_LEN);
        const key = try std.fmt.allocPrint(
            self.storage_engine.allocator,
            "user:{s}",
            .{user_id},
        );
        defer self.storage_engine.allocator.free(key);
        try self.storage_engine.delete_record(key);
    }

    // Search users by email (simple text matching in value).
    pub fn search_by_email(
        self: *UserStorage,
        email: []const u8,
        output: []u64,
    ) u32 {
        std.debug.assert(email.len > 0);
        std.debug.assert(output.len > 0);
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "user:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    const value_slice = record.value[0..record.value_len];
                    if (std.mem.indexOf(u8, value_slice, email) != null) {
                        if (count < output.len) {
                            output[count] = record.record_id;
                            count += 1;
                        }
                    }
                }
            }
        }
        return count;
    }

    // List all users (returns count of matching records).
    pub fn list_users(
        self: *UserStorage,
        output: []u64,
    ) u32 {
        std.debug.assert(output.len > 0);
        return self.list_users_paginated(output, 0, output.len);
    }

    // List users with pagination (offset, limit).
    pub fn list_users_paginated(
        self: *UserStorage,
        output: []u64,
        offset: u32,
        limit: u32,
    ) u32 {
        std.debug.assert(output.len > 0);
        std.debug.assert(limit > 0);
        std.debug.assert(limit <= output.len);
        var count: u32 = 0;
        var skipped: u32 = 0;
        var i: u32 = 0;
        const prefix = "user:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    if (skipped < offset) {
                        skipped += 1;
                    } else {
                        if (count < limit and count < output.len) {
                            output[count] = record.record_id;
                            count += 1;
                        }
                        if (count >= limit) {
                            break;
                        }
                    }
                }
            }
        }
        return count;
    }

    // Count all users.
    pub fn count_users(self: *UserStorage) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        const prefix = "user:";
        while (i < self.storage_engine.records_len) : (i += 1) {
            const record = &self.storage_engine.records[i];
            if (record.key_len >= prefix.len) {
                if (std.mem.eql(u8, record.key[0..prefix.len], prefix)) {
                    count += 1;
                }
            }
        }
        return count;
    }
};
