const std = @import("std");
const types = @import("types.zig");

// Graincard Ecology Generator
// Generates ecological parameters and ASCII visualizations

pub fn generate_ecological_params(
    seed: u64,
    forced_ecology: ?types.EcologyType,
    forced_season: ?types.Season,
) types.EcologicalParams {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    const ecology_type = forced_ecology orelse @as(
        types.EcologyType,
        @enumFromInt(random.intRangeAtMost(
            u4,
            0,
            @intFromEnum(types.EcologyType.ecosystem_immune),
        )),
    );

    const season = forced_season orelse @as(
        types.Season,
        @enumFromInt(random.intRangeAtMost(
            u3,
            0,
            @intFromEnum(types.Season.year_round),
        )),
    );

    const soil_type = @as(
        types.SoilType,
        @enumFromInt(random.intRangeAtMost(
            u3,
            0,
            @intFromEnum(types.SoilType.desert_sand),
        )),
    );

    const weather = @as(
        types.WeatherCondition,
        @enumFromInt(random.intRangeAtMost(
            u3,
            0,
            @intFromEnum(types.WeatherCondition.moonlit),
        )),
    );

    // Generate stalk characteristics
    const stalk_height = random.intRangeAtMost(u8, 5, 15);
    const stalk_lean = random.intRangeAtMost(i8, -3, 3);
    const leaf_count = random.intRangeAtMost(u8, 0, 9);

    // Generate soil metrics
    const mycorrhizal_fungi = random.intRangeAtMost(
        u32,
        200,
        2400,
    );
    const bacterial_biomass = random.intRangeAtMost(
        u32,
        400,
        1800,
    );
    const protozoa_count = random.intRangeAtMost(
        u32,
        5000,
        25000,
    );
    const nematode_diversity = random.intRangeAtMost(u8, 8, 47);
    const earthworm_activity = random.intRangeAtMost(u8, 3, 18);
    const soil_respiration = 0.8 + random.float(f32) * 2.0;

    // System metrics
    const living_root_coverage = random.intRangeAtMost(
        u16,
        180,
        365,
    );
    const soil_carbon_sequestration = random.float(f32) * 1.2;
    const pest_damage = random.float(f32) * 5.0;
    const biodiversity_index = 3.0 + random.float(f32) * 7.0;

    // Calculate rarity
    const rarity_score = calculate_rarity(.{
        .stalk_height = stalk_height,
        .stalk_lean = stalk_lean,
        .leaf_count = leaf_count,
        .ecology_type = ecology_type,
    });

    return .{
        .seed = seed,
        .ecology_type = ecology_type,
        .season = season,
        .soil_type = soil_type,
        .weather = weather,
        .companions = &.{}, // TODO: Generate companions
        .mycorrhizal_fungi = mycorrhizal_fungi,
        .bacterial_biomass = bacterial_biomass,
        .protozoa_count = protozoa_count,
        .nematode_diversity = nematode_diversity,
        .earthworm_activity = earthworm_activity,
        .soil_respiration = soil_respiration,
        .living_root_coverage = living_root_coverage,
        .soil_carbon_sequestration = soil_carbon_sequestration,
        .pest_damage = pest_damage,
        .biodiversity_index = biodiversity_index,
        .stalk_height = stalk_height,
        .stalk_lean = stalk_lean,
        .leaf_count = leaf_count,
        .rarity_score = rarity_score,
    };
}

pub fn generate_stalk(
    allocator: std.mem.Allocator,
    params: types.EcologicalParams,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    errdefer buffer.deinit(allocator);

    var rng = std.Random.DefaultPrng.init(params.seed);
    const random = rng.random();

    // Grain head
    try buffer.appendSlice(allocator, "      . \n");
    try buffer.appendSlice(allocator, "    \\ | / \n");
    try buffer.appendSlice(allocator, "   --(@)-- \n");
    try buffer.appendSlice(allocator, "    / | \\ \n");
    try buffer.appendSlice(allocator, "      | \n");

    // Stalk segments
    var current_lean: i8 = 0;
    var leaves_placed: u8 = 0;
    
    var i: u8 = 0;
    while (i < params.stalk_height) : (i += 1) {
        const sway = random.intRangeAtMost(i8, -1, 1);
        current_lean += sway;
        
        if (current_lean < -3) current_lean = -3;
        if (current_lean > 3) current_lean = 3;

        // Calculate indent
        var indent: usize = 6;
        if (current_lean < 0) {
            indent -= @intCast(@abs(current_lean));
        }
        if (current_lean > 0) {
            indent += @intCast(@abs(current_lean));
        }

        // Add indentation
        var j: usize = 0;
        while (j < indent) : (j += 1) {
            try buffer.append(allocator, ' ');
        }

        // Determine if leaf should be placed
        const has_leaf_left = leaves_placed < params.leaf_count and
            random.boolean() and i % 3 == 0;
        const has_leaf_right = !has_leaf_left and
            leaves_placed < params.leaf_count and
            random.boolean() and i % 3 == 0;

        if (has_leaf_left) {
            try buffer.append(allocator, '(');
            leaves_placed += 1;
        }
        
        try buffer.append(allocator, '|');
        
        if (has_leaf_right) {
            try buffer.append(allocator, ')');
            leaves_placed += 1;
        }
        
        try buffer.append(allocator, '\n');
    }

    // Roots
    try buffer.appendSlice(allocator, "    ~~~~~ \n");

    return buffer.toOwnedSlice(allocator);
}

const RarityInput = struct {
    stalk_height: u8,
    stalk_lean: i8,
    leaf_count: u8,
    ecology_type: types.EcologyType,
};

pub fn calculate_rarity(input: RarityInput) u8 {
    var score: u8 = 0;

    // Perfect straight = rare
    if (input.stalk_lean == 0) score += 30;

    // Maximum height = rare
    if (input.stalk_height >= 14) score += 20;

    // Many leaves = rare
    if (input.leaf_count >= 6) score += 25;

    // Extreme lean = rare
    if (@abs(input.stalk_lean) >= 3) score += 15;

    // Special ecology types = bonus
    if (input.ecology_type == .ecosystem_immune) score += 20;
    if (input.ecology_type == .minimal_disturbance) score += 15;

    return score;
}
