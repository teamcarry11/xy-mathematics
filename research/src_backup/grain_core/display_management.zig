//! Grain OS Display Management: Multi-monitor support and display configuration.
//!
//! Why: Provide multi-monitor support and display configuration management.
//! Architecture: Display detection, configuration, layout management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max displays.
pub const MAX_DISPLAYS: u32 = 8;

// Bounded: Max display name length.
pub const MAX_DISPLAY_NAME_LEN: u32 = 64;

// Display connection type.
pub const DisplayConnection = enum(u8) {
    unknown,
    internal,
    hdmi,
    displayport,
    vga,
    dvi,
    usb_c,
};

// Display state.
pub const DisplayState = enum(u8) {
    disconnected,
    connected,
    active,
    disabled,
};

// Display: represents a physical display.
pub const Display = struct {
    display_id: u32,
    name: [MAX_DISPLAY_NAME_LEN]u8,
    name_len: u32,
    width: u32,
    height: u32,
    x: i32,
    y: i32,
    connection: DisplayConnection,
    state: DisplayState,
    primary: bool,
    active: bool,

    pub fn init() Display {
        var display = Display{
            .display_id = 0,
            .name = undefined,
            .name_len = 0,
            .width = 0,
            .height = 0,
            .x = 0,
            .y = 0,
            .connection = DisplayConnection.unknown,
            .state = DisplayState.disconnected,
            .primary = false,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_DISPLAY_NAME_LEN) : (i += 1) {
            display.name[i] = 0;
        }
        return display;
    }
};

// Display manager: manages multiple displays.
pub const DisplayManager = struct {
    displays: [MAX_DISPLAYS]Display,
    displays_len: u32,
    next_display_id: u32,
    primary_display_id: u32,

    pub fn init() DisplayManager {
        var manager = DisplayManager{
            .displays = undefined,
            .displays_len = 0,
            .next_display_id = 1,
            .primary_display_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_DISPLAYS) : (i += 1) {
            manager.displays[i] = Display.init();
        }
        return manager;
    }

    // Add display.
    pub fn add_display(
        self: *DisplayManager,
        name: []const u8,
        width: u32,
        height: u32,
        connection: DisplayConnection,
    ) ?u32 {
        if (self.displays_len >= MAX_DISPLAYS) {
            return null;
        }
        if (name.len > MAX_DISPLAY_NAME_LEN) {
            return null;
        }
        const display_id = self.next_display_id;
        self.next_display_id += 1;
        self.displays[self.displays_len] = Display.init();
        self.displays[self.displays_len].display_id = display_id;
        self.displays[self.displays_len].width = width;
        self.displays[self.displays_len].height = height;
        self.displays[self.displays_len].connection = connection;
        self.displays[self.displays_len].state = DisplayState.connected;
        self.displays[self.displays_len].active = true;
        var i: u32 = 0;
        while (i < MAX_DISPLAY_NAME_LEN) : (i += 1) {
            self.displays[self.displays_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_DISPLAY_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.displays[self.displays_len].name[i] = name[i];
        }
        self.displays[self.displays_len].name_len = @intCast(name_len);
        if (self.primary_display_id == 0) {
            self.primary_display_id = display_id;
            self.displays[self.displays_len].primary = true;
        }
        self.displays_len += 1;
        return display_id;
    }

    // Find display by ID.
    pub fn find_display(
        self: *DisplayManager,
        display_id: u32,
    ) ?*Display {
        std.debug.assert(display_id > 0);
        var i: u32 = 0;
        while (i < self.displays_len) : (i += 1) {
            if (self.displays[i].display_id == display_id) {
                return &self.displays[i];
            }
        }
        return null;
    }

    // Remove display.
    pub fn remove_display(self: *DisplayManager, display_id: u32) bool {
        std.debug.assert(display_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.displays_len) : (i += 1) {
            if (self.displays[i].display_id == display_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        const was_primary = self.displays[i].primary;
        // Shift remaining displays left.
        while (i < self.displays_len - 1) : (i += 1) {
            self.displays[i] = self.displays[i + 1];
        }
        self.displays_len -= 1;
        if (was_primary and self.displays_len > 0) {
            self.primary_display_id = self.displays[0].display_id;
            self.displays[0].primary = true;
        } else if (self.displays_len == 0) {
            self.primary_display_id = 0;
        }
        return true;
    }

    // Set display position.
    pub fn set_display_position(
        self: *DisplayManager,
        display_id: u32,
        x: i32,
        y: i32,
    ) bool {
        std.debug.assert(display_id > 0);
        if (self.find_display(display_id)) |display| {
            display.x = x;
            display.y = y;
            return true;
        }
        return false;
    }

    // Set display as primary.
    pub fn set_primary_display(self: *DisplayManager, display_id: u32) bool {
        std.debug.assert(display_id > 0);
        if (self.find_display(display_id)) |display| {
            // Clear primary flag from all displays.
            var i: u32 = 0;
            while (i < self.displays_len) : (i += 1) {
                self.displays[i].primary = false;
            }
            display.primary = true;
            self.primary_display_id = display_id;
            return true;
        }
        return false;
    }

    // Enable display.
    pub fn enable_display(self: *DisplayManager, display_id: u32) bool {
        std.debug.assert(display_id > 0);
        if (self.find_display(display_id)) |display| {
            display.active = true;
            display.state = DisplayState.active;
            return true;
        }
        return false;
    }

    // Disable display.
    pub fn disable_display(self: *DisplayManager, display_id: u32) bool {
        std.debug.assert(display_id > 0);
        if (self.find_display(display_id)) |display| {
            display.active = false;
            display.state = DisplayState.disconnected;
            return true;
        }
        return false;
    }

    // Get primary display.
    pub fn get_primary_display(self: *const DisplayManager) ?*const Display {
        if (self.primary_display_id == 0) {
            return null;
        }
        var i: u32 = 0;
        while (i < self.displays_len) : (i += 1) {
            if (self.displays[i].display_id == self.primary_display_id) {
                return &self.displays[i];
            }
        }
        return null;
    }

    // Get display count.
    pub fn get_display_count(self: *const DisplayManager) u32 {
        return self.displays_len;
    }

    // Get active display count.
    pub fn get_active_display_count(self: *const DisplayManager) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.displays_len) : (i += 1) {
            if (self.displays[i].active) {
                count += 1;
            }
        }
        return count;
    }
};

