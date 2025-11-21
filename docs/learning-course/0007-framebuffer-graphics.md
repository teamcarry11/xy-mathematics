# Framebuffer Graphics

**Prerequisites**: Memory management (0005), kernel fundamentals (0006)  
**Focus**: Framebuffer concepts and pixel-level graphics in Grain OS  
**GrainStyle**: Explicit pixel formats, bounded drawing operations

## What is a Framebuffer?

A framebuffer is a region of memory that directly represents the display.
Each memory location corresponds to a pixel on screen. Writing to framebuffer
memory immediately updates the display (after sync).

**Why Framebuffer?**
- Simple: just memory writes
- Fast: direct pixel access
- Flexible: any pixel format, any resolution

## Framebuffer Layout

### Memory Organization

Framebuffer is organized as a 2D array in linear memory:

```
Memory Layout (Row-Major Order):
  Pixel (0,0)  Pixel (1,0)  Pixel (2,0)  ...  Pixel (1023,0)
  Pixel (0,1)  Pixel (1,1)  Pixel (2,1)  ...  Pixel (1023,1)
  ...
  Pixel (0,767) Pixel (1,767) ...           Pixel (1023,767)
```

**Formula**: `offset = (y * width + x) * bytes_per_pixel`

### Pixel Addressing

```zig
// Calculate pixel offset
fn pixel_offset(x: u32, y: u32, width: u32, bpp: u32) u32 {
    std.debug.assert(x < width);
    std.debug.assert(y < FRAMEBUFFER_HEIGHT);
    std.debug.assert(bpp == 4);  // 32-bit RGBA
    
    return (y * width + x) * bpp;
}

// Get pixel address
fn pixel_address(x: u32, y: u32) u64 {
    const FRAMEBUFFER_BASE: u64 = 0x90000000;
    const offset = pixel_offset(x, y, FRAMEBUFFER_WIDTH, 4);
    return FRAMEBUFFER_BASE + offset;
}
```

**GrainStyle**: Explicit calculations, bounds checking.

## Pixel Formats

### RGBA Format

Grain OS uses **32-bit RGBA** (Red, Green, Blue, Alpha):

```
Byte 0: Red   (0-255)
Byte 1: Green (0-255)
Byte 2: Blue  (0-255)
Byte 3: Alpha (0-255, 255 = opaque)
```

**Example**: `0xFF0000FF` = Red pixel (fully opaque)

### Color Constants

```zig
pub const COLOR_BLACK: u32 = 0x000000FF;      // Black (opaque)
pub const COLOR_WHITE: u32 = 0xFFFFFFFF;      // White (opaque)
pub const COLOR_RED: u32 = 0xFF0000FF;        // Red (opaque)
pub const COLOR_GREEN: u32 = 0x00FF00FF;      // Green (opaque)
pub const COLOR_BLUE: u32 = 0x0000FFFF;       // Blue (opaque)
pub const COLOR_DARK_BG: u32 = 0x1E1E2EFF;    // Dark background
```

**Why RGBA?**
- Standard format
- 32-bit aligned (efficient)
- Supports transparency (alpha channel)

### Byte Order

RGBA is stored in **little-endian** order:

```
Memory:  [FF] [00] [00] [FF]  (low to high address)
         Red  Green Blue Alpha
```

**Why Little-Endian?**
- Matches RISC-V (little-endian)
- Matches host (AArch64, little-endian)
- Consistent across system

## Drawing Primitives

### Clear Framebuffer

```zig
pub fn clear(self: *const Framebuffer, color: u32) void {
    std.debug.assert(self.memory.len == FRAMEBUFFER_SIZE);
    
    // Extract RGBA components
    const r: u8 = @truncate((color >> 24) & 0xFF);
    const g: u8 = @truncate((color >> 16) & 0xFF);
    const b: u8 = @truncate((color >> 8) & 0xFF);
    const a: u8 = @truncate(color & 0xFF);
    
    // Fill framebuffer
    var i: u32 = 0;
    while (i < FRAMEBUFFER_SIZE) : (i += 4) {
        self.memory[i + 0] = r;
        self.memory[i + 1] = g;
        self.memory[i + 2] = b;
        self.memory[i + 3] = a;
    }
    
    // Assert: First and last pixels must be set
    std.debug.assert(self.memory[0] == r);
    std.debug.assert(self.memory[FRAMEBUFFER_SIZE - 4] == r);
}
```

