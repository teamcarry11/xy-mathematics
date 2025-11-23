const std = @import("std");

/// Dream Browser Image Decoder: PNG and JPEG decoding for browser rendering.
/// ~<~ Glow Airbend: explicit decoding, bounded buffers.
/// ~~~~ Glow Waterbend: images flow deterministically through DAG.
///
/// This implements:
/// - PNG decoding (basic RGBA support)
/// - JPEG decoding (basic RGB support)
/// - Image format detection (magic bytes)
/// - Decoded image storage (RGBA pixel buffer)
pub const DreamBrowserImageDecoder = struct {
    // Bounded: Max 10MB image size
    pub const MAX_IMAGE_SIZE: u32 = 10 * 1024 * 1024;
    
    // Bounded: Max 10,000x10,000 pixels
    pub const MAX_IMAGE_DIMENSION: u32 = 10_000;
    
    // Bounded: Max 100 decoded images in cache
    pub const MAX_CACHED_IMAGES: u32 = 100;
    
    /// Decoded image (RGBA pixel buffer).
    pub const DecodedImage = struct {
        width: u32, // Image width in pixels
        height: u32, // Image height in pixels
        pixels: []u8, // RGBA pixel data (width * height * 4 bytes)
        format: ImageFormat, // Image format (PNG, JPEG)
    };
    
    /// Image format.
    pub const ImageFormat = enum {
        png,
        jpeg,
        unknown,
    };
    
    /// Image cache entry.
    pub const ImageCacheEntry = struct {
        url: []const u8, // Image URL (key)
        image: DecodedImage, // Decoded image
        last_accessed: u64, // Timestamp of last access
    };
    
    /// Image cache.
    pub const ImageCache = struct {
        entries: []ImageCacheEntry, // Cache entries
        entries_len: u32, // Current number of entries
        entries_index: u32, // Circular buffer index
    };
    
    allocator: std.mem.Allocator,
    cache: ImageCache,
    
    /// Initialize image decoder.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserImageDecoder {
        // Pre-allocate image cache
        const entries = try allocator.alloc(ImageCacheEntry, MAX_CACHED_IMAGES);
        
        return DreamBrowserImageDecoder{
            .allocator = allocator,
            .cache = ImageCache{
                .entries = entries,
                .entries_len = 0,
                .entries_index = 0,
            },
        };
    }
    
    /// Deinitialize image decoder.
    pub fn deinit(self: *DreamBrowserImageDecoder) void {
        // Free cached images
        for (self.cache.entries[0..self.cache.entries_len]) |*entry| {
            self.allocator.free(entry.url);
            self.allocator.free(entry.image.pixels);
        }
        
        // Free cache array
        self.allocator.free(self.cache.entries);
    }
    
    /// Detect image format from magic bytes.
    pub fn detect_format(data: []const u8) ImageFormat {
        // Assert: Data must be non-empty
        std.debug.assert(data.len > 0);
        
        if (data.len < 8) {
            return .unknown;
        }
        
        // PNG signature: 89 50 4E 47 0D 0A 1A 0A
        if (data.len >= 8 and std.mem.eql(u8, data[0..8], "\x89PNG\r\n\x1a\n")) {
            return .png;
        }
        
        // JPEG signature: FF D8 FF
        if (data.len >= 3 and data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF) {
            return .jpeg;
        }
        
        return .unknown;
    }
    
    /// Decode PNG image (basic RGBA support).
    /// Note: This is a simplified PNG decoder. Full PNG support requires handling:
    /// - Multiple chunk types (IHDR, PLTE, IDAT, IEND)
    /// - Compression (zlib/deflate)
    /// - Filtering (sub, up, average, paeth)
    /// - Interlacing (Adam7)
    /// For now, this is a placeholder that returns an error.
    pub fn decode_png(
        self: *DreamBrowserImageDecoder,
        data: []const u8,
    ) !DecodedImage {
        // Assert: Data must be non-empty
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_IMAGE_SIZE);
        
        // TODO: Implement full PNG decoder
        // For now, return error (placeholder)
        return error.PngNotImplemented;
    }
    
    /// Decode JPEG image (basic RGB support).
    /// Note: This is a simplified JPEG decoder. Full JPEG support requires handling:
    /// - Multiple segment types (SOI, SOF, DHT, DQT, SOS, EOI)
    /// - Huffman decoding
    /// - Discrete Cosine Transform (DCT)
    /// - Quantization
    /// - Color space conversion (YCbCr to RGB)
    /// For now, this is a placeholder that returns an error.
    pub fn decode_jpeg(
        self: *DreamBrowserImageDecoder,
        data: []const u8,
    ) !DecodedImage {
        // Self and data not used in placeholder implementation
        _ = self;
        _ = data;
        // Assert: Data must be non-empty
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_IMAGE_SIZE);
        
        // TODO: Implement full JPEG decoder
        // For now, return error (placeholder)
        return error.JpegNotImplemented;
    }
    
    /// Decode image from data (auto-detect format).
    pub fn decode(
        self: *DreamBrowserImageDecoder,
        data: []const u8,
    ) !DecodedImage {
        // Assert: Data must be non-empty
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_IMAGE_SIZE);
        
        const format = detect_format(data);
        
        return switch (format) {
            .png => self.decode_png(data),
            .jpeg => self.decode_jpeg(data),
            .unknown => error.UnknownImageFormat,
        };
    }
    
    /// Get cached image by URL.
    pub fn get_cached_image(
        self: *DreamBrowserImageDecoder,
        url: []const u8,
    ) ?*const DecodedImage {
        var i: u32 = 0;
        while (i < self.cache.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.cache.entries[i].url, url)) {
                // Update last accessed timestamp
                self.cache.entries[i].last_accessed = get_current_timestamp();
                return &self.cache.entries[i].image;
            }
        }
        return null;
    }
    
    /// Cache decoded image.
    pub fn cache_image(
        self: *DreamBrowserImageDecoder,
        url: []const u8,
        image: DecodedImage,
    ) !void {
        // Assert: URL must be non-empty
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= 1024); // Bounded URL length
        
        // Check if already cached
        var i: u32 = 0;
        while (i < self.cache.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.cache.entries[i].url, url)) {
                // Update existing entry
                self.allocator.free(self.cache.entries[i].image.pixels);
                self.cache.entries[i].image = image;
                self.cache.entries[i].last_accessed = get_current_timestamp();
                return;
            }
        }
        
        // Add new entry (or overwrite oldest if cache is full)
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        
        if (self.cache.entries_len < MAX_CACHED_IMAGES) {
            const idx = self.cache.entries_len;
            self.cache.entries[idx] = ImageCacheEntry{
                .url = url_copy,
                .image = image,
                .last_accessed = get_current_timestamp(),
            };
            self.cache.entries_len += 1;
        } else {
            // Overwrite oldest entry (circular buffer)
            const idx = self.cache.entries_index;
            const old_entry = &self.cache.entries[idx];
            
            // Free old entry
            self.allocator.free(old_entry.url);
            self.allocator.free(old_entry.image.pixels);
            
            // Set new entry
            self.cache.entries[idx] = ImageCacheEntry{
                .url = url_copy,
                .image = image,
                .last_accessed = get_current_timestamp(),
            };
            
            self.cache.entries_index = (idx + 1) % MAX_CACHED_IMAGES;
        }
    }
    
    /// Get current timestamp (simplified).
    fn get_current_timestamp() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative;
    }
    
    /// Clear image cache.
    pub fn clear_cache(self: *DreamBrowserImageDecoder) void {
        // Free cached images
        for (self.cache.entries[0..self.cache.entries_len]) |*entry| {
            self.allocator.free(entry.url);
            self.allocator.free(entry.image.pixels);
        }
        
        // Reset cache
        self.cache.entries_len = 0;
        self.cache.entries_index = 0;
    }
    
    /// Get cache statistics.
    pub fn get_cache_stats(self: *const DreamBrowserImageDecoder) CacheStats {
        return CacheStats{
            .cached_images = self.cache.entries_len,
            .max_cache_size = MAX_CACHED_IMAGES,
        };
    }
    
    /// Cache statistics.
    pub const CacheStats = struct {
        cached_images: u32,
        max_cache_size: u32,
    };
};

