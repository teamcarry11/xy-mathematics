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

test "slc preset patterns profile form" {
    const pattern = slc_ui_components.PresetPatterns.create_profile_form_pattern();
    std.debug.assert(pattern.pattern_type == .profile_form);
    std.debug.assert(pattern.color_scheme.primary == 0xFF0066FF);
    std.debug.assert(pattern.spacing.medium == 8.0);
    std.debug.assert(pattern.typography.heading_size == 20);
}

test "slc preset patterns profile viewer" {
    const pattern = slc_ui_components.PresetPatterns.create_profile_viewer_pattern();
    std.debug.assert(pattern.pattern_type == .profile_viewer);
    std.debug.assert(pattern.color_scheme.primary == 0xFF0066FF);
    std.debug.assert(pattern.spacing.large == 24.0);
    std.debug.assert(pattern.typography.heading_size == 24);
}

test "slc preset patterns website editor" {
    const pattern = slc_ui_components.PresetPatterns.create_website_editor_pattern();
    std.debug.assert(pattern.pattern_type == .website_editor);
    std.debug.assert(pattern.color_scheme.primary == 0xFF00AA00);
    std.debug.assert(pattern.spacing.xlarge == 32.0);
    std.debug.assert(pattern.typography.heading_size == 22);
}

test "slc preset patterns workspace app" {
    const pattern = slc_ui_components.PresetPatterns.create_workspace_app_pattern();
    std.debug.assert(pattern.pattern_type == .workspace_app);
    std.debug.assert(pattern.color_scheme.primary == 0xFF333333);
    std.debug.assert(pattern.spacing.medium == 8.0);
    std.debug.assert(pattern.typography.heading_size == 18);
}

test "slc preset animations fade in" {
    const anim = slc_ui_components.PresetAnimations.create_fade_in(300);
    std.debug.assert(anim.animation_type == .fade_in);
    std.debug.assert(anim.duration_ms == 300);
    std.debug.assert(anim.easing == .ease_in_out);
}

test "slc preset animations slide in" {
    const anim = slc_ui_components.PresetAnimations.create_slide_in(400);
    std.debug.assert(anim.animation_type == .slide_in);
    std.debug.assert(anim.duration_ms == 400);
    std.debug.assert(anim.easing == .ease_out);
}

test "slc preset animations scale in" {
    const anim = slc_ui_components.PresetAnimations.create_scale_in(350);
    std.debug.assert(anim.animation_type == .scale_in);
    std.debug.assert(anim.duration_ms == 350);
    std.debug.assert(anim.easing == .ease_out);
}

test "slc preset animations quick fade in" {
    const anim = slc_ui_components.PresetAnimations.create_quick_fade_in();
    std.debug.assert(anim.animation_type == .fade_in);
    std.debug.assert(anim.duration_ms == 200);
    std.debug.assert(anim.easing == .ease_in_out);
}

test "slc preset animations smooth fade in" {
    const anim = slc_ui_components.PresetAnimations.create_smooth_fade_in();
    std.debug.assert(anim.animation_type == .fade_in);
    std.debug.assert(anim.duration_ms == 500);
    std.debug.assert(anim.easing == .ease_in_out);
}

test "slc preset animations quick slide in" {
    const anim = slc_ui_components.PresetAnimations.create_quick_slide_in();
    std.debug.assert(anim.animation_type == .slide_in);
    std.debug.assert(anim.duration_ms == 250);
    std.debug.assert(anim.easing == .ease_out);
}

test "slc preset animations smooth slide in" {
    const anim = slc_ui_components.PresetAnimations.create_smooth_slide_in();
    std.debug.assert(anim.animation_type == .slide_in);
    std.debug.assert(anim.duration_ms == 600);
    std.debug.assert(anim.easing == .ease_out);
}

test "slc component library create variant for profile" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    const variant_id = library.create_variant_for_profile(1, "hover", .state);
    std.debug.assert(variant_id != null);
    std.debug.assert(variant_id.? == 1);
    std.debug.assert(library.get_variant_count_for_profile(1) == 1);
}

test "slc component library create variant for website" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    const variant_id = library.create_variant_for_website(1, "large", .size);
    std.debug.assert(variant_id != null);
    std.debug.assert(variant_id.? == 1);
    std.debug.assert(library.get_variant_count_for_website(1) == 1);
}

test "slc component library create variant for workspace" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    const variant_id = library.create_variant_for_workspace(1, "dark", .theme);
    std.debug.assert(variant_id != null);
    std.debug.assert(variant_id.? == 1);
    std.debug.assert(library.get_variant_count_for_workspace(1) == 1);
}

test "slc component library get variant for profile" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    _ = library.create_variant_for_profile(1, "active", .state);
    const variant = library.get_variant_for_profile(1, 1);
    std.debug.assert(variant != null);
    std.debug.assert(variant.?.id == 1);
    std.debug.assert(variant.?.variant_type == .state);
}

test "slc component library get variant for website" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    _ = library.create_variant_for_website(1, "small", .size);
    const variant = library.get_variant_for_website(1, 1);
    std.debug.assert(variant != null);
    std.debug.assert(variant.?.id == 1);
    std.debug.assert(variant.?.variant_type == .size);
}

test "slc component library get variant for workspace" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    _ = library.create_variant_for_workspace(1, "light", .theme);
    const variant = library.get_variant_for_workspace(1, 1);
    std.debug.assert(variant != null);
    std.debug.assert(variant.?.id == 1);
    std.debug.assert(variant.?.variant_type == .theme);
}

