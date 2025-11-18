const std = @import("std");
const Platform = @import("../../platform.zig").Platform;

/// Null platform implementation: headless fallback for unsupported platforms.
pub const vtable = Platform.VTable{
    .init = init,
    .deinit = deinit,
    .show = show,
    .getBuffer = getBuffer,
    .present = present,
    .width = width,
    .height = height,
    .runEventLoop = runEventLoop,
};

/// NullWindow: headless window implementation for unsupported platforms.
/// 
/// Pointer design (GrainStyle single-level only):
/// - `rgba_buffer: []u8`: slice (pointer + length), not pointer to pointer.
/// - Methods take `self: *NullWindow`: single pointer to struct. No double indirection.
pub const NullWindow = struct {
    allocator: std.mem.Allocator,
    width: u32 = 1024,
    height: u32 = 768,
    /// Slice (pointer + length) to RGBA buffer: single-level pointer, not pointer to pointer.
    rgba_buffer: []u8,

    /// Initialize null window: returns value struct, not pointer.
    /// 
    /// Pointer design: `allocator.alloc(u8, ...)` returns `[]u8` (slice, single-level
    /// pointer). No double indirection. Return type is value struct, not pointer.
    pub fn init(allocator: std.mem.Allocator, title: []const u8) !NullWindow {
        _ = title;
        // Assert compile-time constants: dimensions must be positive.
        std.debug.assert(@as(u32, 1024) > 0);
        std.debug.assert(@as(u32, 768) > 0);
        const buffer_size = 1024 * 768 * 4;
        std.debug.assert(buffer_size > 0);
        std.debug.assert(buffer_size % 4 == 0);
        const rgba_buffer = try allocator.alloc(u8, buffer_size);
        // Assert allocation: buffer must be correct size.
        std.debug.assert(rgba_buffer.len == buffer_size);
        @memset(rgba_buffer, 0);
        const window = NullWindow{
            .allocator = allocator,
            .rgba_buffer = rgba_buffer,
        };
        // Assert postcondition: all fields must be initialized.
        std.debug.assert(window.rgba_buffer.len == buffer_size);
        std.debug.assert(window.width == 1024);
        std.debug.assert(window.height == 768);
        return window;
    }

    /// Deinitialize null window: single pointer to struct.
    /// 
    /// Pointer flow: `self: *NullWindow` (single pointer) → `self.rgba_buffer` (slice,
    /// single-level pointer) → `self.allocator.free()` (takes slice, not pointer to pointer).
    pub fn deinit(self: *NullWindow) void {
        // Assert precondition: buffer must be valid before freeing.
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        // Free slice: single-level pointer passed to allocator.
        self.allocator.free(self.rgba_buffer);
        // Assert postcondition: struct is cleared.
        self.* = undefined;
    }

    /// Show null window: single pointer to struct.
    /// 
    /// Pointer flow: `self: *NullWindow` (single pointer). No double indirection.
    pub fn show(self: *NullWindow) !void {
        // Assert invariant: window must have valid buffer.
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.width > 0);
        std.debug.assert(self.height > 0);
    }

    /// Get null window buffer: single pointer to struct, returns slice.
    /// 
    /// Pointer flow: `self: *NullWindow` (single pointer) → `self.rgba_buffer` (slice,
    /// single-level pointer) → returns slice (not pointer to pointer).
    pub fn getBuffer(self: *NullWindow) []u8 {
        // Assert precondition: buffer must be initialized.
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        // Return slice: single-level pointer, not pointer to pointer.
        const buffer = self.rgba_buffer;
        // Assert return value: buffer must match dimensions.
        std.debug.assert(buffer.len == self.width * self.height * 4);
        return buffer;
    }

    /// Present null window: single pointer to struct.
    /// 
    /// Pointer flow: `self: *NullWindow` (single pointer). No double indirection.
    pub fn present(self: *NullWindow) !void {
        // Assert invariant: window must have valid buffer.
        std.debug.assert(self.rgba_buffer.len > 0);
    }
};

