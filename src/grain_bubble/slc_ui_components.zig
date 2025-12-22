//! Grain Bubble SLC UI Components: Reusable UI components for SLC products.
//!
//! Why: Provide beautiful, intuitive UI components for Nostr Profile Builder,
//! DAG Website Builder, and Workspace App Suite.
//! Architecture: Component library with SLC product-specific components.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-102906-pst: Grain Bubble Agent - SLC Product Integration

const std = @import("std");
const canvas = @import("canvas.zig");
const component = @import("component.zig");
const export_slc = @import("export_slc.zig");

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

    // Get variant for profile component by variant ID.
    pub fn get_variant_for_profile(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
    ) ?*const component.ComponentVariant {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        if (self.get_profile_component(component_id)) |profile_comp| {
            const base = profile_comp.base_component;
            var i: u32 = 0;
            while (i < base.variants_len) : (i += 1) {
                if (base.variants[i].id == variant_id) {
                    return &base.variants[i];
                }
            }
        }
        return null;
    }

    // Get variant for website component by variant ID.
    pub fn get_variant_for_website(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
    ) ?*const component.ComponentVariant {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        if (self.get_website_component(component_id)) |website_comp| {
            const base = website_comp.base_component;
            var i: u32 = 0;
            while (i < base.variants_len) : (i += 1) {
                if (base.variants[i].id == variant_id) {
                    return &base.variants[i];
                }
            }
        }
        return null;
    }

    // Get variant for workspace component by variant ID.
    pub fn get_variant_for_workspace(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
    ) ?*const component.ComponentVariant {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        if (self.get_workspace_component(component_id)) |workspace_comp| {
            const base = workspace_comp.base_component;
            var i: u32 = 0;
            while (i < base.variants_len) : (i += 1) {
                if (base.variants[i].id == variant_id) {
                    return &base.variants[i];
                }
            }
        }
        return null;
    }

    // Create variant for profile component.
    pub fn create_variant_for_profile(
        self: *SlcComponentLibrary,
        component_id: u32,
        name: []const u8,
        variant_type: component.ComponentVariant.VariantType,
    ) ?u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            if (self.profile_components[i].component_id == component_id) {
                const base = self.profile_components[i].base_component;
                if (base.variants_len >= component.MAX_VARIANTS) {
                    return null;
                }
                const variant_id = base.variants_len + 1;
                var variant = component.ComponentVariant.init();
                variant.id = variant_id;
                variant.variant_type = variant_type;
                const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
                @memset(variant.name[0..name_len], 0);
                @memcpy(variant.name[0..name_len], name[0..name_len]);
                variant.name_len = @as(u32, @intCast(name_len));
                base.variants[base.variants_len] = variant;
                base.variants_len += 1;
                std.debug.assert(base.variants_len <= component.MAX_VARIANTS);
                return variant_id;
            }
        }
        return null;
    }

    // Create variant for website component.
    pub fn create_variant_for_website(
        self: *SlcComponentLibrary,
        component_id: u32,
        name: []const u8,
        variant_type: component.ComponentVariant.VariantType,
    ) ?u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.website_components_len) : (i += 1) {
            if (self.website_components[i].component_id == component_id) {
                const base = self.website_components[i].base_component;
                if (base.variants_len >= component.MAX_VARIANTS) {
                    return null;
                }
                const variant_id = base.variants_len + 1;
                var variant = component.ComponentVariant.init();
                variant.id = variant_id;
                variant.variant_type = variant_type;
                const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
                @memset(variant.name[0..name_len], 0);
                @memcpy(variant.name[0..name_len], name[0..name_len]);
                variant.name_len = @as(u32, @intCast(name_len));
                base.variants[base.variants_len] = variant;
                base.variants_len += 1;
                std.debug.assert(base.variants_len <= component.MAX_VARIANTS);
                return variant_id;
            }
        }
        return null;
    }

    // Create variant for workspace component.
    pub fn create_variant_for_workspace(
        self: *SlcComponentLibrary,
        component_id: u32,
        name: []const u8,
        variant_type: component.ComponentVariant.VariantType,
    ) ?u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.workspace_components_len) : (i += 1) {
            if (self.workspace_components[i].component_id == component_id) {
                const base = self.workspace_components[i].base_component;
                if (base.variants_len >= component.MAX_VARIANTS) {
                    return null;
                }
                const variant_id = base.variants_len + 1;
                var variant = component.ComponentVariant.init();
                variant.id = variant_id;
                variant.variant_type = variant_type;
                const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
                @memset(variant.name[0..name_len], 0);
                @memcpy(variant.name[0..name_len], name[0..name_len]);
                variant.name_len = @as(u32, @intCast(name_len));
                base.variants[base.variants_len] = variant;
                base.variants_len += 1;
                std.debug.assert(base.variants_len <= component.MAX_VARIANTS);
                return variant_id;
            }
        }
        return null;
    }

    // Get variant count for profile component.
    pub fn get_variant_count_for_profile(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_profile_component(component_id)) |profile_comp| {
            return profile_comp.base_component.variants_len;
        }
        return 0;
    }

    // Get variant count for website component.
    pub fn get_variant_count_for_website(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_website_component(component_id)) |website_comp| {
            return website_comp.base_component.variants_len;
        }
        return 0;
    }

    // Get variant count for workspace component.
    pub fn get_variant_count_for_workspace(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) u32 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_workspace_component(component_id)) |workspace_comp| {
            return workspace_comp.base_component.variants_len;
        }
        return 0;
    }

    // Export profile component variant to SLC bundle.
    pub fn export_profile_component_to_slc(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
        bundle: *export_slc.SlcBundle,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        std.debug.assert(@intFromPtr(bundle) != 0);
        if (self.get_variant_for_profile(component_id, variant_id)) |variant| {
            bundle.export_component_variant(variant);
            return true;
        }
        return false;
    }

    // Export website component variant to SLC bundle.
    pub fn export_website_component_to_slc(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
        bundle: *export_slc.SlcBundle,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        std.debug.assert(@intFromPtr(bundle) != 0);
        if (self.get_variant_for_website(component_id, variant_id)) |variant| {
            bundle.export_component_variant(variant);
            return true;
        }
        return false;
    }

    // Export workspace component variant to SLC bundle.
    pub fn export_workspace_component_to_slc(
        self: *const SlcComponentLibrary,
        component_id: u32,
        variant_id: u32,
        bundle: *export_slc.SlcBundle,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(variant_id > 0);
        std.debug.assert(@intFromPtr(bundle) != 0);
        if (self.get_variant_for_workspace(component_id, variant_id)) |variant| {
            bundle.export_component_variant(variant);
            return true;
        }
        return false;
    }

    // Get profile component by name.
    pub fn get_profile_component_by_name(
        self: *const SlcComponentLibrary,
        name: []const u8,
    ) ?*const ProfileComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            const comp = &self.profile_components[i];
            const comp_name = comp.name[0..comp.name_len];
            if (std.mem.eql(u8, comp_name, name)) {
                return comp;
            }
        }
        return null;
    }

    // Get website component by name.
    pub fn get_website_component_by_name(
        self: *const SlcComponentLibrary,
        name: []const u8,
    ) ?*const WebsiteComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.website_components_len) : (i += 1) {
            const comp = &self.website_components[i];
            const comp_name = comp.name[0..comp.name_len];
            if (std.mem.eql(u8, comp_name, name)) {
                return comp;
            }
        }
        return null;
    }

    // Get workspace component by name.
    pub fn get_workspace_component_by_name(
        self: *const SlcComponentLibrary,
        name: []const u8,
    ) ?*const WorkspaceComponent {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var i: u32 = 0;
        while (i < self.workspace_components_len) : (i += 1) {
            const comp = &self.workspace_components[i];
            const comp_name = comp.name[0..comp.name_len];
            if (std.mem.eql(u8, comp_name, name)) {
                return comp;
            }
        }
        return null;
    }

    // Validate profile component (check if component exists and has variants).
    pub fn validate_profile_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_profile_component(component_id)) |profile_comp| {
            const base = profile_comp.base_component;
            return base.variants_len > 0;
        }
        return false;
    }

    // Validate website component (check if component exists and has variants).
    pub fn validate_website_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_website_component(component_id)) |website_comp| {
            const base = website_comp.base_component;
            return base.variants_len > 0;
        }
        return false;
    }

    // Validate workspace component (check if component exists and has variants).
    pub fn validate_workspace_component(
        self: *const SlcComponentLibrary,
        component_id: u32,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        if (self.get_workspace_component(component_id)) |workspace_comp| {
            const base = workspace_comp.base_component;
            return base.variants_len > 0;
        }
        return false;
    }

    // Apply design pattern colors to profile component.
    pub fn apply_pattern_colors_to_profile(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            if (self.profile_components[i].component_id == component_id) {
                const base = self.profile_components[i].base_component;
                if (base.design_tokens_len + 5 > component.MAX_DESIGN_TOKENS) {
                    return false;
                }
                const token_names = [_][]const u8{ "primary", "secondary", "background", "text", "accent" };
                const colors = [_]u32{
                    pattern.color_scheme.primary,
                    pattern.color_scheme.secondary,
                    pattern.color_scheme.background,
                    pattern.color_scheme.text,
                    pattern.color_scheme.accent,
                };
                var j: u32 = 0;
                while (j < 5) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .color;
                    token.value = .{ .color = colors[j] };
                    const name_len = @min(token_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], token_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
                return true;
            }
        }
        return false;
    }

    // Apply design pattern spacing to profile component.
    pub fn apply_pattern_spacing_to_profile(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            if (self.profile_components[i].component_id == component_id) {
                const base = self.profile_components[i].base_component;
                if (base.design_tokens_len + 4 > component.MAX_DESIGN_TOKENS) {
                    return false;
                }
                const token_names = [_][]const u8{ "spacing_small", "spacing_medium", "spacing_large", "spacing_xlarge" };
                const spacings = [_]f64{
                    pattern.spacing.small,
                    pattern.spacing.medium,
                    pattern.spacing.large,
                    pattern.spacing.xlarge,
                };
                var j: u32 = 0;
                while (j < 4) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .spacing;
                    token.value = .{ .spacing = spacings[j] };
                    const name_len = @min(token_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], token_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
                return true;
            }
        }
        return false;
    }

    // Apply design pattern typography to profile component.
    pub fn apply_pattern_typography_to_profile(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        var i: u32 = 0;
        while (i < self.profile_components_len) : (i += 1) {
            if (self.profile_components[i].component_id == component_id) {
                const base = self.profile_components[i].base_component;
                if (base.design_tokens_len + 3 > component.MAX_DESIGN_TOKENS) {
                    return false;
                }
                const token_names = [_][]const u8{ "heading_size", "body_size", "caption_size" };
                const font_sizes = [_]u32{
                    pattern.typography.heading_size,
                    pattern.typography.body_size,
                    pattern.typography.caption_size,
                };
                var j: u32 = 0;
                while (j < 3) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .typography;
                    token.value = .{ .typography = component.DesignToken.TypographyValue{
                        .font_size = font_sizes[j],
                        .line_height = pattern.typography.line_height,
                        .letter_spacing = 0.0,
                    } };
                    const name_len = @min(token_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], token_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
                return true;
            }
        }
        return false;
    }

    // Apply full design pattern to profile component (colors, spacing, typography).
    pub fn apply_pattern_to_profile(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        if (!self.apply_pattern_colors_to_profile(component_id, pattern)) {
            return false;
        }
        if (!self.apply_pattern_spacing_to_profile(component_id, pattern)) {
            return false;
        }
        if (!self.apply_pattern_typography_to_profile(component_id, pattern)) {
            return false;
        }
        return true;
    }

    // Apply full design pattern to website component (colors, spacing, typography).
    pub fn apply_pattern_to_website(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        var i: u32 = 0;
        while (i < self.website_components_len) : (i += 1) {
            if (self.website_components[i].component_id == component_id) {
                const base = self.website_components[i].base_component;
                if (base.design_tokens_len + 12 > component.MAX_DESIGN_TOKENS) {
                    return false;
                }
                const color_names = [_][]const u8{ "primary", "secondary", "background", "text", "accent" };
                const colors = [_]u32{
                    pattern.color_scheme.primary,
                    pattern.color_scheme.secondary,
                    pattern.color_scheme.background,
                    pattern.color_scheme.text,
                    pattern.color_scheme.accent,
                };
                var j: u32 = 0;
                while (j < 5) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .color;
                    token.value = .{ .color = colors[j] };
                    const name_len = @min(color_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], color_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                const spacing_names = [_][]const u8{ "spacing_small", "spacing_medium", "spacing_large", "spacing_xlarge" };
                const spacings = [_]f64{
                    pattern.spacing.small,
                    pattern.spacing.medium,
                    pattern.spacing.large,
                    pattern.spacing.xlarge,
                };
                j = 0;
                while (j < 4) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .spacing;
                    token.value = .{ .spacing = spacings[j] };
                    const name_len = @min(spacing_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], spacing_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                const typo_names = [_][]const u8{ "heading_size", "body_size", "caption_size" };
                const font_sizes = [_]u32{
                    pattern.typography.heading_size,
                    pattern.typography.body_size,
                    pattern.typography.caption_size,
                };
                j = 0;
                while (j < 3) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .typography;
                    token.value = .{ .typography = component.DesignToken.TypographyValue{
                        .font_size = font_sizes[j],
                        .line_height = pattern.typography.line_height,
                        .letter_spacing = 0.0,
                    } };
                    const name_len = @min(typo_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], typo_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
                return true;
            }
        }
        return false;
    }

    // Apply full design pattern to workspace component (colors, spacing, typography).
    pub fn apply_pattern_to_workspace(
        self: *SlcComponentLibrary,
        component_id: u32,
        pattern: *const DesignPattern,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(component_id > 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        var i: u32 = 0;
        while (i < self.workspace_components_len) : (i += 1) {
            if (self.workspace_components[i].component_id == component_id) {
                const base = self.workspace_components[i].base_component;
                if (base.design_tokens_len + 12 > component.MAX_DESIGN_TOKENS) {
                    return false;
                }
                const color_names = [_][]const u8{ "primary", "secondary", "background", "text", "accent" };
                const colors = [_]u32{
                    pattern.color_scheme.primary,
                    pattern.color_scheme.secondary,
                    pattern.color_scheme.background,
                    pattern.color_scheme.text,
                    pattern.color_scheme.accent,
                };
                var j: u32 = 0;
                while (j < 5) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .color;
                    token.value = .{ .color = colors[j] };
                    const name_len = @min(color_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], color_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                const spacing_names = [_][]const u8{ "spacing_small", "spacing_medium", "spacing_large", "spacing_xlarge" };
                const spacings = [_]f64{
                    pattern.spacing.small,
                    pattern.spacing.medium,
                    pattern.spacing.large,
                    pattern.spacing.xlarge,
                };
                j = 0;
                while (j < 4) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .spacing;
                    token.value = .{ .spacing = spacings[j] };
                    const name_len = @min(spacing_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], spacing_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                const typo_names = [_][]const u8{ "heading_size", "body_size", "caption_size" };
                const font_sizes = [_]u32{
                    pattern.typography.heading_size,
                    pattern.typography.body_size,
                    pattern.typography.caption_size,
                };
                j = 0;
                while (j < 3) : (j += 1) {
                    const token_id = base.design_tokens_len + 1;
                    var token = component.DesignToken.init();
                    token.id = token_id;
                    token.token_type = .typography;
                    token.value = .{ .typography = component.DesignToken.TypographyValue{
                        .font_size = font_sizes[j],
                        .line_height = pattern.typography.line_height,
                        .letter_spacing = 0.0,
                    } };
                    const name_len = @min(typo_names[j].len, MAX_COMPONENT_NAME_LEN);
                    @memset(token.name[0..name_len], 0);
                    @memcpy(token.name[0..name_len], typo_names[j][0..name_len]);
                    token.name_len = @as(u32, @intCast(name_len));
                    base.design_tokens[base.design_tokens_len] = token;
                    base.design_tokens_len += 1;
                }
                std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
                return true;
            }
        }
        return false;
    }
};

