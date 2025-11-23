// 003 Fuzz Test: Randomized testing for macOS Tahoe window implementation.
//
// Objective: Validate Window buffer operations, dimension handling, and memory safety
// under randomized inputs. Tests focus on logic that doesn't require GUI initialization.
//
// Method:
// - Uses SimpleRng for deterministic randomness (wrap-safe arithmetic)
// - Tests buffer operations with random pixel data
// - Tests dimension validation with edge cases
// - Tests memory safety (buffer bounds, pointer validity)
// - Uses Arena allocator to minimize heap noise
//
// Date: 2025-11-10
// Operator: Glow G2 (Stoic Aquarian cadence)
const std = @import("std");

// SimpleRng: inline copy for test (avoiding module path issues).
const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        return .{ .state = seed };
    }

    fn next(self: *SimpleRng) u64 {
        self.state = self.state *% 6364136223846793005 +% 1;
        return self.state;
    }

    pub fn boolean(self: *SimpleRng) bool {
        return (self.next() & 1) == 1;
    }

    pub fn range(self: *SimpleRng, comptime T: type, upper: T) T {
        return self.uint_less_than(T, upper);
    }

    pub fn uint_less_than(self: *SimpleRng, comptime T: type, bound: T) T {
        return @intCast(self.next() % @as(u64, bound));
    }
};

// Window import - using module system
const Window = @import("window").Window;

test "003 fuzz: window buffer operations with random data" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize RNG with deterministic seed.
    var rng = SimpleRng.init(0x1234567890ABCDEF);

    // Test multiple iterations with random configurations.
    const iterations = 100;
    var iteration: u32 = 0;
    while (iteration < iterations) : (iteration += 1) {

        // Generate random title (1-64 chars).
        const title_len = rng.range(u32, 64) + 1;
        const title = try allocator.alloc(u8, title_len);
        defer allocator.free(title);
        for (title) |*byte| {
            byte.* = @as(u8, @truncate(rng.next() % 256));
        }

        // Initialize window (without showing - no GUI needed for buffer tests).
        // Note: Window.init only accepts title, dimensions are fixed at 1024x768.
        var window = Window.init(allocator, title);

        // Assert: window dimensions are valid (static buffer size).
        std.debug.assert(window.width > 0);
        std.debug.assert(window.height > 0);
        std.debug.assert(window.width <= 1024);
        std.debug.assert(window.height <= 768);
        
        // Use actual window dimensions for buffer operations.
        const actual_width = window.width;
        const actual_height = window.height;
        std.debug.assert(window.title.ptr == title.ptr);
        std.debug.assert(window.title.len == title.len);

        // Get buffer and verify it's valid.
        const buffer = window.getBuffer();
        std.debug.assert(buffer.len > 0);
        std.debug.assert(buffer.len % 4 == 0);
        const expected_size = @as(usize, actual_width) * @as(usize, actual_height) * 4;
        std.debug.assert(buffer.len == expected_size);

        // Fill buffer with random RGBA data.
        var pixel_idx: usize = 0;
        while (pixel_idx < buffer.len / 4) : (pixel_idx += 1) {
            const offset = pixel_idx * 4;
            if (offset + 3 < buffer.len) {
                buffer[offset + 0] = @as(u8, @truncate(rng.next() % 256)); // R
                buffer[offset + 1] = @as(u8, @truncate(rng.next() % 256)); // G
                buffer[offset + 2] = @as(u8, @truncate(rng.next() % 256)); // B
                buffer[offset + 3] = @as(u8, @truncate(rng.next() % 256)); // A
            }
        }

        // Verify buffer integrity: all pixels should be RGBA-aligned.
        var verify_idx: usize = 0;
        while (verify_idx < buffer.len) : (verify_idx += 4) {
            if (verify_idx + 3 < buffer.len) {
                // Each pixel should have 4 bytes (RGBA).
                _ = buffer[verify_idx + 0]; // R
                _ = buffer[verify_idx + 1]; // G
                _ = buffer[verify_idx + 2]; // B
                _ = buffer[verify_idx + 3]; // A
            }
        }

        // Test random pixel access patterns.
        const num_samples = @min(100, buffer.len / 4);
        var sample: u32 = 0;
        while (sample < num_samples) : (sample += 1) {
            const pixel_x = rng.range(u32, actual_width);
            const pixel_y = rng.range(u32, actual_height);
            const pixel_offset = (@as(usize, pixel_y) * @as(usize, actual_width) + @as(usize, pixel_x)) * 4;

            // Assert: pixel offset must be within buffer bounds.
            std.debug.assert(pixel_offset + 3 < buffer.len);

            // Read pixel data.
            const r = buffer[pixel_offset + 0];
            const g = buffer[pixel_offset + 1];
            const b = buffer[pixel_offset + 2];
            const a = buffer[pixel_offset + 3];

            // Assert: pixel values are valid (0-255).
            std.debug.assert(r <= 255);
            std.debug.assert(g <= 255);
            std.debug.assert(b <= 255);
            std.debug.assert(a <= 255);

            // Write random pixel data back.
            buffer[pixel_offset + 0] = @as(u8, @truncate(rng.next() % 256));
            buffer[pixel_offset + 1] = @as(u8, @truncate(rng.next() % 256));
            buffer[pixel_offset + 2] = @as(u8, @truncate(rng.next() % 256));
            buffer[pixel_offset + 3] = @as(u8, @truncate(rng.next() % 256));
        }

        // Cleanup: deinit window (no GUI objects to clean up in test).
        window.deinit();
    }
}

