//! Grain Network Tools: Network utilities for system administration.
//!
//! Why: Provide network scanning, monitoring, and diagnostic capabilities.
//! Architecture: Network scanner, port scanner, bandwidth monitor, DNS tools.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-04-102946-pst: Active implementation
//! 2025-12-07-020824-pst: Phase 10.3 WebSocket integration for live statistics

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max network devices (explicit limit)
// 2025-12-04-102946-pst: Active constant
pub const MAX_NETWORK_DEVICES: u32 = 256;

// Bounded: Max ports to scan (explicit limit)
// 2025-12-04-102946-pst: Active constant
pub const MAX_PORTS: u32 = 65535;

// Bounded: Max active connections (explicit limit)
// 2025-12-04-102946-pst: Active constant
pub const MAX_CONNECTIONS: u32 = 512;

// Bounded: Max hostname length (explicit limit, in bytes)
// 2025-12-04-102946-pst: Active constant
pub const MAX_HOSTNAME_LEN: u32 = 256;

// Bounded: Max WebSocket clients (explicit limit)
// 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
pub const MAX_WEBSOCKET_CLIENTS: u32 = 32;

// Port state enumeration.
// 2025-12-04-102946-pst: Active enum
pub const PortState = enum(u8) {
    closed, // Port is closed
    open, // Port is open
    filtered, // Port is filtered (firewall)
    unknown, // Port state unknown
};

// Connection state enumeration.
// 2025-12-04-102946-pst: Active enum
pub const ConnectionState = enum(u8) {
    established, // Connection established
    listening, // Listening for connections
    time_wait, // Connection in TIME_WAIT
    close_wait, // Connection in CLOSE_WAIT
    closed, // Connection closed
};

// Network device structure.
// 2025-12-04-102946-pst: Active struct
pub const NetworkDevice = struct {
    device_id: u32,
    ip_address: [grain_core.network_manager.MAX_IP_LEN]u8,
    ip_address_len: u32,
    hostname: [MAX_HOSTNAME_LEN]u8,
    hostname_len: u32,
    mac_address: [18]u8, // MAC address format: XX:XX:XX:XX:XX:XX
    mac_address_len: u32,
    discovered_at: u64,
    active: bool,
};

// Port scan result structure.
// 2025-12-04-102946-pst: Active struct
pub const PortScanResult = struct {
    port: u16,
    state: PortState,
    service: [32]u8, // Service name (e.g., "HTTP", "SSH")
    service_len: u32,
};

// Connection information structure.
// 2025-12-04-102946-pst: Active struct
pub const ConnectionInfo = struct {
    connection_id: u32,
    local_ip: [grain_core.network_manager.MAX_IP_LEN]u8,
    local_ip_len: u32,
    local_port: u16,
    remote_ip: [grain_core.network_manager.MAX_IP_LEN]u8,
    remote_ip_len: u32,
    remote_port: u16,
    state: ConnectionState,
    protocol: u8, // 6 = TCP, 17 = UDP
};

