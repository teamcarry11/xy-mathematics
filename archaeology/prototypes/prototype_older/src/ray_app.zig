const std = @import("std");
const RayEnvelope = @import("ray.zig").RayEnvelope;

pub fn main() !void {
    const env = RayEnvelope.init();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);

    const stdout = &stdout_writer.interface;
    try structDump(stdout, env);
    try stdout.flush();
}

fn structDump(writer: *std.io.Writer, env: RayEnvelope) !void {
    try writer.print("[2 | 1 | 1] Ray Envelope\n", .{});
    inline for (env.lead, 0..) |module, index| {
        try writer.print("Lead[{d}] — {s}\n{s}\n\n", .{ index, module.title, module.body });
    }
    try writer.print("Core — {s}\n{s}\n\n", .{ env.core.title, env.core.body });
    try writer.print("Tail — {s}\n{s}\n", .{ env.tail.title, env.tail.body });
    try writer.print(
        "\nTimestamp Registry ({d} entries)\n",
        .{ env.timestamp_db.len },
    );
    for (env.timestamp_db, 0..) |entry, idx| {
        try writer.print(
            "T[{d}] ({s}) {s}\n",
            .{ idx, entry.grammar.name, entry.raw },
        );
    }
}