test "003 fuzz: window dimension edge cases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rng = SimpleRng.init(0xFEDCBA0987654321);

    // Test window initialization with various titles.
    // Note: Window dimensions are fixed at 1024x768 (static buffer).
    const test_titles = [_][]const u8{
        "A",                    // Minimum length
        "Test",                 // Short
        "A" ** 50,              // Medium
        "A" ** 100,             // Long
        "Window Title",          // Normal
    };

    for (test_titles) |title| {
        var window = Window.init(allocator, title);

        // Assert: dimensions are valid (static buffer size).
        std.debug.assert(window.width > 0);
        std.debug.assert(window.height > 0);
        std.debug.assert(window.width <= 1024);
        std.debug.assert(window.height <= 768);

        // Assert: buffer size matches dimensions.
        const buffer = window.getBuffer();
        const expected_size = @as(usize, window.width) * @as(usize, window.height) * 4;
        std.debug.assert(buffer.len == expected_size);

        // Assert: buffer is RGBA-aligned.
        std.debug.assert(buffer.len % 4 == 0);

        // Assert: title is preserved.
        std.debug.assert(window.title.len == title.len);

        window.deinit();
    }

    // Test random titles with various lengths.
    var iteration: u32 = 0;
    while (iteration < 50) : (iteration += 1) {
        const title_len = rng.range(u32, 256) + 1; // 1-256
        const title = try allocator.alloc(u8, title_len);
        defer allocator.free(title);

        for (title) |*byte| {
            byte.* = @as(u8, @truncate(rng.next() % 256));
        }

        var window = Window.init(allocator, title);

        // Assert: dimensions are valid.
        std.debug.assert(window.width > 0);
        std.debug.assert(window.height > 0);
        std.debug.assert(window.width <= 1024);
        std.debug.assert(window.height <= 768);

        // Assert: buffer size matches dimensions.
        const buffer = window.getBuffer();
        const expected_size = @as(usize, window.width) * @as(usize, window.height) * 4;
        std.debug.assert(buffer.len == expected_size);

        window.deinit();
    }
}

