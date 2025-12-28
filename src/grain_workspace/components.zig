//! Grain Workspace Desktop Component API: Component structures for desktop apps.
//!
//! Why: Provide component API structure for File Manager, Text Editor, and Terminal
//! per approved design (Core Agent coordination decision 2025-12-28-125036-pst).
//! Architecture: Component API with variant support (state/size/theme).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-125036-pst: Component API Design Implementation (Phase 32)

const std = @import("std");

// Bounded: Max component name length.
pub const MAX_COMPONENT_NAME_LEN: u32 = 64;

// Bounded: Max component ID.
pub const MAX_COMPONENT_ID: u32 = 4_294_967_295;

// Component state variant: normal, hover, active, disabled, focused.
pub const ComponentState = enum(u8) {
    normal,
    hover,
    active,
    disabled,
    focused,
};

// Component size variant: small, medium, large.
pub const ComponentSize = enum(u8) {
    small,
    medium,
    large,
};

// Component theme variant: light, dark, high_contrast.
pub const ComponentTheme = enum(u8) {
    light,
    dark,
    high_contrast,
};

// Base component: shared component structure.
pub const Component = struct {
    id: u32,
    name: [MAX_COMPONENT_NAME_LEN]u8,
    name_len: u32,
    state: ComponentState,
    size: ComponentSize,
    theme: ComponentTheme,
    visible: bool,
    enabled: bool,

    pub fn init(
        id: u32,
        name: []const u8,
    ) Component {
        std.debug.assert(id > 0);
        std.debug.assert(id <= MAX_COMPONENT_ID);
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_COMPONENT_NAME_LEN);
        var comp = Component{
            .id = id,
            .name = undefined,
            .name_len = 0,
            .state = .normal,
            .size = .medium,
            .theme = .light,
            .visible = true,
            .enabled = true,
        };
        @memset(comp.name[0..], 0);
        const name_len = @min(name.len, MAX_COMPONENT_NAME_LEN);
        @memcpy(comp.name[0..name_len], name[0..name_len]);
        comp.name_len = @as(u32, @intCast(name_len));
        std.debug.assert(comp.name_len > 0);
        std.debug.assert(comp.state == .normal);
        std.debug.assert(comp.size == .medium);
        std.debug.assert(comp.theme == .light);
        return comp;
    }

    pub fn set_state(self: *Component, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.state = state;
        std.debug.assert(self.state == state);
    }

    pub fn set_size(self: *Component, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.size = size;
        std.debug.assert(self.size == size);
    }

    pub fn set_theme(self: *Component, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.theme = theme;
        std.debug.assert(self.theme == theme);
    }
};

// File Manager components: file_tree, file_list, toolbar, status_bar.
pub const FileManagerComponents = struct {
    file_tree: Component,
    file_list: Component,
    toolbar: Component,
    status_bar: Component,

    pub fn init() FileManagerComponents {
        var components = FileManagerComponents{
            .file_tree = Component.init(1, "file_tree"),
            .file_list = Component.init(2, "file_list"),
            .toolbar = Component.init(3, "toolbar"),
            .status_bar = Component.init(4, "status_bar"),
        };
        std.debug.assert(components.file_tree.id == 1);
        std.debug.assert(components.file_list.id == 2);
        std.debug.assert(components.toolbar.id == 3);
        std.debug.assert(components.status_bar.id == 4);
        return components;
    }

    pub fn set_state_all(self: *FileManagerComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.file_tree.set_state(state);
        self.file_list.set_state(state);
        self.toolbar.set_state(state);
        self.status_bar.set_state(state);
        std.debug.assert(self.file_tree.state == state);
    }

    pub fn set_size_all(self: *FileManagerComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.file_tree.set_size(size);
        self.file_list.set_size(size);
        self.toolbar.set_size(size);
        self.status_bar.set_size(size);
        std.debug.assert(self.file_tree.size == size);
    }

    pub fn set_theme_all(self: *FileManagerComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.file_tree.set_theme(theme);
        self.file_list.set_theme(theme);
        self.toolbar.set_theme(theme);
        self.status_bar.set_theme(theme);
        std.debug.assert(self.file_tree.theme == theme);
    }
};

