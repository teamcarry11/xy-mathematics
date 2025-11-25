//! Tests for Grain OS tiling configuration system.
//!
//! Why: Verify tiling configuration functionality and settings management.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const TilingConfig = grain_os.tiling_config.TilingConfig;
const LayoutType = grain_os.layout_generator.LayoutType;

test "tiling config initialization" {
    const config = TilingConfig.init();
    std.debug.assert(config.window_gap == grain_os.tiling_config.DEFAULT_WINDOW_GAP);
    std.debug.assert(config.split_ratio == grain_os.tiling_config.DEFAULT_SPLIT_RATIO);
    std.debug.assert(config.default_layout == LayoutType.tall);
    std.debug.assert(config.auto_tile == true);
    std.debug.assert(config.smart_gaps == false);
}

test "set and get window gap" {
    var config = TilingConfig.init();
    config.set_window_gap(8);
    std.debug.assert(config.get_window_gap() == 8);
    config.set_window_gap(2);
    std.debug.assert(config.get_window_gap() == 2);
}

test "set and get split ratio" {
    var config = TilingConfig.init();
    config.set_split_ratio(0.6);
    std.debug.assert(config.get_split_ratio() == 0.6);
    config.set_split_ratio(0.3);
    std.debug.assert(config.get_split_ratio() == 0.3);
}

test "set and get default layout" {
    var config = TilingConfig.init();
    config.set_default_layout(LayoutType.grid);
    std.debug.assert(config.get_default_layout() == LayoutType.grid);
    config.set_default_layout(LayoutType.wide);
    std.debug.assert(config.get_default_layout() == LayoutType.wide);
}

test "set and get auto-tile" {
    var config = TilingConfig.init();
    config.set_auto_tile(false);
    std.debug.assert(config.get_auto_tile() == false);
    config.set_auto_tile(true);
    std.debug.assert(config.get_auto_tile() == true);
}

test "set and get smart gaps" {
    var config = TilingConfig.init();
    config.set_smart_gaps(true);
    std.debug.assert(config.get_smart_gaps() == true);
    config.set_smart_gaps(false);
    std.debug.assert(config.get_smart_gaps() == false);
}

test "clamp split ratio" {
    const ratio_low = grain_os.tiling_config.clamp_split_ratio(0.05);
    std.debug.assert(ratio_low == grain_os.tiling_config.MIN_SPLIT_RATIO);
    const ratio_high = grain_os.tiling_config.clamp_split_ratio(0.95);
    std.debug.assert(ratio_high == grain_os.tiling_config.MAX_SPLIT_RATIO);
    const ratio_valid = grain_os.tiling_config.clamp_split_ratio(0.5);
    std.debug.assert(ratio_valid == 0.5);
}

test "calc effective gap" {
    var config = TilingConfig.init();
    config.set_smart_gaps(false);
    std.debug.assert(config.calc_effective_gap(1) == config.window_gap);
    std.debug.assert(config.calc_effective_gap(2) == config.window_gap);
    config.set_smart_gaps(true);
    std.debug.assert(config.calc_effective_gap(1) == 0);
    std.debug.assert(config.calc_effective_gap(2) == config.window_gap);
}

test "compositor tiling config" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    comp.set_window_gap(6);
    std.debug.assert(comp.get_window_gap() == 6);
    comp.set_split_ratio(0.7);
    std.debug.assert(comp.get_split_ratio() == 0.7);
    comp.set_default_layout(LayoutType.grid);
    std.debug.assert(comp.get_default_layout() == LayoutType.grid);
}

test "tiling config constants" {
    std.debug.assert(grain_os.tiling_config.DEFAULT_WINDOW_GAP == 4);
    std.debug.assert(grain_os.tiling_config.DEFAULT_SPLIT_RATIO == 0.5);
    std.debug.assert(grain_os.tiling_config.MIN_SPLIT_RATIO == 0.1);
    std.debug.assert(grain_os.tiling_config.MAX_SPLIT_RATIO == 0.9);
}

