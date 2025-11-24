//! Wayland protocol: Core structures for Wayland compositor.
//!
//! Why: Implement Wayland protocol for window management.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max number of Wayland objects per client.
pub const MAX_OBJECTS_PER_CLIENT: u32 = 1024;

// Bounded: Max number of clients connected.
pub const MAX_CLIENTS: u32 = 64;

// Bounded: Max surface width/height (in pixels).
pub const MAX_SURFACE_WIDTH: u32 = 8192;
pub const MAX_SURFACE_HEIGHT: u32 = 8192;

// Wayland object ID type (32-bit unsigned integer).
pub const ObjectId = u32;

// Wayland interface name (bounded string).
pub const InterfaceName = struct {
    data: [64]u8,
    len: u32,

    pub fn init(name: []const u8) InterfaceName {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= 64);
        var result = InterfaceName{
            .data = undefined,
            .len = @intCast(name.len),
        };
        var i: u32 = 0;
        while (i < 64) : (i += 1) {
            result.data[i] = 0;
        }
        i = 0;
        while (i < name.len) : (i += 1) {
            result.data[i] = name[i];
        }
        std.debug.assert(result.len <= 64);
        return result;
    }

    pub fn as_slice(self: *const InterfaceName) []const u8 {
        return self.data[0..self.len];
    }
};

// Wayland object: base structure for all Wayland objects.
pub const Object = struct {
    id: ObjectId,
    interface: InterfaceName,
    version: u32,

    pub fn init(id: ObjectId, interface: InterfaceName, version: u32) Object {
        std.debug.assert(id > 0);
        std.debug.assert(version > 0);
        std.debug.assert(version <= 10);
        const obj = Object{
            .id = id,
            .interface = interface,
            .version = version,
        };
        std.debug.assert(obj.id > 0);
        return obj;
    }
};

// Surface: represents a drawable area (window content).
pub const Surface = struct {
    object: Object,
    width: u32,
    height: u32,
    buffer: ?[]u8,

    pub fn init(id: ObjectId, width: u32, height: u32) Surface {
        std.debug.assert(id > 0);
        std.debug.assert(width > 0);
        std.debug.assert(width <= MAX_SURFACE_WIDTH);
        std.debug.assert(height > 0);
        std.debug.assert(height <= MAX_SURFACE_HEIGHT);
        const surface = Surface{
            .object = Object.init(id, InterfaceName.init("wl_surface"), 4),
            .width = width,
            .height = height,
            .buffer = null,
        };
        std.debug.assert(surface.width > 0);
        std.debug.assert(surface.height > 0);
        return surface;
    }
};

// Output: represents a display/monitor.
pub const Output = struct {
    object: Object,
    width: u32,
    height: u32,
    physical_width: u32,
    physical_height: u32,

    pub fn init(
        id: ObjectId,
        width: u32,
        height: u32,
        physical_width: u32,
        physical_height: u32,
    ) Output {
        std.debug.assert(id > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        const output = Output{
            .object = Object.init(id, InterfaceName.init("wl_output"), 4),
            .width = width,
            .height = height,
            .physical_width = physical_width,
            .physical_height = physical_height,
        };
        std.debug.assert(output.width > 0);
        std.debug.assert(output.height > 0);
        return output;
    }
};

// Seat: represents input devices (keyboard, mouse, touch).
pub const Seat = struct {
    object: Object,
    has_keyboard: bool,
    has_pointer: bool,
    has_touch: bool,

    pub fn init(id: ObjectId) Seat {
        std.debug.assert(id > 0);
        const seat = Seat{
            .object = Object.init(id, InterfaceName.init("wl_seat"), 7),
            .has_keyboard = true,
            .has_pointer = true,
            .has_touch = false,
        };
        std.debug.assert(seat.object.id > 0);
        return seat;
    }
};

// Registry: global object registry for Wayland protocol.
pub const Registry = struct {
    object: Object,
    objects: [MAX_OBJECTS_PER_CLIENT]Object,
    objects_len: u32,

    pub fn init(id: ObjectId) Registry {
        std.debug.assert(id > 0);
        var registry = Registry{
            .object = Object.init(id, InterfaceName.init("wl_registry"), 1),
            .objects = undefined,
            .objects_len = 0,
        };
        var i: u32 = 0;
        while (i < MAX_OBJECTS_PER_CLIENT) : (i += 1) {
            registry.objects[i] = Object.init(0, InterfaceName.init(""), 0);
        }
        std.debug.assert(registry.object.id > 0);
        return registry;
    }

    pub fn bind(
        self: *Registry,
        name: u32,
        interface: InterfaceName,
        version: u32,
    ) !ObjectId {
        std.debug.assert(name > 0);
        std.debug.assert(version > 0);
        std.debug.assert(self.objects_len < MAX_OBJECTS_PER_CLIENT);
        const new_id: ObjectId = self.objects_len + 1;
        self.objects[self.objects_len] = Object.init(new_id, interface, version);
        self.objects_len += 1;
        std.debug.assert(self.objects_len <= MAX_OBJECTS_PER_CLIENT);
        return new_id;
    }
};

