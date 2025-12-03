//! Tests for Grain OS system logging system.
//!
//! Why: Verify system logging functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const SystemLogger = grain_os.system_logger.SystemLogger;
const LogLevel = grain_os.system_logger.LogLevel;

test "system logger initialization" {
    const logger = SystemLogger.init();
    std.debug.assert(logger.entries_len == 0);
    std.debug.assert(logger.next_entry_id == 1);
    std.debug.assert(logger.get_min_log_level() == LogLevel.debug);
}

test "log system event" {
    var logger = SystemLogger.init();
    const entry_id_opt = logger.log(LogLevel.info, "test_source", "Test message", 1000);
    std.debug.assert(entry_id_opt != null);
    if (entry_id_opt) |entry_id| {
        std.debug.assert(entry_id == 1);
        std.debug.assert(logger.get_log_count() == 1);
    }
}

test "find entry by ID" {
    var logger = SystemLogger.init();
    if (logger.log(LogLevel.info, "test_source", "Test message", 1000)) |entry_id| {
        const entry_opt = logger.find_entry(entry_id);
        std.debug.assert(entry_opt != null);
        if (entry_opt) |entry| {
            std.debug.assert(entry.entry_id == entry_id);
            std.debug.assert(entry.level == LogLevel.info);
        }
    }
}

test "get entry by index" {
    var logger = SystemLogger.init();
    _ = logger.log(LogLevel.info, "test_source", "Test message", 1000);
    const entry_opt = logger.get_entry(0);
    std.debug.assert(entry_opt != null);
    if (entry_opt) |entry| {
        std.debug.assert(entry.level == LogLevel.info);
    }
}

test "set minimum log level" {
    var logger = SystemLogger.init();
    logger.set_min_log_level(LogLevel.warning);
    std.debug.assert(logger.get_min_log_level() == LogLevel.warning);
    // Debug log should be filtered out.
    const entry_id_opt = logger.log(LogLevel.debug, "test_source", "Debug message", 1000);
    std.debug.assert(entry_id_opt == null);
    // Warning log should be logged.
    const entry_id_opt2 = logger.log(LogLevel.warning, "test_source", "Warning message", 2000);
    std.debug.assert(entry_id_opt2 != null);
}

test "get log count by level" {
    var logger = SystemLogger.init();
    _ = logger.log(LogLevel.info, "test_source", "Info message 1", 1000);
    _ = logger.log(LogLevel.info, "test_source", "Info message 2", 2000);
    _ = logger.log(LogLevel.error, "test_source", "Error message", 3000);
    std.debug.assert(logger.get_log_count_by_level(LogLevel.info) == 2);
    std.debug.assert(logger.get_log_count_by_level(LogLevel.error) == 1);
}

test "clear all logs" {
    var logger = SystemLogger.init();
    _ = logger.log(LogLevel.info, "test_source", "Test message", 1000);
    std.debug.assert(logger.get_log_count() == 1);
    logger.clear_all();
    std.debug.assert(logger.get_log_count() == 0);
}

test "compositor log system event" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const entry_id_opt = comp.log_system_event(LogLevel.info, "test_source", "Test message", 1000);
    std.debug.assert(entry_id_opt != null);
}

test "compositor set minimum log level" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_min_log_level(LogLevel.warning);
    std.debug.assert(comp.get_min_log_level() == LogLevel.warning);
}

test "compositor get log count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_log_count() == 0);
    _ = comp.log_system_event(LogLevel.info, "test_source", "Test message", 1000);
    std.debug.assert(comp.get_log_count() == 1);
}

test "compositor get log count by level" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.log_system_event(LogLevel.info, "test_source", "Info message", 1000);
    _ = comp.log_system_event(LogLevel.error, "test_source", "Error message", 2000);
    std.debug.assert(comp.get_log_count_by_level(LogLevel.info) == 1);
    std.debug.assert(comp.get_log_count_by_level(LogLevel.error) == 1);
}

test "log levels" {
    std.debug.assert(@intFromEnum(LogLevel.debug) == 0);
    std.debug.assert(@intFromEnum(LogLevel.info) == 1);
    std.debug.assert(@intFromEnum(LogLevel.warning) == 2);
    std.debug.assert(@intFromEnum(LogLevel.error) == 3);
    std.debug.assert(@intFromEnum(LogLevel.critical) == 4);
}

test "system logger constants" {
    std.debug.assert(grain_os.system_logger.MAX_LOG_ENTRIES == 1024);
    std.debug.assert(grain_os.system_logger.MAX_LOG_MESSAGE_LEN == 512);
    std.debug.assert(grain_os.system_logger.MAX_LOG_SOURCE_LEN == 64);
}