// Text Editor components: editor_view, line_numbers, syntax_tokens, status_bar.
pub const TextEditorComponents = struct {
    editor_view: Component,
    line_numbers: Component,
    syntax_tokens: Component,
    status_bar: Component,

    pub fn init() TextEditorComponents {
        var components = TextEditorComponents{
            .editor_view = Component.init(10, "editor_view"),
            .line_numbers = Component.init(11, "line_numbers"),
            .syntax_tokens = Component.init(12, "syntax_tokens"),
            .status_bar = Component.init(13, "status_bar"),
        };
        std.debug.assert(components.editor_view.id == 10);
        std.debug.assert(components.line_numbers.id == 11);
        std.debug.assert(components.syntax_tokens.id == 12);
        std.debug.assert(components.status_bar.id == 13);
        return components;
    }

    pub fn set_state_all(self: *TextEditorComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.editor_view.set_state(state);
        self.line_numbers.set_state(state);
        self.syntax_tokens.set_state(state);
        self.status_bar.set_state(state);
        std.debug.assert(self.editor_view.state == state);
    }

    pub fn set_size_all(self: *TextEditorComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.editor_view.set_size(size);
        self.line_numbers.set_size(size);
        self.syntax_tokens.set_size(size);
        self.status_bar.set_size(size);
        std.debug.assert(self.editor_view.size == size);
    }

    pub fn set_theme_all(self: *TextEditorComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.editor_view.set_theme(theme);
        self.line_numbers.set_theme(theme);
        self.syntax_tokens.set_theme(theme);
        self.status_bar.set_theme(theme);
        std.debug.assert(self.editor_view.theme == theme);
    }
};

// Terminal components: terminal_view, input_line, tabs.
pub const TerminalComponents = struct {
    terminal_view: Component,
    input_line: Component,
    tabs: Component,

    pub fn init() TerminalComponents {
        var components = TerminalComponents{
            .terminal_view = Component.init(20, "terminal_view"),
            .input_line = Component.init(21, "input_line"),
            .tabs = Component.init(22, "tabs"),
        };
        std.debug.assert(components.terminal_view.id == 20);
        std.debug.assert(components.input_line.id == 21);
        std.debug.assert(components.tabs.id == 22);
        return components;
    }

    pub fn set_state_all(self: *TerminalComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.terminal_view.set_state(state);
        self.input_line.set_state(state);
        self.tabs.set_state(state);
        std.debug.assert(self.terminal_view.state == state);
    }

    pub fn set_size_all(self: *TerminalComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.terminal_view.set_size(size);
        self.input_line.set_size(size);
        self.tabs.set_size(size);
        std.debug.assert(self.terminal_view.size == size);
    }

    pub fn set_theme_all(self: *TerminalComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.terminal_view.set_theme(theme);
        self.input_line.set_theme(theme);
        self.tabs.set_theme(theme);
        std.debug.assert(self.terminal_view.theme == theme);
    }
};

// Desktop Component API: unified API for all desktop app components.
pub const DesktopComponentAPI = struct {
    file_manager: FileManagerComponents,
    text_editor: TextEditorComponents,
    terminal: TerminalComponents,

    pub fn init() DesktopComponentAPI {
        var api = DesktopComponentAPI{
            .file_manager = FileManagerComponents.init(),
            .text_editor = TextEditorComponents.init(),
            .terminal = TerminalComponents.init(),
        };
        std.debug.assert(api.file_manager.file_tree.id == 1);
        std.debug.assert(api.text_editor.editor_view.id == 10);
        std.debug.assert(api.terminal.terminal_view.id == 20);
        return api;
    }

    pub fn set_theme_all(self: *DesktopComponentAPI, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.file_manager.set_theme_all(theme);
        self.text_editor.set_theme_all(theme);
        self.terminal.set_theme_all(theme);
        std.debug.assert(self.file_manager.file_tree.theme == theme);
    }

    pub fn set_size_all(self: *DesktopComponentAPI, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.file_manager.set_size_all(size);
        self.text_editor.set_size_all(size);
        self.terminal.set_size_all(size);
        std.debug.assert(self.file_manager.file_tree.size == size);
    }
};
