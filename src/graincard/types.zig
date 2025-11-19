const std = @import("std");

// Graincard Types
// Data structures for 75x100 graincard generation

pub const GraincardConfig = struct {
    seed: u64,
    width: usize = 75,
    height: usize = 100,
    content_width: usize = 73,
    content_height: usize = 98,
    border_char: u8 = '|',
    border_top_bottom: u8 = '+',
    border_horizontal: u8 = '-',
};

pub const Season = enum {
    spring,
    summer,
    autumn,
    winter,
    year_round,
};

pub const SoilType = enum {
    rich_loam,
    sandy_loam,
    clay_rich,
    volcanic,
    frozen,
    desert_sand,
};

pub const EcologyType = enum {
    living_soil,
    carbon_cycle,
    rhizosphere,
    polyculture,
    wild_edges,
    minimal_disturbance,
    cover_crop,
    nutrient_recycler,
    selective_weeding,
    fungal_network,
    residue_builder,
    ecosystem_immune,
};

pub const WeatherCondition = enum {
    clear,
    rainy,
    windy,
    frost,
    hot,
    moonlit,
};

pub const CompanionPlant = enum {
    clover,
    vetch,
    field_pea,
    chicory,
    plantain,
    creeping_thyme,
    yarrow,
    fennel,
    dandelion,
    lambs_quarters,
};

pub const EcologicalParams = struct {
    seed: u64,
    ecology_type: EcologyType,
    season: Season,
    soil_type: SoilType,
    weather: WeatherCondition,
    companions: []const CompanionPlant,
    
    // Soil metrics
    mycorrhizal_fungi: u32, // ft/gram soil
    bacterial_biomass: u32, // μg/g
    protozoa_count: u32, // per gram
    nematode_diversity: u8, // species count
    earthworm_activity: u8, // casts per sq ft
    soil_respiration: f32, // mg CO₂/g/day
    
    // System metrics
    living_root_coverage: u16, // days per year
    soil_carbon_sequestration: f32, // % annually
    pest_damage: f32, // % crop damage
    biodiversity_index: f32, // 0-10 scale
    
    // Stalk characteristics
    stalk_height: u8, // segments
    stalk_lean: i8, // -3 to +3
    leaf_count: u8,
    rarity_score: u8, // 0-100
};

pub const GraincardContent = struct {
    header: []const u8,
    stalk_visual: []const u8,
    metrics_box: []const u8,
    footer: []const u8,
};

pub const RarityTrait = enum {
    common, // 10-20%
    uncommon, // 5-10%
    rare, // 3-5%
    ultra_rare, // 1-3%
    legendary, // 0.5-1%
    mythic, // <0.5%
};

pub fn get_rarity_trait(score: u8) RarityTrait {
    if (score >= 90) return .mythic;
    if (score >= 75) return .legendary;
    if (score >= 60) return .ultra_rare;
    if (score >= 40) return .rare;
    if (score >= 20) return .uncommon;
    return .common;
}

pub fn get_rarity_percentage(trait: RarityTrait) []const u8 {
    return switch (trait) {
        .mythic => "0.5%",
        .legendary => "1%",
        .ultra_rare => "1%",
        .rare => "4%",
        .uncommon => "7%",
        .common => "12%",
    };
}
