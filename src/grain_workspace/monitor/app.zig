//! Grain Monitor: System resource monitoring application.
//!
//! Why: Provide real-time system monitoring and resource tracking.
//! Architecture: Process monitoring, resource usage graphs, system metrics.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-164418-pst: Active implementation
//! 2025-12-06-121120-pst: Phase 10.1 WebSocket integration for real-time updates

const std = @import("std");
const grain_core = @import("grain_core");

// Bounded: Max processes to monitor (explicit limit)
// 2025-12-03-164418-pst: Active constant
pub const MAX_MONITORED_PROCESSES: u32 = 256;

// Bounded: Max history entries (explicit limit)
// 2025-12-03-164418-pst: Active constant
pub const MAX_HISTORY_ENTRIES: u32 = 64;

// Bounded: Max alert thresholds (explicit limit)
// 2025-12-03-164418-pst: Active constant
pub const MAX_ALERT_THRESHOLDS: u32 = 16;

// Bounded: Max WebSocket clients (explicit limit)
// 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
pub const MAX_WEBSOCKET_CLIENTS: u32 = 32;

// Alert threshold structure.
// 2025-12-03-164418-pst: Active struct
pub const AlertThreshold = struct {
    resource_type: ResourceType,
    threshold_value: f64,
    enabled: bool,
};

// Resource type enumeration.
// 2025-12-03-164418-pst: Active enum
pub const ResourceType = enum(u8) {
    cpu, // CPU usage percentage
    memory, // Memory usage percentage
    disk, // Disk usage percentage
    network, // Network bandwidth
};

// Process info structure.
// 2025-12-03-164418-pst: Active struct
pub const ProcessInfo = struct {
    process_id: u32,
    name: []const u8,
    name_len: u32,
    cpu_usage: f64,
    memory_usage: u64,
    state: grain_core.process_manager.ProcessState,
};

// System metrics structure.
// 2025-12-03-164418-pst: Active struct
pub const SystemMetrics = struct {
    uptime: u64, // System uptime in seconds
    load_average: f64, // Load average (1 minute)
    cpu_percent: f64, // Overall CPU usage percentage
    memory_percent: f64, // Memory usage percentage
    disk_percent: f64, // Disk usage percentage
    total_processes: u32,
    running_processes: u32,
    timestamp: u64,
};

