//! Grain OS Window Rules: Automatic window configuration based on properties.
//!
//! Why: Allow windows to be automatically configured based on title, class, etc.
//! Architecture: Rule matching and application system.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

const std = @import("std");
const compositor = @import("compositor.zig");
const window_constraints = @import("window_constraints.zig");

// Bounded: Max window rules.
pub const MAX_RULES: u32 = 64;

// Bounded: Max rule pattern length.
pub const MAX_PATTERN_LEN: u32 = 256;

// Rule match type.
pub const MatchType = enum(u8) {
    title,
    class,
    instance,
};

// Rule action type.
pub const ActionType = enum(u8) {
    none,
    set_position,
    set_size,
    set_workspace,
    set_opacity,
    set_constraints,
    set_floating,
    set_tiled,
};

// Window rule: matches windows and applies actions.
pub const WindowRule = struct {
    rule_id: u32,
    match_type: MatchType,
    pattern: [MAX_PATTERN_LEN]u8,
    pattern_len: u32,
    action_type: ActionType,
    action_value_x: i32,
    action_value_y: i32,
    action_value_width: u32,
    action_value_height: u32,
    action_value_u32: u32,
    action_value_u8: u8,
    active: bool,
};

// Window rule manager: manages window rules.
pub const WindowRuleManager = struct {
    rules: [MAX_RULES]WindowRule,
    rules_len: u32,
    next_rule_id: u32,

    pub fn init() WindowRuleManager {
        var manager = WindowRuleManager{
            .rules = undefined,
            .rules_len = 0,
            .next_rule_id = 1,
        };
        var i: u32 = 0;
        while (i < MAX_RULES) : (i += 1) {
            manager.rules[i] = WindowRule{
                .rule_id = 0,
                .match_type = MatchType.title,
                .pattern = undefined,
                .pattern_len = 0,
                .action_type = ActionType.none,
                .action_value_x = 0,
                .action_value_y = 0,
                .action_value_width = 0,
                .action_value_height = 0,
                .action_value_u32 = 0,
                .action_value_u8 = 0,
                .active = false,
            };
            var j: u32 = 0;
            while (j < MAX_PATTERN_LEN) : (j += 1) {
                manager.rules[i].pattern[j] = 0;
            }
        }
        return manager;
    }

    // Add window rule.
    pub fn add_rule(
        self: *WindowRuleManager,
        match_type: MatchType,
        pattern: []const u8,
        action_type: ActionType,
    ) ?u32 {
        if (self.rules_len >= MAX_RULES) {
            return null;
        }
        if (pattern.len > MAX_PATTERN_LEN) {
            return null;
        }
        const rule_id = self.next_rule_id;
        self.next_rule_id += 1;
        var rule = WindowRule{
            .rule_id = rule_id,
            .match_type = match_type,
            .pattern = undefined,
            .pattern_len = 0,
            .action_type = action_type,
            .action_value_x = 0,
            .action_value_y = 0,
            .action_value_width = 0,
            .action_value_height = 0,
            .action_value_u32 = 0,
            .action_value_u8 = 0,
            .active = true,
        };
        var i: u32 = 0;
        while (i < MAX_PATTERN_LEN) : (i += 1) {
            rule.pattern[i] = 0;
        }
        const copy_len = @min(pattern.len, MAX_PATTERN_LEN);
        i = 0;
        while (i < copy_len) : (i += 1) {
            rule.pattern[i] = pattern[i];
        }
        rule.pattern_len = @intCast(copy_len);
        self.rules[self.rules_len] = rule;
        self.rules_len += 1;
        return rule_id;
    }

    // Match window against rules.
    pub fn match_window(
        self: *const WindowRuleManager,
        window_title: []const u8,
    ) ?*const WindowRule {
        var i: u32 = 0;
        while (i < self.rules_len) : (i += 1) {
            const rule = &self.rules[i];
            if (!rule.active) {
                continue;
            }
            if (rule.match_type == MatchType.title) {
                if (self.match_pattern(window_title, rule.pattern[0..rule.pattern_len])) {
                    return rule;
                }
            }
        }
        return null;
    }

    // Match pattern against text (simple substring match).
    fn match_pattern(
        _self: *const WindowRuleManager,
        text: []const u8,
        pattern: []const u8,
    ) bool {
        _ = _self;
        if (pattern.len == 0) {
            return false;
        }
        if (pattern.len > text.len) {
            return false;
        }
        var i: u32 = 0;
        while (i <= text.len - pattern.len) : (i += 1) {
            var match: bool = true;
            var j: u32 = 0;
            while (j < pattern.len) : (j += 1) {
                if (text[i + j] != pattern[j]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                return true;
            }
        }
        return false;
    }

    // Remove window rule.
    pub fn remove_rule(self: *WindowRuleManager, rule_id: u32) bool {
        std.debug.assert(rule_id > 0);
        var i: u32 = 0;
        var found: bool = false;
        while (i < self.rules_len) : (i += 1) {
            if (self.rules[i].rule_id == rule_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
        // Shift remaining rules left.
        while (i < self.rules_len - 1) : (i += 1) {
            self.rules[i] = self.rules[i + 1];
        }
        self.rules_len -= 1;
        return true;
    }

    // Clear all rules.
    pub fn clear_all(self: *WindowRuleManager) void {
        self.rules_len = 0;
    }

    // Get rule count.
    pub fn get_rule_count(self: *const WindowRuleManager) u32 {
        return self.rules_len;
    }
};

