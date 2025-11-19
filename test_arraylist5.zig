const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Try the struct literal approach
    var list: std.ArrayList(u8) = .{
        .items = &.{},
        .capacity = 0,
        .allocator = allocator,
    };
    defer list.deinit();
    
    try list.append('a');
    std.debug.print("Success! List: {any}\n", .{list.items});
}
