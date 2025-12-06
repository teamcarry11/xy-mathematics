//! Tests for Grain OS notification system.
//!
//! Why: Verify notification management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const NotificationManager = grain_core.notification.NotificationManager;
const NotificationPriority = grain_core.notification.NotificationPriority;

test "notification manager initialization" {
    const manager = NotificationManager.init();
    std.debug.assert(manager.notifications_len == 0);
    std.debug.assert(manager.next_notification_id == 1);
}

test "add notification" {
    var manager = NotificationManager.init();
    const notification_id_opt = manager.add_notification(
        "Test Title",
        "Test message",
        NotificationPriority.normal,
    );
    std.debug.assert(notification_id_opt != null);
    if (notification_id_opt) |notification_id| {
        std.debug.assert(notification_id == 1);
        std.debug.assert(manager.notifications_len == 1);
    }
}

test "find notification by ID" {
    var manager = NotificationManager.init();
    if (manager.add_notification("Title", "Message", NotificationPriority.normal)) |notification_id| {
        const notification_opt = manager.find_notification(notification_id);
        std.debug.assert(notification_opt != null);
        if (notification_opt) |notif| {
            std.debug.assert(notif.notification_id == notification_id);
        }
    }
}

test "remove notification" {
    var manager = NotificationManager.init();
    if (manager.add_notification("Title", "Message", NotificationPriority.normal)) |notification_id| {
        const result = manager.remove_notification(notification_id);
        std.debug.assert(result);
        std.debug.assert(manager.notifications_len == 0);
    }
}

test "expire notification" {
    var manager = NotificationManager.init();
    if (manager.add_notification("Title", "Message", NotificationPriority.normal)) |notification_id| {
        const result = manager.expire_notification(notification_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_active_count() == 0);
    }
}

test "get notification count" {
    var manager = NotificationManager.init();
    std.debug.assert(manager.get_notification_count() == 0);
    _ = manager.add_notification("Title1", "Message1", NotificationPriority.normal);
    std.debug.assert(manager.get_notification_count() == 1);
    _ = manager.add_notification("Title2", "Message2", NotificationPriority.high);
    std.debug.assert(manager.get_notification_count() == 2);
}

test "get active notification count" {
    var manager = NotificationManager.init();
    if (manager.add_notification("Title", "Message", NotificationPriority.normal)) |notification_id| {
        std.debug.assert(manager.get_active_count() == 1);
        _ = manager.expire_notification(notification_id);
        std.debug.assert(manager.get_active_count() == 0);
    }
}

test "clear all notifications" {
    var manager = NotificationManager.init();
    _ = manager.add_notification("Title1", "Message1", NotificationPriority.normal);
    _ = manager.add_notification("Title2", "Message2", NotificationPriority.high);
    manager.clear_all();
    std.debug.assert(manager.get_notification_count() == 0);
}

test "clear expired notifications" {
    var manager = NotificationManager.init();
    if (manager.add_notification("Title1", "Message1", NotificationPriority.normal)) |id1| {
        _ = manager.add_notification("Title2", "Message2", NotificationPriority.high);
        _ = manager.expire_notification(id1);
        manager.clear_expired();
        std.debug.assert(manager.get_notification_count() == 1);
    }
}

test "notification priorities" {
    var manager = NotificationManager.init();
    _ = manager.add_notification("Low", "Message", NotificationPriority.low);
    _ = manager.add_notification("Normal", "Message", NotificationPriority.normal);
    _ = manager.add_notification("High", "Message", NotificationPriority.high);
    _ = manager.add_notification("Urgent", "Message", NotificationPriority.urgent);
    std.debug.assert(manager.get_notification_count() == 4);
}

test "compositor show notification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const notification_id_opt = comp.show_notification(
        "Test Title",
        "Test message",
        NotificationPriority.normal,
    );
    std.debug.assert(notification_id_opt != null);
}

test "compositor remove notification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.show_notification("Title", "Message", NotificationPriority.normal)) |notification_id| {
        const result = comp.remove_notification(notification_id);
        std.debug.assert(result);
    }
}

test "compositor get notification count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_notification_count() == 0);
    _ = comp.show_notification("Title1", "Message1", NotificationPriority.normal);
    std.debug.assert(comp.get_notification_count() == 1);
}

test "compositor clear all notifications" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.show_notification("Title1", "Message1", NotificationPriority.normal);
    _ = comp.show_notification("Title2", "Message2", NotificationPriority.high);
    comp.clear_all_notifications();
    std.debug.assert(comp.get_notification_count() == 0);
}

test "notification constants" {
    std.debug.assert(grain_core.notification.MAX_NOTIFICATIONS == 32);
    std.debug.assert(grain_core.notification.MAX_TITLE_LEN == 128);
    std.debug.assert(grain_core.notification.MAX_MESSAGE_LEN == 512);
    std.debug.assert(grain_core.notification.DEFAULT_TIMEOUT_MS == 5000);
}

