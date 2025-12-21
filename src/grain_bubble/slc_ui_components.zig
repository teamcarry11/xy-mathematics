//! Grain Bubble SLC UI Components: Reusable UI components for SLC products.
//!
//! Why: Provide beautiful, intuitive UI components for Nostr Profile Builder,
//! DAG Website Builder, and Workspace App Suite.
//! Architecture: Component library with SLC product-specific components.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-083043-pst: Grain Bubble Agent

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");

// Bounded: Max SLC components.
pub const MAX_SLC_COMPONENTS: u32 = 64;

// Bounded: Max component name length.
pub const MAX_COMPONENT_NAME_LEN: u32 = 64;

// SLC component type: identifies which SLC product the component is for.
pub const SlcComponentType = enum(u8) {
    profile_builder, // Nostr Profile Builder components
    website_builder, // DAG Website Builder components
    workspace_app, // Workspace App Suite components
};

// Profile UI component: form, editor, or viewer for Nostr profiles.
pub const ProfileComponent = struct {
    component_id: u32,
    component_type: ProfileComponentType,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    base_component: *component.Component,

    pub const ProfileComponentType = enum(u8) {
        form, // Profile form (name, bio, avatar, links)
        editor, // Profile editor (edit fields)
        viewer, // Profile viewer (display profile)
    };

    pub fn init(
        component_id: u32,
        comp_type: ProfileComponentType,
        name: []const u8,
        base: *component.Component,
    ) ProfileComponent {
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        std.debug.assert(@intFromPtr(base) != 0);
        var comp = ProfileComponent{
            .component_id = component_id,
            .component_type = comp_type,
            .name = undefined,
            .name_len = 0,
            .base_component = base,
        };
        @memset(comp.name[0..], 0);
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memcpy(comp.name[0..name_len], name[0..name_len]);
        comp.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(comp.name_len > 0);
        return comp;
    }
};

// Website UI component: DAG editor or content editor for DAG websites.
pub const WebsiteComponent = struct {
    component_id: u32,
    component_type: WebsiteComponentType,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    base_component: *component.Component,

    pub const WebsiteComponentType = enum(u8) {
        dag_editor, // DAG editor (nodes, edges, structure)
        content_editor, // Content editor (text, images, links)
    };

    pub fn init(
        component_id: u32,
        comp_type: WebsiteComponentType,
        name: []const u8,
        base: *component.Component,
    ) WebsiteComponent {
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        std.debug.assert(@intFromPtr(base) != 0);
        var comp = WebsiteComponent{
            .component_id = component_id,
            .component_type = comp_type,
            .name = undefined,
            .name_len = 0,
            .base_component = base,
        };
        @memset(comp.name[0..], 0);
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memcpy(comp.name[0..name_len], name[0..name_len]);
        comp.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(comp.name_len > 0);
        return comp;
    }
};

// Workspace UI component: File Manager, Text Editor, or Terminal component.
pub const WorkspaceComponent = struct {
    component_id: u32,
    component_type: WorkspaceComponentType,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    base_component: *component.Component,

    pub const WorkspaceComponentType = enum(u8) {
        file_manager, // File Manager UI component
        text_editor, // Text Editor UI component
        terminal, // Terminal UI component
    };

    pub fn init(
        component_id: u32,
        comp_type: WorkspaceComponentType,
        name: []const u8,
        base: *component.Component,
    ) WorkspaceComponent {
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        std.debug.assert(@intFromPtr(base) != 0);
        var comp = WorkspaceComponent{
            .component_id = component_id,
            .component_type = comp_type,
            .name = undefined,
            .name_len = 0,
            .base_component = base,
        };
        @memset(comp.name[0..], 0);
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memcpy(comp.name[0..name_len], name[0..name_len]);
        comp.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(comp.name_len > 0);
        return comp;
    }
};

