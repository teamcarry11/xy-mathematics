const std = @import("std");
const tls = @import("tls");

// Grainscape TLS Demo
// Tests basic HTTPS connectivity using grain-tls (forked from ianic/tls.zig)

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n=== Grainscape TLS Demo ===\n\n", .{});
    
    // Test connection to example.com
    const host = "example.com";
    const port: u16 = 443;
    
    std.debug.print("Connecting to {s}:{d}...\n", .{ host, port });

    // Create TCP connection
    var stream = try std.net.tcpConnectToHost(allocator, host, port);
    defer stream.close();

    std.debug.print("TCP connection established\n", .{});

    // Wrap with TLS using Grain TLS
    std.debug.print("Initiating TLS handshake...\n", .{});

    var tls_client = try tls.TlsClient.init(allocator, stream, host);
    defer tls_client.deinit();

    std.debug.print("TLS handshake complete!\n", .{});
    std.debug.print("Protocol: TLS 1.3\n", .{});

    // Send HTTP GET request
    const request = "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n";
    std.debug.print("\nSending HTTP request...\n", .{});

    try tls_client.writeAll(request);

    // Read response
    std.debug.print("Reading response...\n\n", .{});

    var total_bytes: usize = 0;
    var first_chunk = true;
    while (try tls_client.next()) |data| {
        total_bytes += data.len;
        if (first_chunk) {
            // Print first 500 bytes
            std.debug.print("{s}", .{data[0..@min(500, data.len)]});
            if (data.len > 500) {
                std.debug.print("... (truncated)\n", .{});
            }
            first_chunk = false;
        }
    }

    std.debug.print("\n--- Response ({d} bytes total) ---\n", .{total_bytes});
    std.debug.print("\n✓ TLS demo successful!\n", .{});
}
