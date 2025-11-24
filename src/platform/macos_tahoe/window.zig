const std = @import("std");
const c = @import("objc_runtime.zig").c;
const cg = @import("objc_runtime.zig").cg;
const cocoa = @import("cocoa_bridge.zig");
const events = @import("../events.zig");

// C helper function to create NSImage from CGImage.
extern fn createNSImageFromCGImage(cgImage: *anyopaque, width: f64, height: f64) ?*c.objc_object;

/// Thin Cocoa bridge: Aurora owns the RGBA buffer; Cocoa just hosts the view.
/// ~<~ Glow Airbend: explicit allocations prevent dynamic Cocoa leaks into Zig runtime.
/// 
/// Pointer design (GrainStyle single-level only):
/// - `ns_window: ?*c.objc_object`: Single pointer to NSWindow (nullable for cleanup).
/// - `ns_view: ?*c.objc_object`: Single pointer to NSView (nullable for cleanup).
/// - `ns_app: ?*c.objc_object`: Single pointer to NSApplication shared instance (nullable for cleanup).
/// - `rgba_buffer`: Static array, no pointers needed.

/// Buffer dimensions (static, always 1024x768).
const BUFFER_WIDTH: u32 = 1024;
const BUFFER_HEIGHT: u32 = 768;

pub const Window = struct {
    title: []const u8,
    /// Window dimensions (can change on resize).
    width: u32 = 1024,
    height: u32 = 768,
    /// Static buffer for RGBA pixels: avoids dynamic allocation.
    /// Size: 1024 * 768 * 4 = 3,145,728 bytes (3MB).
    /// Why: Static allocation eliminates allocator dependency and reduces runtime overhead.
    /// Note: Buffer size is fixed; window can resize and NSImageView will scale.
    rgba_buffer: [BUFFER_WIDTH * BUFFER_HEIGHT * 4]u8 = [_]u8{0} ** (BUFFER_WIDTH * BUFFER_HEIGHT * 4),
    allocator: std.mem.Allocator,
    /// Single pointer to NSWindow: nullable for cleanup safety.
    ns_window: ?*c.objc_object = null,
    /// Single pointer to NSView: nullable for cleanup safety.
    /// Note: This is TahoeView (content view, handles events).
    ns_view: ?*c.objc_object = null,
    /// Single pointer to NSImageView: nullable for cleanup safety.
    /// Why: Store reference to avoid subviews lookup in present().
    ns_image_view: ?*c.objc_object = null,
    /// Single pointer to NSApplication shared instance: nullable for cleanup safety.
    ns_app: ?*c.objc_object = null,
    /// Optional event handler: nullable if no handler set.
    event_handler: ?*const events.EventHandler = null,
    /// Single pointer to window delegate object (for event handling).
    window_delegate: ?*c.objc_object = null,
    /// Single pointer to view delegate object (for mouse/keyboard events).
    view_delegate: ?*c.objc_object = null,
    /// Single pointer to NSTimer object (for animation loop).
    animation_timer: ?*c.objc_object = null,
    /// Tick callback function pointer (called by timer).
    tick_callback: ?*const fn (*anyopaque) void = null,
    /// User data pointer for tick callback (typically *TahoeSandbox).
    tick_user_data: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, title: []const u8) Self {
        // Assert: title must be valid (non-empty, reasonable length).
        std.debug.assert(title.len > 0);
        std.debug.assert(title.len <= 1024);
        
        // Assert: allocator must be valid (non-null pointer).
        const allocator_ptr = @intFromPtr(allocator.ptr);
        std.debug.assert(allocator_ptr != 0);
        
        const self = Self{
            .title = title,
            .allocator = allocator,
            .width = 1024,
            .height = 768,
            .rgba_buffer = [_]u8{0} ** (1024 * 768 * 4),
            .ns_window = null,
            .ns_view = null,
            .ns_image_view = null,
            .ns_app = null,
        };
        
        // Assert postcondition: dimensions must be valid.
        std.debug.assert(self.width > 0);
        std.debug.assert(self.height > 0);
        std.debug.assert(self.width <= 1024);
        std.debug.assert(self.height <= 768);
        
        // Assert: buffer size matches dimensions.
        const expected_buffer_size = @as(usize, self.width) * @as(usize, self.height) * 4;
        std.debug.assert(self.rgba_buffer.len == expected_buffer_size);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Assert precondition: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        
        // Assert precondition: buffer must be valid.
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        const expected_buffer_size = @as(usize, self.width) * @as(usize, self.height) * 4;
        std.debug.assert(self.rgba_buffer.len == expected_buffer_size);
        
        // Release Cocoa objects: single pointers, explicit cleanup.
        // Why: Explicit cleanup prevents memory leaks, validates pointers before release.
        if (self.ns_image_view) |imageView| {
            const imageViewPtrValue = @intFromPtr(imageView);
            std.debug.assert(imageViewPtrValue != 0);
            if (imageViewPtrValue < 0x1000) {
                std.debug.panic("Window.deinit: ns_image_view pointer is suspiciously small: 0x{x}", .{imageViewPtrValue});
            }
            const releaseSel = c.sel_getUid("release");
            std.debug.assert(releaseSel != null);
            cocoa.objc_msgSendVoid0(@ptrCast(imageView), releaseSel);
        }
        if (self.ns_view) |view| {
            const viewPtrValue = @intFromPtr(view);
            std.debug.assert(viewPtrValue != 0);
            if (viewPtrValue < 0x1000) {
                std.debug.panic("Window.deinit: ns_view pointer is suspiciously small: 0x{x}", .{viewPtrValue});
            }
            const releaseSel = c.sel_getUid("release");
            std.debug.assert(releaseSel != null);
            cocoa.objc_msgSendVoid0(@ptrCast(view), releaseSel);
        }
        if (self.ns_window) |window| {
            const windowPtrValue = @intFromPtr(window);
            std.debug.assert(windowPtrValue != 0);
            const closeSel = c.sel_getUid("close");
            const releaseSel = c.sel_getUid("release");
            std.debug.assert(closeSel != null);
            std.debug.assert(releaseSel != null);
            cocoa.objc_msgSendVoid0(@ptrCast(window), closeSel);
            cocoa.objc_msgSendVoid0(@ptrCast(window), releaseSel);
        }
        
        self.* = undefined;
    }

    pub fn show(self: *Self) void {
        // Assert precondition: title must be valid.
        std.debug.assert(self.title.len > 0);
        std.debug.assert(self.width > 0);
        std.debug.assert(self.height > 0);
        std.debug.assert(self.rgba_buffer.len > 0);
        // Buffer size is fixed (1024x768), window size can differ.
        const expected_buffer_size = BUFFER_WIDTH * BUFFER_HEIGHT * 4;
        std.debug.assert(self.rgba_buffer.len == expected_buffer_size);

        // Initialize NSApplication: get shared instance.
        const NSApplicationClass = c.objc_getClass("NSApplication");
        std.debug.assert(NSApplicationClass != null);
        const sharedAppSel = c.sel_getUid("sharedApplication");
        std.debug.assert(sharedAppSel != null);
        const sharedApp_opt = cocoa.objc_msgSend0(@ptrCast(NSApplicationClass), sharedAppSel);
        std.debug.assert(sharedApp_opt != null);
        const sharedApp: *c.objc_object = @ptrCast(@alignCast(sharedApp_opt.?));
        std.debug.assert(@intFromPtr(sharedApp) != 0);
        
        // Create NSWindow.
        const NSWindowClass = c.objc_getClass("NSWindow");
        std.debug.assert(NSWindowClass != null);
        const allocSel = c.sel_getUid("alloc");
        std.debug.assert(allocSel != null);
        const window_opt = cocoa.objc_msgSend0(@ptrCast(NSWindowClass), allocSel);
        std.debug.assert(window_opt != null);
        const window: *c.objc_object = @ptrCast(@alignCast(window_opt.?));
        std.debug.assert(@intFromPtr(window) != 0);
        
        // Create content rect.
        const contentRect = cocoa.NSRect{
            .origin = .{
                .x = 100.0,
                .y = 100.0,
            },
            .size = .{
                .width = @as(f64, @floatFromInt(self.width)),
                .height = @as(f64, @floatFromInt(self.height)),
            },
        };

        // Initialize window.
        const initSel = c.sel_getUid("initWithContentRect:styleMask:backing:defer:");
        std.debug.assert(initSel != null);
        const styleMask: usize = 15;
        const backing: usize = 2;
        const deferFlag: bool = false;
        const nsWindow_opt = cocoa.objc_msgSend4(@ptrCast(window), initSel, contentRect, styleMask, backing, deferFlag);
        std.debug.assert(nsWindow_opt != null);
        const nsWindow: *c.objc_object = @ptrCast(@alignCast(nsWindow_opt.?));
        std.debug.assert(@intFromPtr(nsWindow) != 0);
        
        // Set window title.
        const setTitleSel = c.sel_getUid("setTitle:");
        std.debug.assert(setTitleSel != null);
        const title_cstr = std.fmt.allocPrint(self.allocator, "{s}\x00", .{self.title}) catch |err| {
            std.debug.panic("Failed to allocate title string: {s}", .{@errorName(err)});
        };
        defer self.allocator.free(title_cstr);
        const NSStringClass = c.objc_getClass("NSString");
        std.debug.assert(NSStringClass != null);
        const stringWithUTF8StringSel = c.sel_getUid("stringWithUTF8String:");
        std.debug.assert(stringWithUTF8StringSel != null);
        const title_nsstring_opt = cocoa.objc_msgSendNSString(@ptrCast(NSStringClass), stringWithUTF8StringSel, title_cstr.ptr);
        std.debug.assert(title_nsstring_opt != null);
        const title_nsstring: *c.objc_object = @ptrCast(@alignCast(title_nsstring_opt.?));
        cocoa.objc_msgSendVoid1(@ptrCast(nsWindow), setTitleSel, title_nsstring);

        // Create TahoeView (custom view that handles mouse/keyboard events).
        // Why: TahoeView accepts first responder and routes events to Zig.
        const window_ptr = @intFromPtr(self);
        std.debug.assert(window_ptr != 0);
        if (window_ptr < 0x1000) {
            std.debug.panic("Window.show: self pointer is suspiciously small: 0x{x}", .{window_ptr});
        }
        if (window_ptr % @alignOf(Window) != 0) {
            std.debug.panic("Window.show: self pointer is not aligned: 0x{x}", .{window_ptr});
        }
        
        const tahoeView_opt = createTahoeView(window_ptr);
        std.debug.assert(tahoeView_opt != null);
        const tahoeView: *c.objc_object = @ptrCast(@alignCast(tahoeView_opt.?));
        const tahoeView_ptr = @intFromPtr(tahoeView);
        std.debug.assert(tahoeView_ptr != 0);
        if (tahoeView_ptr < 0x1000) {
            std.debug.panic("Window.show: tahoeView pointer is suspiciously small: 0x{x}", .{tahoeView_ptr});
        }
        if (tahoeView_ptr % 8 != 0) {
            std.debug.panic("Window.show: tahoeView pointer is not aligned: 0x{x}", .{tahoeView_ptr});
        }
        
        // Initialize TahoeView with frame.
        const initWithFrameSel = c.sel_getUid("initWithFrame:");
        std.debug.assert(initWithFrameSel != null);
        const initTahoeView_opt = cocoa.objc_msgSend1(@ptrCast(tahoeView), initWithFrameSel, contentRect);
        std.debug.assert(initTahoeView_opt != null);
        const initTahoeView: *c.objc_object = @ptrCast(@alignCast(initTahoeView_opt.?));
        const initTahoeView_ptr = @intFromPtr(initTahoeView);
        std.debug.assert(initTahoeView_ptr != 0);
        if (initTahoeView_ptr < 0x1000) {
            std.debug.panic("Window.show: initTahoeView pointer is suspiciously small: 0x{x}", .{initTahoeView_ptr});
        }
        if (initTahoeView_ptr % 8 != 0) {
            std.debug.panic("Window.show: initTahoeView pointer is not aligned: 0x{x}", .{initTahoeView_ptr});
        }
        
        // Create NSImageView as subview (for rendering images).
        // Why: NSImageView handles image scaling; TahoeView handles events.
        const NSImageViewClass = c.objc_getClass("NSImageView");
        std.debug.assert(NSImageViewClass != null);
        const imageView_opt = cocoa.objc_msgSend0(@ptrCast(NSImageViewClass), allocSel);
        std.debug.assert(imageView_opt != null);
        const imageView: *c.objc_object = @ptrCast(@alignCast(imageView_opt.?));
        const imageView_ptr = @intFromPtr(imageView);
        std.debug.assert(imageView_ptr != 0);
        if (imageView_ptr < 0x1000) {
            std.debug.panic("Window.show: imageView pointer is suspiciously small: 0x{x}", .{imageView_ptr});
        }
        if (imageView_ptr % 8 != 0) {
            std.debug.panic("Window.show: imageView pointer is not aligned: 0x{x}", .{imageView_ptr});
        }
        
        const imageViewInitSel = c.sel_getUid("initWithFrame:");
        std.debug.assert(imageViewInitSel != null);
        const nsImageView_opt = cocoa.objc_msgSend1(@ptrCast(imageView), imageViewInitSel, contentRect);
        std.debug.assert(nsImageView_opt != null);
        const nsImageView: *c.objc_object = @ptrCast(@alignCast(nsImageView_opt.?));
        const nsImageView_ptr = @intFromPtr(nsImageView);
        std.debug.assert(nsImageView_ptr != 0);
        if (nsImageView_ptr < 0x1000) {
            std.debug.panic("Window.show: nsImageView pointer is suspiciously small: 0x{x}", .{nsImageView_ptr});
        }
        if (nsImageView_ptr % 8 != 0) {
            std.debug.panic("Window.show: nsImageView pointer is not aligned: 0x{x}", .{nsImageView_ptr});
        }
        
        // Set NSImageView autoresizing mask to fill TahoeView.
        // Why: Ensure image view resizes with parent view.
        const setAutoresizingMaskSel = c.sel_getUid("setAutoresizingMask:");
        std.debug.assert(setAutoresizingMaskSel != null);
        // NSViewWidthSizable | NSViewHeightSizable = 0x18 (fills parent).
        const autoresizingMask: c_ulong = 0x18;
        _ = cocoa.objc_msgSend1Uint(@ptrCast(nsImageView), setAutoresizingMaskSel, autoresizingMask);
        
        // Add NSImageView as subview of TahoeView.
        const addSubviewSel = c.sel_getUid("addSubview:");
        std.debug.assert(addSubviewSel != null);
        cocoa.objc_msgSendVoid1(@ptrCast(initTahoeView), addSubviewSel, nsImageView);
        
        // Set TahoeView as content view (handles events).
        const setContentViewSel = c.sel_getUid("setContentView:");
        std.debug.assert(setContentViewSel != null);
        cocoa.objc_msgSendVoid1(@ptrCast(nsWindow), setContentViewSel, initTahoeView);
        
        // Store pointers: TahoeView is content view, NSImageView is subview.
        self.ns_window = nsWindow;
        self.ns_view = initTahoeView; // TahoeView (event handling)
        self.ns_image_view = nsImageView; // NSImageView (rendering)
        self.ns_app = sharedApp;
        
        // Assert: all stored pointers must be valid.
        std.debug.assert(self.ns_window != null);
        std.debug.assert(self.ns_view != null);
        std.debug.assert(self.ns_image_view != null);
        std.debug.assert(self.ns_app != null);
        
        // Setup window delegate for resize events.
        self.setupDelegates();
        
        // Show window.
        const makeKeySel = c.sel_getUid("makeKeyAndOrderFront:");
        std.debug.assert(makeKeySel != null);
        cocoa.objc_msgSendVoid0(@ptrCast(nsWindow), makeKeySel);
        
        // Make TahoeView the first responder (required for keyboard events).
        // Why: Window must have a first responder to receive keyboard events.
        const makeFirstResponderSel = c.sel_getUid("makeFirstResponder:");
        std.debug.assert(makeFirstResponderSel != null);
        // Note: makeFirstResponder: returns BOOL, but we use void version since we don't need the return value.
        cocoa.objc_msgSendVoid1(@ptrCast(nsWindow), makeFirstResponderSel, @ptrCast(initTahoeView));
        std.debug.print("[window] Made TahoeView first responder for keyboard events.\n", .{});
        
        // Activate application.
        const activateSel = c.sel_getUid("activateIgnoringOtherApps:");
        std.debug.assert(activateSel != null);
        cocoa.objc_msgSendVoidBool(@ptrCast(sharedApp), activateSel, true);
    }

    pub fn getBuffer(self: *Self) []u8 {
        // Assert precondition: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        // Buffer size is fixed (1024x768), window size can differ.
        const expected_buffer_size = BUFFER_WIDTH * BUFFER_HEIGHT * 4;
        std.debug.assert(self.rgba_buffer.len == expected_buffer_size);
        return &self.rgba_buffer;
    }

    pub fn present(self: *Self) !void {
        // Assert precondition: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("Window.present: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        // Assert precondition: NSImageView must be initialized.
        // Why: We store NSImageView reference directly to avoid subviews lookup.
        std.debug.assert(self.ns_image_view != null);
        const imageView = self.ns_image_view.?;
        const imageView_ptr = @intFromPtr(imageView);
        std.debug.assert(imageView_ptr != 0);
        if (imageView_ptr < 0x1000) {
            std.debug.panic("Window.present: imageView pointer is suspiciously small: 0x{x}", .{imageView_ptr});
        }
        if (imageView_ptr % 8 != 0) {
            std.debug.panic("Window.present: imageView pointer is not aligned: 0x{x}", .{imageView_ptr});
        }
        
        // Assert precondition: TahoeView must be initialized (for setNeedsDisplay).
        std.debug.assert(self.ns_view != null);
        const tahoeView = self.ns_view.?;
        const tahoeView_ptr = @intFromPtr(tahoeView);
        std.debug.assert(tahoeView_ptr != 0);
        
        // Assert precondition: buffer must be valid.
        std.debug.assert(self.rgba_buffer.len > 0);
        std.debug.assert(self.rgba_buffer.len % 4 == 0);
        // Buffer size is fixed (1024x768), window size can differ.
        const expected_buffer_size = BUFFER_WIDTH * BUFFER_HEIGHT * 4;
        std.debug.assert(self.rgba_buffer.len == expected_buffer_size);
        std.debug.assert(self.width > 0);
        std.debug.assert(self.height > 0);
        
        std.debug.print("[window] Presenting buffer to view at: 0x{x}, buffer size: {d} bytes (window: {}x{}, buffer: {}x{})\n", .{ imageView_ptr, self.rgba_buffer.len, self.width, self.height, BUFFER_WIDTH, BUFFER_HEIGHT });
        
        // Create CGImage from RGBA buffer.
        // Buffer is always 1024x768 (static), window size may differ.
        const cg_image = try createCGImageFromBuffer(&self.rgba_buffer);
        defer releaseCGImage(cg_image);
        
        // Assert: CGImage must be valid.
        const cg_image_ptr = @intFromPtr(cg_image);
        std.debug.assert(cg_image_ptr != 0);
        if (cg_image_ptr < 0x1000) {
            std.debug.panic("Window.present: cg_image pointer is suspiciously small: 0x{x}", .{cg_image_ptr});
        }
        
        // Create NSImage from CGImage.
        std.debug.print("[window] Creating NSImage from CGImage (using C wrapper)...\n", .{});
        const width_f64 = @as(f64, @floatFromInt(BUFFER_WIDTH));
        const height_f64 = @as(f64, @floatFromInt(BUFFER_HEIGHT));
        std.debug.assert(width_f64 > 0.0);
        std.debug.assert(height_f64 > 0.0);
        
        // Use extern function declared at top level.
        const nsImage_opt = createNSImageFromCGImage(cg_image, width_f64, height_f64);
        std.debug.assert(nsImage_opt != null);
        const nsImage: *c.objc_object = @ptrCast(@alignCast(nsImage_opt.?));
        
        // Assert: NSImage pointer must be valid.
        const nsImage_ptr = @intFromPtr(nsImage);
        std.debug.assert(nsImage_ptr != 0);
        if (nsImage_ptr < 0x1000) {
            std.debug.panic("Window.present: nsImage pointer is suspiciously small: 0x{x}", .{nsImage_ptr});
        }
        if (nsImage_ptr % 8 != 0) {
            std.debug.panic("Window.present: nsImage pointer is not aligned: 0x{x}", .{nsImage_ptr});
        }
        std.debug.print("[window] Created NSImage at: 0x{x}\n", .{nsImage_ptr});
        
        // Set image on NSImageView subview.
        const setImageSel = c.sel_getUid("setImage:");
        std.debug.assert(setImageSel != null);
        cocoa.objc_msgSendVoid1(@ptrCast(imageView), setImageSel, nsImage);
        
        // Set image scaling to none (pixel-perfect rendering).
        // Why: Ensure image is displayed at 1:1 scale without interpolation.
        const setImageScalingSel = c.sel_getUid("setImageScaling:");
        std.debug.assert(setImageScalingSel != null);
        // NSImageScaleNone = 0 (from AppKit), pass as c_ulong.
        const NSImageScaleNone: c_ulong = 0;
        _ = cocoa.objc_msgSend1Uint(@ptrCast(imageView), setImageScalingSel, NSImageScaleNone);
        
        // Mark view as needing display.
        const setNeedsDisplaySel = c.sel_getUid("setNeedsDisplay:");
        std.debug.assert(setNeedsDisplaySel != null);
        cocoa.objc_msgSendVoidBool(@ptrCast(tahoeView), setNeedsDisplaySel, true);
        
        std.debug.print("[window] Set NSImage on NSImageView (scaling: none).\n", .{});
    }
    
    /// Create CGImage from RGBA buffer.
    /// Note: Buffer is always 1024x768 (static allocation).
    /// Note: Converts RGBA to BGRA format for Core Graphics compatibility.
    fn createCGImageFromBuffer(buffer: []const u8) !*anyopaque {
        const width = BUFFER_WIDTH;
        const height = BUFFER_HEIGHT;
        
        // Assert: parameters must be valid.
        std.debug.assert(buffer.len > 0);
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        const expected_size = @as(usize, width) * @as(usize, height) * 4;
        std.debug.assert(buffer.len == expected_size);
        std.debug.assert(buffer.len % 4 == 0);
        
        std.debug.print("[window] Creating CGImage: {d}x{d}, buffer: {d} bytes\n", .{ width, height, buffer.len });
        
        // Convert RGBA buffer to BGRA format for Core Graphics.
        // Why: Core Graphics on macOS expects BGRA format for optimal performance.
        // We'll create a temporary buffer and convert, then use that for CGImage.
        var bgra_buffer = try std.heap.page_allocator.alloc(u8, buffer.len);
        defer std.heap.page_allocator.free(bgra_buffer);
        
        // Convert all pixels from RGBA to BGRA.
        var i: usize = 0;
        const pixel_count = buffer.len / 4;
        std.debug.assert(buffer.len % 4 == 0);
        std.debug.assert(pixel_count == width * height);
        
        while (i < buffer.len) : (i += 4) {
            // Convert [R, G, B, A] to [B, G, R, A]
            bgra_buffer[i + 0] = buffer[i + 2]; // B
            bgra_buffer[i + 1] = buffer[i + 1]; // G
            bgra_buffer[i + 2] = buffer[i + 0]; // R
            bgra_buffer[i + 3] = buffer[i + 3]; // A
        }
        
        // Verify conversion: check a few pixels.
        const test_idx = (10 * width + 10) * 4; // Red rectangle pixel
        const bg_idx = (300 * width + 300) * 4; // Background pixel (outside rectangles)
        if (test_idx + 3 < buffer.len and bg_idx + 3 < buffer.len) {
            std.debug.print("[window] RGBA pixel (10,10): R={d}, G={d}, B={d}, A={d}\n", .{
                buffer[test_idx + 0],
                buffer[test_idx + 1],
                buffer[test_idx + 2],
                buffer[test_idx + 3],
            });
            std.debug.print("[window] BGRA pixel (10,10): R={d}, G={d}, B={d}, A={d}\n", .{
                bgra_buffer[test_idx + 2], // R in BGRA
                bgra_buffer[test_idx + 1], // G
                bgra_buffer[test_idx + 0], // B in BGRA
                bgra_buffer[test_idx + 3], // A
            });
            std.debug.print("[window] RGBA background (300,300): R={d}, G={d}, B={d}, A={d}\n", .{
                buffer[bg_idx + 0],
                buffer[bg_idx + 1],
                buffer[bg_idx + 2],
                buffer[bg_idx + 3],
            });
            std.debug.print("[window] BGRA background (300,300): R={d}, G={d}, B={d}, A={d}\n", .{
                bgra_buffer[bg_idx + 2], // R in BGRA
                bgra_buffer[bg_idx + 1], // G
                bgra_buffer[bg_idx + 0], // B in BGRA
                bgra_buffer[bg_idx + 3], // A
            });
        }
        
        // Create CGColorSpace for RGB.
        const rgb_color_space = cg.CGColorSpaceCreateDeviceRGB();
        std.debug.assert(rgb_color_space != null);
        defer cg.CGColorSpaceRelease(rgb_color_space);
        
        // Create CGDataProvider from BGRA buffer.
        const data_provider = cg.CGDataProviderCreateWithData(
            null,
            bgra_buffer.ptr,
            bgra_buffer.len,
            null,
        );
        std.debug.assert(data_provider != null);
        defer cg.CGDataProviderRelease(data_provider);
        
        // Create CGImage with BGRA format.
        // Note: Using non-premultiplied alpha (kCGImageAlphaLast) since we're not premultiplying.
        // kCGImageAlphaLast means: BGRA with non-premultiplied alpha (alpha in last byte).
        // kCGBitmapByteOrder32Little means: little-endian byte order (native on macOS).
        // Why: Core Graphics expects the format to match the actual data format.
        const bitmap_info: u32 = cg.kCGImageAlphaLast | cg.kCGBitmapByteOrder32Little;
        const cg_image = cg.CGImageCreate(
            width,
            height,
            8,
            32,
            width * 4,
            rgb_color_space,
            bitmap_info,
            data_provider,
            null,
            false,
            cg.kCGRenderingIntentDefault,
        );
        
        std.debug.assert(cg_image != null);
        
        const cg_image_ptr = @intFromPtr(cg_image);
        std.debug.assert(cg_image_ptr != 0);
        if (cg_image_ptr < 0x1000) {
            std.debug.panic("createCGImageFromBuffer: cg_image pointer is suspiciously small: 0x{x}", .{cg_image_ptr});
        }
        
        std.debug.print("[window] Created CGImage at: 0x{x}\n", .{cg_image_ptr});
        return @ptrCast(cg_image);
    }
    
    fn releaseCGImage(cg_image: *anyopaque) void {
        const cg_image_ptr = @intFromPtr(cg_image);
        std.debug.assert(cg_image_ptr != 0);
        if (cg_image_ptr < 0x1000) {
            std.debug.panic("releaseCGImage: cg_image pointer is suspiciously small: 0x{x}", .{cg_image_ptr});
        }
        std.debug.print("[window] Releasing CGImage at: 0x{x}\n", .{cg_image_ptr});
        cg.CGImageRelease(@ptrCast(cg_image));
    }
    
    pub fn runEventLoop(self: *Self) void {
        // Assert precondition: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("Window.runEventLoop: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        // Assert precondition: app must be initialized.
        std.debug.assert(self.ns_app != null);
        const app = self.ns_app.?;
        
        // Assert: app pointer must be valid.
        const app_ptr = @intFromPtr(app);
        std.debug.assert(app_ptr != 0);
        if (app_ptr < 0x1000) {
            std.debug.panic("Window.runEventLoop: app pointer is suspiciously small: 0x{x}", .{app_ptr});
        }
        if (app_ptr % 8 != 0) {
            std.debug.panic("Window.runEventLoop: app pointer is not aligned: 0x{x}", .{app_ptr});
        }
        
        std.debug.print("[window] Running NSApplication event loop...\n", .{});
        
        // Run event loop.
        const runSel = c.sel_getUid("run");
        std.debug.assert(runSel != null);
        
        // Assert: selector pointer must be valid.
        const runSel_ptr = @intFromPtr(runSel);
        std.debug.assert(runSel_ptr != 0);
        
        cocoa.objc_msgSendVoid0(@ptrCast(app), runSel);
        
        std.debug.print("[window] NSApplication event loop exited.\n", .{});
    }
    
    /// Set event handler: stores handler pointer for event routing.
    pub fn setEventHandler(self: *Self, handler: ?*const events.EventHandler) void {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("Window.setEventHandler: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        // Store handler (can be null to clear).
        self.event_handler = handler;
        
        // If handler is set and window exists, set up delegates.
        // Note: If window doesn't exist yet, delegates will be set up in show().
        if (handler != null and self.ns_window != null and self.window_delegate == null) {
            self.setupDelegates();
        }
        
        std.debug.print("[window] Event handler set: {}\n", .{handler != null});
    }
    
    /// Setup Objective-C delegates for event handling.
    /// Note: Window and view must exist before calling this.
    fn setupDelegates(self: *Self) void {
        // Early return if window doesn't exist yet (will be set up later in show()).
        if (self.ns_window == null or self.ns_view == null) {
            std.debug.print("[window] Delegates setup deferred (window not created yet).\n", .{});
            return;
        }
        
        // Create window delegate for resize events.
        if (self.window_delegate == null) {
            const delegate_opt = createWindowDelegate(@intFromPtr(self));
            if (delegate_opt == null) {
                std.debug.panic("Window.setupDelegates: failed to create window delegate", .{});
            }
            const delegate = delegate_opt.?;
            self.window_delegate = delegate;
            
            // Set delegate on window.
            const setDelegateSel = c.sel_getUid("setDelegate:");
            std.debug.assert(setDelegateSel != null);
            cocoa.objc_msgSendVoid1(@ptrCast(self.ns_window.?), setDelegateSel, @ptrCast(delegate));
            
            std.debug.print("[window] Window delegate set for resize handling.\n", .{});
        }
        
        // For now, we'll enable basic event acceptance on the view.
        // Full delegate implementation requires Objective-C compilation or runtime class creation.
        // This is a simplified version that enables basic event acceptance.
        
        // Make view accept first responder (for keyboard events).
        // Note: We'll need to implement actual event handling via NSTrackingArea or
        // by creating custom view classes using runtime API.
        
        std.debug.print("[window] Delegates setup complete (window delegate + basic event acceptance enabled).\n", .{});
        std.debug.print("[window] Window resize events will be handled via delegate.\n", .{});
    }
    
    /// Start animation loop: creates NSTimer that calls tick callback at 60fps.
    /// Grain Style: validate all pointers, ensure timer is properly scheduled.
    pub fn startAnimationLoop(self: *Self, tick_callback: *const fn (*anyopaque) void, user_data: *anyopaque) void {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("Window.startAnimationLoop: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        // Assert: tick_callback function pointer must be valid.
        const callback_ptr = @intFromPtr(tick_callback);
        std.debug.assert(callback_ptr != 0);
        if (callback_ptr < 0x1000) {
            std.debug.panic("Window.startAnimationLoop: tick_callback pointer is suspiciously small: 0x{x}", .{callback_ptr});
        }
        
        // Assert: user_data pointer must be valid.
        const user_data_ptr = @intFromPtr(user_data);
        std.debug.assert(user_data_ptr != 0);
        if (user_data_ptr < 0x1000) {
            std.debug.panic("Window.startAnimationLoop: user_data pointer is suspiciously small: 0x{x}", .{user_data_ptr});
        }
        
        // Store callback and user_data.
        self.tick_callback = tick_callback;
        self.tick_user_data = user_data;
        
        // Create NSTimer: 60fps = 1/60 seconds = 0.016667 seconds interval.
        const NSTimerClass = c.objc_getClass("NSTimer");
        std.debug.assert(NSTimerClass != null);
        
        // Use scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:
        // We'll create a C helper function to set up the timer with our callback.
        const timer = createAnimationTimer(@intFromPtr(self), 1.0 / 60.0);
        if (timer == null) {
            std.debug.panic("Window.startAnimationLoop: failed to create animation timer", .{});
        }
        self.animation_timer = timer;
        
        std.debug.print("[window] Animation loop started (60fps timer).\n", .{});
    }
    
    /// Stop animation loop: invalidates timer.
    /// Grain Style: validate pointers, ensure cleanup.
    pub fn stopAnimationLoop(self: *Self) void {
        // Assert: self pointer must be valid.
        const self_ptr = @intFromPtr(self);
        std.debug.assert(self_ptr != 0);
        if (self_ptr < 0x1000) {
            std.debug.panic("Window.stopAnimationLoop: self pointer is suspiciously small: 0x{x}", .{self_ptr});
        }
        
        if (self.animation_timer) |timer| {
            // Invalidate timer.
            const invalidateSel = c.sel_getUid("invalidate");
            std.debug.assert(invalidateSel != null);
            cocoa.objc_msgSendVoid0(@ptrCast(timer), invalidateSel);
            self.animation_timer = null;
        }
        
        self.tick_callback = null;
        self.tick_user_data = null;
        
        std.debug.print("[window] Animation loop stopped.\n", .{});
    }
};

// C helper functions for delegate creation and timer setup.
extern fn createWindowDelegate(window_ptr: usize) ?*c.objc_object;
extern fn createAnimationTimer(window_ptr: usize, interval: f64) ?*c.objc_object;
extern fn createTahoeView(window_ptr: usize) ?*c.objc_object;

// Event routing functions: called from C delegates, route to Zig event handler.
// These are exported as C functions so Objective-C can call them.
/// Route mouse event from Cocoa to Zig event handler.
/// Grain Style: comprehensive pointer validation, bounds checking, enum validation.
fn routeMouseEventImpl(window_ptr: usize, kind: u32, button: u32, x: f64, y: f64, modifiers: u32) void {
    // Assert: window pointer must be valid (non-zero, aligned, reasonable).
    std.debug.assert(window_ptr != 0);
    if (window_ptr < 0x1000) {
        std.debug.panic("routeMouseEventImpl: window_ptr is suspiciously small: 0x{x}", .{window_ptr});
    }
    if (window_ptr % @alignOf(Window) != 0) {
        std.debug.panic("routeMouseEventImpl: window_ptr is not aligned: 0x{x}", .{window_ptr});
    }
    
    // Assert: coordinates must be reasonable (within window bounds or slightly outside for drag).
    std.debug.assert(x >= -10000.0 and x <= 10000.0);
    std.debug.assert(y >= -10000.0 and y <= 10000.0);
    
    // Cast window pointer back to Window.
    const window: *Window = @ptrFromInt(window_ptr);
    
    // Assert: window pointer must be valid (round-trip check).
    const window_ptr_value = @intFromPtr(window);
    std.debug.assert(window_ptr_value == window_ptr);
    
    // Assert: window must have valid buffer (Grain Style invariant).
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.rgba_buffer.len % 4 == 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    
    // Get event handler.
    const handler = window.event_handler orelse return;
    
    // Assert: handler must be valid (non-null pointer).
    const handler_ptr = @intFromPtr(handler);
    std.debug.assert(handler_ptr != 0);
    if (handler_ptr < 0x1000) {
        std.debug.panic("routeMouseEventImpl: handler pointer is suspiciously small: 0x{x}", .{handler_ptr});
    }
    
    // Convert button enum (Grain Style: validate enum values).
    const mouse_button = switch (button) {
        0 => events.MouseButton.left,
        1 => events.MouseButton.right,
        2 => events.MouseButton.middle,
        else => events.MouseButton.other, // Accept any other value as "other"
    };
    
    // Convert kind enum (Grain Style: validate enum values, reject invalid).
    const mouse_kind = switch (kind) {
        0 => events.MouseEvent.MouseEventKind.down,
        1 => events.MouseEvent.MouseEventKind.up,
        2 => events.MouseEvent.MouseEventKind.move,
        3 => events.MouseEvent.MouseEventKind.drag,
        else => {
            std.debug.panic("routeMouseEventImpl: invalid mouse event kind: {d}", .{kind});
        },
    };
    
    // Create event (Grain Style: validate all fields).
    const mouse_event = events.MouseEvent{
        .kind = mouse_kind,
        .button = mouse_button,
        .x = x,
        .y = y,
        .modifiers = events.ModifierKeys.fromCocoaFlags(modifiers),
    };
    
    // Assert: event must be valid (coordinates already checked above).
    std.debug.assert(@intFromEnum(mouse_event.kind) < 4);
    std.debug.assert(@intFromEnum(mouse_event.button) < 4);
    
    // Call handler (Grain Style: validate handler function pointer).
    const handler_fn_ptr = @intFromPtr(handler.onMouse);
    std.debug.assert(handler_fn_ptr != 0);
    if (handler_fn_ptr < 0x1000) {
        std.debug.panic("routeMouseEventImpl: handler.onMouse pointer is suspiciously small: 0x{x}", .{handler_fn_ptr});
    }
    
    _ = handler.onMouse(handler.user_data, mouse_event);
}

/// Route keyboard event from Cocoa to Zig event handler.
/// Grain Style: comprehensive pointer validation, bounds checking, enum validation.
fn routeKeyboardEventImpl(window_ptr: usize, kind: u32, key_code: u32, character: u32, modifiers: u32) void {
    // Assert: window pointer must be valid (non-zero, aligned, reasonable).
    std.debug.assert(window_ptr != 0);
    if (window_ptr < 0x1000) {
        std.debug.panic("routeKeyboardEventImpl: window_ptr is suspiciously small: 0x{x}", .{window_ptr});
    }
    if (window_ptr % @alignOf(Window) != 0) {
        std.debug.panic("routeKeyboardEventImpl: window_ptr is not aligned: 0x{x}", .{window_ptr});
    }
    
    // Assert: key_code must be reasonable (macOS key codes are typically 0-127).
    std.debug.assert(key_code <= 0xFFFF);
    
    // Assert: character must be valid Unicode (if non-zero).
    if (character != 0) {
        std.debug.assert(character <= 0x10FFFF); // Max valid Unicode code point
        std.debug.assert(!(character >= 0xD800 and character <= 0xDFFF)); // No surrogates
    }
    
    // Cast window pointer back to Window.
    const window: *Window = @ptrFromInt(window_ptr);
    
    // Assert: window pointer must be valid (round-trip check).
    const window_ptr_value = @intFromPtr(window);
    std.debug.assert(window_ptr_value == window_ptr);
    
    // Assert: window must have valid buffer (Grain Style invariant).
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.rgba_buffer.len % 4 == 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    
    // Get event handler.
    const handler = window.event_handler orelse return;
    
    // Assert: handler must be valid (non-null pointer).
    const handler_ptr = @intFromPtr(handler);
    std.debug.assert(handler_ptr != 0);
    if (handler_ptr < 0x1000) {
        std.debug.panic("routeKeyboardEventImpl: handler pointer is suspiciously small: 0x{x}", .{handler_ptr});
    }
    
    // Convert kind enum (Grain Style: validate enum values, reject invalid).
    const keyboard_kind = switch (kind) {
        0 => events.KeyboardEvent.KeyboardEventKind.down,
        1 => events.KeyboardEvent.KeyboardEventKind.up,
        else => {
            std.debug.panic("routeKeyboardEventImpl: invalid keyboard event kind: {d}", .{kind});
        },
    };
    
    // Create event (Grain Style: validate all fields).
    const keyboard_event = events.KeyboardEvent{
        .kind = keyboard_kind,
        .key_code = key_code,
        .character = if (character != 0) @as(u21, @intCast(character)) else null,
        .modifiers = events.ModifierKeys.fromCocoaFlags(modifiers),
    };
    
    // Assert: event must be valid.
    std.debug.assert(@intFromEnum(keyboard_event.kind) < 2);
    
    // Call handler (Grain Style: validate handler function pointer).
    const handler_fn_ptr = @intFromPtr(handler.onKeyboard);
    std.debug.assert(handler_fn_ptr != 0);
    if (handler_fn_ptr < 0x1000) {
        std.debug.panic("routeKeyboardEventImpl: handler.onKeyboard pointer is suspiciously small: 0x{x}", .{handler_fn_ptr});
    }
    
    _ = handler.onKeyboard(handler.user_data, keyboard_event);
}

/// Route focus event from Cocoa to Zig event handler.
/// Grain Style: comprehensive pointer validation, enum validation.
fn routeFocusEventImpl(window_ptr: usize, kind: u32) void {
    // Assert: window pointer must be valid (non-zero, aligned, reasonable).
    std.debug.assert(window_ptr != 0);
    if (window_ptr < 0x1000) {
        std.debug.panic("routeFocusEventImpl: window_ptr is suspiciously small: 0x{x}", .{window_ptr});
    }
    if (window_ptr % @alignOf(Window) != 0) {
        std.debug.panic("routeFocusEventImpl: window_ptr is not aligned: 0x{x}", .{window_ptr});
    }
    
    // Cast window pointer back to Window.
    const window: *Window = @ptrFromInt(window_ptr);
    
    // Assert: window pointer must be valid (round-trip check).
    const window_ptr_value = @intFromPtr(window);
    std.debug.assert(window_ptr_value == window_ptr);
    
    // Assert: window must have valid buffer (Grain Style invariant).
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.rgba_buffer.len % 4 == 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    
    // Get event handler.
    const handler = window.event_handler orelse return;
    
    // Assert: handler must be valid (non-null pointer).
    const handler_ptr = @intFromPtr(handler);
    std.debug.assert(handler_ptr != 0);
    if (handler_ptr < 0x1000) {
        std.debug.panic("routeFocusEventImpl: handler pointer is suspiciously small: 0x{x}", .{handler_ptr});
    }
    
    // Convert kind enum (Grain Style: validate enum values, reject invalid).
    const focus_kind = switch (kind) {
        0 => events.FocusEvent.FocusEventKind.gained,
        1 => events.FocusEvent.FocusEventKind.lost,
        else => {
            std.debug.panic("routeFocusEventImpl: invalid focus event kind: {d}", .{kind});
        },
    };
    
    // Create event (Grain Style: validate all fields).
    const focus_event = events.FocusEvent{
        .kind = focus_kind,
    };
    
    // Assert: event must be valid.
    std.debug.assert(@intFromEnum(focus_event.kind) < 2);
    
    // Call handler (Grain Style: validate handler function pointer).
    const handler_fn_ptr = @intFromPtr(handler.onFocus);
    std.debug.assert(handler_fn_ptr != 0);
    if (handler_fn_ptr < 0x1000) {
        std.debug.panic("routeFocusEventImpl: handler.onFocus pointer is suspiciously small: 0x{x}", .{handler_fn_ptr});
    }
    
    _ = handler.onFocus(handler.user_data, focus_event);
}

// Export C-callable wrappers for event routing.
export fn routeMouseEvent(window_ptr: usize, kind: u32, button: u32, x: f64, y: f64, modifiers: u32) void {
    routeMouseEventImpl(window_ptr, kind, button, x, y, modifiers);
}

export fn routeKeyboardEvent(window_ptr: usize, kind: u32, key_code: u32, character: u32, modifiers: u32) void {
    routeKeyboardEventImpl(window_ptr, kind, key_code, character, modifiers);
}

export fn routeFocusEvent(window_ptr: usize, kind: u32) void {
    routeFocusEventImpl(window_ptr, kind);
}

/// Route tick callback from timer to Zig tick function.
/// Grain Style: validate window pointer, ensure callback is valid.
fn routeTickCallbackImpl(window_ptr: usize) void {
    // Assert: window pointer must be valid (non-zero, aligned, reasonable).
    std.debug.assert(window_ptr != 0);
    if (window_ptr < 0x1000) {
        std.debug.panic("routeTickCallbackImpl: window_ptr is suspiciously small: 0x{x}", .{window_ptr});
    }
    if (window_ptr % @alignOf(Window) != 0) {
        std.debug.panic("routeTickCallbackImpl: window_ptr is not aligned: 0x{x}", .{window_ptr});
    }
    
    // Cast window pointer back to Window.
    const window: *Window = @ptrFromInt(window_ptr);
    
    // Assert: window pointer must be valid (round-trip check).
    const window_ptr_value = @intFromPtr(window);
    std.debug.assert(window_ptr_value == window_ptr);
    
    // Assert: window must have valid buffer (Grain Style invariant).
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.rgba_buffer.len % 4 == 0);
    std.debug.assert(window.width > 0);
    std.debug.assert(window.height > 0);
    
    // Get tick callback and user_data.
    const callback = window.tick_callback orelse return;
    const user_data = window.tick_user_data orelse return;
    
    // Assert: callback function pointer must be valid.
    const callback_ptr = @intFromPtr(callback);
    std.debug.assert(callback_ptr != 0);
    if (callback_ptr < 0x1000) {
        std.debug.panic("routeTickCallbackImpl: callback pointer is suspiciously small: 0x{x}", .{callback_ptr});
    }
    
    // Assert: user_data pointer must be valid.
    const user_data_ptr = @intFromPtr(user_data);
    std.debug.assert(user_data_ptr != 0);
    if (user_data_ptr < 0x1000) {
        std.debug.panic("routeTickCallbackImpl: user_data pointer is suspiciously small: 0x{x}", .{user_data_ptr});
    }
    
    // Call tick callback.
    callback(user_data);
}