**GrainStyle**: Explicit component extraction, bounds checking.

### Draw Pixel

```zig
pub fn draw_pixel(self: *const Framebuffer, x: u32, y: u32, color: u32) void {
    std.debug.assert(x < self.width);
    std.debug.assert(y < self.height);
    
    // Calculate pixel offset
    const offset = (y * self.width + x) * self.bpp;
    std.debug.assert(offset + 3 < FRAMEBUFFER_SIZE);
    
    // Extract RGBA components
    const r: u8 = @truncate((color >> 24) & 0xFF);
    const g: u8 = @truncate((color >> 16) & 0xFF);
    const b: u8 = @truncate((color >> 8) & 0xFF);
    const a: u8 = @truncate(color & 0xFF);
    
    // Write pixel (RGBA format)
    self.memory[offset + 0] = r;
    self.memory[offset + 1] = g;
    self.memory[offset + 2] = b;
    self.memory[offset + 3] = a;
    
    // Assert: Pixel must be written
    std.debug.assert(self.memory[offset + 0] == r);
}
```

### Draw Rectangle

```zig
pub fn draw_rect(self: *const Framebuffer, x: u32, y: u32, w: u32, h: u32, color: u32) void {
    std.debug.assert(x < self.width);
    std.debug.assert(y < self.height);
    std.debug.assert(x + w <= self.width);
    std.debug.assert(y + h <= self.height);
    std.debug.assert(w > 0);
    std.debug.assert(h > 0);
    
    // Draw row by row
    var py: u32 = y;
    while (py < y + h) : (py += 1) {
        var px: u32 = x;
        while (px < x + w) : (px += 1) {
            self.draw_pixel(px, py, color);
        }
    }
    
    // Assert: Rectangle must be drawn (check corners)
    std.debug.assert(self.memory[(y * self.width + x) * self.bpp] == @truncate((color >> 24) & 0xFF));
}
```

**GrainStyle**: Explicit loops, bounds checking, postcondition assertions.

## Test Patterns

### Colored Rectangles

```zig
pub fn draw_test_pattern(self: *const Framebuffer) void {
    // Clear to dark background
    self.clear(COLOR_DARK_BG);
    
    const rect_size: u32 = 100;
    const spacing: u32 = 20;
    
    // Red rectangle (top-left)
    self.draw_rect(spacing, spacing, rect_size, rect_size, COLOR_RED);
    
    // Green rectangle (top-right)
    self.draw_rect(self.width - rect_size - spacing, spacing, rect_size, rect_size, COLOR_GREEN);
    
    // Blue rectangle (bottom-left)
    self.draw_rect(spacing, self.height - rect_size - spacing, rect_size, rect_size, COLOR_BLUE);
    
    // White rectangle (bottom-right)
    self.draw_rect(self.width - rect_size - spacing, self.height - rect_size - spacing, rect_size, rect_size, COLOR_WHITE);
}
```

**Why Test Pattern?**
- Visual verification
- Tests all drawing primitives
- Easy to spot errors

## Kernel Access to Framebuffer

### Via Store Instructions

Kernel writes to framebuffer using RISC-V store instructions:

```riscv
# Write red pixel at (100, 200)
LUI x3, 0x90000         # Load framebuffer base (upper bits)
ADDI x3, x3, 0          # Add lower bits (0x90000000)
LI x4, 100              # x coordinate
LI x5, 200              # y coordinate
LI x6, 1024             # width
MUL x7, x5, x6          # y * width
ADD x7, x7, x4          # y * width + x
SLLI x7, x7, 2          # (y * width + x) * 4
ADD x3, x3, x7          # framebuffer_base + offset
LI x8, 0xFF0000FF       # Red pixel color
SW x8, 0(x3)            # Store pixel
```

