//! Tests for Grain Workspace Desktop Component API.
//!
//! Tests component API structure per approved design (Core Agent coordination
//! decision 2025-12-28-125036-pst).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const testing = std.testing;
const grain_workspace = @import("grain_workspace");
const components = grain_workspace.components;

test "Component init" {
    const comp = components.Component.init(1, "test_component");
    try testing.expect(comp.id == 1);
    try testing.expect(comp.name_len == 14);
    try testing.expect(comp.state == .normal);
    try testing.expect(comp.size == .medium);
    try testing.expect(comp.theme == .light);
    try testing.expect(comp.visible == true);
    try testing.expect(comp.enabled == true);
}

test "Component set_state" {
    var comp = components.Component.init(1, "test");
    comp.set_state(.hover);
    try testing.expect(comp.state == .hover);
    comp.set_state(.active);
    try testing.expect(comp.state == .active);
    comp.set_state(.disabled);
    try testing.expect(comp.state == .disabled);
    comp.set_state(.focused);
    try testing.expect(comp.state == .focused);
    comp.set_state(.normal);
    try testing.expect(comp.state == .normal);
}

test "Component set_size" {
    var comp = components.Component.init(1, "test");
    comp.set_size(.small);
    try testing.expect(comp.size == .small);
    comp.set_size(.large);
    try testing.expect(comp.size == .large);
    comp.set_size(.medium);
    try testing.expect(comp.size == .medium);
}

test "Component set_theme" {
    var comp = components.Component.init(1, "test");
    comp.set_theme(.dark);
    try testing.expect(comp.theme == .dark);
    comp.set_theme(.high_contrast);
    try testing.expect(comp.theme == .high_contrast);
    comp.set_theme(.light);
    try testing.expect(comp.theme == .light);
}

test "FileManagerComponents init" {
    const fm_components = components.FileManagerComponents.init();
    try testing.expect(fm_components.file_tree.id == 1);
    try testing.expect(fm_components.file_list.id == 2);
    try testing.expect(fm_components.toolbar.id == 3);
    try testing.expect(fm_components.status_bar.id == 4);
    try testing.expect(fm_components.file_tree.name_len > 0);
    try testing.expect(fm_components.file_list.name_len > 0);
    try testing.expect(fm_components.toolbar.name_len > 0);
    try testing.expect(fm_components.status_bar.name_len > 0);
}

test "FileManagerComponents set_state_all" {
    var fm_components = components.FileManagerComponents.init();
    fm_components.set_state_all(.hover);
    try testing.expect(fm_components.file_tree.state == .hover);
    try testing.expect(fm_components.file_list.state == .hover);
    try testing.expect(fm_components.toolbar.state == .hover);
    try testing.expect(fm_components.status_bar.state == .hover);
    fm_components.set_state_all(.active);
    try testing.expect(fm_components.file_tree.state == .active);
}

test "FileManagerComponents set_size_all" {
    var fm_components = components.FileManagerComponents.init();
    fm_components.set_size_all(.small);
    try testing.expect(fm_components.file_tree.size == .small);
    try testing.expect(fm_components.file_list.size == .small);
    try testing.expect(fm_components.toolbar.size == .small);
    try testing.expect(fm_components.status_bar.size == .small);
    fm_components.set_size_all(.large);
    try testing.expect(fm_components.file_tree.size == .large);
}

test "FileManagerComponents set_theme_all" {
    var fm_components = components.FileManagerComponents.init();
    fm_components.set_theme_all(.dark);
    try testing.expect(fm_components.file_tree.theme == .dark);
    try testing.expect(fm_components.file_list.theme == .dark);
    try testing.expect(fm_components.toolbar.theme == .dark);
    try testing.expect(fm_components.status_bar.theme == .dark);
    fm_components.set_theme_all(.high_contrast);
    try testing.expect(fm_components.file_tree.theme == .high_contrast);
}

test "TextEditorComponents init" {
    const te_components = components.TextEditorComponents.init();
    try testing.expect(te_components.editor_view.id == 10);
    try testing.expect(te_components.line_numbers.id == 11);
    try testing.expect(te_components.syntax_tokens.id == 12);
    try testing.expect(te_components.status_bar.id == 13);
    try testing.expect(te_components.editor_view.name_len > 0);
    try testing.expect(te_components.line_numbers.name_len > 0);
    try testing.expect(te_components.syntax_tokens.name_len > 0);
    try testing.expect(te_components.status_bar.name_len > 0);
}

test "TextEditorComponents set_state_all" {
    var te_components = components.TextEditorComponents.init();
    te_components.set_state_all(.focused);
    try testing.expect(te_components.editor_view.state == .focused);
    try testing.expect(te_components.line_numbers.state == .focused);
    try testing.expect(te_components.syntax_tokens.state == .focused);
    try testing.expect(te_components.status_bar.state == .focused);
    te_components.set_state_all(.disabled);
    try testing.expect(te_components.editor_view.state == .disabled);
}