// Design pattern: reusable design pattern for SLC components.
pub const DesignPattern = struct {
    pattern_id: u32,
    pattern_type: PatternType,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    color_scheme: ColorScheme,
    spacing: SpacingScheme,
    typography: TypographyScheme,

    pub const PatternType = enum(u8) {
        profile_form, // Profile form pattern
        profile_viewer, // Profile viewer pattern
        website_editor, // Website editor pattern
        workspace_app, // Workspace app pattern
    };

    pub const ColorScheme = struct {
        primary: u32,
        secondary: u32,
        background: u32,
        text: u32,
        accent: u32,
    };

    pub const SpacingScheme = struct {
        small: f64,
        medium: f64,
        large: f64,
        xlarge: f64,
    };

    pub const TypographyScheme = struct {
        heading_size: u32,
        body_size: u32,
        caption_size: u32,
        line_height: f64,
    };

    pub fn init(
        pattern_id: u32,
        pattern_type: PatternType,
        name: []const u8,
    ) DesignPattern {
        std.debug.assert(pattern_id > 0);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var pattern = DesignPattern{
            .pattern_id = pattern_id,
            .pattern_type = pattern_type,
            .name = undefined,
            .name_len = 0,
            .color_scheme = ColorScheme{
                .primary = 0xFF0000FF,
                .secondary = 0xFF00FF00,
                .background = 0xFFFFFFFF,
                .text = 0xFF000000,
                .accent = 0xFFFF0000,
            },
            .spacing = SpacingScheme{
                .small = 4.0,
                .medium = 8.0,
                .large = 16.0,
                .xlarge = 32.0,
            },
            .typography = TypographyScheme{
                .heading_size = 24,
                .body_size = 16,
                .caption_size = 12,
                .line_height = 1.5,
            },
        };
        @memset(pattern.name[0..], 0);
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memcpy(pattern.name[0..name_len], name[0..name_len]);
        pattern.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(pattern.name_len > 0);
        return pattern;
    }
};

