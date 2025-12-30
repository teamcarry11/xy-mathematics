//! Tests for Grain Aurora Dream Browser Component API.
//!
//! Tests component API structure per approved design (Core Agent coordination
//! decision 2025-12-28-125036-pst).
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const testing = std.testing;
const dream_browser_components = @import("dream_browser_components");

test "Component init" {
    const comp = dream_browser_components.Component.init(1, "test_component");
    try testing.expect(comp.id == 1);
    try testing.expect(comp.name_len == 14);
    try testing.expect(comp.state == .normal);
    try testing.expect(comp.size == .medium);
    try testing.expect(comp.theme == .light);
    try testing.expect(comp.visible == true);
    try testing.expect(comp.enabled == true);
}

test "Component set_state" {
    var comp = dream_browser_components.Component.init(1, "test");
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
    var comp = dream_browser_components.Component.init(1, "test");
    comp.set_size(.small);
    try testing.expect(comp.size == .small);
    comp.set_size(.large);
    try testing.expect(comp.size == .large);
    comp.set_size(.medium);
    try testing.expect(comp.size == .medium);
}

test "Component set_theme" {
    var comp = dream_browser_components.Component.init(1, "test");
    comp.set_theme(.dark);
    try testing.expect(comp.theme == .dark);
    comp.set_theme(.high_contrast);
    try testing.expect(comp.theme == .high_contrast);
    comp.set_theme(.light);
    try testing.expect(comp.theme == .light);
}

test "NavigationComponents init" {
    const nav_components = dream_browser_components.NavigationComponents.init();
    try testing.expect(nav_components.navigation_bar.id == 30);
    try testing.expect(nav_components.back_button.id == 31);
    try testing.expect(nav_components.forward_button.id == 32);
    try testing.expect(nav_components.reload_button.id == 33);
    try testing.expect(nav_components.home_button.id == 34);
    try testing.expect(nav_components.navigation_bar.name_len > 0);
    try testing.expect(nav_components.back_button.name_len > 0);
    try testing.expect(nav_components.forward_button.name_len > 0);
    try testing.expect(nav_components.reload_button.name_len > 0);
    try testing.expect(nav_components.home_button.name_len > 0);
}

test "NavigationComponents set_state_all" {
    var nav_components = dream_browser_components.NavigationComponents.init();
    nav_components.set_state_all(.hover);
    try testing.expect(nav_components.navigation_bar.state == .hover);
    try testing.expect(nav_components.back_button.state == .hover);
    try testing.expect(nav_components.forward_button.state == .hover);
    try testing.expect(nav_components.reload_button.state == .hover);
    try testing.expect(nav_components.home_button.state == .hover);
    nav_components.set_state_all(.active);
    try testing.expect(nav_components.navigation_bar.state == .active);
}

test "NavigationComponents set_size_all" {
    var nav_components = dream_browser_components.NavigationComponents.init();
    nav_components.set_size_all(.small);
    try testing.expect(nav_components.navigation_bar.size == .small);
    try testing.expect(nav_components.back_button.size == .small);
    try testing.expect(nav_components.forward_button.size == .small);
    try testing.expect(nav_components.reload_button.size == .small);
    try testing.expect(nav_components.home_button.size == .small);
    nav_components.set_size_all(.large);
    try testing.expect(nav_components.navigation_bar.size == .large);
}

test "NavigationComponents set_theme_all" {
    var nav_components = dream_browser_components.NavigationComponents.init();
    nav_components.set_theme_all(.dark);
    try testing.expect(nav_components.navigation_bar.theme == .dark);
    try testing.expect(nav_components.back_button.theme == .dark);
    try testing.expect(nav_components.forward_button.theme == .dark);
    try testing.expect(nav_components.reload_button.theme == .dark);
    try testing.expect(nav_components.home_button.theme == .dark);
    nav_components.set_theme_all(.high_contrast);
    try testing.expect(nav_components.navigation_bar.theme == .high_contrast);
}

