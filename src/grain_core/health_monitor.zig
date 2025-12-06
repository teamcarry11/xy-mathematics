//! Grain OS Health Monitor: System health monitoring and reporting.
//!
//! Why: Provide system health monitoring for overall system status.
//! Architecture: Health checks, health status, health reporting.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max health checks.
pub const MAX_HEALTH_CHECKS: u32 = 32;

// Bounded: Max health check name length.
pub const MAX_HEALTH_CHECK_NAME_LEN: u32 = 64;

// Bounded: Max health check message length.
pub const MAX_HEALTH_CHECK_MSG_LEN: u32 = 256;

// Health status.
pub const HealthStatus = enum(u8) {
    healthy,
    warning,
    critical,
    unknown,
};

// Health check: represents a system health check.
pub const HealthCheck = struct {
    check_id: u32,
    name: [MAX_HEALTH_CHECK_NAME_LEN]u8,
    name_len: u32,
    status: HealthStatus,
    message: [MAX_HEALTH_CHECK_MSG_LEN]u8,
    message_len: u32,
    last_check_time: u64,
    active: bool,

    pub fn init() HealthCheck {
        var check = HealthCheck{
            .check_id = 0,
            .name = undefined,
            .name_len = 0,
            .status = HealthStatus.unknown,
            .message = undefined,
            .message_len = 0,
            .last_check_time = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_HEALTH_CHECK_NAME_LEN) : (i += 1) {
            check.name[i] = 0;
        }
        i = 0;
        while (i < MAX_HEALTH_CHECK_MSG_LEN) : (i += 1) {
            check.message[i] = 0;
        }
        return check;
    }
};

// Health monitor: monitors system health.
pub const HealthMonitor = struct {
    checks: [MAX_HEALTH_CHECKS]HealthCheck,
    checks_len: u32,
    next_check_id: u32,
    overall_status: HealthStatus,

    pub fn init() HealthMonitor {
        var monitor = HealthMonitor{
            .checks = undefined,
            .checks_len = 0,
            .next_check_id = 1,
            .overall_status = HealthStatus.unknown,
        };
        var i: u32 = 0;
        while (i < MAX_HEALTH_CHECKS) : (i += 1) {
            monitor.checks[i] = HealthCheck.init();
        }
        return monitor;
    }

    // Add health check.
    pub fn add_health_check(
        self: *HealthMonitor,
        name: []const u8,
    ) ?u32 {
        if (self.checks_len >= MAX_HEALTH_CHECKS) {
            return null;
        }
        if (name.len > MAX_HEALTH_CHECK_NAME_LEN) {
            return null;
        }
        const check_id = self.next_check_id;
        self.next_check_id += 1;
        self.checks[self.checks_len] = HealthCheck.init();
        self.checks[self.checks_len].check_id = check_id;
        self.checks[self.checks_len].status = HealthStatus.unknown;
        self.checks[self.checks_len].active = true;
        var i: u32 = 0;
        while (i < MAX_HEALTH_CHECK_NAME_LEN) : (i += 1) {
            self.checks[self.checks_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_HEALTH_CHECK_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.checks[self.checks_len].name[i] = name[i];
        }
        self.checks[self.checks_len].name_len = @intCast(name_len);
        self.checks_len += 1;
        return check_id;
    }

    // Find health check by ID.
    pub fn find_health_check(
        self: *HealthMonitor,
        check_id: u32,
    ) ?*HealthCheck {
        std.debug.assert(check_id > 0);
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].check_id == check_id and self.checks[i].active) {
                return &self.checks[i];
            }
        }
        return null;
    }

    // Update health check status.
    pub fn update_health_check(
        self: *HealthMonitor,
        check_id: u32,
        status: HealthStatus,
        message: []const u8,
        timestamp: u64,
    ) bool {
        std.debug.assert(check_id > 0);
        if (self.find_health_check(check_id)) |check| {
            check.status = status;
            check.last_check_time = timestamp;
            var i: u32 = 0;
            while (i < MAX_HEALTH_CHECK_MSG_LEN) : (i += 1) {
                check.message[i] = 0;
            }
            const msg_len = @min(message.len, MAX_HEALTH_CHECK_MSG_LEN);
            i = 0;
            while (i < msg_len) : (i += 1) {
                check.message[i] = message[i];
            }
            check.message_len = @intCast(msg_len);
            self.update_overall_status();
            return true;
        }
        return false;
    }

    // Update overall status based on all checks.
    pub fn update_overall_status(self: *HealthMonitor) void {
        var has_critical: bool = false;
        var has_warning: bool = false;
        var has_healthy: bool = false;
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].active) {
                switch (self.checks[i].status) {
                    HealthStatus.critical => has_critical = true,
                    HealthStatus.warning => has_warning = true,
                    HealthStatus.healthy => has_healthy = true,
                    HealthStatus.unknown => {},
                }
            }
        }
        if (has_critical) {
            self.overall_status = HealthStatus.critical;
        } else if (has_warning) {
            self.overall_status = HealthStatus.warning;
        } else if (has_healthy) {
            self.overall_status = HealthStatus.healthy;
        } else {
            self.overall_status = HealthStatus.unknown;
        }
    }

    // Remove health check.
    pub fn remove_health_check(self: *HealthMonitor, check_id: u32) bool {
        std.debug.assert(check_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].check_id == check_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        while (i < self.checks_len - 1) : (i += 1) {
            self.checks[i] = self.checks[i + 1];
        }
        self.checks_len -= 1;
        self.update_overall_status();
        return true;
    }

    // Get overall status.
    pub fn get_overall_status(self: *const HealthMonitor) HealthStatus {
        return self.overall_status;
    }

    // Get health check count.
    pub fn get_health_check_count(self: *const HealthMonitor) u32 {
        return self.checks_len;
    }

    // Get healthy check count.
    pub fn get_healthy_check_count(self: *const HealthMonitor) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].status == HealthStatus.healthy) {
                count += 1;
            }
        }
        return count;
    }

    // Get warning check count.
    pub fn get_warning_check_count(self: *const HealthMonitor) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].status == HealthStatus.warning) {
                count += 1;
            }
        }
        return count;
    }

    // Get critical check count.
    pub fn get_critical_check_count(self: *const HealthMonitor) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].status == HealthStatus.critical) {
                count += 1;
            }
        }
        return count;
    }
};