// Animation: animation configuration for SLC components.
pub const Animation = struct {
    animation_id: u32,
    animation_type: AnimationType,
    duration_ms: u32,
    easing: EasingType,
    delay_ms: u32,

    pub const AnimationType = enum(u8) {
        fade_in, // Fade in animation
        fade_out, // Fade out animation
        slide_in, // Slide in animation
        slide_out, // Slide out animation
        scale_in, // Scale in animation
        scale_out, // Scale out animation
    };

    pub const EasingType = enum(u8) {
        linear, // Linear easing
        ease_in, // Ease in easing
        ease_out, // Ease out easing
        ease_in_out, // Ease in-out easing
    };

    pub fn init(
        animation_id: u32,
        anim_type: AnimationType,
        duration_ms: u32,
        easing: EasingType,
    ) Animation {
        std.debug.assert(animation_id > 0);
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        const anim = Animation{
            .animation_id = animation_id,
            .animation_type = anim_type,
            .duration_ms = duration_ms,
            .easing = easing,
            .delay_ms = 0,
        };
        std.debug.assert(anim.duration_ms > 0);
        return anim;
    }

    // Set animation delay.
    pub fn set_delay(self: *Animation, delay_ms: u32) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(delay_ms <= 5000);
        self.delay_ms = delay_ms;
        std.debug.assert(self.delay_ms <= 5000);
    }
};

