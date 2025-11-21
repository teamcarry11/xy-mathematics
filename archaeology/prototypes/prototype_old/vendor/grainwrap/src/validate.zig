//! validate: line length validation
//!
//! How do we check if code follows grain style constraints? This
//! module validates line lengths and reports violations.

const std = @import("std");
const types = @import("types.zig");

// Validate code against maximum line width.
//
// Takes source code and max width, returns a list of violations.
// Each violation includes line number, actual length, and content.
//
// Why return a heap-allocated result? Violations can be numerous.
// We need to allocate space for them. The caller is responsible
// for freeing the memory.
pub fn validate(
    allocator: std.mem.Allocator,
    code: []const u8,
    max_width: usize,
) !types.ValidationResult {
    var violations = std.ArrayList(types.Violation){};
    try violations.ensureTotalCapacity(allocator, 16);
    errdefer violations.deinit(allocator);

    var line_iter = std.mem.splitScalar(u8, code, '\n');
    var line_number: usize = 1;

    while (line_iter.next()) |line| {
        const trimmed = std.mem.trimRight(
            u8,
            line,
            &std.ascii.whitespace,
        );
        const length = trimmed.len;

        if (length > max_width) {
            try violations.append(allocator, .{
                .line_number = line_number,
                .length = length,
                .content = line,
            });
        }

        line_number += 1;
    }

    const violations_slice = try violations.toOwnedSlice(allocator);

    return types.ValidationResult{
        .violations = violations_slice,
        .total_lines = line_number - 1,
        .compliant = violations_slice.len == 0,
    };
}

// Free validation result and its violations.
//
// Why a separate free function? It makes memory management explicit.
// Callers know they need to free the result when done.
pub fn free_result(
    allocator: std.mem.Allocator,
    result: types.ValidationResult,
) void {
    allocator.free(result.violations);
}

