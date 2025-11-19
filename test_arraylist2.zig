const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const ArrayListType = std.ArrayList(u8);
    var list: ArrayListType = .{ .items = &.{}, .capacity = 0, .allocator = allocator };
    defer list.deinit();
    
    try list.append('a');
    std.debug.print("Success!\n", .{});
}