test "AddressBarComponents init" {
    const addr_components = dream_browser_components.AddressBarComponents.init();
    try testing.expect(addr_components.address_bar.id == 40);
    try testing.expect(addr_components.search_bar.id == 41);
    try testing.expect(addr_components.bookmark_button.id == 42);
    try testing.expect(addr_components.address_bar.name_len > 0);
    try testing.expect(addr_components.search_bar.name_len > 0);
    try testing.expect(addr_components.bookmark_button.name_len > 0);
}

test "AddressBarComponents set_state_all" {
    var addr_components = dream_browser_components.AddressBarComponents.init();
    addr_components.set_state_all(.focused);
    try testing.expect(addr_components.address_bar.state == .focused);
    try testing.expect(addr_components.search_bar.state == .focused);
    try testing.expect(addr_components.bookmark_button.state == .focused);
    addr_components.set_state_all(.disabled);
    try testing.expect(addr_components.address_bar.state == .disabled);
}

test "AddressBarComponents set_size_all" {
    var addr_components = dream_browser_components.AddressBarComponents.init();
    addr_components.set_size_all(.large);
    try testing.expect(addr_components.address_bar.size == .large);
    try testing.expect(addr_components.search_bar.size == .large);
    try testing.expect(addr_components.bookmark_button.size == .large);
    addr_components.set_size_all(.small);
    try testing.expect(addr_components.address_bar.size == .small);
}

test "AddressBarComponents set_theme_all" {
    var addr_components = dream_browser_components.AddressBarComponents.init();
    addr_components.set_theme_all(.dark);
    try testing.expect(addr_components.address_bar.theme == .dark);
    try testing.expect(addr_components.search_bar.theme == .dark);
    try testing.expect(addr_components.bookmark_button.theme == .dark);
    addr_components.set_theme_all(.light);
    try testing.expect(addr_components.address_bar.theme == .light);
}

test "TabComponents init" {
    const tab_components = dream_browser_components.TabComponents.init();
    try testing.expect(tab_components.tab_bar.id == 50);
    try testing.expect(tab_components.tab_view.id == 51);
    try testing.expect(tab_components.new_tab_button.id == 52);
    try testing.expect(tab_components.close_tab_button.id == 53);
    try testing.expect(tab_components.tab_bar.name_len > 0);
    try testing.expect(tab_components.tab_view.name_len > 0);
    try testing.expect(tab_components.new_tab_button.name_len > 0);
    try testing.expect(tab_components.close_tab_button.name_len > 0);
}

test "TabComponents set_state_all" {
    var tab_components = dream_browser_components.TabComponents.init();
    tab_components.set_state_all(.active);
    try testing.expect(tab_components.tab_bar.state == .active);
    try testing.expect(tab_components.tab_view.state == .active);
    try testing.expect(tab_components.new_tab_button.state == .active);
    try testing.expect(tab_components.close_tab_button.state == .active);
    tab_components.set_state_all(.normal);
    try testing.expect(tab_components.tab_bar.state == .normal);
}

test "TabComponents set_size_all" {
    var tab_components = dream_browser_components.TabComponents.init();
    tab_components.set_size_all(.medium);
    try testing.expect(tab_components.tab_bar.size == .medium);
    try testing.expect(tab_components.tab_view.size == .medium);
    try testing.expect(tab_components.new_tab_button.size == .medium);
    try testing.expect(tab_components.close_tab_button.size == .medium);
    tab_components.set_size_all(.small);
    try testing.expect(tab_components.tab_bar.size == .small);
}

test "TabComponents set_theme_all" {
    var tab_components = dream_browser_components.TabComponents.init();
    tab_components.set_theme_all(.high_contrast);
    try testing.expect(tab_components.tab_bar.theme == .high_contrast);
    try testing.expect(tab_components.tab_view.theme == .high_contrast);
    try testing.expect(tab_components.new_tab_button.theme == .high_contrast);
    try testing.expect(tab_components.close_tab_button.theme == .high_contrast);
    tab_components.set_theme_all(.dark);
    try testing.expect(tab_components.tab_bar.theme == .dark);
}

test "BrowserViewComponents init" {
    const view_components = dream_browser_components.BrowserViewComponents.init();
    try testing.expect(view_components.browser_view.id == 60);
    try testing.expect(view_components.content_area.id == 61);
    try testing.expect(view_components.status_bar.id == 62);
    try testing.expect(view_components.browser_view.name_len > 0);
    try testing.expect(view_components.content_area.name_len > 0);
    try testing.expect(view_components.status_bar.name_len > 0);
}

