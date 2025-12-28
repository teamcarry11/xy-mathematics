//! Grain Aurora Dream Browser Component API: Component structures for browser.
//!
//! Why: Provide component API structure for Dream Browser per Workspace Agent
//! Component API pattern (Core Agent coordination decision 2025-12-28-125036-pst).
//! Architecture: Component API with variant support (state/size/theme), adapted
//! for browser context (navigation, tabs, address bar, etc.).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-28-144557-pst: Dream Browser Component API Implementation

const std = @import("std");
const workspace_components = @import("grain_workspace").components;

// Re-export component base types from Workspace Agent for consistency.
pub const Component = workspace_components.Component;
pub const ComponentState = workspace_components.ComponentState;
pub const ComponentSize = workspace_components.ComponentSize;
pub const ComponentTheme = workspace_components.ComponentTheme;
pub const MAX_COMPONENT_NAME_LEN = workspace_components.MAX_COMPONENT_NAME_LEN;
pub const MAX_COMPONENT_ID = workspace_components.MAX_COMPONENT_ID;

// Navigation components: navigation_bar, back_button, forward_button, reload_button.
pub const NavigationComponents = struct {
    navigation_bar: Component,
    back_button: Component,
    forward_button: Component,
    reload_button: Component,
    home_button: Component,

    pub fn init() NavigationComponents {
        const components = NavigationComponents{
            .navigation_bar = Component.init(30, "navigation_bar"),
            .back_button = Component.init(31, "back_button"),
            .forward_button = Component.init(32, "forward_button"),
            .reload_button = Component.init(33, "reload_button"),
            .home_button = Component.init(34, "home_button"),
        };
        std.debug.assert(components.navigation_bar.id == 30);
        std.debug.assert(components.back_button.id == 31);
        std.debug.assert(components.forward_button.id == 32);
        std.debug.assert(components.reload_button.id == 33);
        std.debug.assert(components.home_button.id == 34);
        return components;
    }

    pub fn set_state_all(self: *NavigationComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.navigation_bar.set_state(state);
        self.back_button.set_state(state);
        self.forward_button.set_state(state);
        self.reload_button.set_state(state);
        self.home_button.set_state(state);
        std.debug.assert(self.navigation_bar.state == state);
    }

    pub fn set_size_all(self: *NavigationComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.navigation_bar.set_size(size);
        self.back_button.set_size(size);
        self.forward_button.set_size(size);
        self.reload_button.set_size(size);
        self.home_button.set_size(size);
        std.debug.assert(self.navigation_bar.size == size);
    }

    pub fn set_theme_all(self: *NavigationComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.navigation_bar.set_theme(theme);
        self.back_button.set_theme(theme);
        self.forward_button.set_theme(theme);
        self.reload_button.set_theme(theme);
        self.home_button.set_theme(theme);
        std.debug.assert(self.navigation_bar.theme == theme);
    }
};

// Address bar components: address_bar, search_bar, bookmark_button.
pub const AddressBarComponents = struct {
    address_bar: Component,
    search_bar: Component,
    bookmark_button: Component,

    pub fn init() AddressBarComponents {
        const components = AddressBarComponents{
            .address_bar = Component.init(40, "address_bar"),
            .search_bar = Component.init(41, "search_bar"),
            .bookmark_button = Component.init(42, "bookmark_button"),
        };
        std.debug.assert(components.address_bar.id == 40);
        std.debug.assert(components.search_bar.id == 41);
        std.debug.assert(components.bookmark_button.id == 42);
        return components;
    }

    pub fn set_state_all(self: *AddressBarComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.address_bar.set_state(state);
        self.search_bar.set_state(state);
        self.bookmark_button.set_state(state);
        std.debug.assert(self.address_bar.state == state);
    }

    pub fn set_size_all(self: *AddressBarComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.address_bar.set_size(size);
        self.search_bar.set_size(size);
        self.bookmark_button.set_size(size);
        std.debug.assert(self.address_bar.size == size);
    }

    pub fn set_theme_all(self: *AddressBarComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.address_bar.set_theme(theme);
        self.search_bar.set_theme(theme);
        self.bookmark_button.set_theme(theme);
        std.debug.assert(self.address_bar.theme == theme);
    }
};