// SLC UI component library: manages SLC product-specific components.
pub const SlcComponentLibrary = struct {
    profile_components: [MAX_SLC_COMPONENTS]ProfileComponent,
    profile_components_len: u32,
    website_components: [MAX_SLC_COMPONENTS]WebsiteComponent,
    website_components_len: u32,
    workspace_components: [MAX_SLC_COMPONENTS]WorkspaceComponent,
    workspace_components_len: u32,
    next_profile_id: u32,
    next_website_id: u32,
    next_workspace_id: u32,

    pub fn init() SlcComponentLibrary {
        var library = SlcComponentLibrary{
            .profile_components = undefined,
            .profile_components_len = 0,
            .website_components = undefined,
            .website_components_len = 0,
            .workspace_components = undefined,
            .workspace_components_len = 0,
            .next_profile_id = 1,
            .next_website_id = 1,
            .next_workspace_id = 1,
        };
        // Initialize arrays (components will be created via add functions).
        var i: u32 = 0;
        while (i < MAX_SLC_COMPONENTS) : (i += 1) {
            // Use zero-initialized structs (component_id 0 indicates unused).
            library.profile_components[i] = ProfileComponent{
                .component_id = 0,
                .component_type = .form,
                .name = undefined,
                .name_len = 0,
                .base_component = undefined,
            };
            @memset(library.profile_components[i].name[0..], 0);
            library.website_components[i] = WebsiteComponent{
                .component_id = 0,
                .component_type = .dag_editor,
                .name = undefined,
                .name_len = 0,
                .base_component = undefined,
            };
            @memset(library.website_components[i].name[0..], 0);
            library.workspace_components[i] = WorkspaceComponent{
                .component_id = 0,
                .component_type = .file_manager,
                .name = undefined,
                .name_len = 0,
                .base_component = undefined,
            };
            @memset(library.workspace_components[i].name[0..], 0);
        }
        std.debug.assert(library.profile_components_len == 0);
        std.debug.assert(library.website_components_len == 0);
        std.debug.assert(library.workspace_components_len == 0);
        return library;
    }

    // Add profile component to library.
    pub fn add_profile_component(
        self: *SlcComponentLibrary,
        comp_type: ProfileComponent.ProfileComponentType,
        name: []const u8,
        base: *component.Component,
    ) ?*ProfileComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(@intFromPtr(base) != 0);
        if (self.profile_components_len >= MAX_SLC_COMPONENTS) {
            return null;
        }
        const comp_id = self.next_profile_id;
        self.next_profile_id += 1;
        const idx = self.profile_components_len;
        self.profile_components[idx] = ProfileComponent.init(comp_id, comp_type, name, base);
        self.profile_components_len += 1;
        std.debug.assert(self.profile_components_len <= MAX_SLC_COMPONENTS);
        return &self.profile_components[idx];
    }

    // Add website component to library.
    pub fn add_website_component(
        self: *SlcComponentLibrary,
        comp_type: WebsiteComponent.WebsiteComponentType,
        name: []const u8,
        base: *component.Component,
    ) ?*WebsiteComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(@intFromPtr(base) != 0);
        if (self.website_components_len >= MAX_SLC_COMPONENTS) {
            return null;
        }
        const comp_id = self.next_website_id;
        self.next_website_id += 1;
        const idx = self.website_components_len;
        self.website_components[idx] = WebsiteComponent.init(comp_id, comp_type, name, base);
        self.website_components_len += 1;
        std.debug.assert(self.website_components_len <= MAX_SLC_COMPONENTS);
        return &self.website_components[idx];
    }

    // Add workspace component to library.
    pub fn add_workspace_component(
        self: *SlcComponentLibrary,
        comp_type: WorkspaceComponent.WorkspaceComponentType,
        name: []const u8,
        base: *component.Component,
    ) ?*WorkspaceComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(@intFromPtr(base) != 0);
        if (self.workspace_components_len >= MAX_SLC_COMPONENTS) {
            return null;
        }
        const comp_id = self.next_workspace_id;
        self.next_workspace_id += 1;
        const idx = self.workspace_components_len;
        self.workspace_components[idx] = WorkspaceComponent.init(comp_id, comp_type, name, base);
        self.workspace_components_len += 1;
        std.debug.assert(self.workspace_components_len <= MAX_SLC_COMPONENTS);
        return &self.workspace_components[idx];
    }

    // Get profile component by ID.
    pub fn get_profile_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) ?*const ProfileComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            if (self.profile_components[i].component_id == component_id) {
                return &self.profile_components[i];
            }
        }
        return null;
    }

    // Get website component by ID.
    pub fn get_website_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) ?*const WebsiteComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        var i: u32 = 0;
        while (i < self.website_components_len) : (i += 1) {
            if (self.website_components[i].component_id == component_id) {
                return &self.website_components[i];
            }
        }
        return null;
    }

    // Get workspace component by ID.
    pub fn get_workspace_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) ?*const WorkspaceComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        var i: u32 = 0;
        while (i < self.workspace_components_len) : (i += 1) {
            if (self.workspace_components[i].component_id == component_id) {
                return &self.workspace_components[i];
            }
        }
        return null;
    }

    // Get profile component count.
    pub fn get_profile_component_count(self: *const SlcComponentLibrary) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.profile_components_len;
    }

    // Get website component count.
    pub fn get_website_component_count(self: *const SlcComponentLibrary) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.website_components_len;
    }

    // Get workspace component count.
    pub fn get_workspace_component_count(self: *const SlcComponentLibrary) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        return self.workspace_components_len;
    }
};
