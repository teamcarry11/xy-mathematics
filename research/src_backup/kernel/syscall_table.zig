const std = @import("std");

pub const Syscall = struct {
    number: u16,
    name: []const u8,
    description: []const u8,
};

pub const table = [_]Syscall{
    .{ .number = 0, .name = "debug_write", .description = "Writes bytes to the kernel debug console." },
    .{ .number = 1, .name = "exit", .description = "Terminates the calling task with a status code." },
};

pub fn describe(number: u16) ?Syscall {
    for (table) |entry| {
        if (entry.number == number) return entry;
    }
    return null;
}
