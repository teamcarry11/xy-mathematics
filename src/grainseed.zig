const std = @import("std");

// ╔═══════════════════════════════════════════════════════════════╗
// ║  G R A I N S E E D   v1.0                                     ║
// ║  "Plant a seed. Watch it grow. That's it. That's the program."║
// ╚═══════════════════════════════════════════════════════════════╝

const Stalk = struct {
    height: u8,
    lean: i8,
    seed: u64,
    rng: std.Random.DefaultPrng,

    fn init(seed: u64) Stalk {
        return Stalk{
            .height = 0,
            .lean = 0,
            .seed = seed,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    fn grow(self: *Stalk) void {
        const random = self.rng.random();
        self.height = random.intRangeAtMost(u8, 5, 15);
        
        std.debug.print("\n", .{});
        std.debug.print("      . \n", .{});
        std.debug.print("    \\ | / \n", .{});
        std.debug.print("   --(@)-- \n", .{});
        std.debug.print("    / | \\ \n", .{});
        std.debug.print("      | \n", .{});

        var i: u8 = 0;
        while (i < self.height) : (i += 1) {
            const sway = random.intRangeAtMost(i8, -1, 1);
            self.lean += sway;
            
            if (self.lean < -2) self.lean = -2;
            if (self.lean > 2) self.lean = 2;

            self.printSegment(i);
        }
        
        std.debug.print("    ~~~~~ \n", .{});
        std.debug.print("\n", .{});
    }

    fn printSegment(self: *Stalk, height_idx: u8) void {
        const random = self.rng.random();
        
        var indent: usize = 6;
        if (self.lean < 0) indent -= @intCast(@abs(self.lean));
        if (self.lean > 0) indent += @intCast(@abs(self.lean));

        var j: usize = 0;
        while (j < indent) : (j += 1) std.debug.print(" ", .{});

        const has_leaf_left = random.boolean() and height_idx % 3 == 0;
        const has_leaf_right = !has_leaf_left and random.boolean() and height_idx % 3 == 0;

        if (has_leaf_left) std.debug.print("(", .{});
        std.debug.print("|", .{});
        if (has_leaf_right) std.debug.print(")", .{});
        
        std.debug.print("\n", .{});
    }
};

pub fn main() !void {
    var seed: u64 = 12025; 
    
    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |arg| {
        seed = std.fmt.parseInt(u64, arg, 10) catch 12025;
    }

    std.debug.print("\n", .{});
    std.debug.print("┌─────────────────────────────────────────────┐\n", .{});
    std.debug.print("│ GRAINSEED SIMULATOR 1997                    │\n", .{});
    std.debug.print("│ (c) teamcarry11 - All Rights Reserved       │\n", .{});
    std.debug.print("│                                             │\n", .{});
    std.debug.print("│ Press ENTER to plant seed #{d: <15}│\n", .{seed});
    std.debug.print("└─────────────────────────────────────────────┘\n", .{});
    std.debug.print("\n", .{});
    std.debug.print(">>> Initializing soil matrix...\n", .{});
    std.debug.print(">>> Calculating photosynthesis coefficients...\n", .{});
    std.debug.print(">>> Planting...\n", .{});

    var stalk = Stalk.init(seed);
    stalk.grow();
    
    std.debug.print(">>> Growth complete!\n", .{});
    std.debug.print(">>> Thank you for using GRAINSEED v1.0\n", .{});
    std.debug.print("\n", .{});
}
