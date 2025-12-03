//! Grain OS System Diagnostics: System diagnostic information and troubleshooting.
//!
//! Why: Provide diagnostic information for troubleshooting system issues.
//! Architecture: Diagnostic checks, issue detection, diagnostic reporting.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max diagnostic checks.
pub const MAX_DIAGNOSTIC_CHECKS: u32 = 32;

// Bounded: Max diagnostic check name length.
pub const MAX_CHECK_NAME_LEN: u32 = 64;

// Bounded: Max diagnostic message length.
pub const MAX_DIAGNOSTIC_MSG_LEN: u32 = 256;

// Diagnostic severity.
pub const DiagnosticSeverity = enum(u8) {
    info,
    warning,
    err,
    critical,
};

// Diagnostic check: represents a diagnostic check.
pub const DiagnosticCheck = struct {
    check_id: u32,
    name: [MAX_CHECK_NAME_LEN]u8,
    name_len: u32,
    severity: DiagnosticSeverity,
    message: [MAX_DIAGNOSTIC_MSG_LEN]u8,
    message_len: u32,
    timestamp: u64,
    active: bool,

    pub fn init() DiagnosticCheck {
        var check = DiagnosticCheck{
            .check_id = 0,
            .name = undefined,
            .name_len = 0,
            .severity = DiagnosticSeverity.info,
            .message = undefined,
            .message_len = 0,
            .timestamp = 0,
            .active = false,
        };
        var i: u32 = 0;
        while (i < MAX_CHECK_NAME_LEN) : (i += 1) {
            check.name[i] = 0;
        }
        i = 0;
        while (i < MAX_DIAGNOSTIC_MSG_LEN) : (i += 1) {
            check.message[i] = 0;
        }
        return check;
    }
};

// System diagnostics: provides system diagnostic information.
pub const SystemDiagnostics = struct {
    checks: [MAX_DIAGNOSTIC_CHECKS]DiagnosticCheck,
    checks_len: u32,
    next_check_id: u32,

    pub fn init() SystemDiagnostics {
        var diagnostics = SystemDiagnostics{
            .checks = undefined,
            .checks_len = 0,
            .next_check_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_DIAGNOSTIC_CHECKS) : (i += 1) {
            diagnostics.checks[i] = DiagnosticCheck.init();
        }
        return diagnostics;
    }

    // Add diagnostic check.
    pub fn add_diagnostic_check(
        self: *SystemDiagnostics,
        name: []const u8,
        severity: DiagnosticSeverity,
        message: []const u8,
        timestamp: u64,
    ) ?u32 {
        if (self.checks_len >= MAX_DIAGNOSTIC_CHECKS) {
            return null;
        }
        if (name.len > MAX_CHECK_NAME_LEN) {
            return null;
        }
        if (message.len > MAX_DIAGNOSTIC_MSG_LEN) {
            return null;
        }
        const check_id = self.next_check_id;
        self.next_check_id += 1;
        self.checks[self.checks_len] = DiagnosticCheck.init();
        self.checks[self.checks_len].check_id = check_id;
        self.checks[self.checks_len].severity = severity;
        self.checks[self.checks_len].timestamp = timestamp;
        self.checks[self.checks_len].active = true;
        var i: u32 = 0;
        while (i < MAX_CHECK_NAME_LEN) : (i += 1) {
            self.checks[self.checks_len].name[i] = 0;
        }
        const name_len = @min(name.len, MAX_CHECK_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.checks[self.checks_len].name[i] = name[i];
        }
        self.checks[self.checks_len].name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_DIAGNOSTIC_MSG_LEN) : (i += 1) {
            self.checks[self.checks_len].message[i] = 0;
        }
        const msg_len = @min(message.len, MAX_DIAGNOSTIC_MSG_LEN);
        i = 0;
        while (i < msg_len) : (i += 1) {
            self.checks[self.checks_len].message[i] = message[i];
        }
        self.checks[self.checks_len].message_len = @intCast(msg_len);
        self.checks_len += 1;
        return check_id;
    }

    // Find diagnostic check by ID.
    pub fn find_diagnostic_check(
        self: *SystemDiagnostics,
        check_id: u32,
    ) ?*DiagnosticCheck {
        std.debug.assert(check_id > 0);
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].check_id == check_id and self.checks[i].active) {
                return &self.checks[i];
            }
        }
        return null;
    }

    // Remove diagnostic check.
    pub fn remove_diagnostic_check(
        self: *SystemDiagnostics,
        check_id: u32,
    ) bool {
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
        return true;
    }

    // Get diagnostic check count.
    pub fn get_diagnostic_check_count(self: *const SystemDiagnostics) u32 {
        return self.checks_len;
    }

    // Get diagnostic check count by severity.
    pub fn get_diagnostic_check_count_by_severity(
        self: *const SystemDiagnostics,
        severity: DiagnosticSeverity,
    ) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].severity == severity) {
                count += 1;
            }
        }
        return count;
    }

    // Clear all diagnostic checks.
    pub fn clear_all(self: *SystemDiagnostics) void {
        self.checks_len = 0;
    }

    // Clear diagnostic checks by severity.
    pub fn clear_by_severity(
        self: *SystemDiagnostics,
        severity: DiagnosticSeverity,
    ) void {
        var i: u32 = 0;
        while (i < self.checks_len) : (i += 1) {
            if (self.checks[i].severity == severity) {
                var j: u32 = i;
                while (j < self.checks_len - 1) : (j += 1) {
                    self.checks[j] = self.checks[j + 1];
                }
                self.checks_len -= 1;
                i -= 1; // Re-check current index.
            }
        }
    }
};

