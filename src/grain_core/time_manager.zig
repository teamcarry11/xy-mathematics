//! Grain OS Time Manager: System time, timezone, and clock management.
//!
//! Why: Provide time and date management for system clock and timezone.
//! Architecture: Time tracking, timezone management, clock synchronization.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max timezone name length.
pub const MAX_TIMEZONE_NAME_LEN: u32 = 64;

// Bounded: Max timezone abbreviation length.
pub const MAX_TIMEZONE_ABBR_LEN: u32 = 8;

// Time format.
pub const TimeFormat = enum(u8) {
    format_12h,
    format_24h,
};

// Date format.
pub const DateFormat = enum(u8) {
    format_iso, // YYYY-MM-DD
    format_us,  // MM/DD/YYYY
    format_eu,  // DD/MM/YYYY
};

// Timezone: represents a timezone.
pub const Timezone = struct {
    name: [MAX_TIMEZONE_NAME_LEN]u8,
    name_len: u32,
    abbreviation: [MAX_TIMEZONE_ABBR_LEN]u8,
    abbr_len: u32,
    offset_seconds: i32, // Offset from UTC in seconds.

    pub fn init() Timezone {
        var tz = Timezone{
            .name = undefined,
            .name_len = 0,
            .abbreviation = undefined,
            .abbr_len = 0,
            .offset_seconds = 0,
        };
        var i: u32 = 0;
        while (i < MAX_TIMEZONE_NAME_LEN) : (i += 1) {
            tz.name[i] = 0;
        }
        i = 0;
        while (i < MAX_TIMEZONE_ABBR_LEN) : (i += 1) {
            tz.abbreviation[i] = 0;
        }
        return tz;
    }
};

// Time manager: manages system time and timezone.
pub const TimeManager = struct {
    system_time: u64, // System time in nanoseconds since epoch.
    timezone: Timezone,
    time_format: TimeFormat,
    date_format: DateFormat,
    auto_sync_enabled: bool,

    pub fn init() TimeManager {
        var manager = TimeManager{
            .system_time = 0,
            .timezone = Timezone.init(),
            .time_format = TimeFormat.format_24h,
            .date_format = DateFormat.format_iso,
            .auto_sync_enabled = false,
        };
        // Set default timezone to UTC.
        var i: u32 = 0;
        while (i < MAX_TIMEZONE_NAME_LEN) : (i += 1) {
            manager.timezone.name[i] = 0;
        }
        const utc_name = "UTC";
        i = 0;
        while (i < utc_name.len) : (i += 1) {
            manager.timezone.name[i] = utc_name[i];
        }
        manager.timezone.name_len = @intCast(utc_name.len);
        i = 0;
        while (i < MAX_TIMEZONE_ABBR_LEN) : (i += 1) {
            manager.timezone.abbreviation[i] = 0;
        }
        const utc_abbr = "UTC";
        i = 0;
        while (i < utc_abbr.len) : (i += 1) {
            manager.timezone.abbreviation[i] = utc_abbr[i];
        }
        manager.timezone.abbr_len = @intCast(utc_abbr.len);
        manager.timezone.offset_seconds = 0;
        return manager;
    }

    // Set system time.
    pub fn set_system_time(self: *TimeManager, time_ns: u64) void {
        self.system_time = time_ns;
    }

    // Get system time.
    pub fn get_system_time(self: *const TimeManager) u64 {
        return self.system_time;
    }

    // Set timezone.
    pub fn set_timezone(
        self: *TimeManager,
        name: []const u8,
        abbreviation: []const u8,
        offset_seconds: i32,
    ) bool {
        if (name.len > MAX_TIMEZONE_NAME_LEN) {
            return false;
        }
        if (abbreviation.len > MAX_TIMEZONE_ABBR_LEN) {
            return false;
        }
        var i: u32 = 0;
        while (i < MAX_TIMEZONE_NAME_LEN) : (i += 1) {
            self.timezone.name[i] = 0;
        }
        const name_len = @min(name.len, MAX_TIMEZONE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            self.timezone.name[i] = name[i];
        }
        self.timezone.name_len = @intCast(name_len);
        i = 0;
        while (i < MAX_TIMEZONE_ABBR_LEN) : (i += 1) {
            self.timezone.abbreviation[i] = 0;
        }
        const abbr_len = @min(abbreviation.len, MAX_TIMEZONE_ABBR_LEN);
        i = 0;
        while (i < abbr_len) : (i += 1) {
            self.timezone.abbreviation[i] = abbreviation[i];
        }
        self.timezone.abbr_len = @intCast(abbr_len);
        self.timezone.offset_seconds = offset_seconds;
        return true;
    }

    // Get timezone.
    pub fn get_timezone(self: *const TimeManager) Timezone {
        return self.timezone;
    }

    // Set time format.
    pub fn set_time_format(self: *TimeManager, format: TimeFormat) void {
        self.time_format = format;
    }

    // Get time format.
    pub fn get_time_format(self: *const TimeManager) TimeFormat {
        return self.time_format;
    }

    // Set date format.
    pub fn set_date_format(self: *TimeManager, format: DateFormat) void {
        self.date_format = format;
    }

    // Get date format.
    pub fn get_date_format(self: *const TimeManager) DateFormat {
        return self.date_format;
    }

    // Enable auto-sync.
    pub fn enable_auto_sync(self: *TimeManager) void {
        self.auto_sync_enabled = true;
    }

    // Disable auto-sync.
    pub fn disable_auto_sync(self: *TimeManager) void {
        self.auto_sync_enabled = false;
    }

    // Check if auto-sync is enabled.
    pub fn is_auto_sync_enabled(self: *const TimeManager) bool {
        return self.auto_sync_enabled;
    }

    // Get local time (system time + timezone offset).
    pub fn get_local_time(self: *const TimeManager) u64 {
        const offset_ns: i64 = @as(i64, self.timezone.offset_seconds) * 1000000000;
        const system_time_i64: i64 = @intCast(self.system_time);
        const local_time_i64 = system_time_i64 + offset_ns;
        if (local_time_i64 < 0) {
            return 0;
        }
        return @intCast(local_time_i64);
    }
};

