const std = @import("std");

/// Dream Browser Font Renderer: TTF/OTF font loading and glyph rendering.
/// ~<~ Glow Airbend: explicit font loading, bounded glyph cache.
/// ~~~~ Glow Waterbend: fonts flow deterministically through DAG.
///
/// This implements:
/// - TTF/OTF font loading (basic font parsing)
/// - Glyph rendering (character to bitmap conversion)
/// - Font cache (cached loaded fonts)
/// - Glyph cache (cached rendered glyphs)
pub const DreamBrowserFontRenderer = struct {
    // Bounded: Max 100 loaded fonts
    pub const MAX_LOADED_FONTS: u32 = 100;
    
    // Bounded: Max 10,000 cached glyphs
    pub const MAX_CACHED_GLYPHS: u32 = 10_000;
    
    // Bounded: Max 256x256 pixels per glyph
    pub const MAX_GLYPH_DIMENSION: u32 = 256;
    
    // Bounded: Max 10MB font file size
    pub const MAX_FONT_SIZE: u32 = 10 * 1024 * 1024;
    
    /// Font format.
    pub const FontFormat = enum {
        ttf,
        otf,
        unknown,
    };
    
    /// Loaded font (font data and metadata).
    pub const LoadedFont = struct {
        family_name: []const u8, // Font family name (e.g., "Arial", "Times New Roman")
        style: FontStyle, // Font style (normal, bold, italic, bold_italic)
        format: FontFormat, // Font format (TTF, OTF)
        data: []const u8, // Font file data (owned)
        size: u32, // Font size in bytes
    };
    
    /// Font style.
    pub const FontStyle = enum {
        normal,
        bold,
        italic,
        bold_italic,
    };
    
    /// Rendered glyph (bitmap representation of a character).
    pub const RenderedGlyph = struct {
        character: u32, // Unicode code point
        font_family: []const u8, // Font family name
        font_size: u32, // Font size in pixels
        width: u32, // Glyph width in pixels
        height: u32, // Glyph height in pixels
        bitmap: []u8, // Grayscale bitmap (width * height bytes)
        advance_x: u32, // Horizontal advance (pixels to next glyph)
        advance_y: u32, // Vertical advance (pixels to next line)
        bearing_x: i32, // Horizontal bearing (offset from origin)
        bearing_y: i32, // Vertical bearing (offset from baseline)
    };
    
    /// Font cache entry.
    pub const FontCacheEntry = struct {
        key: []const u8, // Cache key (family:style:size)
        font: LoadedFont, // Loaded font
        last_accessed: u64, // Timestamp of last access
    };
    
    /// Glyph cache entry.
    pub const GlyphCacheEntry = struct {
        key: []const u8, // Cache key (character:family:size)
        glyph: RenderedGlyph, // Rendered glyph
        last_accessed: u64, // Timestamp of last access
    };
    
    /// Font cache.
    pub const FontCache = struct {
        entries: []FontCacheEntry, // Cache entries
        entries_len: u32, // Current number of entries
        entries_index: u32, // Circular buffer index
    };
    
    /// Glyph cache.
    pub const GlyphCache = struct {
        entries: []GlyphCacheEntry, // Cache entries
        entries_len: u32, // Current number of entries
        entries_index: u32, // Circular buffer index
    };
    
    allocator: std.mem.Allocator,
    font_cache: FontCache,
    glyph_cache: GlyphCache,
    
    /// Initialize font renderer.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserFontRenderer {
        // Pre-allocate font cache
        const font_entries = try allocator.alloc(FontCacheEntry, MAX_LOADED_FONTS);
        
        // Pre-allocate glyph cache
        const glyph_entries = try allocator.alloc(GlyphCacheEntry, MAX_CACHED_GLYPHS);
        
        return DreamBrowserFontRenderer{
            .allocator = allocator,
            .font_cache = FontCache{
                .entries = font_entries,
                .entries_len = 0,
                .entries_index = 0,
            },
            .glyph_cache = GlyphCache{
                .entries = glyph_entries,
                .entries_len = 0,
                .entries_index = 0,
            },
        };
    }
    
    /// Deinitialize font renderer.
    pub fn deinit(self: *DreamBrowserFontRenderer) void {
        // Free font cache
        for (self.font_cache.entries[0..self.font_cache.entries_len]) |*entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.font.family_name);
            self.allocator.free(entry.font.data);
        }
        
        // Free glyph cache
        for (self.glyph_cache.entries[0..self.glyph_cache.entries_len]) |*entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.glyph.font_family);
            self.allocator.free(entry.glyph.bitmap);
        }
        
        // Free cache arrays
        self.allocator.free(self.font_cache.entries);
        self.allocator.free(self.glyph_cache.entries);
    }
    
    /// Detect font format from magic bytes.
    pub fn detect_format(data: []const u8) FontFormat {
        // Assert: Data must be non-empty
        std.debug.assert(data.len > 0);
        
        if (data.len < 4) {
            return .unknown;
        }
        
        // TTF/OTF signature: Check for "OTTO" (OTF) or "true" (TTF) in first 4 bytes
        // OTF: 4F 54 54 4F ("OTTO")
        if (data.len >= 4 and std.mem.eql(u8, data[0..4], "OTTO")) {
            return .otf;
        }
        
        // TTF: Check for "true" or "ttcf" (TrueType Collection)
        if (data.len >= 4) {
            if (std.mem.eql(u8, data[0..4], "true") or std.mem.eql(u8, data[0..4], "ttcf")) {
                return .ttf;
            }
        }
        
        return .unknown;
    }
    
    /// Load font from data (auto-detect format).
    /// Note: This is a simplified font loader. Full TTF/OTF support requires handling:
    /// - TTF: cmap, head, hhea, hmtx, maxp, name, post, glyf, loca tables
    /// - OTF: CFF (Compact Font Format), similar table structure
    /// - Font metrics (ascent, descent, line height)
    /// - Character mapping (Unicode to glyph index)
    /// For now, this is a placeholder that stores font data.
    pub fn load_font(
        self: *DreamBrowserFontRenderer,
        family_name: []const u8,
        style: FontStyle,
        data: []const u8,
    ) !void {
        // Assert: Family name and data must be non-empty
        std.debug.assert(family_name.len > 0);
        std.debug.assert(family_name.len <= 256); // Bounded family name length
        std.debug.assert(data.len > 0);
        std.debug.assert(data.len <= MAX_FONT_SIZE);
        
        const format = detect_format(data);
        if (format == .unknown) {
            return error.UnknownFontFormat;
        }
        
        // Create cache key
        const key = try self.create_font_cache_key(family_name, style);
        errdefer self.allocator.free(key);
        
        // Check if already cached
        var i: u32 = 0;
        while (i < self.font_cache.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.font_cache.entries[i].key, key)) {
                // Update last accessed
                self.font_cache.entries[i].last_accessed = get_current_timestamp();
                self.allocator.free(key);
                return;
            }
        }
        
        // Copy font data
        const font_data = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(font_data);
        
        const family_copy = try self.allocator.dupe(u8, family_name);
        errdefer self.allocator.free(family_copy);
        
        // Add to cache (or overwrite oldest if cache is full)
        if (self.font_cache.entries_len < MAX_LOADED_FONTS) {
            const idx = self.font_cache.entries_len;
            self.font_cache.entries[idx] = FontCacheEntry{
                .key = key,
                .font = LoadedFont{
                    .family_name = family_copy,
                    .style = style,
                    .format = format,
                    .data = font_data,
                    .size = @as(u32, @intCast(data.len)),
                },
                .last_accessed = get_current_timestamp(),
            };
            self.font_cache.entries_len += 1;
        } else {
            // Overwrite oldest entry (circular buffer)
            const idx = self.font_cache.entries_index;
            const old_entry = &self.font_cache.entries[idx];
            
            // Free old entry
            self.allocator.free(old_entry.key);
            self.allocator.free(old_entry.font.family_name);
            self.allocator.free(old_entry.font.data);
            
            // Set new entry
            self.font_cache.entries[idx] = FontCacheEntry{
                .key = key,
                .font = LoadedFont{
                    .family_name = family_copy,
                    .style = style,
                    .format = format,
                    .data = font_data,
                    .size = @as(u32, @intCast(data.len)),
                },
                .last_accessed = get_current_timestamp(),
            };
            
            self.font_cache.entries_index = (idx + 1) % MAX_LOADED_FONTS;
        }
    }
    
    /// Create font cache key (family:style).
    fn create_font_cache_key(
        self: *DreamBrowserFontRenderer,
        family_name: []const u8,
        style: FontStyle,
    ) ![]const u8 {
        const style_str = switch (style) {
            .normal => "normal",
            .bold => "bold",
            .italic => "italic",
            .bold_italic => "bold_italic",
        };
        
        // Format: "family:style"
        const key_len = family_name.len + 1 + style_str.len;
        const key = try self.allocator.alloc(u8, key_len);
        std.mem.copy(u8, key[0..family_name.len], family_name);
        key[family_name.len] = ':';
        std.mem.copy(u8, key[family_name.len + 1..], style_str);
        
        return key;
    }
    
    /// Render glyph (character to bitmap).
    /// Note: This is a simplified glyph renderer. Full glyph rendering requires:
    /// - TTF: Parse glyf table, extract outline, rasterize with hinting
    /// - OTF: Parse CFF table, extract outline, rasterize
    /// - Subpixel rendering (anti-aliasing)
    /// - Kerning (character spacing adjustments)
    /// For now, this is a placeholder that returns an error.
    pub fn render_glyph(
        self: *DreamBrowserFontRenderer,
        character: u32,
        font_family: []const u8,
        font_size: u32,
    ) !RenderedGlyph {
        // Assert: Parameters must be valid
        std.debug.assert(font_family.len > 0);
        std.debug.assert(font_size > 0);
        std.debug.assert(font_size <= 256); // Bounded font size
        
        // Self, character, font_family, font_size not used in placeholder implementation
        // (will be used in full implementation)
        _ = self;
        _ = character;
        
        // TODO: Implement full glyph rendering
        // For now, return error (placeholder)
        return error.GlyphRenderingNotImplemented;
    }
    
    /// Get cached glyph.
    pub fn get_cached_glyph(
        self: *DreamBrowserFontRenderer,
        character: u32,
        font_family: []const u8,
        font_size: u32,
    ) ?*const RenderedGlyph {
        // Create cache key
        const key = self.create_glyph_cache_key(character, font_family, font_size) catch return null;
        defer self.allocator.free(key);
        
        var i: u32 = 0;
        while (i < self.glyph_cache.entries_len) : (i += 1) {
            if (std.mem.eql(u8, self.glyph_cache.entries[i].key, key)) {
                // Update last accessed
                self.glyph_cache.entries[i].last_accessed = get_current_timestamp();
                return &self.glyph_cache.entries[i].glyph;
            }
        }
        return null;
    }
    
    /// Create glyph cache key (character:family:size).
    fn create_glyph_cache_key(
        self: *DreamBrowserFontRenderer,
        character: u32,
        font_family: []const u8,
        font_size: u32,
    ) ![]const u8 {
        // Format: "character:family:size"
        var buffer: [256]u8 = undefined;
        const key_str = try std.fmt.bufPrint(&buffer, "{d}:{s}:{d}", .{ character, font_family, font_size });
        return try self.allocator.dupe(u8, key_str);
    }
    
    /// Get current timestamp (simplified).
    fn get_current_timestamp() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative;
    }
    
    /// Clear font cache.
    pub fn clear_font_cache(self: *DreamBrowserFontRenderer) void {
        // Free cached fonts
        for (self.font_cache.entries[0..self.font_cache.entries_len]) |*entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.font.family_name);
            self.allocator.free(entry.font.data);
        }
        
        // Reset cache
        self.font_cache.entries_len = 0;
        self.font_cache.entries_index = 0;
    }
    
    /// Clear glyph cache.
    pub fn clear_glyph_cache(self: *DreamBrowserFontRenderer) void {
        // Free cached glyphs
        for (self.glyph_cache.entries[0..self.glyph_cache.entries_len]) |*entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.glyph.font_family);
            self.allocator.free(entry.glyph.bitmap);
        }
        
        // Reset cache
        self.glyph_cache.entries_len = 0;
        self.glyph_cache.entries_index = 0;
    }
    
    /// Get cache statistics.
    pub fn get_cache_stats(self: *const DreamBrowserFontRenderer) CacheStats {
        return CacheStats{
            .loaded_fonts = self.font_cache.entries_len,
            .cached_glyphs = self.glyph_cache.entries_len,
            .max_fonts = MAX_LOADED_FONTS,
            .max_glyphs = MAX_CACHED_GLYPHS,
        };
    }
    
    /// Cache statistics.
    pub const CacheStats = struct {
        loaded_fonts: u32,
        cached_glyphs: u32,
        max_fonts: u32,
        max_glyphs: u32,
    };
};