// Monitor application state.
// 2025-12-03-164418-pst: Active struct
// 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
pub const MonitorApp = struct {
    process_manager: *grain_core.process_manager.ProcessManager,
    resource_monitor: *grain_core.resource_monitor.ResourceMonitor,
    metrics_history: [MAX_HISTORY_ENTRIES]SystemMetrics,
    metrics_history_len: u32,
    metrics_history_index: u32,
    alert_thresholds: [MAX_ALERT_THRESHOLDS]AlertThreshold,
    alert_thresholds_len: u32,
    websocket_manager: *grain_core.websocket.WebSocketManager,
    websocket_clients: [MAX_WEBSOCKET_CLIENTS]u32,
    websocket_clients_len: u32,
    allocator: std.mem.Allocator,

    /// Initialize monitor application.
    // 2025-12-03-164418-pst: Active function
    // 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
    pub fn init(
        allocator: std.mem.Allocator,
        process_mgr: *grain_core.process_manager.ProcessManager,
        resource_mon: *grain_core.resource_monitor.ResourceMonitor,
        ws_manager: *grain_core.websocket.WebSocketManager,
    ) MonitorApp {
        // Precondition: Allocator and managers must be valid
        std.debug.assert(allocator.ptr != null);
        std.debug.assert(@intFromPtr(process_mgr) != 0);
        std.debug.assert(@intFromPtr(resource_mon) != 0);
        std.debug.assert(@intFromPtr(ws_manager) != 0);

        var app = MonitorApp{
            .process_manager = process_mgr,
            .resource_monitor = resource_mon,
            .metrics_history = undefined,
            .metrics_history_len = 0,
            .metrics_history_index = 0,
            .alert_thresholds = undefined,
            .alert_thresholds_len = 0,
            .websocket_manager = ws_manager,
            .websocket_clients = undefined,
            .websocket_clients_len = 0,
            .allocator = allocator,
        };

        // Initialize metrics history
        var i: u32 = 0;
        while (i < MAX_HISTORY_ENTRIES) : (i += 1) {
            app.metrics_history[i] = SystemMetrics{
                .uptime = 0,
                .load_average = 0.0,
                .cpu_percent = 0.0,
                .memory_percent = 0.0,
                .disk_percent = 0.0,
                .total_processes = 0,
                .running_processes = 0,
                .timestamp = 0,
            };
        }

        // Initialize WebSocket clients
        i = 0;
        while (i < MAX_WEBSOCKET_CLIENTS) : (i += 1) {
            app.websocket_clients[i] = 0;
        }

        // Postcondition: App must be valid
        std.debug.assert(app.metrics_history_len == 0);
        std.debug.assert(app.websocket_clients_len == 0);

        return app;
    }

    /// Update system metrics.
    // 2025-12-03-164418-pst: Active function
    pub fn update_metrics(self: *MonitorApp, uptime: u64) void {
        // Precondition: Uptime must be valid
        std.debug.assert(uptime >= 0);

        const usage = self.resource_monitor.current_usage;
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        var metrics = SystemMetrics{
            .uptime = uptime,
            .load_average = 0.0, // TODO: Calculate from process count
            .cpu_percent = usage.cpu_percent,
            .memory_percent = if (usage.memory_total > 0) @as(f64, @floatFromInt(usage.memory_used)) / @as(f64, @floatFromInt(usage.memory_total)) * 100.0 else 0.0,
            .disk_percent = if (usage.disk_total > 0) @as(f64, @floatFromInt(usage.disk_used)) / @as(f64, @floatFromInt(usage.disk_total)) * 100.0 else 0.0,
            .total_processes = usage.total_processes,
            .running_processes = usage.running_processes,
            .timestamp = timestamp,
        };

        // Add to history
        self.metrics_history[self.metrics_history_index] = metrics;
        self.metrics_history_index = (self.metrics_history_index + 1) % MAX_HISTORY_ENTRIES;
        if (self.metrics_history_len < MAX_HISTORY_ENTRIES) {
            self.metrics_history_len += 1;
        }

        // Check alert thresholds
        self.check_alert_thresholds(&metrics);

        // Broadcast metrics to WebSocket clients
        self.broadcast_metrics_update(&metrics);
    }

    /// Get current system metrics.
    // 2025-12-03-164418-pst: Active function
    pub fn get_current_metrics(self: *const MonitorApp) SystemMetrics {
        // Precondition: Must have metrics
        std.debug.assert(self.metrics_history_len > 0);

        const idx = if (self.metrics_history_index == 0) MAX_HISTORY_ENTRIES - 1 else self.metrics_history_index - 1;
        const metrics = self.metrics_history[idx];

        // Postcondition: Metrics must be valid
        std.debug.assert(metrics.timestamp > 0);

        return metrics;
    }

    /// Get process information.
    // 2025-12-03-164418-pst: Active function
    pub fn get_process_info(
        self: *const MonitorApp,
        process_id: u32,
        info: *ProcessInfo,
    ) bool {
        // Precondition: Process ID and info must be valid
        std.debug.assert(process_id > 0);
        std.debug.assert(@intFromPtr(info) != 0);

        var i: u32 = 0;
        while (i < self.process_manager.processes_len) : (i += 1) {
            const proc = &self.process_manager.processes[i];
            if (proc.process_id == process_id and proc.active) {
                info.process_id = proc.process_id;
                info.name = &proc.name;
                info.name_len = proc.name_len;
                info.cpu_usage = proc.cpu_usage;
                info.memory_usage = proc.memory_usage;
                info.state = proc.state;

                // Postcondition: Info must be valid
                std.debug.assert(info.process_id == process_id);

                return true;
            }
        }

        return false;
    }

    /// Get all processes (up to limit).
    // 2025-12-03-164418-pst: Active function
    pub fn get_all_processes(
        self: *const MonitorApp,
        processes: []ProcessInfo,
        processes_len: *u32,
    ) void {
        // Precondition: Processes buffer must be valid
        std.debug.assert(processes.len > 0);
        std.debug.assert(processes_len != null);

        processes_len.* = 0;

        var i: u32 = 0;
        while (i < self.process_manager.processes_len and processes_len.* < processes.len) : (i += 1) {
            const proc = &self.process_manager.processes[i];
            if (proc.active) {
                processes[processes_len.*] = ProcessInfo{
                    .process_id = proc.process_id,
                    .name = &proc.name,
                    .name_len = proc.name_len,
                    .cpu_usage = proc.cpu_usage,
                    .memory_usage = proc.memory_usage,
                    .state = proc.state,
                };
                processes_len.* += 1;
            }
        }
    }

    /// Add alert threshold.
    // 2025-12-03-164418-pst: Active function
    pub fn add_alert_threshold(
        self: *MonitorApp,
        resource_type: ResourceType,
        threshold_value: f64,
    ) !void {
        // Precondition: Must have space for threshold
        std.debug.assert(self.alert_thresholds_len < MAX_ALERT_THRESHOLDS);
        std.debug.assert(threshold_value >= 0.0);
        std.debug.assert(threshold_value <= 100.0);

        self.alert_thresholds[self.alert_thresholds_len] = AlertThreshold{
            .resource_type = resource_type,
            .threshold_value = threshold_value,
            .enabled = true,
        };
        self.alert_thresholds_len += 1;

        // Postcondition: Threshold count increased
        std.debug.assert(self.alert_thresholds_len > 0);
        std.debug.assert(self.alert_thresholds_len <= MAX_ALERT_THRESHOLDS);
    }

    /// Check alert thresholds (internal).
    // 2025-12-03-164418-pst: Active function
    fn check_alert_thresholds(
        self: *MonitorApp,
        metrics: *const SystemMetrics,
    ) void {
        // Precondition: Metrics must be valid
        std.debug.assert(metrics.timestamp > 0);

        var i: u32 = 0;
        while (i < self.alert_thresholds_len) : (i += 1) {
            const threshold = &self.alert_thresholds[i];
            if (!threshold.enabled) {
                continue;
            }

            const current_value: f64 = switch (threshold.resource_type) {
                .cpu => metrics.cpu_percent,
                .memory => metrics.memory_percent,
                .disk => metrics.disk_percent,
                .network => 0.0, // TODO: Network monitoring
            };

            if (current_value >= threshold.threshold_value) {
                // Alert triggered (would notify here)
                _ = current_value; // Suppress unused warning
            }
        }
    }

    /// Add WebSocket client for real-time updates.
    // 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
    pub fn add_websocket_client(
        self: *MonitorApp,
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
    // 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
    pub fn remove_websocket_client(
        self: *MonitorApp,
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

    /// Broadcast metrics update to WebSocket clients (internal).
    // 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
    fn broadcast_metrics_update(
        self: *MonitorApp,
        metrics: *const SystemMetrics,
    ) void {
        // Precondition: Metrics must be valid
        std.debug.assert(metrics.timestamp > 0);

        if (self.websocket_clients_len == 0) {
            return;
        }

        // Serialize metrics to JSON-like format (simplified)
        var json_buf: [512]u8 = undefined;
        const json_len = self.serialize_metrics_json(metrics, &json_buf);
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

    /// Serialize metrics to JSON format (simplified).
    // 2025-12-06-121120-pst: Phase 10.1 WebSocket integration
    fn serialize_metrics_json(
        self: *const MonitorApp,
        metrics: *const SystemMetrics,
        buf: []u8,
    ) u32 {
        // Precondition: Buffer must be valid
        std.debug.assert(buf.len >= 512);
        std.debug.assert(metrics.timestamp > 0);

        _ = self; // Suppress unused warning

        // Simplified JSON serialization
        const json_fmt = 
            \\{"uptime":%d,"cpu":%.2f,"memory":%.2f,"disk":%.2f,"processes":%d,"running":%d}
        ;
        const written = std.fmt.bufPrint(buf, json_fmt, .{
            metrics.uptime,
            metrics.cpu_percent,
            metrics.memory_percent,
            metrics.disk_percent,
            metrics.total_processes,
            metrics.running_processes,
        }) catch return 0;

        return @intCast(written.len);
    }
};

