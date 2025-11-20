const std = @import("std");

// Import from grainstore fork (now as a proper module)
const tls_impl = @import("grain_tls_impl");

/// Simplified TLS 1.3 client for Grain OS
/// Wraps ianic/tls.zig with grain_case naming
pub const TlsClient = struct {
    connection: tls_impl.Connection,
    
    /// Initialize TLS client and perform handshake
    pub fn init(
        allocator: std.mem.Allocator,
        stream: std.net.Stream,
        host: []const u8,
    ) !TlsClient {
        // Load system root certificates
        var root_ca = try tls_impl.config.cert.fromSystem(allocator);
        errdefer root_ca.deinit(allocator);
        
        // Create IO buffers
        var input_buf: [tls_impl.input_buffer_len]u8 = undefined;
        var output_buf: [tls_impl.output_buffer_len]u8 = undefined;
        
        // Create reader/writer from stream
        var reader = stream.reader(&input_buf);
        var writer = stream.writer(&output_buf);
        
        // Perform TLS handshake
        const connection = try tls_impl.client(reader.interface(), &writer.interface, .{
            .host = host,
            .root_ca = root_ca,
        });
        
        return TlsClient{
            .connection = connection,
        };
    }
    
    /// Write encrypted data
    pub fn writeAll(self: *TlsClient, data: []const u8) !void {
        try self.connection.writeAll(data);
    }
    
    /// Read next chunk of decrypted data
    pub fn next(self: *TlsClient) !?[]const u8 {
        return try self.connection.next();
    }
    
    /// Close TLS connection
    pub fn close(self: *TlsClient) !void {
        try self.connection.close();
    }
    
    pub fn deinit(self: *TlsClient) void {
        self.close() catch {};
    }
};

// Re-export useful types with grain_case names
pub const CipherSuite = tls_impl.config.CipherSuite;
pub const NamedGroup = tls_impl.config.NamedGroup;
pub const Version = tls_impl.config.Version;