// Preset design patterns: common design patterns for SLC products.
pub const PresetPatterns = struct {
    // Create profile form pattern (Nostr Profile Builder).
    pub fn create_profile_form_pattern() DesignPattern {
        var pattern = DesignPattern.init(1, .profile_form, "Profile Form");
        pattern.color_scheme = DesignPattern.ColorScheme{
            .primary = 0xFF0066FF, // Blue
            .secondary = 0xFF00CCFF, // Light blue
            .background = 0xFFFFFFFF, // White
            .text = 0xFF000000, // Black
            .accent = 0xFFFF6600, // Orange
        };
        pattern.spacing = DesignPattern.SpacingScheme{
            .small = 4.0,
            .medium = 8.0,
            .large = 16.0,
            .xlarge = 24.0,
        };
        pattern.typography = DesignPattern.TypographyScheme{
            .heading_size = 20,
            .body_size = 14,
            .caption_size = 12,
            .line_height = 1.6,
        };
        std.debug.assert(pattern.pattern_id == 1);
        return pattern;
    }

    // Create profile viewer pattern (Nostr Profile Builder).
    pub fn create_profile_viewer_pattern() DesignPattern {
        var pattern = DesignPattern.init(2, .profile_viewer, "Profile Viewer");
        pattern.color_scheme = DesignPattern.ColorScheme{
            .primary = 0xFF0066FF, // Blue
            .secondary = 0xFFE6F2FF, // Light blue background
            .background = 0xFFFFFFFF, // White
            .text = 0xFF1A1A1A, // Dark gray
            .accent = 0xFFFF6600, // Orange
        };
        pattern.spacing = DesignPattern.SpacingScheme{
            .small = 6.0,
            .medium = 12.0,
            .large = 24.0,
            .xlarge = 32.0,
        };
        pattern.typography = DesignPattern.TypographyScheme{
            .heading_size = 24,
            .body_size = 16,
            .caption_size = 12,
            .line_height = 1.5,
        };
        std.debug.assert(pattern.pattern_id == 2);
        return pattern;
    }

    // Create website editor pattern (DAG Website Builder).
    pub fn create_website_editor_pattern() DesignPattern {
        var pattern = DesignPattern.init(3, .website_editor, "Website Editor");
        pattern.color_scheme = DesignPattern.ColorScheme{
            .primary = 0xFF00AA00, // Green
            .secondary = 0xFF66FF66, // Light green
            .background = 0xFFF5F5F5, // Light gray
            .text = 0xFF000000, // Black
            .accent = 0xFFFF0000, // Red
        };
        pattern.spacing = DesignPattern.SpacingScheme{
            .small = 4.0,
            .medium = 8.0,
            .large = 16.0,
            .xlarge = 32.0,
        };
        pattern.typography = DesignPattern.TypographyScheme{
            .heading_size = 22,
            .body_size = 15,
            .caption_size = 11,
            .line_height = 1.6,
        };
        std.debug.assert(pattern.pattern_id == 3);
        return pattern;
    }

    // Create workspace app pattern (Workspace App Suite).
    pub fn create_workspace_app_pattern() DesignPattern {
        var pattern = DesignPattern.init(4, .workspace_app, "Workspace App");
        pattern.color_scheme = DesignPattern.ColorScheme{
            .primary = 0xFF333333, // Dark gray
            .secondary = 0xFF666666, // Medium gray
            .background = 0xFFFFFFFF, // White
            .text = 0xFF000000, // Black
            .accent = 0xFF0066CC, // Blue
        };
        pattern.spacing = DesignPattern.SpacingScheme{
            .small = 4.0,
            .medium = 8.0,
            .large = 16.0,
            .xlarge = 24.0,
        };
        pattern.typography = DesignPattern.TypographyScheme{
            .heading_size = 18,
            .body_size = 14,
            .caption_size = 11,
            .line_height = 1.5,
        };
        std.debug.assert(pattern.pattern_id == 4);
        return pattern;
    }
};

