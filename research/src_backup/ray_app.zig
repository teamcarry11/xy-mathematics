const std = @import("std");
const ray = @import("ray");
const RayEnvelope = ray.RayEnvelope;
const RayTraining = ray.RayTraining;

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var training = RayTraining.init();

    try print_stage(stdout, "Baseline (air)", training.current_envelope());

    const with_water = training.rebuild(.water);
    try print_stage(stdout, "After water training", with_water);

    const back_to_air = training.rollback();
    try print_stage(stdout, "Rollback (forget water)", back_to_air);

    const first_earth = training.rebuild(.earth);
    try print_stage(stdout, "First earth training", first_earth);

    const forgot_earth = training.rollback();
    try print_stage(stdout, "Rollback (forget earth)", forgot_earth);

    const relearned = training.rebuild(.earth);
    try stdout.print("=== Relearned Earth — full envelope ===\n", .{});
    try struct_dump(stdout, relearned);
}

fn print_stage(
    writer: *std.io.Writer,
    label: []const u8,
    env: RayEnvelope,
) !void {
    try writer.print("=== {s} ===\n{s}\n\n", .{ label, env.lead[1].body });
}

fn struct_dump(writer: *std.io.Writer, env: RayEnvelope) !void {
    try writer.print("[2 | 1 | 1] Ray Envelope — Emo Tahoe Edition\n", .{});
    inline for (env.lead, 0..) |module, index| {
        try writer.print("Lead[{d}] — {s}\n{s}\n\n", .{ index, module.title, module.body });
    }
    try writer.print("Core — {s}\n{s}\n\n", .{ env.core.title, env.core.body });
    try writer.print("Tail — {s}\n{s}\n", .{ env.tail.title, env.tail.body });
    try writer.print(
        "\nTimestamp Registry ({d} entries)\n",
        .{env.timestamp_db.len},
    );
    for (env.timestamp_db, 0..) |entry, idx| {
        try writer.print(
            "T[{d}] ({s}) {s}\n",
            .{ idx, entry.grammar.name, entry.raw },
        );
    }
}
