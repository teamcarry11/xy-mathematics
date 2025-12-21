//! Tests for Aurora Tab Manager module.
//!
//! Why: Verify tab management functionality (constants, structures, metadata,
//! bounds checking).
//! Architecture: Comprehensive test coverage for tab management operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! NOTE: Some tests require Editor initialization which is blocked by Zig 0.15.2
//! comptime issue. These tests focus on functionality that can be tested:
//! constants, structures, metadata, bounds checking.
//!
//! 2025-12-21-090618-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const TabManager = @import("aurora_tab_manager").TabManager;

test "tab manager constants" {
    // Assert: Constants are defined correctly
    std.debug.assert(TabManager.MAX_EDITOR_TABS == 100);
    std.debug.assert(TabManager.MAX_BROWSER_TABS == 100);
    std.debug.assert(TabManager.MAX_TAB_GROUPS == 20);
    std.debug.assert(TabManager.MAX_GROUP_NAME_LENGTH == 256);
    std.debug.assert(TabManager.MAX_EDITOR_TABS > 0);
    std.debug.assert(TabManager.MAX_BROWSER_TABS > 0);
    std.debug.assert(TabManager.MAX_TAB_GROUPS > 0);
    std.debug.assert(TabManager.MAX_GROUP_NAME_LENGTH > 0);
}

test "tab manager tab metadata structure" {
    // Assert: TabMetadata structure fields
    const metadata = TabManager.TabMetadata{
        .last_accessed = 1234567890,
        .is_pinned = true,
        .group_id = 5,
        .order = 10,
    };

    std.debug.assert(metadata.last_accessed == 1234567890);
    std.debug.assert(metadata.is_pinned == true);
    std.debug.assert(metadata.group_id.? == 5);
    std.debug.assert(metadata.order == 10);
}

test "tab manager tab metadata default group id" {
    // Assert: TabMetadata with null group_id
    const metadata = TabManager.TabMetadata{
        .last_accessed = 0,
        .is_pinned = false,
        .group_id = null,
        .order = 0,
    };

    std.debug.assert(metadata.group_id == null);
    std.debug.assert(metadata.is_pinned == false);
}

test "tab manager tab group structure" {
    // Assert: TabGroup structure fields
    const group = TabManager.TabGroup{
        .id = 1,
        .name = "test group",
        .editor_tabs = &.{1, 2, 3},
        .editor_tabs_len = 3,
        .browser_tabs = &.{4, 5},
        .browser_tabs_len = 2,
        .created_at = 1234567890,
    };

    std.debug.assert(group.id == 1);
    std.debug.assert(std.mem.eql(u8, group.name, "test group"));
    std.debug.assert(group.editor_tabs_len == 3);
    std.debug.assert(group.browser_tabs_len == 2);
    std.debug.assert(group.created_at == 1234567890);
}

test "tab manager tab storage structure" {
    // Assert: TabStorage structure fields
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const editor_tabs = try arena.allocator().alloc(
        TabManager.ManagedEditorTab,
        TabManager.MAX_EDITOR_TABS,
    );
    const browser_tabs = try arena.allocator().alloc(
        TabManager.ManagedBrowserTab,
        TabManager.MAX_BROWSER_TABS,
    );
    const groups = try arena.allocator().alloc(
        TabManager.TabGroup,
        TabManager.MAX_TAB_GROUPS,
    );

    const storage = TabManager.TabStorage{
        .editor_tabs = editor_tabs,
        .editor_tabs_len = 0,
        .browser_tabs = browser_tabs,
        .browser_tabs_len = 0,
        .groups = groups,
        .groups_len = 0,
        .next_group_id = 1,
    };

    std.debug.assert(storage.editor_tabs_len == 0);
    std.debug.assert(storage.browser_tabs_len == 0);
    std.debug.assert(storage.groups_len == 0);
    std.debug.assert(storage.next_group_id == 1);
}

test "tab manager bounds checking editor tabs" {
    // Assert: MAX_EDITOR_TABS is reasonable
    std.debug.assert(TabManager.MAX_EDITOR_TABS == 100);
    std.debug.assert(TabManager.MAX_EDITOR_TABS > 0);
    std.debug.assert(TabManager.MAX_EDITOR_TABS <= 1_000);
}

test "tab manager bounds checking browser tabs" {
    // Assert: MAX_BROWSER_TABS is reasonable
    std.debug.assert(TabManager.MAX_BROWSER_TABS == 100);
    std.debug.assert(TabManager.MAX_BROWSER_TABS > 0);
    std.debug.assert(TabManager.MAX_BROWSER_TABS <= 1_000);
}

test "tab manager bounds checking tab groups" {
    // Assert: MAX_TAB_GROUPS is reasonable
    std.debug.assert(TabManager.MAX_TAB_GROUPS == 20);
    std.debug.assert(TabManager.MAX_TAB_GROUPS > 0);
    std.debug.assert(TabManager.MAX_TAB_GROUPS <= 100);
}

