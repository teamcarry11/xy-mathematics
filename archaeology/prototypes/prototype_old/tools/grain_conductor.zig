const std = @import("std");
const GrainStore = @import("../src/grain_store.zig").GrainStore;

const usage =
    \\Grain Conductor — orchestrate brew sync, linking, and workspace helpers.
    \\
    \\Usage:
    \\  grain conduct brew [--assume-yes]
    \\  grain conduct link [--manifest=path.json]
    \\  grain conduct manifest
    \\  grain conduct mmt [--npub=hex --title=name --emit-raw --mint=amount --burn=amount]
    \\  grain conduct cdn [--npub=hex --tier=basic|pro|premier|ultra --start=unix --seats=count --autopay --emit-raw]
    \\  grain conduct ai [--tool=cursor|claude --arg=\"...\"]
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
        var manifest_path: ?[]const u8 = null;
        while (args.next()) |flag| {
            if (std.mem.startsWith(u8, flag, "--manifest=")) {
                manifest_path = flag["--manifest=".len..];
            } else {
                try std.io.getStdErr().writer().print(
                    "unknown flag: {s}\n",
                    .{flag},
                );
                return error.UnknownFlag;
            }
        }
        try run_link(allocator, manifest_path);
    } else if (std.mem.eql(u8, subcommand, "edit")) {
        try run_edit();
    } else if (std.mem.eql(u8, subcommand, "manifest")) {
        try run_manifest();
    } else if (std.mem.eql(u8, subcommand, "mmt")) {
        try run_mmt(allocator, &args);
    } else if (std.mem.eql(u8, subcommand, "cdn")) {
        try run_cdn(allocator, &args);
    } else if (std.mem.eql(u8, subcommand, "make")) {
        try run_make();
    } else if (std.mem.eql(u8, subcommand, "ai")) {
        try run_ai(allocator, &args);
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

fn run_link(
    allocator: std.mem.Allocator,
    manifest_path: ?[]const u8,
) !void {
    const manifest_entries = @import("../src/grain_manifest.zig").entries;

    var store = try GrainStore.init(allocator, "@kae3g");
    defer store.deinit();

    const platforms = [_][]const u8{ "codeberg", "github", "gitab" };
    try store.ensure_platforms(&platforms);

    if (manifest_path) |path| {
        try std.io.getStdOut().writer().print(
            "manifest flag ignored in static build: {s}\n",
            .{path},
        );
    }

    try store.sync_manifest_entries(&manifest_entries);

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
    const commands = [_][]const []const u8{
        &.{ "zig", "build", "test" },
        &.{ "zig", "build", "wrap-docs" },
        &.{ "zig", "build", "validate" },
        &.{ "zig", "build", "thread" },
    };

    for (commands) |cmd| {
        try spawn_and_log(cmd);
    }

    try std.io.getStdOut().writeAll("build automation finished.\n");
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

fn file_exists(path: []const u8) bool {
    return std.fs.cwd().access(path, .{}) catch false;
}

fn run_manifest() !void {
    const entries = @import("../src/grain_manifest.zig").entries;
    var stdout = std.io.getStdOut().writer();
    try stdout.print("GrainStore static manifest ({d} entries)\n", .{entries.len});
    for (entries, 0..) |entry, idx| {
        try stdout.print(
            "  [{d}] {s}/{s}/{s}\n",
            .{ idx, entry.platform, entry.org, entry.repo },
        );
    }
}

fn run_mmt(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    const MMTPayload = @import("../src/nostr_mmt.zig");
    const TigerBank = @import("../src/tigerbank_client.zig");

    var npub_hex: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    var emit_raw = false;
    var action: MMTPayload.Action = .{ .mint = 0 };
    var policy = MMTPayload.Policy{ .base_rate_bps = 0, .tax_rate_bps = 0 };
    var cluster_storage: [8]TigerBank.ClusterEndpoint = undefined;
    var cluster_len: usize = 0;
    var relay_storage: [8]TigerBank.RelayEndpoint = undefined;
    var relay_len: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--npub=")) {
            npub_hex = arg["--npub=".len..];
        } else if (std.mem.startsWith(u8, arg, "--title=")) {
            title = arg["--title=".len..];
        } else if (std.mem.startsWith(u8, arg, "--mint=")) {
            action = .{ .mint = try parseU128(arg["--mint=".len..]) };
        } else if (std.mem.startsWith(u8, arg, "--burn=")) {
            action = .{ .burn = try parseU128(arg["--burn=".len..]) };
        } else if (std.mem.eql(u8, arg, "--emit-raw")) {
            emit_raw = true;
        } else if (std.mem.startsWith(u8, arg, "--base-rate=")) {
            policy.base_rate_bps = try parseI32(arg["--base-rate=".len..]);
        } else if (std.mem.startsWith(u8, arg, "--tax-rate=")) {
            policy.tax_rate_bps = try parseI32(arg["--tax-rate=".len..]);
        } else if (std.mem.startsWith(u8, arg, "--cluster=")) {
            const endpoint_slice = arg["--cluster=".len..];
            const sep = std.mem.indexOfScalar(u8, endpoint_slice, ':') orelse return error.InvalidClusterFormat;
            const port_slice = endpoint_slice[sep + 1 ..];
            const port = try std.fmt.parseInt(u16, port_slice, 10);
            if (cluster_len >= cluster_storage.len) return error.TooManyClusterEndpoints;
            cluster_storage[cluster_len] = .{
                .host = endpoint_slice[0..sep],
                .port = port,
            };
            cluster_len += 1;
        } else if (std.mem.startsWith(u8, arg, "--relay=")) {
            if (relay_len >= relay_storage.len) return error.TooManyRelays;
            relay_storage[relay_len] = .{ .url = arg["--relay=".len..] };
            relay_len += 1;
        } else {
            return error.UnknownFlag;
        }
    }

    if (npub_hex == null or title == null) {
        try std.io.getStdOut().writeAll("Interactive MMT mode coming soon. Provide --npub and --title for non-interactive usage.\n");
        return;
    }

    var npub = try parseNpubHex(npub_hex.?);
    defer allocator.free(npub);

    var payload = MMTPayload.MMTCurrencyPayload{
        .npub = npub[0..32].*,
        .title = title.?,
        .policy = policy,
        .action = action,
    };

    var buffer: [MMTPayload.MMTCurrencyPayload.max_encoded_len]u8 = undefined;
    const encoded = try payload.encode(&buffer);

    if (emit_raw) {
        try std.io.getStdOut().writer().print("raw bytes ({d}): {x}\n", .{ encoded.len, encoded });
    } else {
        const client = TigerBank.Client.init(allocator, cluster_storage[0..cluster_len], relay_storage[0..relay_len]);
        var client_copy = client;
        const submit_result = client_copy.submitTigerBeetle(encoded);
        if (submit_result) |_| {} else |err| {
            if (err == error.NoClusterEndpoints) {
                try std.io.getStdOut().writeAll("TigerBank: no cluster endpoints; skipped TigerBeetle submission.\n");
            } else {
                return err;
            }
        }
        try client_copy.broadcastRelays(encoded);
        try std.io.getStdOut().writeAll("TigerBank stub submission complete.\n");
    }
}

