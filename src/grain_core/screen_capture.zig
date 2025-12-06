//! Grain OS Screen Capture: Screenshot and screen recording.
//!
//! Why: Provide screen capture functionality for screenshots and recordings.
//! Architecture: Framebuffer capture, image formats, capture regions.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max capture history.
pub const MAX_CAPTURES: u32 = 16;

// Bounded: Max capture name length.
pub const MAX_CAPTURE_NAME_LEN: u32 = 128;

// Capture format.
pub const CaptureFormat = enum(u8) {
    raw,
    png,
    jpeg,
};

// Capture type.
pub const CaptureType = enum(u8) {
    screenshot,
    recording,
};

// Capture: represents a screen capture.
pub const Capture = struct {
    capture_id: u32,
    capture_type: CaptureType,
    format: CaptureFormat,
    name: [MAX_CAPTURE_NAME_LEN]u8,
    name_len: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    timestamp: u64,
    active: bool,

    pub fn init() Capture {
        var capture = Capture{
            .capture_id = 0,
            .capture_type = CaptureType.screenshot,
            .format = CaptureFormat.raw,
            .name = undefined,
            .name_len = 0,
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .timestamp = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_CAPTURE_NAME_LEN) : (i += 1) {
            capture.name[i] = 0;
        }
        return capture;
    }
};

// Screen capture manager: manages screen captures.
pub const ScreenCaptureManager = struct {
    captures: [MAX_CAPTURES]Capture,
    captures_len: u32,
    next_capture_id: u32,
    recording_active: bool,
    current_recording_id: u32,

    pub fn init() ScreenCaptureManager {
        var manager = ScreenCaptureManager{
            .captures = undefined,
            .captures_len = 0,
            .next_capture_id = 1,
            .recording_active = false,
            .current_recording_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_CAPTURES) : (i += 1) {
            manager.captures[i] = Capture.init();
        }
        return manager;
    }

    // Capture screenshot.
    pub fn capture_screenshot(
        self: *ScreenCaptureManager,
        name: []const u8,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        format: CaptureFormat,
        timestamp: u64,
    ) ?u32 {
        if (self.captures_len >= MAX_CAPTURES) {
            return null;
        }
        if (name.len > MAX_CAPTURE_NAME_LEN) {
            return null;
        }
        const capture_id = self.next_capture_id;
        self.next_capture_id += 1;
        self.captures[self.captures_len] = Capture.init();
        self.captures[self.captures_len].capture_id = capture_id;
        self.captures[self.captures_len].capture_type = CaptureType.screenshot;
        self.captures[self.captures_len].format = format;
        self.captures[self.captures_len].x = x;
        self.captures[self.captures_len].y = y;
        self.captures[self.captures_len].width = width;
        self.captures[self.captures_len].height = height;
        self.captures[self.captures_len].timestamp = timestamp;
        self.captures[self.captures_len].active = true;
        var i: u32 = 0;
        while (i < MAX_CAPTURE_NAME_LEN) : (i += 1) {
            self.captures[self.captures_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_CAPTURE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.captures[self.captures_len].name[i] = name[i];
        }
        self.captures[self.captures_len].name_len = @intCast(name_len);
        self.captures_len += 1;
        return capture_id;
    }

    // Start recording.
    pub fn start_recording(
        self: *ScreenCaptureManager,
        name: []const u8,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
        format: CaptureFormat,
        timestamp: u64,
    ) ?u32 {
        if (self.recording_active) {
            return null;
        }
        if (self.captures_len >= MAX_CAPTURES) {
            return null;
        }
        if (name.len > MAX_CAPTURE_NAME_LEN) {
            return null;
        }
        const capture_id = self.next_capture_id;
        self.next_capture_id += 1;
        self.captures[self.captures_len] = Capture.init();
        self.captures[self.captures_len].capture_id = capture_id;
        self.captures[self.captures_len].capture_type = CaptureType.recording;
        self.captures[self.captures_len].format = format;
        self.captures[self.captures_len].x = x;
        self.captures[self.captures_len].y = y;
        self.captures[self.captures_len].width = width;
        self.captures[self.captures_len].height = height;
        self.captures[self.captures_len].timestamp = timestamp;
        self.captures[self.captures_len].active = true;
        var i: u32 = 0;
        while (i < MAX_CAPTURE_NAME_LEN) : (i += 1) {
            self.captures[self.captures_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_CAPTURE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.captures[self.captures_len].name[i] = name[i];
        }
        self.captures[self.captures_len].name_len = @intCast(name_len);
        self.captures_len += 1;
        self.recording_active = true;
        self.current_recording_id = capture_id;
        return capture_id;
    }

    // Stop recording.
    pub fn stop_recording(self: *ScreenCaptureManager) bool {
        if (!self.recording_active) {
            return false;
        }
        self.recording_active = false;
        self.current_recording_id = 0;
        return true;
    }

    // Find capture by ID.
    pub fn find_capture(
        self: *ScreenCaptureManager,
        capture_id: u32,
    ) ?*Capture {
        std.debug.assert(capture_id > 0);
        var i: u32 = 0;
        while (i < self.captures_len) : (i += 1) {
            if (self.captures[i].capture_id == capture_id and self.captures[i].active) {
                return &self.captures[i];
            }
        }
        return null;
    }

    // Remove capture.
    pub fn remove_capture(self: *ScreenCaptureManager, capture_id: u32) bool {
        std.debug.assert(capture_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.captures_len) : (i += 1) {
            if (self.captures[i].capture_id == capture_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        if (self.current_recording_id == capture_id) {
            self.recording_active = false;
            self.current_recording_id = 0;
        }
        // Shift remaining captures left.
        while (i < self.captures_len - 1) : (i += 1) {
            self.captures[i] = self.captures[i + 1];
        }
        self.captures_len -= 1;
        return true;
    }

    // Check if recording is active.
    pub fn is_recording_active(self: *const ScreenCaptureManager) bool {
        return self.recording_active;
    }

    // Get current recording ID.
    pub fn get_current_recording_id(self: *const ScreenCaptureManager) ?u32 {
        if (self.recording_active) {
            return self.current_recording_id;
        }
        return null;
    }

    // Get capture count.
    pub fn get_capture_count(self: *const ScreenCaptureManager) u32 {
        return self.captures_len;
    }
};