test "BrowserViewComponents set_state_all" {
    var view_components = dream_browser_components.BrowserViewComponents.init();
    view_components.set_state_all(.focused);
    try testing.expect(view_components.browser_view.state == .focused);
    try testing.expect(view_components.content_area.state == .focused);
    try testing.expect(view_components.status_bar.state == .focused);
    view_components.set_state_all(.disabled);
    try testing.expect(view_components.browser_view.state == .disabled);
}

test "BrowserViewComponents set_size_all" {
    var view_components = dream_browser_components.BrowserViewComponents.init();
    view_components.set_size_all(.large);
    try testing.expect(view_components.browser_view.size == .large);
    try testing.expect(view_components.content_area.size == .large);
    try testing.expect(view_components.status_bar.size == .large);
    view_components.set_size_all(.small);
    try testing.expect(view_components.browser_view.size == .small);
}

test "BrowserViewComponents set_theme_all" {
    var view_components = dream_browser_components.BrowserViewComponents.init();
    view_components.set_theme_all(.dark);
    try testing.expect(view_components.browser_view.theme == .dark);
    try testing.expect(view_components.content_area.theme == .dark);
    try testing.expect(view_components.status_bar.theme == .dark);
    view_components.set_theme_all(.high_contrast);
    try testing.expect(view_components.browser_view.theme == .high_contrast);
}

test "DreamBrowserComponentAPI init" {
    const api = dream_browser_components.DreamBrowserComponentAPI.init();
    try testing.expect(api.navigation.navigation_bar.id == 30);
    try testing.expect(api.address_bar.address_bar.id == 40);
    try testing.expect(api.tabs.tab_bar.id == 50);
    try testing.expect(api.browser_view.browser_view.id == 60);
    try testing.expect(api.navigation.back_button.id == 31);
    try testing.expect(api.address_bar.search_bar.id == 41);
    try testing.expect(api.tabs.tab_view.id == 51);
    try testing.expect(api.browser_view.content_area.id == 61);
}

test "DreamBrowserComponentAPI set_theme_all" {
    var api = dream_browser_components.DreamBrowserComponentAPI.init();
    api.set_theme_all(.dark);
    try testing.expect(api.navigation.navigation_bar.theme == .dark);
    try testing.expect(api.address_bar.address_bar.theme == .dark);
    try testing.expect(api.tabs.tab_bar.theme == .dark);
    try testing.expect(api.browser_view.browser_view.theme == .dark);
    api.set_theme_all(.high_contrast);
    try testing.expect(api.navigation.navigation_bar.theme == .high_contrast);
    try testing.expect(api.address_bar.address_bar.theme == .high_contrast);
    try testing.expect(api.tabs.tab_bar.theme == .high_contrast);
    try testing.expect(api.browser_view.browser_view.theme == .high_contrast);
}

test "DreamBrowserComponentAPI set_size_all" {
    var api = dream_browser_components.DreamBrowserComponentAPI.init();
    api.set_size_all(.large);
    try testing.expect(api.navigation.navigation_bar.size == .large);
    try testing.expect(api.address_bar.address_bar.size == .large);
    try testing.expect(api.tabs.tab_bar.size == .large);
    try testing.expect(api.browser_view.browser_view.size == .large);
    api.set_size_all(.small);
    try testing.expect(api.navigation.navigation_bar.size == .small);
    try testing.expect(api.address_bar.address_bar.size == .small);
    try testing.expect(api.tabs.tab_bar.size == .small);
    try testing.expect(api.browser_view.browser_view.size == .small);
}

test "Component name truncation" {
    const long_name = "a" ** 100;
    const comp = dream_browser_components.Component.init(1, long_name);
    try testing.expect(comp.name_len == dream_browser_components.MAX_COMPONENT_NAME_LEN);
    try testing.expect(comp.name_len <= dream_browser_components.MAX_COMPONENT_NAME_LEN);
}

test "Component variant combinations" {
    var comp = dream_browser_components.Component.init(1, "test");
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
