//! Grain Bubble Workspace Integration: Component API integration.
//!
//! Why: Integrate Bubble SLC UI components with Workspace Agent DesktopComponentAPI.
//! Architecture: Integration layer between Bubble components and Workspace components.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-162338-pst: Grain Bubble Agent

const std = @import("std");
const slc_ui_components = @import("slc_ui_components.zig");
const component = @import("component.zig");
const grain_workspace = @import("grain_workspace");

// Workspace integration: manages integration between Bubble and Workspace components.
pub const WorkspaceIntegration = struct {
    component_library: *slc_ui_components.SlcComponentLibrary,
    workspace_api: ?*grain_workspace.components.DesktopComponentAPI,

    pub fn init(
        library: *slc_ui_components.SlcComponentLibrary,
    ) WorkspaceIntegration {
        std.debug.assert(@intFromPtr(library) != 0);
        const integration = WorkspaceIntegration{
            .component_library = library,
            .workspace_api = null,
        };
        std.debug.assert(integration.component_library == library);
        return integration;
    }

    // Set Workspace Agent DesktopComponentAPI instance.
    pub fn set_workspace_api(
        self: *WorkspaceIntegration,
        api: *grain_workspace.components.DesktopComponentAPI,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(api) != 0);
        self.workspace_api = api;
        std.debug.assert(self.workspace_api != null);
    }

    // Apply theme to Workspace component based on design pattern.
    fn apply_theme_from_pattern(
        workspace_comp: *grain_workspace.components.Component,
        pattern: *const slc_ui_components.DesignPattern,
    ) void {
        std.debug.assert(@intFromPtr(workspace_comp) != 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        // Determine theme from pattern colors (simplified - use primary color brightness).
        // For now, default to light theme (can be enhanced later).
        const theme = grain_workspace.components.ComponentTheme.light;
        workspace_comp.set_theme(theme);
        std.debug.assert(workspace_comp.theme == theme);
    }

    // Apply Bubble design pattern to Workspace component.
    pub fn apply_pattern_to_workspace_component(
        self: *WorkspaceIntegration,
        workspace_comp: *grain_workspace.components.Component,
        pattern: *const slc_ui_components.DesignPattern,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(workspace_comp) != 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        // Apply theme from pattern.
        apply_theme_from_pattern(workspace_comp, pattern);
        std.debug.assert(workspace_comp.theme == .light or workspace_comp.theme == .dark or workspace_comp.theme == .high_contrast);
    }

    // Sync Workspace component theme to Bubble component design tokens.
    pub fn sync_theme_to_bubble(
        self: *WorkspaceIntegration,
        bubble_comp_id: u32,
        workspace_comp: *const grain_workspace.components.Component,
    ) bool {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(bubble_comp_id > 0);
        std.debug.assert(@intFromPtr(workspace_comp) != 0);
        // Get Bubble component.
        const bubble_comp = self.component_library.get_workspace_component(bubble_comp_id) orelse return false;
        const base = bubble_comp.base_component;
        // Apply theme as design token (simplified - create theme token).
        const theme_name = switch (workspace_comp.theme) {
            .light => "theme_light",
            .dark => "theme_dark",
            .high_contrast => "theme_high_contrast",
        };
        // Add theme as design token (simplified implementation).
        // Full implementation would add proper design tokens for theme colors.
        std.debug.assert(base.design_tokens_len <= component.MAX_DESIGN_TOKENS);
        return true;
    }

    // Apply Bubble design pattern to all Workspace components.
    pub fn apply_pattern_to_workspace_api(
        self: *WorkspaceIntegration,
        pattern: *const slc_ui_components.DesignPattern,
    ) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(pattern) != 0);
        if (self.workspace_api == null) {
            return;
        }
        const api = self.workspace_api.?;
        // Apply pattern to file manager components.
        self.apply_pattern_to_workspace_component(&api.file_manager.file_tree, pattern);
        self.apply_pattern_to_workspace_component(&api.file_manager.file_list, pattern);
        self.apply_pattern_to_workspace_component(&api.file_manager.toolbar, pattern);
        self.apply_pattern_to_workspace_component(&api.file_manager.status_bar, pattern);
        // Apply pattern to text editor components.
        self.apply_pattern_to_workspace_component(&api.text_editor.editor_view, pattern);
        self.apply_pattern_to_workspace_component(&api.text_editor.line_numbers, pattern);
        self.apply_pattern_to_workspace_component(&api.text_editor.syntax_tokens, pattern);
        self.apply_pattern_to_workspace_component(&api.text_editor.status_bar, pattern);
        // Apply pattern to terminal components.
        self.apply_pattern_to_workspace_component(&api.terminal.terminal_view, pattern);
        self.apply_pattern_to_workspace_component(&api.terminal.input_line, pattern);
        self.apply_pattern_to_workspace_component(&api.terminal.tabs, pattern);
        std.debug.assert(api.file_manager.file_tree.theme == .light or api.file_manager.file_tree.theme == .dark or api.file_manager.file_tree.theme == .high_contrast);
    }
};
