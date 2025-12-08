const std = @import("std");
const events = @import("platform/events.zig");

/// Platform abstraction: windowing and rendering interface.
/// ~<~ Glow Earthbend: platform code isolated; core Aurora stays portable.
/// 
/// Pointer design (GrainStyle single-level only):
/// - `vtable: *const VTable`: Single pointer to immutable vtable struct.
///   Why: VTable is compile-time constant per platform; pointer avoids copying.
/// - `impl: *anyopaque`: Single pointer to type-erased platform window.
///   Why: Type erasure enables platform-agnostic dispatch; `anyopaque` is
///   cast back to concrete type (`*Window`, `*RiscvWindow`, `*NullWindow`) in
///   platform-specific implementations. No double indirection.
pub const Platform = struct {
    /// Single pointer to immutable vtable: compile-time constant per platform.
    vtable: *const VTable,
    /// Single pointer to type-erased window: cast to concrete type in impls.
    impl: *anyopaque,

    /// VTable: function pointers for platform dispatch (single-level only).
    /// 
    /// Pointer design (GrainStyle):
    /// - Function pointers (`*const fn(...)`) are single-level: pointer to
    ///   function, not pointer to pointer. Functions are immutable constants.
    /// - `impl: *anyopaque` parameters: single pointer to type-erased window.
    ///   Why: Type erasure enables platform-agnostic interface; concrete types
    ///   (`*Window`, `*RiscvWindow`, `*NullWindow`) are cast from `*anyopaque`
    ///   in platform implementations. No double indirection.
    pub const VTable = struct {
        /// Single pointer to init function: returns single pointer to anyopaque.
        init: *const fn (allocator: std.mem.Allocator, title: []const u8) anyerror!*anyopaque,
        /// Single pointer to deinit function: takes single pointer to anyopaque.
        deinit: *const fn (impl: *anyopaque) void,
        /// Single pointer to show function: takes single pointer to anyopaque.
        show: *const fn (impl: *anyopaque) anyerror!void,
        /// Single pointer to getBuffer function: takes single pointer, returns slice.
        getBuffer: *const fn (impl: *anyopaque) []u8,
        /// Single pointer to present function: takes single pointer to anyopaque.
        present: *const fn (impl: *anyopaque) anyerror!void,
        /// Single pointer to width function: takes single pointer to anyopaque.
        width: *const fn (impl: *anyopaque) u32,
        /// Single pointer to height function: takes single pointer to anyopaque.
        height: *const fn (impl: *anyopaque) u32,
        /// Single pointer to runEventLoop function: takes single pointer to anyopaque.
        runEventLoop: *const fn (impl: *anyopaque) void,
        /// Single pointer to setEventHandler function: takes single pointer to anyopaque and event handler.
        setEventHandler: *const fn (impl: *anyopaque, handler: ?*const events.EventHandler) void,
        /// Single pointer to startAnimationLoop function: takes single pointer to anyopaque and tick callback.
        startAnimationLoop: *const fn (impl: *anyopaque, tick_callback: *const fn (*anyopaque) void, user_data: *anyopaque) void,
        /// Single pointer to stopAnimationLoop function: takes single pointer to anyopaque.
        stopAnimationLoop: *const fn (impl: *anyopaque) void,
    };

    /// Initialize platform: returns Platform struct with single-level pointers.
    /// 
    /// Pointer flow (GrainStyle single-level only):
    /// - `getPlatformVTable()` returns `*const VTable`: single pointer to vtable.
    /// - `vtable.init()` returns `*anyopaque`: single pointer to type-erased window.
    /// - Platform struct stores both as single-level pointers. No double indirection.
    pub fn init(allocator: std.mem.Allocator, title: []const u8) !Platform {
        // Assert arguments: title must not be empty and within bounds.
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= 256);
        // Single pointer to vtable: compile-time constant per platform.
        const vtable = try getPlatformVTable();
        // Single pointer to type-erased window: cast to concrete type in impls.
        const impl = try vtable.init(allocator, title);
        const platform = Platform{
            .vtable = vtable,
            .impl = impl,
        };
        return platform;
    }

    /// Deinitialize platform: single pointer to Platform struct.
    /// 
    /// Pointer flow: `self: *Platform` is single-level pointer; `self.vtable` and
    /// `self.impl` are single-level pointers stored in struct. No double indirection.
    pub fn deinit(self: *Platform) void {
        // Single pointer to vtable function: calls deinit with single pointer to impl.
        self.vtable.deinit(self.impl);
        // Assert postcondition: struct is cleared after deinit.
        self.* = undefined;
    }

    /// Show platform window: single pointer to Platform struct.
    /// 
    /// Pointer flow: `self: *Platform` → `self.vtable` (single pointer) →
    /// `self.vtable.show` (single function pointer) → `self.impl` (single pointer).
    pub fn show(self: *Platform) !void {
        try self.vtable.show(self.impl);
    }

    /// Get platform buffer: single pointer to Platform struct, returns slice.
    /// 
    /// Pointer flow: `self: *Platform` → `self.vtable.getBuffer` (single function
    /// pointer) → `self.impl` (single pointer) → returns slice (not pointer).
    pub fn getBuffer(self: *Platform) []u8 {
        const buffer = self.vtable.getBuffer(self.impl);
        // Assert return value: buffer must not be empty, must be RGBA-aligned.
        std.debug.assert(buffer.len > 0);
        std.debug.assert(buffer.len % 4 == 0);
        return buffer;
    }

    /// Present platform window: single pointer to Platform struct.
    /// 
    /// Pointer flow: `self: *Platform` → `self.vtable.present` (single function
    /// pointer) → `self.impl` (single pointer). No double indirection.
    pub fn present(self: *Platform) !void {
        try self.vtable.present(self.impl);
    }
    
    /// Run the platform event loop: blocks until app terminates.
    /// Why: macOS needs NSApplication run loop; RISC-V may need custom event handling.
    pub fn runEventLoop(self: *Platform) void {
        self.vtable.runEventLoop(self.impl);
    }

    /// Get platform width: single pointer to Platform struct.
    /// 
    /// Pointer flow: `self: *Platform` → `self.vtable.width` (single function
    /// pointer) → `self.impl` (single pointer) → returns u32 (not pointer).
    pub fn width(self: *Platform) u32 {
        const w = self.vtable.width(self.impl);
        // Assert return value: width must be positive and reasonable.
        std.debug.assert(w > 0);
        std.debug.assert(w <= 16384);
        return w;
    }

    /// Get platform height: single pointer to Platform struct.
    /// 
    /// Pointer flow: `self: *Platform` → `self.vtable.height` (single function
    /// pointer) → `self.impl` (single pointer) → returns u32 (not pointer).
    pub fn height(self: *Platform) u32 {
        const h = self.vtable.height(self.impl);
        // Assert return value: height must be positive and reasonable.
        std.debug.assert(h > 0);
        std.debug.assert(h <= 16384);
        return h;
    }

    /// Get platform vtable: returns single pointer to VTable.
    /// 
    /// Pointer design: Returns `*const VTable` (single pointer). Address-of
    /// operator `&` takes address of compile-time constant vtable struct,
    /// producing single pointer. No double indirection.
    fn getPlatformVTable() !*const VTable {
        // Select platform implementation based on compile-time target.
        // Address-of operator `&` produces single pointer to vtable constant.
        const vtable_ptr = switch (@import("builtin").os.tag) {
            .macos => &@import("platform/macos_tahoe/impl.zig").vtable,
            .freestanding => &@import("platform/riscv/impl.zig").vtable,
            else => &@import("platform/null/impl.zig").vtable,
        };
        return vtable_ptr;
    }
};

