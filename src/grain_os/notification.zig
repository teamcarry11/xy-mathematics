//! Grain OS Notification: System notification management.
//!
//! Why: Display system notifications to users for events and messages.
//! Architecture: Notification queue, priority levels, expiration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max notifications.
pub const MAX_NOTIFICATIONS: u32 = 32;

// Bounded: Max notification title length.
pub const MAX_TITLE_LEN: u32 = 128;

// Bounded: Max notification message length.
pub const MAX_MESSAGE_LEN: u32 = 512;

// Bounded: Default notification timeout (ms).
pub const DEFAULT_TIMEOUT_MS: u32 = 5000;

// Notification priority levels.
pub const NotificationPriority = enum(u8) {
    low,
    normal,
    high,
    urgent,
};

// Notification: represents a system notification.
pub const Notification = struct {
    notification_id: u32,
    title: [MAX_TITLE_LEN]u8,
    title_len: u32,
    message: [MAX_MESSAGE_LEN]u8,
    message_len: u32,
    priority: NotificationPriority,
    timestamp: u64,
    timeout_ms: u32,
    expired: bool,

    pub fn init(
        notification_id: u32,
        title: []const u8,
        message: []const u8,
        priority: NotificationPriority,
    ) Notification {
        std.debug.assert(notification_id > 0);
        std.debug.assert(title.len <= MAX_TITLE_LEN);
        std.debug.assert(message.len <= MAX_MESSAGE_LEN);
        var notification = Notification{
            .notification_id = notification_id,
            .title = undefined,
            .title_len = 0,
            .message = undefined,
            .message_len = 0,
            .priority = priority,
            .timestamp = 0,
            .timeout_ms = DEFAULT_TIMEOUT_MS,
            .expired = false,
        };
        var i: u32 = 0;
        while (i < MAX_TITLE_LEN) : (i += 1) {
            notification.title[i] = 0;
        }
        const title_len = @min(title.len, MAX_TITLE_LEN);
        i = 0;
        while (i < title_len) : (i += 1) {
            notification.title[i] = title[i];
        }
        notification.title_len = @intCast(title_len);
        var j: u32 = 0;
        while (j < MAX_MESSAGE_LEN) : (j += 1) {
            notification.message[j] = 0;
        }
        const message_len = @min(message.len, MAX_MESSAGE_LEN);
        j = 0;
        while (j < message_len) : (j += 1) {
            notification.message[j] = message[j];
        }
        notification.message_len = @intCast(message_len);
        return notification;
    }
};

// Notification manager: manages system notifications.
pub const NotificationManager = struct {
    notifications: [MAX_NOTIFICATIONS]Notification,
    notifications_len: u32,
    next_notification_id: u32,

    pub fn init() NotificationManager {
        var manager = NotificationManager{
            .notifications = undefined,
            .notifications_len = 0,
            .next_notification_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_NOTIFICATIONS) : (i += 1) {
            manager.notifications[i] = Notification.init(0, "", "", NotificationPriority.normal);
        }
        return manager;
    }

    // Add notification.
    pub fn add_notification(
        self: *NotificationManager,
        title: []const u8,
        message: []const u8,
        priority: NotificationPriority,
    ) ?u32 {
        if (self.notifications_len >= MAX_NOTIFICATIONS) {
            return null;
        }
        if (title.len > MAX_TITLE_LEN) {
            return null;
        }
        if (message.len > MAX_MESSAGE_LEN) {
            return null;
        }
        const notification_id = self.next_notification_id;
        self.next_notification_id += 1;
        self.notifications[self.notifications_len] = Notification.init(
            notification_id,
            title,
            message,
            priority,
        );
        self.notifications_len += 1;
        return notification_id;
    }

    // Find notification by ID.
    pub fn find_notification(
        self: *NotificationManager,
        notification_id: u32,
    ) ?*Notification {
        std.debug.assert(notification_id > 0);
        var i: u32 = 0;
        while (i < self.notifications_len) : (i += 1) {
            if (self.notifications[i].notification_id == notification_id and !self.notifications[i].expired) {
                return &self.notifications[i];
            }
        }
        return null;
    }

    // Remove notification.
    pub fn remove_notification(self: *NotificationManager, notification_id: u32) bool {
        std.debug.assert(notification_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.notifications_len) : (i += 1) {
            if (self.notifications[i].notification_id == notification_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining notifications left.
        while (i < self.notifications_len - 1) : (i += 1) {
            self.notifications[i] = self.notifications[i + 1];
        }
        self.notifications_len -= 1;
        return true;
    }

    // Mark notification as expired.
    pub fn expire_notification(self: *NotificationManager, notification_id: u32) bool {
        std.debug.assert(notification_id > 0);
        if (self.find_notification(notification_id)) |notification| {
            notification.expired = true;
            return true;
        }
        return false;
    }

    // Get notification count.
    pub fn get_notification_count(self: *const NotificationManager) u32 {
        return self.notifications_len;
    }

    // Get active notification count (non-expired).
    pub fn get_active_count(self: *const NotificationManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.notifications_len) : (i += 1) {
            if (!self.notifications[i].expired) {
                count += 1;
            }
        }
        return count;
    }

    // Clear all notifications.
    pub fn clear_all(self: *NotificationManager) void {
        self.notifications_len = 0;
    }

    // Clear expired notifications.
    pub fn clear_expired(self: *NotificationManager) void {
        var i: u32 = 0;
        while (i < self.notifications_len) : (i += 1) {
            if (self.notifications[i].expired) {
                // Shift remaining notifications left.
                var j: u32 = i;
                while (j < self.notifications_len - 1) : (j += 1) {
                    self.notifications[j] = self.notifications[j + 1];
                }
                self.notifications_len -= 1;
                i -= 1; // Recheck current index.
            }
        }
    }
};

