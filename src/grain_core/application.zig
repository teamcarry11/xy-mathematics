//! Grain OS Application Framework: Application API and loader.
//!
//! Why: Provide application launching and management for desktop environment.
//! Architecture: Application registry, loader, launcher integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const basin_kernel = @import("basin_kernel");

// Bounded: Max number of applications.
pub const MAX_APPLICATIONS: u32 = 256;

// Bounded: Max application name length.
pub const MAX_APP_NAME_LEN: u32 = 64;

// Bounded: Max application path length.
pub const MAX_APP_PATH_LEN: u32 = 256;

// Bounded: Max application command length.
pub const MAX_APP_CMD_LEN: u32 = 512;

// Application: represents a desktop application.
pub const Application = struct {
    id: u32,
    name: [MAX_APP_NAME_LEN]u8,
    name_len: u32,
    path: [MAX_APP_PATH_LEN]u8,
    path_len: u32,
    command: [MAX_APP_CMD_LEN]u8,
    command_len: u32,
    icon: u32, // Placeholder for icon ID.
    visible: bool,

    pub fn init(
        id: u32,
        name: []const u8,
        path: []const u8,
        command: []const u8,
    ) Application {
        std.debug.assert(id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_APP_NAME_LEN);
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= MAX_APP_PATH_LEN);
        std.debug.assert(command.len > 0);
        std.debug.assert(command.len <= MAX_APP_CMD_LEN);
        var app = Application{
            .id = id,
            .name = undefined,
            .name_len = 0,
            .path = undefined,
            .path_len = 0,
            .command = undefined,
            .command_len = 0,
            .icon = 0,
            .visible = true,
        };
        @memset(&app.name, 0);
        @memset(&app.path, 0);
        @memset(&app.command, 0);
        const name_copy_len = @min(name.len, MAX_APP_NAME_LEN);
        @memcpy(app.name[0..name_copy_len], name[0..name_copy_len]);
        app.name_len = @intCast(name_copy_len);
        const path_copy_len = @min(path.len, MAX_APP_PATH_LEN);
        @memcpy(app.path[0..path_copy_len], path[0..path_copy_len]);
        app.path_len = @intCast(path_copy_len);
        const cmd_copy_len = @min(command.len, MAX_APP_CMD_LEN);
        @memcpy(app.command[0..cmd_copy_len], command[0..cmd_copy_len]);
        app.command_len = @intCast(cmd_copy_len);
        std.debug.assert(app.id > 0);
        std.debug.assert(app.name_len > 0);
        return app;
    }
};

// Application registry: manages available applications.
pub const ApplicationRegistry = struct {
    applications: [MAX_APPLICATIONS]Application,
    applications_len: u32,
    next_app_id: u32,

    pub fn init() ApplicationRegistry {
        var registry = ApplicationRegistry{
            .applications = undefined,
            .applications_len = 0,
            .next_app_id = 1,
        };
        // Initialize all applications to zero.
        var i: u32 = 0;
        while (i < MAX_APPLICATIONS) : (i += 1) {
            registry.applications[i] = Application.init(0, "", "", "");
        }
        std.debug.assert(registry.applications_len == 0);
        std.debug.assert(registry.next_app_id > 0);
        return registry;
    }

    // Register application.
    pub fn register_application(
        self: *ApplicationRegistry,
        name: []const u8,
        path: []const u8,
        command: []const u8,
    ) ?u32 {
        std.debug.assert(name.len > 0);
        std.debug.assert(path.len > 0);
        std.debug.assert(command.len > 0);
        if (self.applications_len >= MAX_APPLICATIONS) return null;
        const app_id = self.next_app_id;
        self.next_app_id += 1;
        self.applications[self.applications_len] = Application.init(
            app_id,
            name,
            path,
            command,
        );
        self.applications_len += 1;
        std.debug.assert(self.applications_len <= MAX_APPLICATIONS);
        std.debug.assert(self.next_app_id > 0);
        return app_id;
    }

    // Get application by ID.
    pub fn get_application(self: *ApplicationRegistry, app_id: u32) ?*Application {
        std.debug.assert(app_id > 0);
        var i: u32 = 0;
        while (i < self.applications_len) : (i += 1) {
            if (self.applications[i].id == app_id) {
                return &self.applications[i];
            }
        }
        return null;
    }

    // Get application by name.
    pub fn get_application_by_name(
        self: *ApplicationRegistry,
        name: []const u8,
    ) ?*Application {
        std.debug.assert(name.len > 0);
        var i: u32 = 0;
        while (i < self.applications_len) : (i += 1) {
            const app = &self.applications[i];
            if (app.name_len == name.len) {
                var match: bool = true;
                var j: u32 = 0;
                while (j < name.len) : (j += 1) {
                    if (app.name[j] != name[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    return app;
                }
            }
        }
        return null;
    }

    // Get all visible applications.
    pub fn get_visible_applications(
        self: *const ApplicationRegistry,
    ) struct { apps: []const Application, len: u32 } {
        var visible: [MAX_APPLICATIONS]Application = undefined;
        var visible_len: u32 = 0;
        var i: u32 = 0;
        while (i < self.applications_len and visible_len < MAX_APPLICATIONS) : (i += 1) {
            if (self.applications[i].visible) {
                visible[visible_len] = self.applications[i];
                visible_len += 1;
            }
        }
        std.debug.assert(visible_len <= MAX_APPLICATIONS);
        return .{ .apps = visible[0..visible_len], .len = visible_len };
    }
};

// Application launcher: launches applications via kernel spawn.
pub const ApplicationLauncher = struct {
    registry: *ApplicationRegistry,
    syscall_fn: ?*const fn (u32, u64, u64, u64, u64) i64 = null,

    pub fn init(registry: *ApplicationRegistry) ApplicationLauncher {
        std.debug.assert(@intFromPtr(registry) != 0);
        return ApplicationLauncher{
            .registry = registry,
            .syscall_fn = null,
        };
    }

    // Set syscall function for spawning processes.
    pub fn set_syscall_fn(
        self: *ApplicationLauncher,
        fn_ptr: *const fn (u32, u64, u64, u64, u64) i64,
    ) void {
        std.debug.assert(@intFromPtr(fn_ptr) != 0);
        self.syscall_fn = fn_ptr;
        std.debug.assert(self.syscall_fn != null);
    }

    // Launch application by ID.
    pub fn launch_application(self: *ApplicationLauncher, app_id: u32) bool {
        std.debug.assert(app_id > 0);
        std.debug.assert(self.syscall_fn != null);
        if (self.registry.get_application(app_id)) |app| {
            if (self.syscall_fn) |syscall_ptr| {
                // Spawn process using kernel spawn syscall.
                // Syscall: spawn = 1, args: path_ptr, path_len, cmd_ptr, cmd_len
                const path_ptr = @intFromPtr(&app.path);
                const path_len: u64 = app.path_len;
                const cmd_ptr = @intFromPtr(&app.command);
                const cmd_len: u64 = app.command_len;
                const result = syscall_ptr(
                    @intFromEnum(basin_kernel.Syscall.spawn),
                    path_ptr,
                    path_len,
                    cmd_ptr,
                    cmd_len,
                );
                if (result >= 0) {
                    return true;
                }
            }
        }
        return false;
    }

    // Launch application by name.
    pub fn launch_application_by_name(
        self: *ApplicationLauncher,
        name: []const u8,
    ) bool {
        std.debug.assert(name.len > 0);
        if (self.registry.get_application_by_name(name)) |app| {
            return self.launch_application(app.id);
        }
        return false;
    }
};