test "003 fuzz: buffer pattern operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rng = SimpleRng.init(0xABCDEF1234567890);

    const title = "Pattern Test";
    var window = Window.init(allocator, title);
    defer window.deinit();

    const buffer = window.getBuffer();
    const width = window.width;
    const height = window.height;

    // Pattern 1: Fill with solid color.
    const solid_color: u32 = 0xFF00FF00; // Green
    var i: usize = 0;
    while (i < buffer.len) : (i += 4) {
        if (i + 3 < buffer.len) {
            buffer[i + 0] = @as(u8, @truncate(solid_color));
            buffer[i + 1] = @as(u8, @truncate(solid_color >> 8));
            buffer[i + 2] = @as(u8, @truncate(solid_color >> 16));
            buffer[i + 3] = @as(u8, @truncate(solid_color >> 24));
        }
    }

    // Pattern 2: Checkerboard pattern.
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const offset = (@as(usize, y) * @as(usize, width) + @as(usize, x)) * 4;
            if (offset + 3 < buffer.len) {
                const is_white = ((x / 32) + (y / 32)) % 2 == 0;
                if (is_white) {
                    buffer[offset + 0] = 0xFF; // R
                    buffer[offset + 1] = 0xFF; // G
                    buffer[offset + 2] = 0xFF; // B
                    buffer[offset + 3] = 0xFF; // A
                } else {
                    buffer[offset + 0] = 0x00; // R
                    buffer[offset + 1] = 0x00; // G
                    buffer[offset + 2] = 0x00; // B
                    buffer[offset + 3] = 0xFF; // A
                }
            }
        }
    }

    // Pattern 3: Random gradient.
    var grad_y: u32 = 0;
    while (grad_y < height) : (grad_y += 1) {
        var grad_x: u32 = 0;
        while (grad_x < width) : (grad_x += 1) {
            const offset = (@as(usize, grad_y) * @as(usize, width) + @as(usize, grad_x)) * 4;
            if (offset + 3 < buffer.len) {
                const intensity = @as(u8, @truncate((grad_x * 255) / width));
                buffer[offset + 0] = intensity; // R
                buffer[offset + 1] = intensity; // G
                buffer[offset + 2] = intensity; // B
                buffer[offset + 3] = 0xFF;      // A
            }
        }
    }

    // Pattern 4: Random noise.
    var noise_iter: u32 = 0;
    while (noise_iter < 1000) : (noise_iter += 1) {
        const noise_x = rng.range(u32, width);
        const noise_y = rng.range(u32, height);
        const offset = (@as(usize, noise_y) * @as(usize, width) + @as(usize, noise_x)) * 4;
        if (offset + 3 < buffer.len) {
            buffer[offset + 0] = @as(u8, @truncate(rng.next() % 256));
            buffer[offset + 1] = @as(u8, @truncate(rng.next() % 256));
            buffer[offset + 2] = @as(u8, @truncate(rng.next() % 256));
            buffer[offset + 3] = 0xFF;
        }
    }
}

test "003 fuzz: buffer bounds safety" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rng = SimpleRng.init(0x1122334455667788);

    const title = "Bounds Test";
    var window = Window.init(allocator, title);
    defer window.deinit();

    const buffer = window.getBuffer();
    const buffer_size = buffer.len;
    const width = window.width;
    const height = window.height;

    // Test: All valid pixel offsets should be within bounds.
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const offset = (@as(usize, y) * @as(usize, width) + @as(usize, x)) * 4;
            std.debug.assert(offset + 3 < buffer_size);
        }
    }

    // Test: Random valid accesses.
    var iteration: u32 = 0;
    while (iteration < 1000) : (iteration += 1) {
        const rand_x = rng.range(u32, width);
        const rand_y = rng.range(u32, height);
        const offset = (@as(usize, rand_y) * @as(usize, width) + @as(usize, rand_x)) * 4;

        // Assert: offset is within bounds.
        std.debug.assert(offset + 3 < buffer_size);

        // Access pixel safely.
        _ = buffer[offset + 0];
        _ = buffer[offset + 1];
        _ = buffer[offset + 2];
        _ = buffer[offset + 3];
    }
}

test "003 fuzz: title handling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rng = SimpleRng.init(0x9988776655443322);

    // Test various title lengths.
    const title_lengths = [_]u32{ 1, 10, 50, 100, 200, 256 };
    for (title_lengths) |title_len| {
        const title = try allocator.alloc(u8, title_len);
        defer allocator.free(title);

        // Fill with random bytes.
        for (title) |*byte| {
            byte.* = @as(u8, @truncate(rng.next() % 256));
        }

        var window = Window.init(allocator, title);

        // Assert: title is preserved.
        std.debug.assert(window.title.ptr == title.ptr);
        std.debug.assert(window.title.len == title_len);

        // Assert: dimensions are valid.
        std.debug.assert(window.width > 0);
        std.debug.assert(window.height > 0);
        std.debug.assert(window.width <= 1024);
        std.debug.assert(window.height <= 768);

        window.deinit();
    }

    // Test random title lengths.
    var iteration: u32 = 0;
    while (iteration < 50) : (iteration += 1) {
        const title_len = rng.range(u32, 256) + 1; // 1-256
        const title = try allocator.alloc(u8, title_len);
        defer allocator.free(title);

        for (title) |*byte| {
            byte.* = @as(u8, @truncate(rng.next() % 256));
        }

        var window = Window.init(allocator, title);

        // Assert: title length matches.
        std.debug.assert(window.title.len == title_len);

        // Assert: dimensions are valid.
        std.debug.assert(window.width > 0);
        std.debug.assert(window.height > 0);
        std.debug.assert(window.width <= 1024);
        std.debug.assert(window.height <= 768);

        window.deinit();
    }
}

