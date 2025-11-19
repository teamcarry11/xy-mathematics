const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const ListType = std.ArrayList(u8);
    var list = ListType.init(allocator);
    defer list.deinit();
    
    try list.append('a');
    std.debug.print("Success! List: {any}\n", .{list.items});
}
