// mixed file with some lines that fit and some that don't
const std = @import("std");

pub fn main() !void {
    // this line fits
    const short = "ok";
    
    // this line is way too long and exceeds the 73 character limit by many characters
    const long_line = "this is a very long string that definitely exceeds seventy three characters and needs to be wrapped";
    
    // this fits
    const x = 42;
    
    // this is also too long with a complex expression that goes over the limit
    const result = try std.fmt.allocPrint(std.heap.page_allocator, "format: {s} {d}", .{"test", 99});
    
    // short line
    std.debug.print("ok\n", .{});
}

