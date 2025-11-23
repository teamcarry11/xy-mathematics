const std = @import("std");
const Tab = @import("tab.zig").Tab;
const Terminal = @import("terminal.zig").Terminal;

/// Grain Terminal Plugin: Plugin architecture for terminal extensions.
/// ~<~ Glow Airbend: explicit plugin state, bounded plugin management.
/// ~~~~ Glow Waterbend: deterministic plugin loading, iterative algorithms.
///
/// GrainStyle/TigerStyle compliance:
/// - grain_case function names
/// - u32/u64 types (not usize)
/// - MAX_ constants for bounded allocations
/// - Assertions for preconditions/postconditions
/// - No recursion (iterative algorithms, stack-based)
pub const Plugin = struct {
    // Bounded: Max plugin name length (explicit limit)
    pub const MAX_PLUGIN_NAME_LEN: u32 = 256;

    // Bounded: Max plugins (explicit limit)
    pub const MAX_PLUGINS: u32 = 256;

    // Bounded: Max plugin path length (explicit limit)
    pub const MAX_PLUGIN_PATH_LEN: u32 = 4_096;

    /// Plugin state enumeration.
    pub const PluginState = enum(u8) {
        loaded, // Plugin loaded
        unloaded, // Plugin unloaded
        error_state, // Plugin error state
    };

    /// Plugin structure.
    pub const PluginData = struct {
        id: u32, // Plugin ID (unique identifier)
        name: []const u8, // Plugin name (bounded)
        name_len: u32,
        path: []const u8, // Plugin file path (bounded)
        path_len: u32,
        state: PluginState, // Plugin state
        version: u32, // Plugin version (semantic version as u32: major << 16 | minor << 8 | patch)
        allocator: std.mem.Allocator,

        /// Initialize plugin data.
        pub fn init(allocator: std.mem.Allocator, id: u32, name: []const u8, path: []const u8, version: u32) !PluginData {
            // Assert: Allocator must be valid
            std.debug.assert(allocator.ptr != null);

            // Assert: Name and path must be bounded
            std.debug.assert(name.len <= MAX_PLUGIN_NAME_LEN);
            std.debug.assert(path.len <= MAX_PLUGIN_PATH_LEN);

            // Allocate name
            const name_copy = try allocator.dupe(u8, name);
            errdefer allocator.free(name_copy);

            // Allocate path
            const path_copy = try allocator.dupe(u8, path);
            errdefer allocator.free(path_copy);

            return PluginData{
                .id = id,
                .name = name_copy,
                .name_len = @as(u32, @intCast(name_copy.len)),
                .path = path_copy,
                .path_len = @as(u32, @intCast(path_copy.len)),
                .state = .unloaded,
                .version = version,
                .allocator = allocator,
            };
        }

        /// Deinitialize plugin data and free memory.
        pub fn deinit(self: *PluginData) void {
            // Assert: Allocator must be valid
            std.debug.assert(self.allocator.ptr != null);

            // Free name
            if (self.name_len > 0) {
                self.allocator.free(self.name);
            }

            // Free path
            if (self.path_len > 0) {
                self.allocator.free(self.path);
            }

            self.* = undefined;
        }
    };

    /// Plugin API structure (functions plugins can implement).
    pub const PluginApi = struct {
        /// Plugin initialization callback.
        on_init: ?*const fn (plugin: *PluginData, allocator: std.mem.Allocator) anyerror!void = null,

        /// Plugin deinitialization callback.
        on_deinit: ?*const fn (plugin: *PluginData) void = null,

        /// Terminal character processing hook.
        on_char: ?*const fn (plugin: *PluginData, tab: *Tab, ch: u8) anyerror!void = null,

        /// Terminal escape sequence hook.
        on_escape: ?*const fn (plugin: *PluginData, tab: *Tab, sequence: []const u8) anyerror!void = null,

        /// Tab creation hook.
        on_tab_create: ?*const fn (plugin: *PluginData, tab: *Tab) anyerror!void = null,

        /// Tab destruction hook.
        on_tab_destroy: ?*const fn (plugin: *PluginData, tab: *Tab) void = null,
    };

    /// Plugin manager structure.
    plugins: []PluginData, // Plugins buffer (bounded)
    plugins_len: u32, // Number of plugins
    next_plugin_id: u32, // Next available plugin ID
    allocator: std.mem.Allocator,

    /// Initialize plugin manager.
    pub fn init(allocator: std.mem.Allocator) !Plugin {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        // Pre-allocate plugins buffer
        const plugins = try allocator.alloc(PluginData, MAX_PLUGINS);
        errdefer allocator.free(plugins);

        return Plugin{
            .plugins = plugins,
            .plugins_len = 0,
            .next_plugin_id = 1, // Start at 1
            .allocator = allocator,
        };
    }

    /// Deinitialize plugin manager and free memory.
    pub fn deinit(self: *Plugin) void {
        // Assert: Allocator must be valid
        std.debug.assert(self.allocator.ptr != null);

        // Unload and deinitialize all plugins
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (self.plugins[i].state == .loaded) {
                _ = self.unload_plugin(self.plugins[i].id);
            }
            self.plugins[i].deinit();
        }

        // Free plugins buffer
        self.allocator.free(self.plugins);

        self.* = undefined;
    }

    /// Load plugin from file path.
    pub fn load_plugin(self: *Plugin, name: []const u8, path: []const u8, version: u32) !u32 {
        // Assert: Name and path must be bounded
        std.debug.assert(name.len <= MAX_PLUGIN_NAME_LEN);
        std.debug.assert(path.len <= MAX_PLUGIN_PATH_LEN);

        // Check plugins limit
        if (self.plugins_len >= MAX_PLUGINS) {
            return error.TooManyPlugins;
        }

        // Check if plugin already loaded
        if (self.find_plugin_by_name(name)) |_| {
            return error.PluginAlreadyLoaded;
        }

        // Create plugin data
        const plugin_id = self.next_plugin_id;
        self.next_plugin_id += 1;

        var plugin_data = try PluginData.init(self.allocator, plugin_id, name, path, version);
        errdefer plugin_data.deinit();

        // Load plugin (in a full implementation, this would load a shared library)
        // For now, we just mark it as loaded
        plugin_data.state = .loaded;

        // Store plugin
        self.plugins[self.plugins_len] = plugin_data;
        self.plugins_len += 1;

        return plugin_id;
    }

    /// Unload plugin.
    pub fn unload_plugin(self: *Plugin, plugin_id: u32) !void {
        if (self.find_plugin(plugin_id)) |plugin| {
            if (plugin.state == .loaded) {
                plugin.state = .unloaded;
                // In a full implementation, we would unload the shared library here
            } else {
                return error.PluginNotLoaded;
            }
        } else {
            return error.PluginNotFound;
        }
    }

    /// Get plugin by ID.
    pub fn get_plugin(self: *Plugin, plugin_id: u32) ?*PluginData {
        return self.find_plugin(plugin_id);
    }

    /// Find plugin by ID (internal helper).
    fn find_plugin(self: *Plugin, plugin_id: u32) ?*PluginData {
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (self.plugins[i].id == plugin_id) {
                return &self.plugins[i];
            }
        }
        return null;
    }

    /// Find plugin by name (internal helper).
    fn find_plugin_by_name(self: *Plugin, name: []const u8) ?*PluginData {
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (std.mem.eql(u8, self.plugins[i].name, name)) {
                return &self.plugins[i];
            }
        }
        return null;
    }

    /// Call plugin hook for character processing.
    pub fn call_on_char(self: *Plugin, tab: *Tab, ch: u8) void {
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (self.plugins[i].state == .loaded) {
                // In a full implementation, we would call the plugin's on_char hook
                // For now, this is a placeholder
                _ = tab;
                _ = ch;
            }
        }
    }

    /// Call plugin hook for tab creation.
    pub fn call_on_tab_create(self: *Plugin, tab: *Tab) void {
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (self.plugins[i].state == .loaded) {
                // In a full implementation, we would call the plugin's on_tab_create hook
                // For now, this is a placeholder
                _ = tab;
            }
        }
    }

    /// Call plugin hook for tab destruction.
    pub fn call_on_tab_destroy(self: *Plugin, tab: *Tab) void {
        var i: u32 = 0;
        while (i < self.plugins_len) : (i += 1) {
            if (self.plugins[i].state == .loaded) {
                // In a full implementation, we would call the plugin's on_tab_destroy hook
                // For now, this is a placeholder
                _ = tab;
            }
        }
    }
};