// Preset animations: common animations for SLC components.
pub const PresetAnimations = struct {
    // Create fade in animation.
    pub fn create_fade_in(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(1, .fade_in, duration_ms, .ease_in_out);
    }

    // Create fade out animation.
    pub fn create_fade_out(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(2, .fade_out, duration_ms, .ease_in_out);
    }

    // Create slide in animation.
    pub fn create_slide_in(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(3, .slide_in, duration_ms, .ease_out);
    }

    // Create slide out animation.
    pub fn create_slide_out(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(4, .slide_out, duration_ms, .ease_in);
    }

    // Create scale in animation.
    pub fn create_scale_in(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(5, .scale_in, duration_ms, .ease_out);
    }

    // Create scale out animation.
    pub fn create_scale_out(duration_ms: u32) Animation {
        std.debug.assert(duration_ms > 0);
        std.debug.assert(duration_ms <= 10000);
        return Animation.init(6, .scale_out, duration_ms, .ease_in);
    }

    // Create quick fade in (200ms).
    pub fn create_quick_fade_in() Animation {
        return create_fade_in(200);
    }

    // Create smooth fade in (500ms).
    pub fn create_smooth_fade_in() Animation {
        return create_fade_in(500);
    }

    // Create quick slide in (250ms).
    pub fn create_quick_slide_in() Animation {
        return create_slide_in(250);
    }

    // Create smooth slide in (600ms).
    pub fn create_smooth_slide_in() Animation {
        return create_slide_in(600);
    }
};

