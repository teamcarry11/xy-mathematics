# Grain TLS

**TLS 1.3 Client for Grain OS**

A simplified, pure Zig TLS 1.3 client implementation forked from [ianic/tls.zig](https://github.com/ianic/tls.zig).

## Philosophy

Grain TLS follows "The Art of Grain" philosophy:
- **Minimal**: TLS 1.3 client only (no server, no TLS 1.2)
- **Decomplected**: Simple stream-based API
- **Pure Zig**: No C dependencies
- **grain_case**: Consistent naming convention

## Usage

```zig
const grain_tls = @import("grain_tls");

// Connect TCP
var stream = try std.net.tcpConnectToHost(allocator, "example.com", 443);
defer stream.close();

// Upgrade to TLS
var tls_client = try grain_tls.TlsClient.init(
    allocator,
    stream,
    "example.com",
);
defer tls_client.close();

// Write encrypted data
try tls_client.write("GET / HTTP/1.1\r\n...");

// Read encrypted data
var buf: [4096]u8 = undefined;
const n = try tls_client.read(&buf);
```

## Features

- ✅ TLS 1.3 client
- ✅ AES-GCM and ChaCha20-Poly1305 ciphers
- ✅ Certificate validation
- ✅ Simple stream-based API
- ❌ TLS 1.2 (removed for simplicity)
- ❌ Server implementation (not needed)

## Attribution

Based on [tls.zig](https://github.com/ianic/tls.zig) by Igor Anić (MIT License).
Refactored and simplified for Grain OS.

## License

MIT License - See [LICENSE](LICENSE) for details.