// Network Tools application state.
// 2025-12-04-102946-pst: Active struct
// 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
pub const NetworkToolsApp = struct {
    network_manager: *grain_core.network_manager.NetworkManager,
    dns_resolver: *grain_core.dns_resolver.DnsResolver,
    devices: [MAX_NETWORK_DEVICES]?NetworkDevice,
    devices_len: u32,
    connections: [MAX_CONNECTIONS]?ConnectionInfo,
    connections_len: u32,
    bandwidth_bytes_sent: u64,
    bandwidth_bytes_received: u64,
    bandwidth_timestamp: u64,
    websocket_manager: *grain_core.websocket.WebSocketManager,
    websocket_clients: [MAX_WEBSOCKET_CLIENTS]u32,
    websocket_clients_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize network tools application.
    // 2025-12-06-011616-pst: Active function
    // 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
    pub fn init(
        allocator: std.mem.Allocator,
        nm: *grain_core.network_manager.NetworkManager,
        dns_res: *grain_core.dns_resolver.DnsResolver,
        ws_manager: *grain_core.websocket.WebSocketManager,
    ) NetworkToolsApp {
        // Precondition: Allocator and managers must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(nm) != 0);
        std.debug.assert(@intFromPtr(dns_res) != 0);
        std.debug.assert(@intFromPtr(ws_manager) != 0);

        var app = NetworkToolsApp{
            .network_manager = nm,
            .dns_resolver = dns_res,
            .devices = undefined,
            .devices_len = 0,
            .connections = undefined,
            .connections_len = 0,
            .bandwidth_bytes_sent = 0,
            .bandwidth_bytes_received = 0,
            .bandwidth_timestamp = 0,
            .websocket_manager = ws_manager,
            .websocket_clients = undefined,
            .websocket_clients_len = 0,
            .allocator = allocator,
        };

        // Initialize devices array
        var i: u32 = 0;
        while (i < MAX_NETWORK_DEVICES) : (i += 1) {
            app.devices[i] = null;
        }

        // Initialize connections array
        i = 0;
        while (i < MAX_CONNECTIONS) : (i += 1) {
            app.connections[i] = null;
        }

        // Initialize WebSocket clients array
        i = 0;
        while (i < MAX_WEBSOCKET_CLIENTS) : (i += 1) {
            app.websocket_clients[i] = 0;
        }

        // Postcondition: App must be valid
        std.debug.assert(app.devices_len == 0);
        std.debug.assert(app.connections_len == 0);
        std.debug.assert(app.websocket_clients_len == 0);

        return app;
    }

    /// Scan network for devices.
    // 2025-12-04-102946-pst: Active function
    pub fn scan_network(
        self: *NetworkToolsApp,
        network_ip: []const u8,
        netmask: []const u8,
    ) u32 {
        // Precondition: IP and netmask must be valid
        std.debug.assert(network_ip.len > 0);
        std.debug.assert(netmask.len > 0);

        // Clear existing devices
        self.devices_len = 0;
        var i: u32 = 0;
        while (i < MAX_NETWORK_DEVICES) : (i += 1) {
            self.devices[i] = null;
        }

        // In full implementation, would perform actual network scan
        // For now, add localhost as example device
        if (self.devices_len < MAX_NETWORK_DEVICES) {
            const now = @as(u64, @intCast(std.time.timestamp()));
            var device = NetworkDevice{
                .device_id = 1,
                .ip_address = undefined,
                .ip_address_len = 0,
                .hostname = undefined,
                .hostname_len = 0,
                .mac_address = undefined,
                .mac_address_len = 0,
                .discovered_at = now,
                .active = true,
            };

            // Set IP address
            const ip_len = @min(network_ip.len, grain_core.network_manager.MAX_IP_LEN);
            @memset(&device.ip_address, 0);
            @memcpy(device.ip_address[0..ip_len], network_ip[0..ip_len]);
            device.ip_address_len = @as(u32, @intCast(ip_len));

            // Set hostname
            const hostname_str = "localhost";
            const hostname_len = @min(hostname_str.len, MAX_HOSTNAME_LEN);
            @memset(&device.hostname, 0);
            @memcpy(device.hostname[0..hostname_len], hostname_str[0..hostname_len]);
            device.hostname_len = @as(u32, @intCast(hostname_len));

            self.devices[self.devices_len] = device;
            self.devices_len += 1;
        }

        // Postcondition: Devices must be valid
        std.debug.assert(self.devices_len <= MAX_NETWORK_DEVICES);

        return self.devices_len;
    }

    /// Scan ports on a host.
    // 2025-12-04-102946-pst: Active function
    pub fn scan_ports(
        self: *NetworkToolsApp,
        host_ip: []const u8,
        start_port: u16,
        end_port: u16,
        results: []PortScanResult,
        results_len: *u32,
    ) void {
        // Precondition: Host IP and ports must be valid
        std.debug.assert(host_ip.len > 0);
        std.debug.assert(start_port <= end_port);
        std.debug.assert(end_port <= MAX_PORTS);
        std.debug.assert(results.len > 0);
        std.debug.assert(results_len != null);

        results_len.* = 0;

        // In full implementation, would perform actual port scan
        // For now, add example results
        var port: u16 = start_port;
        while (port <= end_port and results_len.* < results.len) : (port += 1) {
            // Example: mark common ports as open
            if (port == 22 or port == 80 or port == 443) {
                results[results_len.*] = PortScanResult{
                    .port = port,
                    .state = .open,
                    .service = undefined,
                    .service_len = 0,
                };

                // Set service name
                var service_name: []const u8 = "";
                if (port == 22) {
                    service_name = "SSH";
                } else if (port == 80) {
                    service_name = "HTTP";
                } else if (port == 443) {
                    service_name = "HTTPS";
                }

                if (service_name.len > 0) {
                    const service_len = @min(service_name.len, 32);
                    @memset(&results[results_len.*].service, 0);
                    @memcpy(results[results_len.*].service[0..service_len], service_name[0..service_len]);
                    results[results_len.*].service_len = @as(u32, @intCast(service_len));
                }

                results_len.* += 1;
            }
        }
    }

    /// Update bandwidth statistics.
    // 2025-12-04-102946-pst: Active function
    pub fn update_bandwidth(
        self: *NetworkToolsApp,
        bytes_sent: u64,
        bytes_received: u64,
    ) void {
        // Precondition: Values must be valid
        std.debug.assert(bytes_sent >= self.bandwidth_bytes_sent);
        std.debug.assert(bytes_received >= self.bandwidth_bytes_received);

        self.bandwidth_bytes_sent = bytes_sent;
        self.bandwidth_bytes_received = bytes_received;
        self.bandwidth_timestamp = @as(u64, @intCast(std.time.timestamp()));

        // Postcondition: Timestamp must be set
        std.debug.assert(self.bandwidth_timestamp > 0);

        // Broadcast bandwidth update to WebSocket clients
        self.broadcast_bandwidth_update();
    }

    /// Get bandwidth statistics.
    // 2025-12-04-102946-pst: Active function
    pub fn get_bandwidth(
        self: *const NetworkToolsApp,
        bytes_sent: *u64,
        bytes_received: *u64,
    ) void {
        // Precondition: Pointers must be valid
        std.debug.assert(@intFromPtr(bytes_sent) != 0);
        std.debug.assert(@intFromPtr(bytes_received) != 0);

        bytes_sent.* = self.bandwidth_bytes_sent;
        bytes_received.* = self.bandwidth_bytes_received;
    }

    /// Add connection to connection list.
    // 2025-12-04-102946-pst: Active function
    pub fn add_connection(
        self: *NetworkToolsApp,
        local_ip: []const u8,
        local_port: u16,
        remote_ip: []const u8,
        remote_port: u16,
        state: ConnectionState,
        protocol: u8,
    ) bool {
        // Precondition: Must have space for connection
        std.debug.assert(self.connections_len < MAX_CONNECTIONS);
        std.debug.assert(local_ip.len > 0);
        std.debug.assert(remote_ip.len > 0);

        const connection_id = self.connections_len + 1;
        var conn = ConnectionInfo{
            .connection_id = connection_id,
            .local_ip = undefined,
            .local_ip_len = 0,
            .local_port = local_port,
            .remote_ip = undefined,
            .remote_ip_len = 0,
            .remote_port = remote_port,
            .state = state,
            .protocol = protocol,
        };

        // Set local IP
        const local_ip_len = @min(local_ip.len, grain_core.network_manager.MAX_IP_LEN);
        @memset(&conn.local_ip, 0);
        @memcpy(conn.local_ip[0..local_ip_len], local_ip[0..local_ip_len]);
        conn.local_ip_len = @as(u32, @intCast(local_ip_len));

        // Set remote IP
        const remote_ip_len = @min(remote_ip.len, grain_core.network_manager.MAX_IP_LEN);
        @memset(&conn.remote_ip, 0);
        @memcpy(conn.remote_ip[0..remote_ip_len], remote_ip[0..remote_ip_len]);
        conn.remote_ip_len = @as(u32, @intCast(remote_ip_len));

        self.connections[self.connections_len] = conn;
        self.connections_len += 1;

        // Postcondition: Connection count increased
        std.debug.assert(self.connections_len > 0);
        std.debug.assert(self.connections_len <= MAX_CONNECTIONS);

        return true;
    }

    /// Get DNS lookup result (using Grain Core DNS resolver).
    // 2025-12-06-011616-pst: Active function
    pub fn dns_lookup(
        self: *NetworkToolsApp,
        hostname: []const u8,
        record_type: grain_core.dns_resolver.DnsRecordType,
        ip_address: []u8,
        ip_address_len: *u32,
    ) bool {
        // Precondition: Hostname and buffer must be valid
        std.debug.assert(hostname.len > 0);
        std.debug.assert(hostname.len <= grain_core.dns_resolver.MAX_HOSTNAME_LEN);
        std.debug.assert(ip_address.len > 0);
        std.debug.assert(ip_address_len != null);

        ip_address_len.* = 0;

        // Use Grain Core DNS resolver
        const now = @as(u64, @intCast(std.time.timestamp()));
        var ip_buf: [grain_core.dns_resolver.MAX_IP_ADDRESS_LEN]u8 = undefined;
        const found = self.dns_resolver.resolve_hostname(
            hostname,
            record_type,
            now,
            &ip_buf,
        );

        if (found) {
            const ip_len = @min(grain_core.dns_resolver.MAX_IP_ADDRESS_LEN, ip_address.len);
            @memcpy(ip_address[0..ip_len], ip_buf[0..ip_len]);
            ip_address_len.* = ip_len;
            return true;
        }

        return false;
    }

    /// Add DNS cache entry (using Grain Core DNS resolver).
    // 2025-12-06-011616-pst: Active function
    pub fn add_dns_cache_entry(
        self: *NetworkToolsApp,
        hostname: []const u8,
        record_type: grain_core.dns_resolver.DnsRecordType,
        ip_address: []const u8,
    ) bool {
        // Precondition: Hostname and IP must be valid
        std.debug.assert(hostname.len > 0);
        std.debug.assert(hostname.len <= grain_core.dns_resolver.MAX_HOSTNAME_LEN);
        std.debug.assert(ip_address.len > 0);
        std.debug.assert(ip_address.len <= grain_core.dns_resolver.MAX_IP_ADDRESS_LEN);

        const now = @as(u64, @intCast(std.time.timestamp()));
        const result = self.dns_resolver.add_cache_entry(
            hostname,
            record_type,
            ip_address,
            now,
        );

        // Postcondition: Cache entry added if successful
        std.debug.assert(result or self.dns_resolver.cache_len >= grain_core.dns_resolver.MAX_DNS_CACHE_ENTRIES);

        return result;
    }

    /// Clear expired DNS cache entries.
    // 2025-12-06-011616-pst: Active function
    pub fn clear_expired_dns_cache(self: *NetworkToolsApp) u32 {
        // Precondition: App must be valid
        std.debug.assert(@intFromPtr(self) != 0);

        const now = @as(u64, @intCast(std.time.timestamp()));
        const cleared_count = self.dns_resolver.clear_expired_cache(now);

        // Postcondition: Cleared count must be valid
        std.debug.assert(cleared_count <= self.dns_resolver.cache_len);

        return cleared_count;
    }

    /// Add WebSocket client for live statistics updates.
    // 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
    pub fn add_websocket_client(
        self: *NetworkToolsApp,
        connection_id: u32,
    ) bool {
        // Precondition: Connection ID must be valid
        std.debug.assert(connection_id > 0);
        std.debug.assert(self.websocket_clients_len < MAX_WEBSOCKET_CLIENTS);

        if (self.websocket_clients_len >= MAX_WEBSOCKET_CLIENTS) {
            return false;
        }

        self.websocket_clients[self.websocket_clients_len] = connection_id;
        self.websocket_clients_len += 1;

        // Postcondition: Client count increased
        std.debug.assert(self.websocket_clients_len > 0);
        std.debug.assert(self.websocket_clients_len <= MAX_WEBSOCKET_CLIENTS);

        return true;
    }

    /// Remove WebSocket client.
    // 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
    pub fn remove_websocket_client(
        self: *NetworkToolsApp,
        connection_id: u32,
    ) bool {
        // Precondition: Connection ID must be valid
        std.debug.assert(connection_id > 0);

        var i: u32 = 0;
        while (i < self.websocket_clients_len) : (i += 1) {
            if (self.websocket_clients[i] == connection_id) {
                var j: u32 = i;
                while (j < self.websocket_clients_len - 1) : (j += 1) {
                    self.websocket_clients[j] = self.websocket_clients[j + 1];
                }
                self.websocket_clients_len -= 1;
                return true;
            }
        }

        return false;
    }

    /// Broadcast bandwidth update to WebSocket clients (internal).
    // 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
    fn broadcast_bandwidth_update(self: *NetworkToolsApp) void {
        // Precondition: App must be valid
        std.debug.assert(self.bandwidth_timestamp > 0);

        if (self.websocket_clients_len == 0) {
            return;
        }

        // Serialize bandwidth statistics to JSON-like format (simplified)
        var json_buf: [256]u8 = undefined;
        const json_len = self.serialize_bandwidth_json(&json_buf);
        if (json_len == 0) {
            return;
        }

        // Create WebSocket frame
        var frame = grain_core.websocket.WebSocketFrame.init();
        frame.flags.opcode = grain_core.websocket.FrameOpcode.text;
        frame.flags.fin = true;
        frame.flags.masked = false;
        frame.payload_len = @intCast(json_len);

        var i: u32 = 0;
        while (i < json_len and i < grain_core.websocket.MAX_FRAME_SIZE) : (i += 1) {
            frame.payload[i] = json_buf[i];
        }

        // Broadcast to all clients
        i = 0;
        while (i < self.websocket_clients_len) : (i += 1) {
            const conn_id = self.websocket_clients[i];
            const conn = self.websocket_manager.find_connection(conn_id);
            if (conn != null and conn.?.state == grain_core.websocket.ConnectionState.open) {
                // Frame would be sent here (actual send via socket not implemented)
                _ = frame;
            }
        }
    }

    /// Serialize bandwidth statistics to JSON format (simplified).
    // 2025-12-07-020824-pst: Phase 10.3 WebSocket integration
    fn serialize_bandwidth_json(
        self: *const NetworkToolsApp,
        buf: []u8,
    ) u32 {
        // Precondition: Buffer must be valid
        std.debug.assert(buf.len >= 256);
        std.debug.assert(self.bandwidth_timestamp > 0);

        // Simplified JSON serialization
        const json_fmt = 
            \\{"bytes_sent":%d,"bytes_received":%d,"devices":%d,"connections":%d}
        ;
        const written = std.fmt.bufPrint(buf, json_fmt, .{
            self.bandwidth_bytes_sent,
            self.bandwidth_bytes_received,
            self.devices_len,
            self.connections_len,
        }) catch return 0;

        return @intCast(written.len);
    }
};