// Tab components: tab_bar, tab_view, new_tab_button, close_tab_button.
pub const TabComponents = struct {
    tab_bar: Component,
    tab_view: Component,
    new_tab_button: Component,
    close_tab_button: Component,

    pub fn init() TabComponents {
        const components = TabComponents{
            .tab_bar = Component.init(50, "tab_bar"),
            .tab_view = Component.init(51, "tab_view"),
            .new_tab_button = Component.init(52, "new_tab_button"),
            .close_tab_button = Component.init(53, "close_tab_button"),
        };
        std.debug.assert(components.tab_bar.id == 50);
        std.debug.assert(components.tab_view.id == 51);
        std.debug.assert(components.new_tab_button.id == 52);
        std.debug.assert(components.close_tab_button.id == 53);
        return components;
    }

    pub fn set_state_all(self: *TabComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.tab_bar.set_state(state);
        self.tab_view.set_state(state);
        self.new_tab_button.set_state(state);
        self.close_tab_button.set_state(state);
        std.debug.assert(self.tab_bar.state == state);
    }

    pub fn set_size_all(self: *TabComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.tab_bar.set_size(size);
        self.tab_view.set_size(size);
        self.new_tab_button.set_size(size);
        self.close_tab_button.set_size(size);
        std.debug.assert(self.tab_bar.size == size);
    }

    pub fn set_theme_all(self: *TabComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.tab_bar.set_theme(theme);
        self.tab_view.set_theme(theme);
        self.new_tab_button.set_theme(theme);
        self.close_tab_button.set_theme(theme);
        std.debug.assert(self.tab_bar.theme == theme);
    }
};

// Browser view components: browser_view, content_area, status_bar.
pub const BrowserViewComponents = struct {
    browser_view: Component,
    content_area: Component,
    status_bar: Component,

    pub fn init() BrowserViewComponents {
        const components = BrowserViewComponents{
            .browser_view = Component.init(60, "browser_view"),
            .content_area = Component.init(61, "content_area"),
            .status_bar = Component.init(62, "status_bar"),
        };
        std.debug.assert(components.browser_view.id == 60);
        std.debug.assert(components.content_area.id == 61);
        std.debug.assert(components.status_bar.id == 62);
        return components;
    }

    pub fn set_state_all(self: *BrowserViewComponents, state: ComponentState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.browser_view.set_state(state);
        self.content_area.set_state(state);
        self.status_bar.set_state(state);
        std.debug.assert(self.browser_view.state == state);
    }

    pub fn set_size_all(self: *BrowserViewComponents, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.browser_view.set_size(size);
        self.content_area.set_size(size);
        self.status_bar.set_size(size);
        std.debug.assert(self.browser_view.size == size);
    }

    pub fn set_theme_all(self: *BrowserViewComponents, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.browser_view.set_theme(theme);
        self.content_area.set_theme(theme);
        self.status_bar.set_theme(theme);
        std.debug.assert(self.browser_view.theme == theme);
    }
};

// Dream Browser Component API: unified API for all browser components.
pub const DreamBrowserComponentAPI = struct {
    navigation: NavigationComponents,
    address_bar: AddressBarComponents,
    tabs: TabComponents,
    browser_view: BrowserViewComponents,

    pub fn init() DreamBrowserComponentAPI {
        const api = DreamBrowserComponentAPI{
            .navigation = NavigationComponents.init(),
            .address_bar = AddressBarComponents.init(),
            .tabs = TabComponents.init(),
            .browser_view = BrowserViewComponents.init(),
        };
        std.debug.assert(api.navigation.navigation_bar.id == 30);
        std.debug.assert(api.address_bar.address_bar.id == 40);
        std.debug.assert(api.tabs.tab_bar.id == 50);
        std.debug.assert(api.browser_view.browser_view.id == 60);
        return api;
    }

    pub fn set_theme_all(self: *DreamBrowserComponentAPI, theme: ComponentTheme) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.navigation.set_theme_all(theme);
        self.address_bar.set_theme_all(theme);
        self.tabs.set_theme_all(theme);
        self.browser_view.set_theme_all(theme);
        std.debug.assert(self.navigation.navigation_bar.theme == theme);
    }

    pub fn set_size_all(self: *DreamBrowserComponentAPI, size: ComponentSize) void {
        std.debug.assert(@intFromPtr(self) != 0);
        self.navigation.set_size_all(size);
        self.address_bar.set_size_all(size);
        self.tabs.set_size_all(size);
        self.browser_view.set_size_all(size);
        std.debug.assert(self.navigation.navigation_bar.size == size);
    }
};
