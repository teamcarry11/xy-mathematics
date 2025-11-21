# macOS Integration

**Prerequisites**: Framebuffer graphics (0007), basic GUI concepts  
**Focus**: Cocoa/AppKit integration for Grain Aurora IDE on macOS Tahoe  
**GrainStyle**: Explicit Objective-C bridging, clear ownership semantics

## macOS Application Architecture

### Cocoa Framework

macOS applications use **Cocoa** framework (Objective-C):

- **AppKit**: Window management, events, UI
- **Foundation**: Basic types, collections, I/O
- **Core Graphics**: 2D graphics, image rendering

**Grain OS**: Uses Cocoa for window management, minimal Objective-C.

### Application Structure

```
macOS App:
  NSApplication (main app)
    └── NSWindow (window)
        └── NSView (content view)
            └── NSImageView (display framebuffer)
```

**Grain Aurora**: Single window displaying VM framebuffer.

## Objective-C Basics

### Why Objective-C?

macOS APIs are Objective-C. We need minimal Objective-C for:

- Window creation and management
- Event handling (keyboard, mouse)
- Image display (framebuffer → NSImage)

**GrainStyle**: Minimal Objective-C, most code in Zig.

### Message Passing

Objective-C uses message passing (not function calls):

```objc
// Objective-C
[window setTitle:@"Grain OS"];
[view setImage:image];
```

**Zig Bridge**: Use `objc_msgSend` to call Objective-C from Zig:

```zig
// Zig
const objc_msgSend = @import("cocoa_bridge").objc_msgSend;
objc_msgSend(window, sel_getUid("setTitle:"), title);
```

**Why Bridge?**
- Zig can't directly call Objective-C
- Bridge provides C-compatible interface
- Minimal Objective-C code

## Window Creation

### NSWindow Setup

```zig
// Create window
const window_class = objc_getClass("NSWindow");
const window = objc_msgSend(objc_msgSend(window_class, sel_getUid("alloc")), sel_getUid("init"));

// Set window properties
const rect = NSMakeRect(100, 100, 1024, 768);
objc_msgSend(window, sel_getUid("setFrame:display:"), rect, true);
objc_msgSend(window, sel_getUid("setTitle:"), @"Grain OS");
objc_msgSend(window, sel_getUid("makeKeyAndOrderFront:"), null);
```

**GrainStyle**: Explicit window setup, clear property setting.

### NSImageView for Framebuffer

```zig
// Create image view
const image_view_class = objc_getClass("NSImageView");
const image_view = objc_msgSend(objc_msgSend(image_view_class, sel_getUid("alloc")), sel_getUid("init"));

// Set image (from framebuffer)
const ns_image = create_ns_image_from_framebuffer(fb_memory);
objc_msgSend(image_view, sel_getUid("setImage:"), ns_image);

// Add to window
objc_msgSend(window_content_view, sel_getUid("addSubview:"), image_view);
```

**Why NSImageView?**
- Simple: just set image, Cocoa handles display
- Automatic scaling and layout
- Efficient: Cocoa optimizes rendering

## Framebuffer to NSImage

### Create CGImage from Framebuffer

```zig
fn create_cg_image_from_framebuffer(fb_memory: []const u8) ?*anyopaque {
    const width: usize = 1024;
    const height: usize = 768;
    const bytes_per_pixel: usize = 4;
    
    // Create CGImage from pixel data
    // Note: Framebuffer is RGBA, macOS may expect BGRA
    const color_space = CGColorSpaceCreateDeviceRGB();
    const bitmap_info = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little;
    
    const cg_image = CGImageCreate(
        width,
        height,
        8,  // bits per component
        32, // bits per pixel
        width * bytes_per_pixel,  // bytes per row
        color_space,
        bitmap_info,
        nil,  // provider
        nil,  // decode
        false,  // should interpolate
        kCGRenderingIntentDefault
    );
    
    return cg_image;
}
```

**Why CGImage?**
- Core Graphics format
- Can convert to NSImage
- Supports various pixel formats

### Convert to NSImage

```zig
fn create_ns_image_from_cg_image(cg_image: *anyopaque) ?*anyopaque {
    const ns_image_class = objc_getClass("NSImage");
    const ns_image = objc_msgSend(objc_msgSend(ns_image_class, sel_getUid("alloc")), sel_getUid("init"));
    
    // Create NSImage from CGImage
    const size = NSSize{ .width = 1024, .height = 768 };
    objc_msgSend(ns_image, sel_getUid("initWithCGImage:size:"), cg_image, size);
    
    return ns_image;
}
```

## Event Handling

### Keyboard Events

```zig
// Custom NSView subclass to handle events
const TahoeView = objc_allocateClassPair(objc_getClass("NSView"), "TahoeView", 0);

// Add keyDown: method
const keyDown_impl: extern fn(*anyopaque, SEL, *anyopaque) void = handle_key_down;
class_addMethod(TahoeView, sel_getUid("keyDown:"), keyDown_impl, "v@:@");

fn handle_key_down(self: *anyopaque, _cmd: SEL, event: *anyopaque) void {
    // Extract key code
    const key_code = objc_msgSend(event, sel_getUid("keyCode"));
    
    // Route to VM (inject as virtual interrupt or syscall)
    // ... handle key ...
}
```

**Why Custom View?**
- Intercept keyboard events
- Route to VM/kernel
- Handle special keys (Ctrl+C, etc.)

### Mouse Events