fn run_cdn(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    const TigerBank = @import("../src/tigerbank_client.zig");
    const CDN = @import("../src/tigerbank_cdn.zig");

    var npub_hex: ?[]const u8 = null;
    var tier_str: ?[]const u8 = null;
    var start_timestamp: ?u64 = null;
    var seats: u16 = 1;
    var autopay = false;
    var emit_raw = false;

    var cluster_storage: [8]TigerBank.ClusterEndpoint = undefined;
    var cluster_len: usize = 0;
    var relay_storage: [8]TigerBank.RelayEndpoint = undefined;
    var relay_len: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--npub=")) {
            npub_hex = arg["--npub=".len..];
        } else if (std.mem.startsWith(u8, arg, "--tier=")) {
            tier_str = arg["--tier=".len..];
        } else if (std.mem.startsWith(u8, arg, "--start=")) {
            start_timestamp = try std.fmt.parseInt(u64, arg["--start=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--seats=")) {
            seats = try std.fmt.parseInt(u16, arg["--seats=".len..], 10);
        } else if (std.mem.eql(u8, arg, "--autopay")) {
            autopay = true;
        } else if (std.mem.eql(u8, arg, "--emit-raw")) {
            emit_raw = true;
        } else if (std.mem.startsWith(u8, arg, "--cluster=")) {
            const endpoint_slice = arg["--cluster=".len..];
            const sep = std.mem.indexOfScalar(u8, endpoint_slice, ':') orelse return error.InvalidClusterFormat;
            const port_slice = endpoint_slice[sep + 1 ..];
            const port = try std.fmt.parseInt(u16, port_slice, 10);
            if (cluster_len >= cluster_storage.len) return error.TooManyClusterEndpoints;
            cluster_storage[cluster_len] = .{
                .host = endpoint_slice[0..sep],
                .port = port,
            };
            cluster_len += 1;
        } else if (std.mem.startsWith(u8, arg, "--relay=")) {
            if (relay_len >= relay_storage.len) return error.TooManyRelays;
            relay_storage[relay_len] = .{ .url = arg["--relay=".len..] };
            relay_len += 1;
        } else {
            return error.UnknownFlag;
        }
    }

    if (npub_hex == null or tier_str == null or start_timestamp == null) {
        try std.io.getStdOut().writeAll(
            "CDN mode requires --npub, --tier, and --start (unix timestamp).\n",
        );
        return;
    }

    var npub = try parseNpubHex(npub_hex.?);
    defer allocator.free(npub);

    const tier = try parseTier(tier_str.?);

    var request = CDN.SubscriptionRequest{
        .tier = tier,
        .subscriber_npub = npub[0..32].*,
        .start_timestamp_seconds = start_timestamp.?,
        .seats = seats,
        .autopay_enabled = autopay,
    };

    var buffer: [CDN.SubscriptionRequest.encoded_len]u8 = undefined;
    const encoded = try request.encode(&buffer);

    if (emit_raw) {
        try std.io.getStdOut().writer().print("raw bytes ({d}): {x}\n", .{ encoded.len, encoded });
        return;
    }

    const client = TigerBank.Client.init(allocator, cluster_storage[0..cluster_len], relay_storage[0..relay_len]);
    var client_copy = client;
    const submit_result = client_copy.submitTigerBeetle(encoded);
    if (submit_result) |_| {} else |err| {
        if (err == error.NoClusterEndpoints) {
            try std.io.getStdOut().writeAll("TigerBank: no cluster endpoints; skipped TigerBeetle submission.\n");
        } else {
            return err;
        }
    }
    try client_copy.broadcastRelays(encoded);
    try std.io.getStdOut().writeAll("TigerBank CDN stub submission complete.\n");
}

