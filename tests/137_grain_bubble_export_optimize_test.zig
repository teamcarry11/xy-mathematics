//! Grain Bubble Export Optimization Tests.
//!
//! Why: Test export optimization for minification and compression.
//! Architecture: Unit tests for export optimization.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-19-191440-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const export_optimize = @import("grain_bubble").export_optimize;

test "export optimizer init" {
    const optimizer = export_optimize.ExportOptimizer.init();
    std.debug.assert(optimizer.minify_html == true);
    std.debug.assert(optimizer.minify_css == true);
    std.debug.assert(optimizer.compress == false);
}

test "export optimizer set options" {
    var optimizer = export_optimize.ExportOptimizer.init();
    optimizer.set_options(false, false, true);
    std.debug.assert(optimizer.minify_html == false);
    std.debug.assert(optimizer.minify_css == false);
    std.debug.assert(optimizer.compress == true);
}

test "export optimizer minify html" {
    var optimizer = export_optimize.ExportOptimizer.init();
    const input = "  <div>  \n  Hello  \n  World  \n  </div>  ";
    var output: [256]u8 = undefined;
    const len = optimizer.minify_html_content(input, output[0..]);
    std.debug.assert(len > 0);
    std.debug.assert(len < input.len);
}

test "export optimizer minify css" {
    var optimizer = export_optimize.ExportOptimizer.init();
    const input = "  .class  {  \n  color: red;  \n  }  ";
    var output: [256]u8 = undefined;
    const len = optimizer.minify_css_content(input, output[0..]);
    std.debug.assert(len > 0);
    std.debug.assert(len < input.len);
}

test "export optimizer calculate compression ratio" {
    var optimizer = export_optimize.ExportOptimizer.init();
    const original: u32 = 1000;
    const optimized: u32 = 750;
    const ratio = optimizer.calculate_compression_ratio(original, optimized);
    std.debug.assert(ratio > 0.0);
    std.debug.assert(ratio < 1.0);
    std.debug.assert(ratio == 0.75);
}