```zig
// Add mouseDown: method
const mouseDown_impl: extern fn(*anyopaque, SEL, *anyopaque) void = handle_mouse_down;
class_addMethod(TahoeView, sel_getUid("mouseDown:"), mouseDown_impl, "v@:@");

fn handle_mouse_down(self: *anyopaque, _cmd: SEL, event: *anyopaque) void {
    // Get mouse location
    const location = objc_msgSend(event, sel_getUid("locationInWindow"));
    const x = objc_msgSend(location, sel_getUid("x"));
    const y = objc_msgSend(location, sel_getUid("y"));
    
    // Route to VM
    // ... handle mouse click ...
}
```

## Framebuffer Synchronization

### Update Loop

```zig
pub fn update_framebuffer(window: *TahoeWindow) void {
    // Get framebuffer from VM
    const fb_memory = window.vm.get_framebuffer_memory();
    
    // Create NSImage from framebuffer
    const cg_image = create_cg_image_from_framebuffer(fb_memory);
    const ns_image = create_ns_image_from_cg_image(cg_image);
    
    // Update image view
    objc_msgSend(window.image_view, sel_getUid("setImage:"), ns_image);
    
    // Request redraw
    objc_msgSend(window.content_view, sel_getUid("setNeedsDisplay:"), true);
}
```

**When to Update?**
- After VM step (if framebuffer changed)
- On timer (60 FPS refresh)
- On demand (when kernel writes to framebuffer)

### Dirty Region Tracking

For efficiency, only update changed regions:

```zig
pub fn update_dirty_regions(window: *TahoeWindow, dirty_regions: []DirtyRegion) void {
    for (dirty_regions) |region| {
        // Extract region from framebuffer
        const region_data = extract_region(fb_memory, region);
        
        // Update only that region in NSImage
        update_image_region(ns_image, region, region_data);
    }
}
```

**Why Track?**
- Reduce copy overhead
- Better performance
- Smoother animation

## Objective-C Memory Management

### Reference Counting

Objective-C uses reference counting:

```zig
// Retain (increment count)
objc_msgSend(object, sel_getUid("retain"));

// Release (decrement count)
objc_msgSend(object, sel_getUid("release"));

// Autorelease (release later)
objc_msgSend(object, sel_getUid("autorelease"));
```

**GrainStyle**: Explicit ownership, clear retain/release.

### ARC (Automatic Reference Counting)

Modern Objective-C uses ARC, but we use manual management:

- **Why Manual?**: More control, explicit ownership
- **When to Retain**: When storing pointer
- **When to Release**: When done with object

## Core Graphics Integration

### Pixel Format Conversion

macOS Core Graphics may expect different pixel format:

```zig
// Framebuffer: RGBA
// macOS: May expect BGRA or ARGB

fn convert_rgba_to_bgra(rgba_memory: []const u8, bgra_memory: []u8) void {
    std.debug.assert(rgba_memory.len == bgra_memory.len);
    std.debug.assert(rgba_memory.len % 4 == 0);
    
    var i: u32 = 0;
    while (i < rgba_memory.len) : (i += 4) {
        bgra_memory[i + 0] = rgba_memory[i + 2];  // B
        bgra_memory[i + 1] = rgba_memory[i + 1];  // G
        bgra_memory[i + 2] = rgba_memory[i + 0];  // R
        bgra_memory[i + 3] = rgba_memory[i + 3];  // A
    }
}
```

**When to Convert?**
- When creating CGImage
- Or configure framebuffer as BGRA from start

## Application Lifecycle

### NSApplication Run Loop

```zig
// Get shared application
const app = objc_msgSend(objc_getClass("NSApplication"), sel_getUid("sharedApplication"));

// Set up app delegate
const delegate = create_app_delegate();
objc_msgSend(app, sel_getUid("setDelegate:"), delegate);

// Run application (blocks until quit)
objc_msgSend(app, sel_getUid("run"));
```

**Why Run Loop?**
- Handles events (keyboard, mouse, window)
- Updates display
- Manages application lifecycle

### Window Updates

```zig
// Update window on timer
const timer = NSTimer.timerWithTimeInterval(1.0 / 60.0, update_callback, null, true);
objc_msgSend(app, sel_getUid("addTimer:forMode:"), timer, @"NSDefaultRunLoopMode");
```

**Why Timer?**
- Regular updates (60 FPS)
- Smooth animation
- Responsive UI

## Grain Aurora IDE Integration

### Window Structure

```
TahoeWindow (Zig struct)
├── vm: *VM                    # RISC-V virtual machine
├── window: *NSWindow          # macOS window
├── image_view: *NSImageView  # Framebuffer display
└── content_view: *NSView     # Custom view for events
```

### Update Flow

```
1. VM executes kernel code
2. Kernel writes to framebuffer (0x90000000)
3. VM translates address to physical offset
4. Framebuffer memory updated
5. macOS app reads framebuffer
6. Convert to NSImage
7. Update NSImageView
8. Cocoa renders to screen
```

## Exercises

1. **Window Creation**: Create an NSWindow with title "Grain OS".

2. **Framebuffer Display**: Convert framebuffer memory to NSImage and display.

3. **Event Handling**: Handle keyboard events and route to VM.

4. **Update Loop**: Implement 60 FPS framebuffer update.

## Key Takeaways

- Cocoa/AppKit: macOS GUI framework (Objective-C)
- Minimal Objective-C: Bridge to Zig, most code in Zig
- NSWindow: Main application window
- NSImageView: Display framebuffer as image
- Event handling: Custom NSView subclass
- Framebuffer sync: Update NSImage from VM memory
- Core Graphics: Pixel format conversion (RGBA ↔ BGRA)

## Next Document

**0009-grainstyle-principles.md**: Learn GrainStyle coding discipline in detail.

---

*now == next + 1*

