const std = @import("std");
const graincard = @import("graincard.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try show_help();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "create")) {
        if (args.len < 5) {
            std.debug.print("error: missing arguments\n", .{});
            std.debug.print("usage: graincard create <grainorder> <title> <content>\n", .{});
            return;
        }

        const grainorder = args[2];
        const title = args[3];
        const content = args[4];

        std.debug.assert(grainorder.len == 6);
        std.debug.assert(title.len > 0);
        std.debug.assert(content.len > 0);

        const card = graincard.GrainCard{
            .grainorder = grainorder,
            .title = title,
            .content = content,
            .file_path = try std.fmt.allocPrint(allocator, "{s}-graincard.md", .{grainorder}),
            .live_url = "https://github.com/teamcarry11/graincard",
            .card_num = 1,
            .total_cards = 1_235_520,
            .author = "kae3g (kj3x39, @risc.love)",
            .grainbook_name = "ember harvest",
        };

        const filename = try std.fmt.allocPrint(allocator, "{s}-graincard.md", .{grainorder});
        defer allocator.free(filename);

        const success = try graincard.save_graincard(allocator, &card, filename);
        if (success) {
            std.debug.print("graincard saved successfully!\n", .{});
        }
    } else if (std.mem.eql(u8, command, "validate")) {
        if (args.len < 3) {
            std.debug.print("error: missing filename\n", .{});
            std.debug.print("usage: graincard validate <file>\n", .{});
            return;
        }

        const filename = args[2];
        const file_contents = try std.fs.cwd().readFileAlloc(allocator, filename, 1024 * 1024);
        defer allocator.free(file_contents);

        const validation = try graincard.validate_graincard(allocator, file_contents);
        defer {
            switch (validation) {
                .ok => {},
                .err => |errs| {
                    for (errs) |err| {
                        allocator.free(err);
                    }
                    allocator.free(errs);
                },
            }
        }

        switch (validation) {
            .ok => |msg| {
                std.debug.print("VALID graincard: {s}\n", .{msg});
            },
            .err => |errs| {
                std.debug.print("INVALID graincard:\n", .{});
                for (errs) |err| {
                    std.debug.print("  {s}\n", .{err});
                }
            },
        }
    } else if (std.mem.eql(u8, command, "help")) {
        try show_help();
    } else {
        std.debug.print("unknown command: {s}\n", .{command});
        std.debug.print("run 'graincard help' for usage\n", .{});
    }
}

fn show_help() !void {
    const help_text =
        \\graincard - 75x100 monospace teaching cards
        \\
        \\usage:
        \\  graincard create <grainorder> <title> <content>
        \\  graincard validate <file>
        \\  graincard help
        \\
        \\examples:
        \\  graincard create xbdghj "intro to graintime" "content here..."
        \\  graincard validate xbdghj-graincard.md
        \\
        \\what it does:
        \\  - wraps content to 73 chars (preserves words)
        \\  - generates 75x100 ASCII box with borders
        \\  - adds grainorder, card number, metadata footer
        \\  - validates against spec before saving
        \\  - enforces ASCII-only (no unicode/emojis)
        \\
        \\graincard format:
        \\  - 75 characters wide
        \\  - 100 lines tall
        \\  - ASCII box-drawing characters (+-|)
        \\  - grainorder unique ID (6 chars)
        \\  - part of a grainbook (collection of cards)
        \\
    ;
    std.debug.print("{s}", .{help_text});
}

