const std = @import("std");

// GRAINSEED ORDINALS COLLECTION GENERATOR
// Generates deterministic ASCII grainseeds for BTC Ordinals

const GrainseedMetadata = struct {
    seed_id: u64,
    height: u8,
    lean_direction: []const u8,
    leaf_count: u8,
    rarity_score: u8,
};

const Stalk = struct {
    height: u8,
    lean: i8,
    seed: u64,
    rng: std.Random.DefaultPrng,
    leaf_count: u8,

    fn init(seed: u64) Stalk {
        return Stalk{
            .height = 0,
            .lean = 0,
            .seed = seed,
            .rng = std.Random.DefaultPrng.init(seed),
            .leaf_count = 0,
        };
    }

    fn generateToBuffer(self: *Stalk, buffer: *std.ArrayList(u8)) !GrainseedMetadata {
        const random = self.rng.random();
        self.height = random.intRangeAtMost(u8, 5, 15);
        self.leaf_count = 0;
        
        // Header
        try buffer.appendSlice("      . \n");
        try buffer.appendSlice("    \\ | / \n");
        try buffer.appendSlice("   --(@)-- \n");
        try buffer.appendSlice("    / | \\ \n");
        try buffer.appendSlice("      | \n");

        // Stalk
        var i: u8 = 0;
        while (i < self.height) : (i += 1) {
            const sway = random.intRangeAtMost(i8, -1, 1);
            self.lean += sway;
            
            if (self.lean < -3) self.lean = -3;
            if (self.lean > 3) self.lean = 3;

            try self.printSegmentToBuffer(buffer, i);
        }
        
        // Roots
        try buffer.appendSlice("    ~~~~~ \n");

        // Calculate rarity
        const rarity = self.calculateRarity();
        
        const lean_dir = if (self.lean < 0) "left" else if (self.lean > 0) "right" else "straight";
        
        return GrainseedMetadata{
            .seed_id = self.seed,
            .height = self.height,
            .lean_direction = lean_dir,
            .leaf_count = self.leaf_count,
            .rarity_score = rarity,
        };
    }

    fn printSegmentToBuffer(self: *Stalk, buffer: *std.ArrayList(u8), height_idx: u8) !void {
        const random = self.rng.random();
        
        var indent: usize = 6;
        if (self.lean < 0) indent -= @intCast(@abs(self.lean));
        if (self.lean > 0) indent += @intCast(@abs(self.lean));

        var j: usize = 0;
        while (j < indent) : (j += 1) try buffer.append(' ');

        const has_leaf_left = random.boolean() and height_idx % 3 == 0;
        const has_leaf_right = !has_leaf_left and random.boolean() and height_idx % 3 == 0;

        if (has_leaf_left) {
            try buffer.append('(');
            self.leaf_count += 1;
        }
        try buffer.append('|');
        if (has_leaf_right) {
            try buffer.append(')');
            self.leaf_count += 1;
        }
        
        try buffer.append('\n');
    }

    fn calculateRarity(self: *Stalk) u8 {
        var score: u8 = 0;
        
        // Perfect straight = rare
        if (self.lean == 0) score += 30;
        
        // Maximum height = rare
        if (self.height >= 14) score += 20;
        
        // Many leaves = rare
        if (self.leaf_count >= 5) score += 25;
        
        // Extreme lean = rare
        if (@abs(self.lean) >= 3) score += 15;
        
        return score;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: grainseed_collection <start_id> [end_id]\n", .{});
        std.debug.print("Example: grainseed_collection 1 100\n", .{});
        return;
    }

    const start_id = try std.fmt.parseInt(u64, args[1], 10);
    const end_id = if (args.len >= 3) try std.fmt.parseInt(u64, args[2], 10) else start_id;

    std.debug.print("Generating Grainseeds #{d} to #{d}...\n\n", .{start_id, end_id});

    // Create output directory
    const cwd = std.fs.cwd();
    cwd.makeDir("grainseeds_output") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var id = start_id;
    while (id <= end_id) : (id += 1) {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        var stalk = Stalk.init(id);
        const metadata = try stalk.generateToBuffer(&buffer);

        // Write to file
        const filename = try std.fmt.allocPrint(allocator, "grainseeds_output/grainseed_{d}.txt", .{id});
        defer allocator.free(filename);

        const file = try cwd.createFile(filename, .{});
        defer file.close();

        try file.writeAll(buffer.items);

        // Print metadata
        std.debug.print("Grainseed #{d}: height={d}, lean={s}, leaves={d}, rarity={d}\n", 
            .{metadata.seed_id, metadata.height, metadata.lean_direction, metadata.leaf_count, metadata.rarity_score});
    }

    std.debug.print("\n✓ Generated {d} grainseeds in grainseeds_output/\n", .{end_id - start_id + 1});
}