// Export C-callable wrapper for tick callback routing.
export fn routeTickCallback(window_ptr: usize) void {
    routeTickCallbackImpl(window_ptr);
}

/// Route window resize event from Cocoa to Zig.
/// Grain Style: validate window pointer, ensure dimensions are reasonable.
fn routeWindowDidResizeImpl(window_ptr: usize, new_width: f64, new_height: f64) void {
    // Assert: window pointer must be valid (non-zero, aligned, reasonable).
    std.debug.assert(window_ptr != 0);
    if (window_ptr < 0x1000) {
        std.debug.panic("routeWindowDidResizeImpl: window_ptr is suspiciously small: 0x{x}", .{window_ptr});
    }
    if (window_ptr % @alignOf(Window) != 0) {
        std.debug.panic("routeWindowDidResizeImpl: window_ptr is not aligned: 0x{x}", .{window_ptr});
    }
    
    // Assert: dimensions must be reasonable (positive, not too large).
    std.debug.assert(new_width > 0.0);
    std.debug.assert(new_height > 0.0);
    std.debug.assert(new_width <= 100000.0); // Reasonable maximum
    std.debug.assert(new_height <= 100000.0); // Reasonable maximum
    
    // Cast window pointer back to Window.
    const window: *Window = @ptrFromInt(window_ptr);
    
    // Assert: window pointer must be valid (round-trip check).
    const window_ptr_value = @intFromPtr(window);
    std.debug.assert(window_ptr_value == window_ptr);
    
    // Assert: window must have valid buffer (Grain Style invariant).
    std.debug.assert(window.rgba_buffer.len > 0);
    std.debug.assert(window.rgba_buffer.len % 4 == 0);
    const expected_buffer_size = BUFFER_WIDTH * BUFFER_HEIGHT * 4;
    std.debug.assert(window.rgba_buffer.len == expected_buffer_size);
    
    // Update window dimensions (for tracking window size).
    // Note: Buffer remains static (1024x768), NSImageView will scale rendering.
    const old_width = window.width;
    const old_height = window.height;
    
    // Convert to u32 (clamp to reasonable range).
    const clamped_width = if (new_width > 65535.0) 65535.0 else new_width;
    const clamped_height = if (new_height > 65535.0) 65535.0 else new_height;
    const new_width_u32 = @as(u32, @intFromFloat(clamped_width));
    const new_height_u32 = @as(u32, @intFromFloat(clamped_height));
    
    window.width = new_width_u32;
    window.height = new_height_u32;
    
    std.debug.print("[window] Window resized: {}x{} -> {}x{} (buffer remains {}x{})\n", .{ old_width, old_height, new_width_u32, new_height_u32, BUFFER_WIDTH, BUFFER_HEIGHT });
    
    // Note: Buffer size is fixed at 1024x768.
    // NSImageView automatically scales the image to fit the window size.
    // Future: If dynamic buffer resizing is needed, we'd reallocate here.
}

// Export C-callable wrapper for window resize routing.
export fn routeWindowDidResize(window_ptr: usize, new_width: f64, new_height: f64) void {
    routeWindowDidResizeImpl(window_ptr, new_width, new_height);
}
