//! Grain OS Workspace: Workspace management for window organization.
//!
//! Why: Organize windows into separate workspaces (River-style).
//! Architecture: Multiple workspaces, window assignment, switching.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");

// Bounded: Max number of workspaces.
pub const MAX_WORKSPACES: u32 = 10;

// Bounded: Max windows per workspace.
pub const MAX_WORKSPACE_WINDOWS: u32 = 256;

// Workspace: represents a workspace with windows.
pub const Workspace = struct {
    id: u32,
    name: [32]u8,
    name_len: u32,
    window_ids: [MAX_WORKSPACE_WINDOWS]u32,
    window_ids_len: u32,
    focused_window_id: u32,
    visible: bool,

    pub fn init(id: u32, name: []const u8) Workspace {
        std.debug.assert(id > 0);
        std.debug.assert(id <= MAX_WORKSPACES);
        std.debug.assert(name.len <= 32);
        var workspace = Workspace{
            .id = id,
            .name = undefined,
            .name_len = 0,
            .window_ids = undefined,
            .window_ids_len = 0,
            .focused_window_id = 0,
            .visible = false,
        };
        var j: u32 = 0;
        while (j < 32) : (j += 1) {
            workspace.name[j] = 0;
        }
        j = 0;
        while (j < MAX_WORKSPACE_WINDOWS) : (j += 1) {
            workspace.window_ids[j] = 0;
        }
        const copy_len = @min(name.len, 32);
        var i: u32 = 0;
        while (i < copy_len) : (i += 1) {
            workspace.name[i] = name[i];
        }
        workspace.name_len = @intCast(copy_len);
        std.debug.assert(workspace.id > 0);
        return workspace;
    }

    pub fn add_window(self: *Workspace, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        if (self.window_ids_len >= MAX_WORKSPACE_WINDOWS) {
            return false;
        }
        // Check if window already in workspace.
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                return false; // Already in workspace.
            }
        }
        self.window_ids[self.window_ids_len] = window_id;
        self.window_ids_len += 1;
        std.debug.assert(self.window_ids_len <= MAX_WORKSPACE_WINDOWS);
        return true;
    }

    pub fn remove_window(self: *Workspace, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining windows left.
        while (i < self.window_ids_len - 1) : (i += 1) {
            self.window_ids[i] = self.window_ids[i + 1];
        }
        self.window_ids_len -= 1;
        if (self.focused_window_id == window_id) {
            self.focused_window_id = 0;
        }
        return true;
    }

    pub fn set_focused_window(self: *Workspace, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        // Check if window is in workspace.
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                self.focused_window_id = window_id;
                return true;
            }
        }
        return false;
    }

    pub fn has_window(self: *const Workspace, window_id: u32) bool {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.window_ids_len) : (i += 1) {
            if (self.window_ids[i] == window_id) {
                return true;
            }
        }
        return false;
    }
};

// Workspace manager: manages all workspaces.
pub const WorkspaceManager = struct {
    workspaces: [MAX_WORKSPACES]Workspace,
    workspaces_len: u32,
    current_workspace_id: u32,

    pub fn init() WorkspaceManager {
        var manager = WorkspaceManager{
            .workspaces = undefined,
            .workspaces_len = 0,
            .current_workspace_id = 0,
        };
        var i: u32 = 0;
        while (i < MAX_WORKSPACES) : (i += 1) {
            manager.workspaces[i] = Workspace.init(i + 1, "");
        }
        // Create default workspace.
        manager.workspaces[0] = Workspace.init(1, "main");
        manager.workspaces[0].visible = true;
        manager.workspaces_len = 1;
        manager.current_workspace_id = 1;
        std.debug.assert(manager.current_workspace_id > 0);
        return manager;
    }

    pub fn get_workspace(self: *WorkspaceManager, workspace_id: u32) ?*Workspace {
        std.debug.assert(workspace_id > 0);
        var i: u32 = 0;
        while (i < self.workspaces_len) : (i += 1) {
            if (self.workspaces[i].id == workspace_id) {
                return &self.workspaces[i];
            }
        }
        return null;
    }

    pub fn get_current_workspace(self: *WorkspaceManager) ?*Workspace {
        if (self.current_workspace_id == 0) {
            return null;
        }
        return self.get_workspace(self.current_workspace_id);
    }

    pub fn switch_workspace(self: *WorkspaceManager, workspace_id: u32) bool {
        std.debug.assert(workspace_id > 0);
        if (self.get_workspace(workspace_id)) |workspace| {
            // Hide current workspace.
            if (self.get_current_workspace()) |current| {
                current.visible = false;
            }
            // Show new workspace.
            workspace.visible = true;
            self.current_workspace_id = workspace_id;
            std.debug.assert(self.current_workspace_id > 0);
            return true;
        }
        return false;
    }

    pub fn create_workspace(self: *WorkspaceManager, name: []const u8) ?u32 {
        std.debug.assert(name.len <= 32);
        if (self.workspaces_len >= MAX_WORKSPACES) {
            return null;
        }
        const new_id = self.workspaces_len + 1;
        std.debug.assert(new_id <= MAX_WORKSPACES);
        self.workspaces[self.workspaces_len] = Workspace.init(new_id, name);
        self.workspaces_len += 1;
        std.debug.assert(self.workspaces_len <= MAX_WORKSPACES);
        return new_id;
    }

    pub fn assign_window_to_workspace(
        self: *WorkspaceManager,
        window_id: u32,
        workspace_id: u32,
    ) bool {
        std.debug.assert(window_id > 0);
        std.debug.assert(workspace_id > 0);
        // Remove from current workspace (if any).
        var i: u32 = 0;
        while (i < self.workspaces_len) : (i += 1) {
            _ = self.workspaces[i].remove_window(window_id);
        }
        // Add to target workspace.
        if (self.get_workspace(workspace_id)) |workspace| {
            return workspace.add_window(window_id);
        }
        return false;
    }

    pub fn get_window_workspace(
        self: *const WorkspaceManager,
        window_id: u32,
    ) ?u32 {
        std.debug.assert(window_id > 0);
        var i: u32 = 0;
        while (i < self.workspaces_len) : (i += 1) {
            if (self.workspaces[i].has_window(window_id)) {
                return self.workspaces[i].id;
            }
        }
        return null;
    }
};
