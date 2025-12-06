//! Grain OS Application Launcher: Quick application launcher and search.
//!
//! Why: Provide quick access to applications with search functionality.
//! Architecture: Application registry, search, favorites, recent apps.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const application = @import("application.zig");

// Bounded: Max applications in launcher.
pub const MAX_APPS: u32 = 256;

// Bounded: Max search results.
pub const MAX_SEARCH_RESULTS: u32 = 32;

// Bounded: Max favorites.
pub const MAX_FAVORITES: u32 = 16;

// Bounded: Max recent apps.
pub const MAX_RECENT_APPS: u32 = 16;

// Bounded: Max search query length.
pub const MAX_QUERY_LEN: u32 = 128;

// Launcher entry: represents an application in the launcher.
pub const LauncherEntry = struct {
    app_id: u32,
    name: [application.MAX_APP_NAME_LEN]u8,
    name_len: u32,
    icon_path: [application.MAX_APP_NAME_LEN]u8,
    icon_path_len: u32,
    favorite: bool,
    last_used: u64,
    use_count: u32,

    pub fn init() LauncherEntry {
        var entry = LauncherEntry{
            .app_id = 0,
            .name = undefined,
            .name_len = 0,
            .icon_path = undefined,
            .icon_path_len = 0,
            .favorite = false,
            .last_used = 0,
            .use_count = 0,
        };
        var i: u32 = 0;
        while (i < application.MAX_APP_NAME_LEN) : (i += 1) {
            entry.name[i] = 0;
            entry.icon_path[i] = 0;
        }
        return entry;
    }
};

