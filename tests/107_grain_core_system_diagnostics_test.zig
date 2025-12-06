//! Tests for Grain OS system diagnostics.
//!
//! Why: Verify system diagnostics functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const SystemDiagnostics = grain_core.system_diagnostics.SystemDiagnostics;
const DiagnosticSeverity = grain_core.system_diagnostics.DiagnosticSeverity;

test "system diagnostics initialization" {
    const diagnostics = SystemDiagnostics.init();
    std.debug.assert(diagnostics.checks_len == 0);
    std.debug.assert(diagnostics.next_check_id == 1);
}

test "add diagnostic check" {
    var diagnostics = SystemDiagnostics.init();
    const check_id_opt = diagnostics.add_diagnostic_check(
        "high_cpu",
        DiagnosticSeverity.warning,
        "CPU usage is high",
        1000,
    );
    std.debug.assert(check_id_opt != null);
    if (check_id_opt) |check_id| {
        std.debug.assert(check_id == 1);
        std.debug.assert(diagnostics.get_diagnostic_check_count() == 1);
    }
}

test "find diagnostic check" {
    var diagnostics = SystemDiagnostics.init();
    if (diagnostics.add_diagnostic_check("test", DiagnosticSeverity.info, "Test message", 1000)) |check_id| {
        if (diagnostics.find_diagnostic_check(check_id)) |check| {
            std.debug.assert(check.check_id == check_id);
            std.debug.assert(check.severity == DiagnosticSeverity.info);
        }
    }
}

test "remove diagnostic check" {
    var diagnostics = SystemDiagnostics.init();
    if (diagnostics.add_diagnostic_check("test", DiagnosticSeverity.info, "Test", 1000)) |check_id| {
        const result = diagnostics.remove_diagnostic_check(check_id);
        std.debug.assert(result);
        std.debug.assert(diagnostics.get_diagnostic_check_count() == 0);
    }
}

test "get diagnostic check count by severity" {
    var diagnostics = SystemDiagnostics.init();
    _ = diagnostics.add_diagnostic_check("check1", DiagnosticSeverity.warning, "Warning 1", 1000);
    _ = diagnostics.add_diagnostic_check("check2", DiagnosticSeverity.warning, "Warning 2", 1000);
    _ = diagnostics.add_diagnostic_check("check3", DiagnosticSeverity.err, "Error 1", 1000);
    const warning_count = diagnostics.get_diagnostic_check_count_by_severity(DiagnosticSeverity.warning);
    const error_count = diagnostics.get_diagnostic_check_count_by_severity(DiagnosticSeverity.err);
    std.debug.assert(warning_count == 2);
    std.debug.assert(error_count == 1);
}

test "clear all diagnostic checks" {
    var diagnostics = SystemDiagnostics.init();
    _ = diagnostics.add_diagnostic_check("check1", DiagnosticSeverity.info, "Info 1", 1000);
    _ = diagnostics.add_diagnostic_check("check2", DiagnosticSeverity.warning, "Warning 1", 1000);
    std.debug.assert(diagnostics.get_diagnostic_check_count() == 2);
    diagnostics.clear_all();
    std.debug.assert(diagnostics.get_diagnostic_check_count() == 0);
}

test "clear diagnostic checks by severity" {
    var diagnostics = SystemDiagnostics.init();
    _ = diagnostics.add_diagnostic_check("check1", DiagnosticSeverity.info, "Info 1", 1000);
    _ = diagnostics.add_diagnostic_check("check2", DiagnosticSeverity.warning, "Warning 1", 1000);
    _ = diagnostics.add_diagnostic_check("check3", DiagnosticSeverity.warning, "Warning 2", 1000);
    diagnostics.clear_by_severity(DiagnosticSeverity.warning);
    std.debug.assert(diagnostics.get_diagnostic_check_count() == 1);
    const info_count = diagnostics.get_diagnostic_check_count_by_severity(DiagnosticSeverity.info);
    std.debug.assert(info_count == 1);
}

test "compositor add diagnostic check" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const check_id_opt = comp.add_diagnostic_check(
        "high_memory",
        DiagnosticSeverity.warning,
        "Memory usage is high",
        1000,
    );
    std.debug.assert(check_id_opt != null);
}

test "compositor get diagnostic check count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_diagnostic_check("check1", DiagnosticSeverity.info, "Info", 1000);
    _ = comp.add_diagnostic_check("check2", DiagnosticSeverity.warning, "Warning", 1000);
    const count = comp.get_diagnostic_check_count();
    std.debug.assert(count == 2);
}

test "compositor get diagnostic check count by severity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_diagnostic_check("check1", DiagnosticSeverity.err, "Error", 1000);
    _ = comp.add_diagnostic_check("check2", DiagnosticSeverity.err, "Error 2", 1000);
    const error_count = comp.get_diagnostic_check_count_by_severity(DiagnosticSeverity.err);
    std.debug.assert(error_count == 2);
}

test "compositor clear all diagnostic checks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_diagnostic_check("check1", DiagnosticSeverity.info, "Info", 1000);
    comp.clear_all_diagnostic_checks();
    std.debug.assert(comp.get_diagnostic_check_count() == 0);
}

test "diagnostic severity enum" {
    std.debug.assert(@intFromEnum(DiagnosticSeverity.info) == 0);
    std.debug.assert(@intFromEnum(DiagnosticSeverity.warning) == 1);
    std.debug.assert(@intFromEnum(DiagnosticSeverity.err) == 2);
    std.debug.assert(@intFromEnum(DiagnosticSeverity.critical) == 3);
}

test "system diagnostics constants" {
    std.debug.assert(grain_core.system_diagnostics.MAX_DIAGNOSTIC_CHECKS == 32);
    std.debug.assert(grain_core.system_diagnostics.MAX_CHECK_NAME_LEN == 64);
    std.debug.assert(grain_core.system_diagnostics.MAX_DIAGNOSTIC_MSG_LEN == 256);
}

