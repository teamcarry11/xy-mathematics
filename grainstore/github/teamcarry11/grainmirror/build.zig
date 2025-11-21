const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the grainmirror module
    const mirror_mod = b.addModule("grainmirror", .{
        .root_source_file = b.path("src/grainmirror.zig"),
    });

    // Create CLI executable
    const exe = b.addExecutable(.{
        .name = "grainmirror",
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Create run step for CLI
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run grainmirror CLI");
    run_step.dependOn(&run_cmd.step);

    // Create test executable
    const tests = b.addTest(.{
        .root_source_file = b.path("src/grainmirror.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    _ = mirror_mod;
}