// Animation utilities: helper functions for working with animations.
pub const AnimationUtils = struct {
    // Bounded: Max CSS animation string length.
    const MAX_ANIMATION_CSS_LEN: u32 = 256;

    // Get easing function name from easing type.
    pub fn get_easing_name(easing: Animation.EasingType) []const u8 {
        return switch (easing) {
            .linear => "linear",
            .ease_in => "ease-in",
            .ease_out => "ease-out",
            .ease_in_out => "ease-in-out",
        };
    }

    // Generate CSS animation property from animation.
    pub fn generate_css_animation(
        anim: *const Animation,
        css_buf: []u8,
    ) []const u8 {
        std.debug.assert(@intFromPtr(anim) != 0);
        std.debug.assert(css_buf.len >= MAX_ANIMATION_CSS_LEN);
        const anim_name = switch (anim.animation_type) {
            .fade_in => "fadeIn",
            .fade_out => "fadeOut",
            .slide_in => "slideIn",
            .slide_out => "slideOut",
            .scale_in => "scaleIn",
            .scale_out => "scaleOut",
        };
        const easing = get_easing_name(anim.easing);
        const duration_s = @as(f64, @floatFromInt(anim.duration_ms)) / 1000.0;
        const delay_s = @as(f64, @floatFromInt(anim.delay_ms)) / 1000.0;
        const css_str = std.fmt.bufPrint(
            css_buf,
            "{s} {d:.2}s {s} {d:.2}s",
            .{ anim_name, duration_s, easing, delay_s },
        ) catch return "";
        std.debug.assert(css_str.len > 0);
        return css_str;
    }

    // Generate CSS keyframes for animation type.
    pub fn generate_css_keyframes(
        anim_type: Animation.AnimationType,
        keyframes_buf: []u8,
    ) []const u8 {
        std.debug.assert(keyframes_buf.len >= MAX_ANIMATION_CSS_LEN);
        const keyframes = switch (anim_type) {
            .fade_in => "@keyframes fadeIn {\n  from { opacity: 0; }\n  to { opacity: 1; }\n}\n",
            .fade_out => "@keyframes fadeOut {\n  from { opacity: 1; }\n  to { opacity: 0; }\n}\n",
            .slide_in => "@keyframes slideIn {\n  from { transform: translateX(-100%); }\n  to { transform: translateX(0); }\n}\n",
            .slide_out => "@keyframes slideOut {\n  from { transform: translateX(0); }\n  to { transform: translateX(100%); }\n}\n",
            .scale_in => "@keyframes scaleIn {\n  from { transform: scale(0); }\n  to { transform: scale(1); }\n}\n",
            .scale_out => "@keyframes scaleOut {\n  from { transform: scale(1); }\n  to { transform: scale(0); }\n}\n",
        };
        const keyframes_len = @min(keyframes.len, keyframes_buf.len);
        @memcpy(keyframes_buf[0..keyframes_len], keyframes[0..keyframes_len]);
        std.debug.assert(keyframes_len > 0);
        return keyframes_buf[0..keyframes_len];
    }

    // Get animation duration in seconds.
    pub fn get_duration_seconds(anim: *const Animation) f64 {
        std.debug.assert(@intFromPtr(anim) != 0);
        return @as(f64, @floatFromInt(anim.duration_ms)) / 1000.0;
    }

    // Get animation delay in seconds.
    pub fn get_delay_seconds(anim: *const Animation) f64 {
        std.debug.assert(@intFromPtr(anim) != 0);
        return @as(f64, @floatFromInt(anim.delay_ms)) / 1000.0;
    }
};