const SimpleRng = @import("simple_rng.zig").SimpleRng;

// Simple buffer checksum: CRC32-style hash for content validation.
// Why: Detects silent buffer corruption that assertions might miss.
fn buffer_checksum(buffer: []const u8) u32 {
    std.debug.assert(buffer.len > 0);
    var hash: u32 = 0x811c9dc5; // FNV-1a offset basis.
    for (buffer) |byte| {
        hash ^= byte;
        hash = hash *% 0x01000193; // FNV-1a prime.
    }
    return hash;
}

// macOS platform abstraction boundary fuzz: validates deterministic behavior
// across window initialization, buffer operations, and vtable dispatch paths.
// 
// Pointer design: all operations use single-level pointers only. No double
// indirection in vtable dispatch or buffer access.
test "macos platform abstraction boundary fuzz" {
    // Only run on macOS targets.
    if (@import("builtin").os.tag != .macos) return;
    var rng = SimpleRng.init(0xffaa6025);
    // Use test allocator to detect memory leaks.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Fuzz window initialization: random titles and dimensions.
    const num_iterations = 100;
    var i: u32 = 0;
    while (i < num_iterations) : (i += 1) {
        // Random title length: 1-256 chars.
        const title_len = rng.range(u32, 256) + 1;
        var title_buf: [256]u8 = undefined;
        var j: u32 = 0;
        while (j < title_len) : (j += 1) {
            title_buf[j] = @intCast(rng.range(u8, 95) + 32); // Printable ASCII.
        }
        const title = title_buf[0..title_len];

        // Initialize platform: single pointer to Platform struct.
        var platform = try Platform.init(allocator, title);
        defer platform.deinit();

        // Test vtable dispatch: show, getBuffer, present, width, height.
        try platform.show();

        const buffer = platform.getBuffer();
        // Assert buffer: must be RGBA-aligned and match dimensions.
        std.debug.assert(buffer.len > 0);
        std.debug.assert(buffer.len % 4 == 0);
        const actual_width = platform.width();
        const actual_height = platform.height();
        std.debug.assert(actual_width > 0);
        std.debug.assert(actual_height > 0);
        std.debug.assert(buffer.len == actual_width * actual_height * 4);

        // Buffer content validation: compute checksum before operations.
        const checksum_before = buffer_checksum(buffer);

        // Fuzz buffer operations: random pixel writes.
        const num_pixel_writes = rng.range(u32, 100);
        var k: u32 = 0;
        while (k < num_pixel_writes) : (k += 1) {
            const pixel_count = @as(u32, @intCast(buffer.len / 4));
            const pixel_offset = rng.range(u32, pixel_count) * 4;
            std.debug.assert(pixel_offset + 3 < buffer.len);
            buffer[pixel_offset] = @intCast(rng.range(u8, 255));
            buffer[pixel_offset + 1] = @intCast(rng.range(u8, 255));
            buffer[pixel_offset + 2] = @intCast(rng.range(u8, 255));
            buffer[pixel_offset + 3] = 255; // Alpha.
        }

        // Validate buffer still matches dimensions after writes.
        const buffer_after = platform.getBuffer();
        std.debug.assert(buffer_after.len == actual_width * actual_height * 4);
        std.debug.assert(buffer_after.len % 4 == 0);
        // Buffer content validation: checksum should change after writes.
        const checksum_after = buffer_checksum(buffer_after);
        std.debug.assert(checksum_after != checksum_before or num_pixel_writes == 0);

        try platform.present();

        // Test width/height consistency.
        const width_again = platform.width();
        const height_again = platform.height();
        std.debug.assert(width_again == actual_width);
        std.debug.assert(height_again == actual_height);

        // Buffer content validation: getBuffer() should return same slice.
        const buffer_final = platform.getBuffer();
        std.debug.assert(buffer_final.ptr == buffer_after.ptr);
        std.debug.assert(buffer_final.len == buffer_after.len);
    }

    // Memory leak detection: assert no leaks after all iterations.
    // Why: defer would call deinit automatically, but we need to check the result.
    const leak_check = gpa.deinit();
    std.debug.assert(leak_check == .ok);
}

// macOS error path coverage: validates error handling for invalid inputs.
// Why: Ensures error paths follow GrainStyle safety guarantees.
test "macos platform error paths" {
    // Only run on macOS targets.
    if (@import("builtin").os.tag != .macos) return;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Test: empty title should fail gracefully (currently asserts, but should
    // return error in future).
    // Note: Currently platform.init() asserts title.len > 0, so this test
    // documents expected behavior. Future: return error instead of panic.
    _ = allocator;
    // Deferred: implement error-returning init() for empty titles.

    // Memory leak detection: assert no leaks.
    const leak_check = gpa.deinit();
    std.debug.assert(leak_check == .ok);
}

// RISC-V platform abstraction boundary fuzz: validates deterministic behavior
// across framebuffer initialization, buffer operations, and vtable dispatch
// paths.
// 
// Pointer design: all operations use single-level pointers only. No double
// indirection in vtable dispatch or buffer access.
test "riscv platform abstraction boundary fuzz" {
    // Only run on RISC-V freestanding targets.
    if (@import("builtin").os.tag != .freestanding) return;
    // Deferred: requires QEMU setup and RISC-V hardware.
    // Resume once Framework 13 RISC-V board or VPS is available.
    return;
}