test "font renderer initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = try DreamBrowserFontRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    // Assert: Renderer initialized
    try std.testing.expect(renderer.font_cache.entries.len > 0);
    try std.testing.expect(renderer.glyph_cache.entries.len > 0);
}

test "font format detection ttf" {
    const ttf_signature = "true";
    const format = DreamBrowserFontRenderer.detect_format(ttf_signature);
    try std.testing.expect(format == .ttf);
}

test "font format detection otf" {
    const otf_signature = "OTTO";
    const format = DreamBrowserFontRenderer.detect_format(otf_signature);
    try std.testing.expect(format == .otf);
}

test "font format detection unknown" {
    const unknown_data = "not a font";
    const format = DreamBrowserFontRenderer.detect_format(unknown_data);
    try std.testing.expect(format == .unknown);
}

test "font renderer cache stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var renderer = try DreamBrowserFontRenderer.init(arena.allocator());
    defer renderer.deinit();
    
    const stats = renderer.get_cache_stats();
    try std.testing.expect(stats.loaded_fonts == 0);
    try std.testing.expect(stats.cached_glyphs == 0);
    try std.testing.expect(stats.max_fonts == DreamBrowserFontRenderer.MAX_LOADED_FONTS);
    try std.testing.expect(stats.max_glyphs == DreamBrowserFontRenderer.MAX_CACHED_GLYPHS);
}