test "TextEditorComponents set_size_all" {
    var te_components = components.TextEditorComponents.init();
    te_components.set_size_all(.large);
    try testing.expect(te_components.editor_view.size == .large);
    try testing.expect(te_components.line_numbers.size == .large);
    try testing.expect(te_components.syntax_tokens.size == .large);
    try testing.expect(te_components.status_bar.size == .large);
    te_components.set_size_all(.small);
    try testing.expect(te_components.editor_view.size == .small);
}

test "TextEditorComponents set_theme_all" {
    var te_components = components.TextEditorComponents.init();
    te_components.set_theme_all(.dark);
    try testing.expect(te_components.editor_view.theme == .dark);
    try testing.expect(te_components.line_numbers.theme == .dark);
    try testing.expect(te_components.syntax_tokens.theme == .dark);
    try testing.expect(te_components.status_bar.theme == .dark);
    te_components.set_theme_all(.light);
    try testing.expect(te_components.editor_view.theme == .light);
}

test "TerminalComponents init" {
    const term_components = components.TerminalComponents.init();
    try testing.expect(term_components.terminal_view.id == 20);
    try testing.expect(term_components.input_line.id == 21);
    try testing.expect(term_components.tabs.id == 22);
    try testing.expect(term_components.terminal_view.name_len > 0);
    try testing.expect(term_components.input_line.name_len > 0);
    try testing.expect(term_components.tabs.name_len > 0);
}

test "TerminalComponents set_state_all" {
    var term_components = components.TerminalComponents.init();
    term_components.set_state_all(.active);
    try testing.expect(term_components.terminal_view.state == .active);
    try testing.expect(term_components.input_line.state == .active);
    try testing.expect(term_components.tabs.state == .active);
    term_components.set_state_all(.normal);
    try testing.expect(term_components.terminal_view.state == .normal);
}

test "TerminalComponents set_size_all" {
    var term_components = components.TerminalComponents.init();
    term_components.set_size_all(.medium);
    try testing.expect(term_components.terminal_view.size == .medium);
    try testing.expect(term_components.input_line.size == .medium);
    try testing.expect(term_components.tabs.size == .medium);
    term_components.set_size_all(.small);
    try testing.expect(term_components.terminal_view.size == .small);
}

test "TerminalComponents set_theme_all" {
    var term_components = components.TerminalComponents.init();
    term_components.set_theme_all(.high_contrast);
    try testing.expect(term_components.terminal_view.theme == .high_contrast);
    try testing.expect(term_components.input_line.theme == .high_contrast);
    try testing.expect(term_components.tabs.theme == .high_contrast);
    term_components.set_theme_all(.dark);
    try testing.expect(term_components.terminal_view.theme == .dark);
}

test "DesktopComponentAPI init" {
    const api = components.DesktopComponentAPI.init();
    try testing.expect(api.file_manager.file_tree.id == 1);
    try testing.expect(api.text_editor.editor_view.id == 10);
    try testing.expect(api.terminal.terminal_view.id == 20);
    try testing.expect(api.file_manager.file_list.id == 2);
    try testing.expect(api.text_editor.line_numbers.id == 11);
    try testing.expect(api.terminal.input_line.id == 21);
}

test "DesktopComponentAPI set_theme_all" {
    var api = components.DesktopComponentAPI.init();
    api.set_theme_all(.dark);
    try testing.expect(api.file_manager.file_tree.theme == .dark);
    try testing.expect(api.text_editor.editor_view.theme == .dark);
    try testing.expect(api.terminal.terminal_view.theme == .dark);
    api.set_theme_all(.high_contrast);
    try testing.expect(api.file_manager.file_tree.theme == .high_contrast);
    try testing.expect(api.text_editor.editor_view.theme == .high_contrast);
    try testing.expect(api.terminal.terminal_view.theme == .high_contrast);
}

test "DesktopComponentAPI set_size_all" {
    var api = components.DesktopComponentAPI.init();
    api.set_size_all(.large);
    try testing.expect(api.file_manager.file_tree.size == .large);
    try testing.expect(api.text_editor.editor_view.size == .large);
    try testing.expect(api.terminal.terminal_view.size == .large);
    api.set_size_all(.small);
    try testing.expect(api.file_manager.file_tree.size == .small);
    try testing.expect(api.text_editor.editor_view.size == .small);
    try testing.expect(api.terminal.terminal_view.size == .small);
}

test "Component name truncation" {
    const long_name = "a" ** 100;
    const comp = components.Component.init(1, long_name);
    try testing.expect(comp.name_len == components.MAX_COMPONENT_NAME_LEN);
    try testing.expect(comp.name_len <= components.MAX_COMPONENT_NAME_LEN);
}

test "Component variant combinations" {
    var comp = components.Component.init(1, "test");
    comp.set_state(.hover);
    comp.set_size(.large);
    comp.set_theme(.dark);
    try testing.expect(comp.state == .hover);
    try testing.expect(comp.size == .large);
    try testing.expect(comp.theme == .dark);
    comp.set_state(.active);
    comp.set_size(.small);
    comp.set_theme(.high_contrast);
    try testing.expect(comp.state == .active);
    try testing.expect(comp.size == .small);
    try testing.expect(comp.theme == .high_contrast);
}
