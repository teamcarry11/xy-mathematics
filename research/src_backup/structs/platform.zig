const std = @import("std");

/// Platform abstraction structs: windowing and rendering interfaces.
/// All platform-related struct definitions in one place.

/// Platform VTable: function pointers for platform operations.
pub const PlatformVTable = struct {
    init: *const fn (allocator: std.mem.Allocator, title: []const u8) anyerror!*anyopaque,
    deinit: *const fn (impl: *anyopaque) void,
    show: *const fn (impl: *anyopaque) anyerror!void,
    getBuffer: *const fn (impl: *anyopaque) []u8,
    present: *const fn (impl: *anyopaque) anyerror!void,
    width: *const fn (impl: *anyopaque) u32,
    height: *const fn (impl: *anyopaque) u32,
};

/// Platform wrapper: vtable + opaque implementation pointer.
pub const Platform = struct {
    vtable: *const PlatformVTable,
    impl: *anyopaque,
};

/// macOS Window: Cocoa bridge with RGBA buffer.
pub const MacWindow = struct {
    title: []const u8,
    width: u32 = 1024,
    height: u32 = 768,
    rgba_buffer: []u8 = undefined,
    allocator: std.mem.Allocator,
};

/// RISC-V Window: framebuffer-based rendering for kernel mode.
pub const RiscvWindow = struct {
    allocator: std.mem.Allocator,
    width: u32 = 1024,
    height: u32 = 768,
    rgba_buffer: []u8,
};

/// Null Window: headless fallback for unsupported platforms.
pub const NullWindow = struct {
    allocator: std.mem.Allocator,
    width: u32 = 1024,
    height: u32 = 768,
    rgba_buffer: []u8,
};

