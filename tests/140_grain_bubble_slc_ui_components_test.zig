//! Grain Bubble SLC UI Components Tests.
//!
//! Why: Test SLC UI components for SLC products.
//! Architecture: Unit tests for SLC component library.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-083043-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const component = @import("grain_bubble").component;
const slc_ui_components = @import("grain_bubble").slc_ui_components;

test "slc component library init" {
    const library = slc_ui_components.SlcComponentLibrary.init();
    std.debug.assert(library.profile_components_len == 0);
    std.debug.assert(library.website_components_len == 0);
    std.debug.assert(library.workspace_components_len == 0);
    std.debug.assert(library.next_profile_id == 1);
    std.debug.assert(library.next_website_id == 1);
    std.debug.assert(library.next_workspace_id == 1);
}

test "slc component library add profile component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_library = component.ComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    const profile_comp = library.add_profile_component(
        .form,
        "Profile Form",
        &base_comp,
    );
    std.debug.assert(profile_comp != null);
    std.debug.assert(library.profile_components_len == 1);
    std.debug.assert(profile_comp.?.component_id == 1);
    std.debug.assert(profile_comp.?.component_type == .form);
}

test "slc component library add website component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    const website_comp = library.add_website_component(
        .dag_editor,
        "DAG Editor",
        &base_comp,
    );
    std.debug.assert(website_comp != null);
    std.debug.assert(library.website_components_len == 1);
    std.debug.assert(website_comp.?.component_id == 1);
    std.debug.assert(website_comp.?.component_type == .dag_editor);
}

test "slc component library add workspace component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    const workspace_comp = library.add_workspace_component(
        .file_manager,
        "File Manager",
        &base_comp,
    );
    std.debug.assert(workspace_comp != null);
    std.debug.assert(library.workspace_components_len == 1);
    std.debug.assert(workspace_comp.?.component_id == 1);
    std.debug.assert(workspace_comp.?.component_type == .file_manager);
}

test "slc component library get profile component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    const profile_comp = library.get_profile_component(1);
    std.debug.assert(profile_comp != null);
    std.debug.assert(profile_comp.?.component_id == 1);
}

test "slc component library get website component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    const website_comp = library.get_website_component(1);
    std.debug.assert(website_comp != null);
    std.debug.assert(website_comp.?.component_id == 1);
}

test "slc component library get workspace component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    const workspace_comp = library.get_workspace_component(1);
    std.debug.assert(workspace_comp != null);
    std.debug.assert(workspace_comp.?.component_id == 1);
}

test "slc component library component counts" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    std.debug.assert(library.get_profile_component_count() == 1);
    std.debug.assert(library.get_website_component_count() == 1);
    std.debug.assert(library.get_workspace_component_count() == 1);
}

test "slc component library multiple components" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp1 = component.Component.init();
    base_comp1.id = 1;
    var base_comp2 = component.Component.init();
    base_comp2.id = 2;
    var base_comp3 = component.Component.init();
    base_comp3.id = 3;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp1);
    _ = library.add_profile_component(.editor, "Profile Editor", &base_comp2);
    _ = library.add_profile_component(.viewer, "Profile Viewer", &base_comp3);
    std.debug.assert(library.profile_components_len == 3);
    std.debug.assert(library.get_profile_component_count() == 3);
}

test "slc design pattern init" {
    const pattern = slc_ui_components.DesignPattern.init(
        1,
        .profile_form,
        "Profile Form Pattern",
    );
    std.debug.assert(pattern.pattern_id == 1);
    std.debug.assert(pattern.pattern_type == .profile_form);
    std.debug.assert(pattern.name_len > 0);
    std.debug.assert(pattern.color_scheme.primary == 0xFF0000FF);
    std.debug.assert(pattern.spacing.medium == 8.0);
    std.debug.assert(pattern.typography.heading_size == 24);
}

test "slc animation init" {
    const anim = slc_ui_components.Animation.init(
        1,
        .fade_in,
        300,
        .ease_in_out,
    );
    std.debug.assert(anim.animation_id == 1);
    std.debug.assert(anim.animation_type == .fade_in);
    std.debug.assert(anim.duration_ms == 300);
    std.debug.assert(anim.easing == .ease_in_out);
    std.debug.assert(anim.delay_ms == 0);
}

test "slc animation set delay" {
    var anim = slc_ui_components.Animation.init(
        1,
        .slide_in,
        500,
        .ease_out,
    );
    anim.set_delay(100);
    std.debug.assert(anim.delay_ms == 100);
}