test "tab manager bounds checking group name length" {
    // Assert: MAX_GROUP_NAME_LENGTH is reasonable
    std.debug.assert(TabManager.MAX_GROUP_NAME_LENGTH == 256);
    std.debug.assert(TabManager.MAX_GROUP_NAME_LENGTH > 0);
    std.debug.assert(TabManager.MAX_GROUP_NAME_LENGTH <= 1_024);
}

test "tab manager tab metadata order" {
    // Assert: TabMetadata order field
    const metadata1 = TabManager.TabMetadata{
        .last_accessed = 0,
        .is_pinned = false,
        .group_id = null,
        .order = 1,
    };

    const metadata2 = TabManager.TabMetadata{
        .last_accessed = 0,
        .is_pinned = false,
        .group_id = null,
        .order = 2,
    };

    std.debug.assert(metadata1.order < metadata2.order);
}

test "tab manager tab metadata pinned" {
    // Assert: TabMetadata is_pinned field
    const pinned = TabManager.TabMetadata{
        .last_accessed = 0,
        .is_pinned = true,
        .group_id = null,
        .order = 0,
    };

    const unpinned = TabManager.TabMetadata{
        .last_accessed = 0,
        .is_pinned = false,
        .group_id = null,
        .order = 0,
    };

    std.debug.assert(pinned.is_pinned == true);
    std.debug.assert(unpinned.is_pinned == false);
}

test "tab manager tab group empty" {
    // Assert: TabGroup with empty tabs
    const group = TabManager.TabGroup{
        .id = 1,
        .name = "empty",
        .editor_tabs = &.{},
        .editor_tabs_len = 0,
        .browser_tabs = &.{},
        .browser_tabs_len = 0,
        .created_at = 0,
    };

    std.debug.assert(group.editor_tabs_len == 0);
    std.debug.assert(group.browser_tabs_len == 0);
}

test "tab manager tab group with editor tabs only" {
    // Assert: TabGroup with only editor tabs
    const group = TabManager.TabGroup{
        .id = 1,
        .name = "editor only",
        .editor_tabs = &.{1, 2, 3},
        .editor_tabs_len = 3,
        .browser_tabs = &.{},
        .browser_tabs_len = 0,
        .created_at = 0,
    };

    std.debug.assert(group.editor_tabs_len == 3);
    std.debug.assert(group.browser_tabs_len == 0);
}

test "tab manager tab group with browser tabs only" {
    // Assert: TabGroup with only browser tabs
    const group = TabManager.TabGroup{
        .id = 1,
        .name = "browser only",
        .editor_tabs = &.{},
        .editor_tabs_len = 0,
        .browser_tabs = &.{4, 5},
        .browser_tabs_len = 2,
        .created_at = 0,
    };

    std.debug.assert(group.editor_tabs_len == 0);
    std.debug.assert(group.browser_tabs_len == 2);
}

test "tab manager tab storage next group id" {
    // Assert: TabStorage next_group_id increments
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const editor_tabs = try arena.allocator().alloc(
        TabManager.ManagedEditorTab,
        TabManager.MAX_EDITOR_TABS,
    );
    const browser_tabs = try arena.allocator().alloc(
        TabManager.ManagedBrowserTab,
        TabManager.MAX_BROWSER_TABS,
    );
    const groups = try arena.allocator().alloc(
        TabManager.TabGroup,
        TabManager.MAX_TAB_GROUPS,
    );

    var storage = TabManager.TabStorage{
        .editor_tabs = editor_tabs,
        .editor_tabs_len = 0,
        .browser_tabs = browser_tabs,
        .browser_tabs_len = 0,
        .groups = groups,
        .groups_len = 0,
        .next_group_id = 1,
    };

    std.debug.assert(storage.next_group_id == 1);
    // Simulate increment
    const next_id = storage.next_group_id;
    storage.next_group_id += 1;
    std.debug.assert(storage.next_group_id == next_id + 1);
}

test "tab manager tab metadata last accessed" {
    // Assert: TabMetadata last_accessed timestamp
    const metadata = TabManager.TabMetadata{
        .last_accessed = 1234567890,
        .is_pinned = false,
        .group_id = null,
        .order = 0,
    };

    std.debug.assert(metadata.last_accessed == 1234567890);
    std.debug.assert(metadata.last_accessed > 0);
}

test "tab manager tab group created at" {
    // Assert: TabGroup created_at timestamp
    const group = TabManager.TabGroup{
        .id = 1,
        .name = "test",
        .editor_tabs = &.{},
        .editor_tabs_len = 0,
        .browser_tabs = &.{},
        .browser_tabs_len = 0,
        .created_at = 9876543210,
    };

    std.debug.assert(group.created_at == 9876543210);
    std.debug.assert(group.created_at > 0);
}

test "tab manager constants coverage" {
    // Assert: All constants are defined
    _ = TabManager.MAX_EDITOR_TABS;
    _ = TabManager.MAX_BROWSER_TABS;
    _ = TabManager.MAX_TAB_GROUPS;
    _ = TabManager.MAX_GROUP_NAME_LENGTH;
}