fn run_ai(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    const GrainVault = @import("../src/grainvault.zig");

    var tool: ?[]const u8 = null;
    var extras = std.ArrayListUnmanaged([]const u8){};
    defer extras.deinit(allocator);

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--tool=")) {
            tool = arg["--tool=".len..];
        } else if (std.mem.startsWith(u8, arg, "--arg=")) {
            try extras.append(allocator, arg["--arg=".len..]);
        } else {
            return error.UnknownFlag;
        }
    }

    if (tool == null) {
        try std.io.getStdOut().writeAll("AI mode requires --tool=cursor or --tool=claude.\n");
        return;
    }

    var vault = GrainVault.Vault.initFromEnv(allocator) catch |err| switch (err) {
        GrainVault.MissingSecret => {
            try std.io.getStdOut().writeAll(
                "GrainVault secrets missing. Mirror `{teamtreasure02}/grainvault` and export CURSOR_API_TOKEN / CLAUDE_CODE_API_TOKEN.\n",
            );
            return;
        },
        else => return err,
    };
    defer vault.deinit(allocator);

    const extras_slice = try extras.toOwnedSlice(allocator);
    defer allocator.free(extras_slice);

    var argv: []const []const u8 = switch (tool.?) {
        "cursor" => try vault.cursorCommandArgs(extras_slice, allocator),
        "claude" => try vault.claudeCommandArgs(extras_slice, allocator),
        else => {
            try std.io.getStdOut().writeAll("Unknown tool. Choose cursor or claude.\n");
            return;
        },
    };
    defer allocator.free(argv);

    try spawn_and_log(argv);
}

fn parseU128(slice: []const u8) !u128 {
    return std.fmt.parseInt(u128, slice, 10);
}

fn parseI32(slice: []const u8) !i32 {
    return std.fmt.parseInt(i32, slice, 10);
}

fn parseNpubHex(slice: []const u8) ![]u8 {
    if (slice.len != 64) {
        return error.InvalidNpubLength;
    }
    var bytes = std.heap.page_allocator.alloc(u8, 32) catch return error.OutOfMemory;
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, slice[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}

fn parseTier(raw: []const u8) !@import("../src/tigerbank_cdn.zig").Tier {
    const CDN = @import("../src/tigerbank_cdn.zig");
    if (std.mem.eql(u8, raw, "basic")) return CDN.Tier.basic;
    if (std.mem.eql(u8, raw, "pro")) return CDN.Tier.pro;
    if (std.mem.eql(u8, raw, "premier")) return CDN.Tier.premier;
    if (std.mem.eql(u8, raw, "ultra")) return CDN.Tier.ultra;
    return error.InvalidTier;
}