**Why Assembly?**
- Kernel runs in VM (can't call Zig functions directly)
- Store instructions are translated by VM
- Address translation handles `0x90000000` → physical offset

## Framebuffer Synchronization

### Host-Side Access

Host code (macOS app) can access framebuffer directly:

```zig
// Get framebuffer memory from VM
const fb_memory = vm.get_framebuffer_memory();

// Read pixels directly
const pixel = std.mem.readInt(u32, fb_memory[0..4], .little);

// Copy to macOS window (Day 3 task)
copy_to_macos_window(fb_memory);
```

**Why Direct Access?**
- Host needs to render to macOS window
- No translation needed (already physical address)
- Fast: direct memory access

### Dirty Region Tracking

For efficiency, track which regions changed:

```zig
pub const Framebuffer = struct {
    dirty_regions: []DirtyRegion,  // Changed rectangles
    // ...
};

pub const DirtyRegion = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};
```

**Why Track?**
- Only update changed regions in macOS window
- Reduces copy overhead
- Better performance

## Pixel Format Conversion

### RGBA to BGRA

macOS may expect BGRA format (different byte order):

```
RGBA: [R] [G] [B] [A]
BGRA: [B] [G] [R] [A]
```

**Conversion**:

```zig
fn rgba_to_bgra(rgba: u32) u32 {
    const r = (rgba >> 24) & 0xFF;
    const g = (rgba >> 16) & 0xFF;
    const b = (rgba >> 8) & 0xFF;
    const a = rgba & 0xFF;
    
    return (b << 24) | (g << 16) | (r << 8) | a;
}
```

**When to Convert?**
- When copying to macOS window (if needed)
- Or configure framebuffer as BGRA from start

## Performance Considerations

### Drawing Speed

Pixel-by-pixel drawing is slow:

- **Clear**: 1024×768×4 = 3MB write (fast, sequential)
- **Rectangle**: 100×100 = 10,000 pixels (slower)
- **Complex shapes**: Very slow (many pixels)

**Optimizations**:
- Use larger primitives (rectangles vs pixels)
- Batch operations
- Hardware acceleration (future)

### Memory Bandwidth

Framebuffer writes consume memory bandwidth:

- **3MB framebuffer**: Large memory region
- **60 FPS**: 180MB/s write bandwidth
- **Acceptable**: Modern systems handle this easily

## Testing Framebuffer

### Unit Tests

```zig
test "draw_pixel" {
    var fb = Framebuffer.init(fb_memory);
    fb.draw_pixel(100, 200, COLOR_RED);
    
    const offset = (200 * 1024 + 100) * 4;
    const pixel = std.mem.readInt(u32, fb_memory[offset..][0..4], .little);
    try std.testing.expectEqual(COLOR_RED, pixel);
}

test "draw_rect" {
    var fb = Framebuffer.init(fb_memory);
    fb.draw_rect(10, 10, 50, 50, COLOR_GREEN);
    
    // Check corners
    const top_left = std.mem.readInt(u32, fb_memory[(10 * 1024 + 10) * 4..][0..4], .little);
    try std.testing.expectEqual(COLOR_GREEN, top_left);
}
```

### Visual Tests

```zig
test "test_pattern" {
    var fb = Framebuffer.init(fb_memory);
    fb.draw_test_pattern();
    
    // Verify colored rectangles appear
    // (manual visual inspection, or automated pixel checks)
}
```

## Exercises

1. **Pixel Calculation**: Calculate memory offset for pixel at (500, 300).

2. **Color Conversion**: Convert `0x00FF00FF` (green) to BGRA format.

3. **Rectangle Optimization**: How could you optimize `draw_rect()` for
   better performance?

4. **Framebuffer Sync**: When should framebuffer be synced to macOS window?

## Key Takeaways

- Framebuffer: memory region representing display
- Row-major layout: `offset = (y * width + x) * bpp`
- RGBA format: 32-bit, little-endian
- Drawing primitives: clear, pixel, rectangle
- Kernel access: via RISC-V store instructions
- Host access: direct memory read
- Performance: pixel-by-pixel is slow, use larger primitives

## Next Document

**0008-macos-integration.md**: Learn Cocoa/AppKit basics for macOS window
management and event handling.

---

*now == next + 1*

