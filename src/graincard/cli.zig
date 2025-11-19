const std = @import("std");
const types = @import("types.zig");
const ecology = @import("ecology.zig");
const layout = @import("layout.zig");

// Graincard CLI
// Command-line interface for graincard generation

pub const Options = struct {
    seed: ?u64 = null,
    output: ?[]const u8 = null,
    range_start: ?u64 = null,
    range_end: ?u64 = null,
    output_dir: ?[]const u8 = null,
    ecology_type: ?types.EcologyType = null,
    season: ?types.Season = null,
    format: Format = .txt,

    pub const Format = enum {
        txt,
        json,
    };
};

pub fn parse_args(allocator: std.mem.Allocator) !Options {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // Skip program name

    var options = Options{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--seed")) {
            const seed_str = args.next() orelse return error.MissingSeedValue;
            options.seed = try std.fmt.parseInt(u64, seed_str, 10);
        } else if (std.mem.eql(u8, arg, "--output")) {
            options.output = args.next() orelse return error.MissingOutputValue;
        } else if (std.mem.eql(u8, arg, "--range")) {
            const range_str = args.next() orelse return error.MissingRangeValue;
            const dash_pos = std.mem.indexOf(u8, range_str, "-") orelse
                return error.InvalidRangeFormat;
            
            const start_str = range_str[0..dash_pos];
            const end_str = range_str[dash_pos + 1 ..];
            
            options.range_start = try std.fmt.parseInt(u64, start_str, 10);
            options.range_end = try std.fmt.parseInt(u64, end_str, 10);
        } else if (std.mem.eql(u8, arg, "--output-dir")) {
            options.output_dir = args.next() orelse return error.MissingOutputDirValue;
        } else if (std.mem.eql(u8, arg, "--ecology")) {
            const ecology_str = args.next() orelse return error.MissingEcologyValue;
            options.ecology_type = std.meta.stringToEnum(
                types.EcologyType,
                ecology_str,
            ) orelse return error.InvalidEcologyType;
        } else if (std.mem.eql(u8, arg, "--season")) {
            const season_str = args.next() orelse return error.MissingSeasonValue;
            options.season = std.meta.stringToEnum(
                types.Season,
                season_str,
            ) orelse return error.InvalidSeason;
        } else if (std.mem.eql(u8, arg, "--format")) {
            const format_str = args.next() orelse return error.MissingFormatValue;
            options.format = std.meta.stringToEnum(
                Options.Format,
                format_str,
            ) orelse return error.InvalidFormat;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            print_usage();
            std.process.exit(0);
        }
    }

    return options;
}

pub fn print_usage() void {
    std.debug.print(
        \\Usage: graincard [OPTIONS]
        \\
        \\Options:
        \\  --seed <u64>           Seed number for generation (required)
        \\  --output <path>        Output file path (default: stdout)
        \\  --range <start>-<end>  Generate multiple graincards
        \\  --output-dir <path>    Directory for batch output
        \\  --ecology <type>       Force specific ecology type
        \\  --season <season>      Force specific season
        \\  --format <txt|json>    Output format (default: txt)
        \\  --help, -h             Show this help message
        \\
        \\Examples:
        \\  graincard --seed 12025 --output graincard_12025.txt
        \\  graincard --range 1-100 --output-dir ordinals/
        \\  graincard --seed 42069 --ecology wild_edges --season summer
        \\
    , .{});
}

pub fn run(allocator: std.mem.Allocator) !void {
    const options = try parse_args(allocator);

    // Validate options
    if (options.seed == null and options.range_start == null) {
        std.debug.print("Error: Either --seed or --range is required\n\n", .{});
        print_usage();
        return error.MissingRequiredOption;
    }

    // Single graincard generation
    if (options.seed) |seed| {
        const graincard = try generate_graincard(allocator, seed, options);
        defer allocator.free(graincard);

        if (options.output) |output_path| {
            const file = try std.fs.cwd().createFile(output_path, .{});
            defer file.close();
            try file.writeAll(graincard);
            std.debug.print("Generated graincard: {s}\n", .{output_path});
        } else {
            std.debug.print("{s}", .{graincard});
        }
        return;
    }

    // Batch generation
    if (options.range_start) |start| {
        const end = options.range_end orelse return error.MissingRangeEnd;
        const output_dir = options.output_dir orelse return error.MissingOutputDir;

        // Create output directory
        try std.fs.cwd().makePath(output_dir);

        var current = start;
        while (current <= end) : (current += 1) {
            const graincard = try generate_graincard(allocator, current, options);
            defer allocator.free(graincard);

            const filename = try std.fmt.allocPrint(
                allocator,
                "{s}/graincard_{d}.txt",
                .{ output_dir, current },
            );
            defer allocator.free(filename);

            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();
            try file.writeAll(graincard);

            if (current % 10 == 0) {
                std.debug.print("Generated {d}/{d} graincards...\n", .{ current - start + 1, end - start + 1 });
            }
        }

        std.debug.print("✓ Generated {d} graincards in {s}/\n", .{ end - start + 1, output_dir });
    }
}

fn generate_graincard(
    allocator: std.mem.Allocator,
    seed: u64,
    options: Options,
) ![]u8 {
    // Generate ecological parameters
    const params = ecology.generate_ecological_params(
        seed,
        options.ecology_type,
        options.season,
    );

    // Generate stalk visual
    const stalk = try ecology.generate_stalk(allocator, params);
    defer allocator.free(stalk);

    // Create header
    const rarity_trait = types.get_rarity_trait(params.rarity_score);
    const rarity_pct = types.get_rarity_percentage(rarity_trait);
    
    const header = try std.fmt.allocPrint(
        allocator,
        \\
        \\  GRAINSEED #{d}                                    Rarity: {s} ({s})
        \\  Seed: {d}                                       Height: {d} segments
        \\  Type: {s}                             Lean: {s}
        \\  Season: {s}                                    Leaves: {d}
        \\
    ,
        .{
            seed,
            @tagName(rarity_trait),
            rarity_pct,
            seed,
            params.stalk_height,
            @tagName(params.ecology_type),
            if (params.stalk_lean == 0) "Straight" else if (params.stalk_lean < 0) "Left" else "Right",
            @tagName(params.season),
            params.leaf_count,
        },
    );
    defer allocator.free(header);

    // Create metrics box (simplified for now)
    const metrics = try std.fmt.allocPrint(
        allocator,
        \\  Soil Food Web: {d} species
        \\  Carbon Sequestration: +{d:.1}% annually
        \\  Biodiversity Index: {d:.1}/10
    ,
        .{
            params.nematode_diversity,
            params.soil_carbon_sequestration,
            params.biodiversity_index,
        },
    );
    defer allocator.free(metrics);

    const footer = "  \"Code that grows. Grain that lasts.\"";

    // Assemble graincard
    const config = types.GraincardConfig{ .seed = seed };
    const content = types.GraincardContent{
        .header = header,
        .stalk_visual = stalk,
        .metrics_box = metrics,
        .footer = footer,
    };

    return layout.layout_graincard(allocator, config, content);
}
