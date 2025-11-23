const std = @import("std");

// Import grainorder from the grainstore
const Grainorder = @import("grainstore/github/teamcarry11/grainorder/src/core.zig").Grainorder;

pub fn main() !void {
    const current_str = "zyxsqn";
    const current = try Grainorder.from_string(current_str);
    
    if (current.prev()) |next| {
        // Grainorder has chars array, convert to string
        var buf: [6]u8 = undefined;
        @memcpy(&buf, &next.chars);
        std.debug.print("{s}\n", .{&buf});
    } else {
        std.debug.print("error: cannot get prev (already at smallest)\n", .{});
    }
}
