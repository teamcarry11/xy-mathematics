const std = @import("std");
const GrainStore = @import("../src/grain_store.zig").GrainStore;

const usage =
    \\Grain Conductor — orchestrate brew sync, linking, and workspace helpers.
    \\
    \\Usage:
    \\  grain conduct brew [--assume-yes]
    \\  grain conduct link
    \\  grain conduct edit
    \\  grain conduct make
    \\  grain conduct help
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // executable name
    var subcommand = args.next() orelse {
        try std.io.getStdOut().writeAll(usage);
        return;
    };

    if (std.mem.eql(u8, subcommand, "conduct")) {
        subcommand = args.next() orelse {
            try std.io.getStdOut().writeAll(usage);
            return;
        };
    }

    if (std.mem.eql(u8, subcommand, "brew")) {
        var assume_yes = false;
        while (args.next()) |flag| {
            if (std.mem.eql(u8, flag, "--assume-yes")) {
                assume_yes = true;
            } else {
                try std.io.getStdErr().writer().print("unknown flag: {s}\n", .{flag});
                return error.UnknownFlag;
            }
        }
        try run_brew(assume_yes);
    } else if (std.mem.eql(u8, subcommand, "link")) {
        try run_link(allocator);
    } else if (std.mem.eql(u8, subcommand, "edit")) {
        try run_edit();
    } else if (std.mem.eql(u8, subcommand, "make")) {
        try run_make();
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try std.io.getStdOut().writeAll(usage);
    } else {
        try std.io.getStdErr().writer().print("unknown command: {s}\n", .{subcommand});
        try std.io.getStdOut().writeAll(usage);
        return error.UnknownSubcommand;
    }
}

fn prompt_confirm(message: []const u8) !bool {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    try stdout.writer().print("{s} [y/N]: ", .{message});
    var buf: [4]u8 = undefined;
    const read = try stdin.reader().read(&buf);
    if (read == 0) return false;
    const trimmed = std.mem.trim(u8, buf[0..read], " \t\r\n");
    return trimmed.len > 0 and (trimmed[0] == 'y' or trimmed[0] == 'Y');
}

fn run_brew(assume_yes: bool) !void {
    const brewfile = "Brewfile";
    if (!assume_yes) {
        const ok = try prompt_confirm("Run brew bundle with Brewfile");
        if (!ok) return;
    }

    try spawn_and_log(.{ "brew", "bundle", "install", "--cleanup", "--file", brewfile });
    try spawn_and_log(.{ "brew", "upgrade", "--cask" });
}

fn run_link(allocator: std.mem.Allocator) !void {
    var store = try GrainStore.init(allocator, "@kae3g");
    defer store.deinit();

    const platforms = [_][]const u8{ "codeberg", "github", "gitab" };
    try store.ensure_platforms(&platforms);

    try std.io.getStdOut().writeAll("grainstore platforms ensured.\n");
}

fn run_edit() !void {
    const commands = [_][]const u8{ "cursor", "code" };
    const project_path = ".";

    for (commands) |cmd_name| {
        const result = spawn_process(.{ cmd_name, project_path }) catch continue;
        if (result == 0) return;
    }

    try std.io.getStdErr().writeAll("Failed to launch editor (cursor/code).\n");
}

fn run_make() !void {
    try std.io.getStdOut().writeAll("`grain conduct make` is a placeholder for future tool builds.\n");
}

fn spawn_and_log(argv: []const []const u8) !void {
    var process = std.ChildProcess.init(argv, std.heap.c_allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Inherit;
    process.stderr_behavior = .Inherit;
    defer process.deinit();

    try process.spawn();
    const status = try process.wait();
    if (status != 0) {
        return error.SubprocessFailed;
    }
}

fn spawn_process(argv: []const []const u8) !u8 {
    var process = std.ChildProcess.init(argv, std.heap.c_allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Inherit;
    process.stderr_behavior = .Inherit;
    defer process.deinit();
    try process.spawn();
    return try process.wait();
}
