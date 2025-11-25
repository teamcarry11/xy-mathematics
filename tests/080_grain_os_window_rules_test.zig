//! Tests for Grain OS window rules system.
//!
//! Why: Verify window rule matching and application functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const WindowRuleManager = grain_os.window_rules.WindowRuleManager;
const MatchType = grain_os.window_rules.MatchType;
const ActionType = grain_os.window_rules.ActionType;

test "window rule manager initialization" {
    const manager = WindowRuleManager.init();
    std.debug.assert(manager.rules_len == 0);
    std.debug.assert(manager.next_rule_id == 1);
}

test "add window rule" {
    var manager = WindowRuleManager.init();
    const rule_id_opt = manager.add_rule(
        MatchType.title,
        "Terminal",
        ActionType.set_position,
    );
    std.debug.assert(rule_id_opt != null);
    if (rule_id_opt) |rule_id| {
        std.debug.assert(rule_id == 1);
        std.debug.assert(manager.rules_len == 1);
    }
}

test "match window" {
    var manager = WindowRuleManager.init();
    _ = manager.add_rule(MatchType.title, "Terminal", ActionType.set_position);
    const rule_opt = manager.match_window("Terminal");
    std.debug.assert(rule_opt != null);
    if (rule_opt) |rule| {
        std.debug.assert(rule.match_type == MatchType.title);
        std.debug.assert(rule.action_type == ActionType.set_position);
    }
}

test "match window substring" {
    var manager = WindowRuleManager.init();
    _ = manager.add_rule(MatchType.title, "Term", ActionType.set_position);
    const rule_opt = manager.match_window("Terminal");
    std.debug.assert(rule_opt != null);
}

test "remove window rule" {
    var manager = WindowRuleManager.init();
    if (manager.add_rule(MatchType.title, "Terminal", ActionType.set_position)) |rule_id| {
        const result = manager.remove_rule(rule_id);
        std.debug.assert(result);
        std.debug.assert(manager.rules_len == 0);
    }
}

test "clear all rules" {
    var manager = WindowRuleManager.init();
    _ = manager.add_rule(MatchType.title, "Terminal", ActionType.set_position);
    _ = manager.add_rule(MatchType.title, "Editor", ActionType.set_size);
    manager.clear_all();
    std.debug.assert(manager.rules_len == 0);
}

test "get rule count" {
    var manager = WindowRuleManager.init();
    std.debug.assert(manager.get_rule_count() == 0);
    _ = manager.add_rule(MatchType.title, "Terminal", ActionType.set_position);
    std.debug.assert(manager.get_rule_count() == 1);
}

test "compositor add window rule" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const rule_id_opt = comp.add_window_rule(
        MatchType.title,
        "Terminal",
        ActionType.set_position,
    );
    std.debug.assert(rule_id_opt != null);
}

test "compositor remove window rule" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_window_rule(MatchType.title, "Terminal", ActionType.set_position)) |rule_id| {
        const result = comp.remove_window_rule(rule_id);
        std.debug.assert(result);
    }
}

test "compositor get rule count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_rule_count() == 0);
    _ = comp.add_window_rule(MatchType.title, "Terminal", ActionType.set_position);
    std.debug.assert(comp.get_rule_count() == 1);
}

test "window rules constants" {
    std.debug.assert(grain_os.window_rules.MAX_RULES == 64);
    std.debug.assert(grain_os.window_rules.MAX_PATTERN_LEN == 256);
}

