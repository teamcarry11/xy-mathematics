const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ray_module = b.addModule("ray", .{
        .root_source_file = b.path("src/ray.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ray",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ray_app.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = ray_module },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the Ray envelope printer");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
