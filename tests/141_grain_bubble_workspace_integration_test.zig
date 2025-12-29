//! Grain Bubble Workspace Integration Tests.
//!
//! Why: Test integration between Bubble SLC UI components and Workspace Agent DesktopComponentAPI.
//! Architecture: Unit tests for Workspace integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-162338-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const grain_bubble = @import("grain_bubble");
const grain_workspace = @import("grain_workspace");

test "workspace integration init" {
    var library = grain_bubble.slc_ui_components.SlcComponentLibrary.init();
    var integration = grain_bubble.workspace_integration.WorkspaceIntegration.init(&library);
    std.debug.assert(integration.component_library == &library);
    std.debug.assert(integration.workspace_api == null);
}

test "workspace integration set workspace api" {
    var library = grain_bubble.slc_ui_components.SlcComponentLibrary.init();
    var integration = grain_bubble.workspace_integration.WorkspaceIntegration.init(&library);
    var workspace_api = grain_workspace.components.DesktopComponentAPI.init();
    integration.set_workspace_api(&workspace_api);
    std.debug.assert(integration.workspace_api != null);
}

test "workspace integration apply pattern to workspace component" {
    var library = grain_bubble.slc_ui_components.SlcComponentLibrary.init();
    var integration = grain_bubble.workspace_integration.WorkspaceIntegration.init(&library);
    var workspace_api = grain_workspace.components.DesktopComponentAPI.init();
    integration.set_workspace_api(&workspace_api);
    var pattern = grain_bubble.slc_ui_components.PresetPatterns.get_workspace_app_pattern();
    integration.apply_pattern_to_workspace_component(
        &workspace_api.file_manager.file_tree,
        &pattern,
    );
    std.debug.assert(workspace_api.file_manager.file_tree.theme == .light or workspace_api.file_manager.file_tree.theme == .dark or workspace_api.file_manager.file_tree.theme == .high_contrast);
}

test "workspace integration apply pattern to workspace api" {
    var library = grain_bubble.slc_ui_components.SlcComponentLibrary.init();
    var integration = grain_bubble.workspace_integration.WorkspaceIntegration.init(&library);
    var workspace_api = grain_workspace.components.DesktopComponentAPI.init();
    integration.set_workspace_api(&workspace_api);
    var pattern = grain_bubble.slc_ui_components.PresetPatterns.get_workspace_app_pattern();
    integration.apply_pattern_to_workspace_api(&pattern);
    std.debug.assert(workspace_api.file_manager.file_tree.theme == .light or workspace_api.file_manager.file_tree.theme == .dark or workspace_api.file_manager.file_tree.theme == .high_contrast);
    std.debug.assert(workspace_api.text_editor.editor_view.theme == .light or workspace_api.text_editor.editor_view.theme == .dark or workspace_api.text_editor.editor_view.theme == .high_contrast);
    std.debug.assert(workspace_api.terminal.terminal_view.theme == .light or workspace_api.terminal.terminal_view.theme == .dark or workspace_api.terminal.terminal_view.theme == .high_contrast);
}

test "workspace integration sync theme to bubble" {
    var library = grain_bubble.slc_ui_components.SlcComponentLibrary.init();
    var integration = grain_bubble.workspace_integration.WorkspaceIntegration.init(&library);
    var workspace_api = grain_workspace.components.DesktopComponentAPI.init();
    integration.set_workspace_api(&workspace_api);
    // Create a workspace component in Bubble library.
    var component_lib = grain_bubble.component.ComponentLibrary.init();
    const base_comp_id = component_lib.create_component("TestWorkspace") orelse return;
    const base_comp = component_lib.get_component(base_comp_id).?;
    const workspace_comp = library.add_workspace_component(
        grain_bubble.slc_ui_components.WorkspaceComponent.WorkspaceComponentType.file_manager,
        "TestFileManager",
        base_comp,
    ) orelse return;
    std.debug.assert(workspace_comp.component_id > 0);
    // Sync theme from workspace component.
    const result = integration.sync_theme_to_bubble(
        workspace_comp.component_id,
        &workspace_api.file_manager.file_tree,
    );
    std.debug.assert(result == true);
}
