//! Tests for Grain OS time management system.
//!
//! Why: Verify time management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const TimeManager = grain_os.time_manager.TimeManager;
const TimeFormat = grain_os.time_manager.TimeFormat;
const DateFormat = grain_os.time_manager.DateFormat;

test "time manager initialization" {
    const manager = TimeManager.init();
    std.debug.assert(manager.get_system_time() == 0);
    std.debug.assert(manager.get_time_format() == TimeFormat.format_24h);
    std.debug.assert(manager.get_date_format() == DateFormat.format_iso);
    std.debug.assert(!manager.is_auto_sync_enabled());
}

test "set and get system time" {
    var manager = TimeManager.init();
    manager.set_system_time(1000000000);
    std.debug.assert(manager.get_system_time() == 1000000000);
}

test "set timezone" {
    var manager = TimeManager.init();
    const result = manager.set_timezone("America/Los_Angeles", "PST", -28800);
    std.debug.assert(result);
    const tz = manager.get_timezone();
    std.debug.assert(tz.offset_seconds == -28800);
}

test "set time format" {
    var manager = TimeManager.init();
    manager.set_time_format(TimeFormat.format_12h);
    std.debug.assert(manager.get_time_format() == TimeFormat.format_12h);
    manager.set_time_format(TimeFormat.format_24h);
    std.debug.assert(manager.get_time_format() == TimeFormat.format_24h);
}

test "set date format" {
    var manager = TimeManager.init();
    manager.set_date_format(DateFormat.format_us);
    std.debug.assert(manager.get_date_format() == DateFormat.format_us);
    manager.set_date_format(DateFormat.format_eu);
    std.debug.assert(manager.get_date_format() == DateFormat.format_eu);
}

test "enable and disable auto-sync" {
    var manager = TimeManager.init();
    manager.enable_auto_sync();
    std.debug.assert(manager.is_auto_sync_enabled());
    manager.disable_auto_sync();
    std.debug.assert(!manager.is_auto_sync_enabled());
}

test "get local time" {
    var manager = TimeManager.init();
    manager.set_system_time(1000000000);
    _ = manager.set_timezone("America/Los_Angeles", "PST", -28800);
    const local_time = manager.get_local_time();
    const expected = 1000000000 - (@as(u64, @intCast(28800)) * 1000000000);
    std.debug.assert(local_time == expected);
}

test "compositor set system time" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_system_time(1000000000);
    std.debug.assert(comp.get_system_time() == 1000000000);
}

test "compositor set timezone" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const result = comp.set_timezone("America/New_York", "EST", -18000);
    std.debug.assert(result);
    const tz = comp.get_timezone();
    std.debug.assert(tz.offset_seconds == -18000);
}

test "compositor set time format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_time_format(TimeFormat.format_12h);
    std.debug.assert(comp.get_time_format() == TimeFormat.format_12h);
}

test "compositor enable auto-sync" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.enable_time_auto_sync();
    std.debug.assert(comp.is_time_auto_sync_enabled());
    comp.disable_time_auto_sync();
    std.debug.assert(!comp.is_time_auto_sync_enabled());
}

test "compositor get local time" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_system_time(1000000000);
    _ = comp.set_timezone("UTC", "UTC", 0);
    const local_time = comp.get_local_time();
    std.debug.assert(local_time == 1000000000);
}

test "time formats" {
    std.debug.assert(@intFromEnum(TimeFormat.format_12h) == 0);
    std.debug.assert(@intFromEnum(TimeFormat.format_24h) == 1);
}

test "date formats" {
    std.debug.assert(@intFromEnum(DateFormat.format_iso) == 0);
    std.debug.assert(@intFromEnum(DateFormat.format_us) == 1);
    std.debug.assert(@intFromEnum(DateFormat.format_eu) == 2);
}

test "time manager constants" {
    std.debug.assert(grain_os.time_manager.MAX_TIMEZONE_NAME_LEN == 64);
    std.debug.assert(grain_os.time_manager.MAX_TIMEZONE_ABBR_LEN == 8);
}