/// Initialize null platform window: returns single pointer to type-erased window.
/// 
/// Pointer design (GrainStyle single-level only):
/// - `allocator.create(NullWindow)` returns `*NullWindow`: single pointer.
/// - Return type `*anyopaque`: single pointer to type-erased window.
/// - Cast from `*NullWindow` to `*anyopaque` is single-level; no double indirection.
fn init(allocator: std.mem.Allocator, title: []const u8) !*anyopaque {
    // Assert arguments: title length must be within bounds.
    std.debug.assert(title.len <= 256);
    // Single pointer to NullWindow: allocated on heap, returned as single pointer.
    const window = try allocator.create(NullWindow);
    window.* = try NullWindow.init(allocator, title);
    // Assert postcondition: window must be initialized.
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    // Cast single pointer from concrete type to type-erased: single-level only.
    return window;
}

/// Deinitialize null platform window: single pointer to type-erased window.
/// 
/// Pointer design (GrainStyle single-level only):
/// - `impl: *anyopaque`: single pointer to type-erased window.
/// - `@ptrCast(@alignCast(impl))`: casts single pointer to `*NullWindow`.
/// - Cast is single-level; no double indirection. Both pointers are same level.
fn deinit(impl: *anyopaque) void {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    // Assert invariant: window must have valid buffer before deinit.
    std.debug.assert(window.rgba_buffer.len > 0);
    // Save allocator before deinit clears the struct.
    const allocator = window.allocator;
    window.deinit();
    allocator.destroy(window);
}

/// Show null platform window: single pointer to type-erased window.
/// 
/// Pointer flow: `impl: *anyopaque` (single pointer) → cast to `*NullWindow`
/// (single pointer). Both are same level; no double indirection.
fn show(impl: *anyopaque) !void {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    // Assert invariant: window must have valid buffer.
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    try window.show();
}

/// Get null platform buffer: single pointer to type-erased window, returns slice.
/// 
/// Pointer flow: `impl: *anyopaque` (single pointer) → cast to `*NullWindow`
/// (single pointer) → returns slice (not pointer). No double indirection.
fn getBuffer(impl: *anyopaque) []u8 {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    const buffer = window.getBuffer();
    // Assert return value: buffer must be RGBA-aligned and match dimensions.
    std.debug.assert(buffer.len > 0);
    std.debug.assert(buffer.len % 4 == 0);
    std.debug.assert(buffer.len == window.width * window.height * 4);
    return buffer;
}

/// Present null platform window: single pointer to type-erased window.
/// 
/// Pointer flow: `impl: *anyopaque` (single pointer) → cast to `*NullWindow`
/// (single pointer). Both are same level; no double indirection.
fn present(impl: *anyopaque) !void {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    // Assert invariant: window must have valid buffer.
    std.debug.assert(window.rgba_buffer.len > 0);
    try window.present();
}

/// Get null platform width: single pointer to type-erased window, returns u32.
/// 
/// Pointer flow: `impl: *anyopaque` (single pointer) → cast to `*NullWindow`
/// (single pointer) → returns u32 (not pointer). No double indirection.
fn width(impl: *anyopaque) u32 {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    const w = window.width;
    // Assert return value: width must be positive and reasonable.
    std.debug.assert(w > 0);
    std.debug.assert(w <= 16384);
    return w;
}

/// Get null platform height: single pointer to type-erased window, returns u32.
/// 
/// Pointer flow: `impl: *anyopaque` (single pointer) → cast to `*NullWindow`
/// (single pointer) → returns u32 (not pointer). No double indirection.
fn height(impl: *anyopaque) u32 {
    // Cast single pointer from type-erased to concrete type: single-level only.
    const window: *NullWindow = @ptrCast(@alignCast(impl));
    const h = window.height;
    // Assert return value: height must be positive and reasonable.
    std.debug.assert(h > 0);
    std.debug.assert(h <= 16384);
    return h;
}

/// Run null platform event loop: no-op.
/// Why: Platform abstraction requires vtable dispatch; null platform has no events.
fn runEventLoop(impl: *anyopaque) void {
    _ = impl;
    // Null platform: no-op.
}

