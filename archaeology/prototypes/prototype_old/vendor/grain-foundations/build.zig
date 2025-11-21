const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the grain-foundations module
    const grain_mod = b.addModule("grain-foundations", .{
        .root_source_file = b.path("src/grain-foundations.zig"),
    });

    // Create test executable
    const tests = b.addTest(.{
        .root_source_file = b.path("src/grain-foundations.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run grain-foundations tests");
    test_step.dependOn(&run_tests.step);

    _ = grain_mod;
}

