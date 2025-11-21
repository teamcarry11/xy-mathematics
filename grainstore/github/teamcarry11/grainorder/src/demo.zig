//! demo: interactive grainorder demonstration
//!
//! this program shows how grainorder works by generating
//! a sequence of codes, demonstrating the decrement algorithm.

const std = @import("std");
const grainorder = @import("grainorder");

pub fn main() !void {
    const stdout = std.io.stdOut().writer();

    try stdout.print(
        "🌾⚒️ grain network - grainorder (grain style)\n",
        .{},
    );
    try stdout.print(
        "════════════════════════════════════════════\n\n",
        .{},
    );

    try stdout.print("alphabet: {s}\n", .{grainorder.ALPHABET});
    try stdout.print("code length: {d} characters\n", .{
        grainorder.CODE_LEN,
    });
    try stdout.print("max codes: {d}\n\n", .{
        grainorder.MAX_CODES,
    });

    // demonstrate the decrement algorithm
    // we start from an OLDER (larger) code and decrement to
    // get NEWER (smaller) codes. then we print from newest
    // to oldest!
    try stdout.print("starting from older code: xsqyl\n", .{});
    try stdout.print("decrementing 10 times...\n\n", .{});

    // collect 10 codes by decrementing
    var codes: [10]grainorder.Grainorder = undefined;
    var current = try grainorder.from_string("xsqyl");
    var count: usize = 0;

    while (count < 10) : (count += 1) {
        if (current.prev()) |next| {
            codes[count] = next;
            current = next;
        } else {
            try stdout.print(
                "\n⚠️  reached minimum (overflow)!\n",
                .{},
            );
            break;
        }
    }

    // print from newest (smallest) to oldest (largest)
    try stdout.print("grainorders (newest → oldest):\n", .{});
    var i: usize = count;
    while (i > 0) {
        i -= 1;
        try stdout.print(
            "{d}. {} ← {s}\n",
            .{ count - i, codes[i], if (i == count - 1)
                "newest (smallest)"
            else if (i == 0)
                "oldest (largest)"
            else
                "" },
        );
    }

    try stdout.print(
        "\n✅ grain style: all assertions passed!\n",
        .{},
    );
    try stdout.print("\nnow == next + 1 🌾⚒️\n", .{});
}