test "slc component library multiple variants" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    _ = library.create_variant_for_profile(1, "default", .state);
    _ = library.create_variant_for_profile(1, "hover", .state);
    _ = library.create_variant_for_profile(1, "active", .state);
    std.debug.assert(library.get_variant_count_for_profile(1) == 3);
    const variant1 = library.get_variant_for_profile(1, 1);
    const variant2 = library.get_variant_for_profile(1, 2);
    const variant3 = library.get_variant_for_profile(1, 3);
    std.debug.assert(variant1 != null);
    std.debug.assert(variant2 != null);
    std.debug.assert(variant3 != null);
}

test "slc component library variant count zero" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    std.debug.assert(library.get_variant_count_for_profile(1) == 0);
}

test "slc component library get profile component by name" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    const comp = library.get_profile_component_by_name("Profile Form");
    std.debug.assert(comp != null);
    std.debug.assert(comp.?.component_id == 1);
}

test "slc component library get website component by name" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    const comp = library.get_website_component_by_name("DAG Editor");
    std.debug.assert(comp != null);
    std.debug.assert(comp.?.component_id == 1);
}

test "slc component library get workspace component by name" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    const comp = library.get_workspace_component_by_name("File Manager");
    std.debug.assert(comp != null);
    std.debug.assert(comp.?.component_id == 1);
}

test "slc component library validate profile component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    _ = library.create_variant_for_profile(1, "default", .state);
    std.debug.assert(library.validate_profile_component(1) == true);
    std.debug.assert(library.validate_profile_component(999) == false);
}

test "slc component library validate website component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    _ = library.create_variant_for_website(1, "default", .state);
    std.debug.assert(library.validate_website_component(1) == true);
    std.debug.assert(library.validate_website_component(999) == false);
}

test "slc component library validate workspace component" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    _ = library.create_variant_for_workspace(1, "default", .state);
    std.debug.assert(library.validate_workspace_component(1) == true);
    std.debug.assert(library.validate_workspace_component(999) == false);
}

test "slc component library apply pattern to profile" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_profile_component(.form, "Profile Form", &base_comp);
    const pattern = slc_ui_components.PresetPatterns.create_profile_form_pattern();
    const result = library.apply_pattern_to_profile(1, &pattern);
    std.debug.assert(result == true);
    const profile_comp = library.get_profile_component(1);
    std.debug.assert(profile_comp != null);
    std.debug.assert(profile_comp.?.base_component.design_tokens_len == 12);
}

test "slc component library apply pattern to website" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_website_component(.dag_editor, "DAG Editor", &base_comp);
    const pattern = slc_ui_components.PresetPatterns.create_website_editor_pattern();
    const result = library.apply_pattern_to_website(1, &pattern);
    std.debug.assert(result == true);
    const website_comp = library.get_website_component(1);
    std.debug.assert(website_comp != null);
    std.debug.assert(website_comp.?.base_component.design_tokens_len == 12);
}

test "slc component library apply pattern to workspace" {
    var library = slc_ui_components.SlcComponentLibrary.init();
    var base_comp = component.Component.init();
    base_comp.id = 1;
    _ = library.add_workspace_component(.file_manager, "File Manager", &base_comp);
    const pattern = slc_ui_components.PresetPatterns.create_workspace_app_pattern();
    const result = library.apply_pattern_to_workspace(1, &pattern);
    std.debug.assert(result == true);
    const workspace_comp = library.get_workspace_component(1);
    std.debug.assert(workspace_comp != null);
    std.debug.assert(workspace_comp.?.base_component.design_tokens_len == 12);
}

test "slc animation utils get easing name" {
    std.debug.assert(std.mem.eql(u8, slc_ui_components.AnimationUtils.get_easing_name(.linear), "linear"));
    std.debug.assert(std.mem.eql(u8, slc_ui_components.AnimationUtils.get_easing_name(.ease_in), "ease-in"));
    std.debug.assert(std.mem.eql(u8, slc_ui_components.AnimationUtils.get_easing_name(.ease_out), "ease-out"));
    std.debug.assert(std.mem.eql(u8, slc_ui_components.AnimationUtils.get_easing_name(.ease_in_out), "ease-in-out"));
}

test "slc animation utils generate css animation" {
    var anim = slc_ui_components.Animation.init(1, .fade_in, 300, .ease_in_out);
    anim.set_delay(100);
    var css_buf: [256]u8 = undefined;
    const css = slc_ui_components.AnimationUtils.generate_css_animation(&anim, &css_buf);
    std.debug.assert(css.len > 0);
    std.debug.assert(std.mem.indexOf(u8, css, "fadeIn") != null);
}

test "slc animation utils generate css keyframes" {
    var keyframes_buf: [256]u8 = undefined;
    const keyframes = slc_ui_components.AnimationUtils.generate_css_keyframes(.fade_in, &keyframes_buf);
    std.debug.assert(keyframes.len > 0);
    std.debug.assert(std.mem.indexOf(u8, keyframes, "@keyframes fadeIn") != null);
}

test "slc animation utils get duration and delay" {
    var anim = slc_ui_components.Animation.init(1, .slide_in, 500, .ease_out);
    anim.set_delay(200);
    const duration = slc_ui_components.AnimationUtils.get_duration_seconds(&anim);
    const delay = slc_ui_components.AnimationUtils.get_delay_seconds(&anim);
    std.debug.assert(duration == 0.5);
    std.debug.assert(delay == 0.2);
}
