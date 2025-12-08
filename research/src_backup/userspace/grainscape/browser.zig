const std = @import("std");
const stdlib = @import("userspace_stdlib");

// Grainscape Browser - Core Module
// A minimal text-based browser for Grain OS

pub const BrowserConfig = struct {
    viewport_width: usize = 80,
    viewport_height: usize = 24,
    max_history: usize = 100,
    user_agent: []const u8 = "Grainscape/0.1.0 (Grain OS; RISC-V64)",
};

pub const Url = struct {
    scheme: []const u8, // "http", "https", "grain"
    host: []const u8,
    port: ?u16 = null,
    path: []const u8 = "/",
    
    pub fn parse(allocator: std.mem.Allocator, url_str: []const u8) !Url {
        // Simple URL parser
        // Format: scheme://host:port/path
        
        const scheme_end = std.mem.indexOf(u8, url_str, "://") orelse return error.InvalidUrl;
        const scheme = url_str[0..scheme_end];
        
        var remainder = url_str[scheme_end + 3..];
        
        // Find path start
        const path_start = std.mem.indexOf(u8, remainder, "/") orelse remainder.len;
        const host_port = remainder[0..path_start];
        const path = if (path_start < remainder.len) remainder[path_start..] else "/";
        
        // Parse host:port
        var host: []const u8 = undefined;
        var port: ?u16 = null;
        
        if (std.mem.indexOf(u8, host_port, ":")) |colon_pos| {
            host = host_port[0..colon_pos];
            const port_str = host_port[colon_pos + 1..];
            port = try std.fmt.parseInt(u16, port_str, 10);
        } else {
            host = host_port;
        }
        
        return Url{
            .scheme = try allocator.dupe(u8, scheme),
            .host = try allocator.dupe(u8, host),
            .port = port,
            .path = try allocator.dupe(u8, path),
        };
    }
    
    pub fn deinit(self: *Url, allocator: std.mem.Allocator) void {
        allocator.free(self.scheme);
        allocator.free(self.host);
        allocator.free(self.path);
    }
};

pub const Page = struct {
    url: Url,
    title: []const u8,
    content: []const u8,
    rendered_lines: [][]const u8,
    
    pub fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        self.url.deinit(allocator);
        allocator.free(self.title);
        allocator.free(self.content);
        for (self.rendered_lines) |line| {
            allocator.free(line);
        }
        allocator.free(self.rendered_lines);
    }
};

pub const Browser = struct {
    allocator: std.mem.Allocator,
    config: BrowserConfig,
    current_page: ?Page = null,
    history: std.ArrayList([]const u8),
    history_index: usize = 0,
    
    pub fn init(allocator: std.mem.Allocator, config: BrowserConfig) !Browser {
        return Browser{
            .allocator = allocator,
            .config = config,
            .history = .{
                .items = &.{},
                .capacity = 0,
            },
        };
    }
    
    pub fn deinit(self: *Browser) void {
        if (self.current_page) |*page| {
            page.deinit(self.allocator);
        }
        for (self.history.items) |url| {
            self.allocator.free(url);
        }
        self.history.deinit(self.allocator);
    }
    
    pub fn navigate(self: *Browser, url_str: []const u8) !void {
        // Parse URL
        var url = try Url.parse(self.allocator, url_str);
        errdefer url.deinit(self.allocator);
        
        // Fetch content (stub for now)
        const content = try self.fetch_content(&url);
        errdefer self.allocator.free(content);
        
        // Render content
        const rendered = try self.render_content(content);
        errdefer {
            for (rendered) |line| self.allocator.free(line);
            self.allocator.free(rendered);
        }
        
        // Extract title (first line or URL)
        const title = try self.allocator.dupe(u8, url.host);
        
        // Clean up old page
        if (self.current_page) |*old_page| {
            old_page.deinit(self.allocator);
        }
        
        // Set new page
        self.current_page = Page{
            .url = url,
            .title = title,
            .content = content,
            .rendered_lines = rendered,
        };
        
        // Add to history
        const history_url = try self.allocator.dupe(u8, url_str);
        try self.history.append(self.allocator, history_url);
        self.history_index = self.history.items.len - 1;
    }
    
    fn fetch_content(self: *Browser, url: *const Url) ![]const u8 {
        // Stub: In real implementation, this would make HTTP requests
        // For now, return a placeholder
        
        if (std.mem.eql(u8, url.scheme, "grain")) {
            // Internal Grain OS pages
            return try self.allocator.dupe(u8, 
                \\Welcome to Grainscape
                \\
                \\This is the Grain OS native browser.
                \\
                \\Features:
                \\- Text-based rendering
                \\- Minimal resource usage
                \\- Native RISC-V performance
                \\
                \\Navigate to grain://help for more information.
            );
        }
        
        return try self.allocator.dupe(u8, "Page content placeholder");
    }
    
    fn render_content(self: *Browser, content: []const u8) ![][]const u8 {
        // Simple line-based rendering
        var lines: std.ArrayList([]const u8) = .{
            .items = &.{},
            .capacity = 0,
        };
        errdefer {
            for (lines.items) |line| self.allocator.free(line);
            lines.deinit(self.allocator);
        }
        
        var it = std.mem.splitScalar(u8, content, '\n');
        while (it.next()) |line| {
            // Wrap long lines
            if (line.len > self.config.viewport_width) {
                var start: usize = 0;
                while (start < line.len) {
                    const end = @min(start + self.config.viewport_width, line.len);
                    const wrapped = try self.allocator.dupe(u8, line[start..end]);
                    try lines.append(self.allocator, wrapped);
                    start = end;
                }
            } else {
                const dup_line = try self.allocator.dupe(u8, line);
                try lines.append(self.allocator, dup_line);
            }
        }
        
        return lines.toOwnedSlice(self.allocator);
    }
    
    pub fn render_viewport(self: *Browser, writer: anytype) !void {
        if (self.current_page) |*page| {
            // Render title bar
            try writer.print("+-- {s} ", .{page.title});
            const title_len = page.title.len + 5;
            var i: usize = title_len;
            while (i < self.config.viewport_width) : (i += 1) {
                try writer.writeByte('-');
            }
            try writer.writeByte('+');
            try writer.writeByte('\n');
            
            // Render content lines
            const max_lines = self.config.viewport_height - 3; // Title + status + border
            for (page.rendered_lines, 0..) |line, idx| {
                if (idx >= max_lines) break;
                try writer.print("| {s}", .{line});
                
                // Pad to viewport width
                const padding = self.config.viewport_width - line.len - 2;
                var j: usize = 0;
                while (j < padding) : (j += 1) {
                    try writer.writeByte(' ');
                }
                try writer.writeByte('|');
                try writer.writeByte('\n');
            }
            
            // Fill remaining lines
            const rendered_count = @min(page.rendered_lines.len, max_lines);
            var remaining = max_lines - rendered_count;
            while (remaining > 0) : (remaining -= 1) {
                try writer.writeByte('|');
                i = 0;
                while (i < self.config.viewport_width - 2) : (i += 1) {
                    try writer.writeByte(' ');
                }
                try writer.writeByte('|');
                try writer.writeByte('\n');
            }
            
            // Bottom border
            try writer.writeByte('+');
            i = 0;
            while (i < self.config.viewport_width - 2) : (i += 1) {
                try writer.writeByte('-');
            }
            try writer.writeByte('+');
            try writer.writeByte('\n');
        } else {
            try writer.writeAll("No page loaded. Navigate to a URL to begin.\n");
        }
    }
};