// Application launcher: manages application launcher.
pub const ApplicationLauncher = struct {
    entries: [MAX_APPS]LauncherEntry,
    entries_len: u32,
    favorites: [MAX_FAVORITES]u32,
    favorites_len: u32,
    recent_apps: [MAX_RECENT_APPS]u32,
    recent_apps_len: u32,
    visible: bool,

    pub fn init() ApplicationLauncher {
        var launcher = ApplicationLauncher{
            .entries = undefined,
            .entries_len = 0,
            .favorites = undefined,
            .favorites_len = 0,
            .recent_apps = undefined,
            .recent_apps_len = 0,
            .visible = false,
        };
        var i: u32 = 0;
        while (i < MAX_APPS) : (i += 1) {
            launcher.entries[i] = LauncherEntry.init();
        }
        i = 0;
        while (i < MAX_FAVORITES) : (i += 1) {
            launcher.favorites[i] = 0;
        }
        i = 0;
        while (i < MAX_RECENT_APPS) : (i += 1) {
            launcher.recent_apps[i] = 0;
        }
        return launcher;
    }

    // Add application to launcher.
    pub fn add_app(
        self: *ApplicationLauncher,
        app_id: u32,
        name: []const u8,
        icon_path: []const u8,
    ) bool {
        if (self.entries_len >= MAX_APPS) {
            return false;
        }
        if (name.len > application.MAX_APP_NAME_LEN) {
            return false;
        }
        if (icon_path.len > application.MAX_APP_NAME_LEN) {
            return false;
        }
        // Check if app already exists.
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].app_id == app_id) {
                return false; // Already exists.
            }
        }
        // Add new entry.
        self.entries[self.entries_len] = LauncherEntry.init();
        self.entries[self.entries_len].app_id = app_id;
        var j: u32 = 0;
        while (j < application.MAX_APP_NAME_LEN) : (j += 1) {
            self.entries[self.entries_len].name[j] = 0;
            self.entries[self.entries_len].icon_path[j] = 0;
        }
        const name_len = @min(name.len, application.MAX_APP_NAME_LEN);
        j = 0;
        while (j < name_len) : (j += 1) {
            self.entries[self.entries_len].name[j] = name[j];
        }
        self.entries[self.entries_len].name_len = @intCast(name_len);
        const icon_len = @min(icon_path.len, application.MAX_APP_NAME_LEN);
        j = 0;
        while (j < icon_len) : (j += 1) {
            self.entries[self.entries_len].icon_path[j] = icon_path[j];
        }
        self.entries[self.entries_len].icon_path_len = @intCast(icon_len);
        self.entries_len += 1;
        return true;
    }

    // Find application by ID.
    pub fn find_app(
        self: *ApplicationLauncher,
        app_id: u32,
    ) ?*LauncherEntry {
        std.debug.assert(app_id > 0);
        var i: u32 = 0;
        while (i < self.entries_len) : (i += 1) {
            if (self.entries[i].app_id == app_id) {
                return &self.entries[i];
            }
        }
        return null;
    }

    // Search applications.
    pub fn search_apps(
        self: *ApplicationLauncher,
        query: []const u8,
        results: []u32,
    ) u32 {
        std.debug.assert(query.len <= MAX_QUERY_LEN);
        if (query.len == 0) {
            return 0;
        }
        var result_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.entries_len and result_count < results.len) : (i += 1) {
            const entry = &self.entries[i];
            const name_slice = entry.name[0..entry.name_len];
            // Simple substring match (case-insensitive would be better).
            var match: bool = false;
            if (query.len <= name_slice.len) {
                var j: u32 = 0;
                while (j <= name_slice.len - query.len) : (j += 1) {
                    var k: u32 = 0;
                    match = true;
                    while (k < query.len) : (k += 1) {
                        if (name_slice[j + k] != query[k]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        break;
                    }
                }
            }
            if (match) {
                results[result_count] = entry.app_id;
                result_count += 1;
            }
        }
        return result_count;
    }

    // Add to favorites.
    pub fn add_favorite(self: *ApplicationLauncher, app_id: u32) bool {
        std.debug.assert(app_id > 0);
        if (self.favorites_len >= MAX_FAVORITES) {
            return false;
        }
        // Check if already favorite.
        var i: u32 = 0;
        while (i < self.favorites_len) : (i += 1) {
            if (self.favorites[i] == app_id) {
                return false; // Already favorite.
            }
        }
        // Add to favorites.
        self.favorites[self.favorites_len] = app_id;
        self.favorites_len += 1;
        // Mark entry as favorite.
        if (self.find_app(app_id)) |entry| {
            entry.favorite = true;
        }
        return true;
    }

    // Remove from favorites.
    pub fn remove_favorite(self: *ApplicationLauncher, app_id: u32) bool {
        std.debug.assert(app_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.favorites_len) : (i += 1) {
            if (self.favorites[i] == app_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining favorites left.
        while (i < self.favorites_len - 1) : (i += 1) {
            self.favorites[i] = self.favorites[i + 1];
        }
        self.favorites_len -= 1;
        // Unmark entry as favorite.
        if (self.find_app(app_id)) |entry| {
            entry.favorite = false;
        }
        return true;
    }

    // Record app usage (adds to recent apps).
    pub fn record_app_usage(self: *ApplicationLauncher, app_id: u32) void {
        std.debug.assert(app_id > 0);
        // Update use count and last used time.
        if (self.find_app(app_id)) |entry| {
            entry.use_count += 1;
            entry.last_used = 0; // Would use actual timestamp.
        }
        // Add to recent apps (remove if already present).
        var i: u32 = 0;
        while (i < self.recent_apps_len) : (i += 1) {
            if (self.recent_apps[i] == app_id) {
                // Move to front.
                var j: u32 = i;
                while (j > 0) : (j -= 1) {
                    self.recent_apps[j] = self.recent_apps[j - 1];
                }
                self.recent_apps[0] = app_id;
                return;
            }
        }
        // Add to front if not present.
        if (self.recent_apps_len < MAX_RECENT_APPS) {
            // Shift right.
            i = self.recent_apps_len;
            while (i > 0) : (i -= 1) {
                self.recent_apps[i] = self.recent_apps[i - 1];
            }
            self.recent_apps[0] = app_id;
            self.recent_apps_len += 1;
        } else {
            // Shift right and replace last.
            i = MAX_RECENT_APPS - 1;
            while (i > 0) : (i -= 1) {
                self.recent_apps[i] = self.recent_apps[i - 1];
            }
            self.recent_apps[0] = app_id;
        }
    }

    // Show launcher.
    pub fn show(self: *ApplicationLauncher) void {
        self.visible = true;
    }

    // Hide launcher.
    pub fn hide(self: *ApplicationLauncher) void {
        self.visible = false;
    }

    // Check if launcher is visible.
    pub fn is_visible(self: *const ApplicationLauncher) bool {
        return self.visible;
    }

    // Get app count.
    pub fn get_app_count(self: *const ApplicationLauncher) u32 {
        return self.entries_len;
    }

    // Get favorites count.
    pub fn get_favorites_count(self: *const ApplicationLauncher) u32 {
        return self.favorites_len;
    }

    // Get recent apps count.
    pub fn get_recent_apps_count(self: *const ApplicationLauncher) u32 {
        return self.recent_apps_len;
    }
};

