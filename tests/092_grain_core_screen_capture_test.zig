//! Tests for Grain OS screen capture system.
//!
//! Why: Verify screen capture functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const ScreenCaptureManager = grain_core.screen_capture.ScreenCaptureManager;
const CaptureFormat = grain_core.screen_capture.CaptureFormat;
const CaptureType = grain_core.screen_capture.CaptureType;

test "screen capture manager initialization" {
    const manager = ScreenCaptureManager.init();
    std.debug.assert(manager.captures_len == 0);
    std.debug.assert(manager.next_capture_id == 1);
    std.debug.assert(!manager.is_recording_active());
    std.debug.assert(manager.current_recording_id == 0);
}

test "capture screenshot" {
    var manager = ScreenCaptureManager.init();
    const capture_id_opt = manager.capture_screenshot("screenshot1", 0, 0, 1920, 1080, CaptureFormat.png, 1000);
    std.debug.assert(capture_id_opt != null);
    if (capture_id_opt) |capture_id| {
        std.debug.assert(capture_id == 1);
        std.debug.assert(manager.get_capture_count() == 1);
    }
}

test "start recording" {
    var manager = ScreenCaptureManager.init();
    const recording_id_opt = manager.start_recording("recording1", 0, 0, 1920, 1080, CaptureFormat.raw, 1000);
    std.debug.assert(recording_id_opt != null);
    if (recording_id_opt) |recording_id| {
        std.debug.assert(recording_id == 1);
        std.debug.assert(manager.is_recording_active());
        std.debug.assert(manager.get_current_recording_id() == recording_id);
    }
}

test "stop recording" {
    var manager = ScreenCaptureManager.init();
    if (manager.start_recording("recording1", 0, 0, 1920, 1080, CaptureFormat.raw, 1000)) |recording_id| {
        _ = recording_id;
        std.debug.assert(manager.is_recording_active());
        const result = manager.stop_recording();
        std.debug.assert(result);
        std.debug.assert(!manager.is_recording_active());
    }
}

test "find capture by ID" {
    var manager = ScreenCaptureManager.init();
    if (manager.capture_screenshot("screenshot1", 0, 0, 1920, 1080, CaptureFormat.png, 1000)) |capture_id| {
        const capture_opt = manager.find_capture(capture_id);
        std.debug.assert(capture_opt != null);
        if (capture_opt) |capture| {
            std.debug.assert(capture.capture_id == capture_id);
            std.debug.assert(capture.capture_type == CaptureType.screenshot);
            std.debug.assert(capture.format == CaptureFormat.png);
        }
    }
}

test "remove capture" {
    var manager = ScreenCaptureManager.init();
    if (manager.capture_screenshot("screenshot1", 0, 0, 1920, 1080, CaptureFormat.png, 1000)) |capture_id| {
        const result = manager.remove_capture(capture_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_capture_count() == 0);
    }
}

test "remove active recording" {
    var manager = ScreenCaptureManager.init();
    if (manager.start_recording("recording1", 0, 0, 1920, 1080, CaptureFormat.raw, 1000)) |recording_id| {
        std.debug.assert(manager.is_recording_active());
        const result = manager.remove_capture(recording_id);
        std.debug.assert(result);
        std.debug.assert(!manager.is_recording_active());
    }
}

test "compositor capture screenshot" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const capture_id_opt = comp.capture_screenshot("screenshot1", 0, 0, 1920, 1080, CaptureFormat.png, 1000);
    std.debug.assert(capture_id_opt != null);
}

test "compositor start recording" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const recording_id_opt = comp.start_screen_recording("recording1", 0, 0, 1920, 1080, CaptureFormat.raw, 1000);
    std.debug.assert(recording_id_opt != null);
    std.debug.assert(comp.is_recording_active());
}

test "compositor stop recording" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.start_screen_recording("recording1", 0, 0, 1920, 1080, CaptureFormat.raw, 1000);
    const result = comp.stop_screen_recording();
    std.debug.assert(result);
    std.debug.assert(!comp.is_recording_active());
}

test "compositor get capture count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_capture_count() == 0);
    _ = comp.capture_screenshot("screenshot1", 0, 0, 1920, 1080, CaptureFormat.png, 1000);
    std.debug.assert(comp.get_capture_count() == 1);
}

test "capture formats" {
    std.debug.assert(@intFromEnum(CaptureFormat.raw) == 0);
    std.debug.assert(@intFromEnum(CaptureFormat.png) == 1);
    std.debug.assert(@intFromEnum(CaptureFormat.jpeg) == 2);
}

test "capture types" {
    std.debug.assert(@intFromEnum(CaptureType.screenshot) == 0);
    std.debug.assert(@intFromEnum(CaptureType.recording) == 1);
}

test "screen capture constants" {
    std.debug.assert(grain_core.screen_capture.MAX_CAPTURES == 16);
    std.debug.assert(grain_core.screen_capture.MAX_CAPTURE_NAME_LEN == 128);
}

