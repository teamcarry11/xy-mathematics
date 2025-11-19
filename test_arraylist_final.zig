const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var list: std.ArrayList(u8) = .{
        .items = &.{},
        .capacity = 0,
    };
    defer list.deinit(allocator);
    
    try list.append(allocator, 'a');
    try list.append(allocator, 'b');
    std.debug.print("Success! List: {s}\n", .{list.items});
}