test "image decoder initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var decoder = try DreamBrowserImageDecoder.init(arena.allocator());
    defer decoder.deinit();
    
    // Assert: Decoder initialized
    try std.testing.expect(decoder.cache.entries.len > 0);
}

test "image format detection png" {
    const png_signature = "\x89PNG\r\n\x1a\n";
    const format = DreamBrowserImageDecoder.detect_format(png_signature);
    try std.testing.expect(format == .png);
}

test "image format detection jpeg" {
    const jpeg_signature = "\xFF\xD8\xFF";
    const format = DreamBrowserImageDecoder.detect_format(jpeg_signature);
    try std.testing.expect(format == .jpeg);
}

test "image format detection unknown" {
    const unknown_data = "not an image";
    const format = DreamBrowserImageDecoder.detect_format(unknown_data);
    try std.testing.expect(format == .unknown);
}

test "image decoder cache" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var decoder = try DreamBrowserImageDecoder.init(arena.allocator());
    defer decoder.deinit();
    
    // Create a test image
    const test_url = "test.png";
    const test_image = DreamBrowserImageDecoder.DecodedImage{
        .width = 100,
        .height = 100,
        .pixels = try arena.allocator().alloc(u8, 100 * 100 * 4),
        .format = .png,
    };
    
    // Cache image
    try decoder.cache_image(test_url, test_image);
    
    // Get cached image
    const cached = decoder.get_cached_image(test_url);
    try std.testing.expect(cached != null);
    try std.testing.expect(cached.?.width == 100);
    try std.testing.expect(cached.?.height == 100);
}

test "image decoder cache stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var decoder = try DreamBrowserImageDecoder.init(arena.allocator());
    defer decoder.deinit();
    
    const stats = decoder.get_cache_stats();
    try std.testing.expect(stats.cached_images == 0);
    try std.testing.expect(stats.max_cache_size == DreamBrowserImageDecoder.MAX_CACHED_IMAGES);
}

