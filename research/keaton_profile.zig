//! Keaton Dunsford Profile: Grainscript-compatible DAG node structure.
//!
//! Why: Represent person profile as storable Grain Silo object and DAG node.
//! Architecture: Bounded fields, explicit types, serializable to Grainscript.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-020000-pst: Glow G2

const std = @import("std");

// Note: GraphNode and GraphEdge types would be imported from grain_database
// For standalone file, these are type placeholders
pub const GraphNode = struct {
    node_id: u64,
    node_type: []const u8,
    node_type_len: u32,
    properties: []const u8,
    properties_len: u32,
    created_at: u64,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        node_id: u64,
        node_type: []const u8,
        properties: []const u8,
    ) !GraphNode {
        const type_copy = try allocator.dupe(u8, node_type);
        errdefer allocator.free(type_copy);
        const props_copy = try allocator.dupe(u8, properties);
        errdefer allocator.free(props_copy);
        const now = std.time.timestamp();
        return GraphNode{
            .node_id = node_id,
            .node_type = type_copy,
            .node_type_len = @as(u32, @intCast(type_copy.len)),
            .properties = props_copy,
            .properties_len = @as(u32, @intCast(props_copy.len)),
            .created_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }
};

pub const GraphEdge = struct {
    edge_id: u64,
    from_node_id: u64,
    to_node_id: u64,
    relationship_type: []const u8,
    relationship_type_len: u32,
    properties: []const u8,
    properties_len: u32,
    created_at: u64,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        edge_id: u64,
        from_node_id: u64,
        to_node_id: u64,
        relationship_type: []const u8,
        properties: []const u8,
    ) !GraphEdge {
        const rel_copy = try allocator.dupe(u8, relationship_type);
        errdefer allocator.free(rel_copy);
        const props_copy = try allocator.dupe(u8, properties);
        errdefer allocator.free(props_copy);
        const now = std.time.timestamp();
        return GraphEdge{
            .edge_id = edge_id,
            .from_node_id = from_node_id,
            .to_node_id = to_node_id,
            .relationship_type = rel_copy,
            .relationship_type_len = @as(u32, @intCast(rel_copy.len)),
            .properties = props_copy,
            .properties_len = @as(u32, @intCast(props_copy.len)),
            .created_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }
};

/// Person Profile: Core identity and attributes.
/// Storable as Grain Silo Object and Grain Database GraphNode.
pub const PersonProfile = struct {
    // Bounded: Max name length (explicit limit)
    pub const MAX_NAME_LEN: u32 = 256;

    // Bounded: Max description length (explicit limit)
    pub const MAX_DESCRIPTION_LEN: u32 = 4_096;

    // Bounded: Max inspirations per category (explicit limit)
    pub const MAX_INSPIRATIONS_PER_CATEGORY: u32 = 32;

    // Bounded: Max values count (explicit limit)
    pub const MAX_VALUES: u32 = 64;

    // Bounded: Max musical artists per genre (explicit limit)
    pub const MAX_ARTISTS_PER_GENRE: u32 = 32;

    // Core identity
    name: []const u8,
    name_len: u32,

    // Description (free-form text about the person)
    description: []const u8,
    description_len: u32,

    // Values (core principles and ethics)
    values: []const Value,
    values_len: u32,

    // Inspirations (people, ideas, movements)
    inspirations: Inspirations,

    // Musical preferences
    music: MusicPreferences,

    // Work and projects
    work: WorkContext,

    // Timestamps
    created_at: u64, // Unix epoch
    updated_at: u64, // Unix epoch

    allocator: std.mem.Allocator,

    /// Value: Core principle or ethical commitment.
    pub const Value = struct {
        name: []const u8, // e.g., "veganism", "authenticity", "systems_thinking"
        name_len: u32,
        description: []const u8, // Why this value matters
        description_len: u32,
        intensity: u8, // 0-255: How central this value is (255 = core)
    };

    /// Inspirations: People and ideas that influence.
    pub const Inspirations = struct {
        // Technical/Systems
        technical: []const Inspiration,
        technical_len: u32,

        // Spiritual/Mystical
        spiritual: []const Inspiration,
        spiritual_len: u32,

        // Ethical/Activist
        ethical: []const Inspiration,
        ethical_len: u32,

        // Creative/Artistic
        creative: []const Inspiration,
        creative_len: u32,
    };

    /// Inspiration: A person, idea, or movement.
    pub const Inspiration = struct {
        name: []const u8, // e.g., "Vic Dicara", "Natalie Vais"
        name_len: u32,
        category: []const u8, // e.g., "vedic_astrology", "venture_capital"
        category_len: u32,
        description: []const u8, // What resonates about this inspiration
        description_len: u32,
        resonance_strength: u8, // 0-255: How deeply this resonates
    };

    /// Music Preferences: Musical tastes and patterns.
    pub const MusicPreferences = struct {
        // Technical mastery layer
        technical_mastery: []const Artist,
        technical_mastery_len: u32,

        // Innovation layer
        innovation: []const Artist,
        innovation_len: u32,

        // Emotional/spiritual layer
        emotional_spiritual: []const Artist,
        emotional_spiritual_len: u32,

        // Functional layer (for work/focus)
        functional: []const FunctionalMusic,
        functional_len: u32,
    };

    /// Artist: Musical artist or composer.
    pub const Artist = struct {
        name: []const u8, // e.g., "Charlie Parker", "Night Verses"
        name_len: u32,
        genre: []const u8, // e.g., "bebop_jazz", "instrumental_progressive_metal"
        genre_len: u32,
        description: []const u8, // What resonates about this artist
        description_len: u32,
    };

    /// Functional Music: Music used for specific purposes.
    pub const FunctionalMusic = struct {
        purpose: []const u8, // e.g., "focus", "contemplation", "energy"
        purpose_len: u32,
        artists: []const Artist,
        artists_len: u32,
    };

    /// Work Context: Professional work and projects.
    pub const WorkContext = struct {
        primary_project: []const u8, // e.g., "Grain OS"
        primary_project_len: u32,
        role: []const u8, // e.g., "systems_architect", "founder"
        role_len: u32,
        approach: []const u8, // e.g., "zero_technical_debt", "patient_discipline"
        approach_len: u32,
        research_interests: []const ResearchInterest,
        research_interests_len: u32,
    };

    /// Research Interest: Areas of exploration.
    pub const ResearchInterest = struct {
        topic: []const u8, // e.g., "healing", "systems_thinking", "music_therapy"
        topic_len: u32,
        description: []const u8, // Why this is interesting
        description_len: u32,
        status: ResearchStatus,
    };

    /// Research Status: Current state of research interest.
    pub const ResearchStatus = enum(u8) {
        exploring, // Just beginning to explore
        active, // Actively researching
        integrating, // Integrating into work/life
        mature, // Well-developed understanding
    };

    /// Initialize person profile.
    pub fn init(allocator: std.mem.Allocator) !PersonProfile {
        // Assert: Allocator must be valid
        std.debug.assert(allocator.ptr != null);

        const now = std.time.timestamp();

        // Allocate core fields
        const name = try allocator.dupe(u8, "Keaton Dunsford");
        errdefer allocator.free(name);

        const description = try init_description(allocator);
        errdefer allocator.free(description);

        // Initialize arrays
        const values = try allocator.alloc(Value, MAX_VALUES);
        errdefer allocator.free(values);

        const inspirations = try init_inspirations(allocator);
        errdefer {
            allocator.free(inspirations.technical);
            allocator.free(inspirations.spiritual);
            allocator.free(inspirations.ethical);
            allocator.free(inspirations.creative);
        }

        const music = try init_music(allocator);
        errdefer {
            allocator.free(music.technical_mastery);
            allocator.free(music.innovation);
            allocator.free(music.emotional_spiritual);
            allocator.free(music.functional);
        }

        const work = try init_work(allocator);
        errdefer {
            allocator.free(work.primary_project);
            allocator.free(work.role);
            allocator.free(work.approach);
            allocator.free(work.research_interests);
        }

        return PersonProfile{
            .name = name,
            .name_len = @as(u32, @intCast(name.len)),
            .description = description,
            .description_len = @as(u32, @intCast(description.len)),
            .values = values,
            .values_len = 0,
            .inspirations = inspirations,
            .music = music,
            .work = work,
            .created_at = @as(u64, @intCast(now)),
            .updated_at = @as(u64, @intCast(now)),
            .allocator = allocator,
        };
    }

    /// Initialize description text.
    fn init_description(allocator: std.mem.Allocator) ![]const u8 {
        const desc_text =
            \\Systems architect building Grain OS with patient discipline.
            \\Values: veganism, authenticity, technical precision, systems thinking.
            \\Seeks to bridge worlds: technical/spiritual, structured/exploratory.
            \\Uses research directory as space for "the ache" - acknowledging
            \\difficulty while staying forward-looking. Appreciates intensity and
            \\stillness.
        ;
        return try allocator.dupe(u8, desc_text);
    }

    /// Initialize inspirations arrays.
    fn init_inspirations(allocator: std.mem.Allocator) !Inspirations {
        const technical = try allocator.alloc(
            Inspiration,
            MAX_INSPIRATIONS_PER_CATEGORY,
        );
        errdefer allocator.free(technical);
        const spiritual = try allocator.alloc(
            Inspiration,
            MAX_INSPIRATIONS_PER_CATEGORY,
        );
        errdefer allocator.free(spiritual);
        const ethical = try allocator.alloc(
            Inspiration,
            MAX_INSPIRATIONS_PER_CATEGORY,
        );
        errdefer allocator.free(ethical);
        const creative = try allocator.alloc(
            Inspiration,
            MAX_INSPIRATIONS_PER_CATEGORY,
        );
        errdefer allocator.free(creative);

        return Inspirations{
            .technical = technical,
            .technical_len = 0,
            .spiritual = spiritual,
            .spiritual_len = 0,
            .ethical = ethical,
            .ethical_len = 0,
            .creative = creative,
            .creative_len = 0,
        };
    }

    /// Initialize music preferences arrays.
    fn init_music(allocator: std.mem.Allocator) !MusicPreferences {
        const technical_mastery = try allocator.alloc(Artist, MAX_ARTISTS_PER_GENRE);
        errdefer allocator.free(technical_mastery);
        const innovation = try allocator.alloc(Artist, MAX_ARTISTS_PER_GENRE);
        errdefer allocator.free(innovation);
        const emotional_spiritual = try allocator.alloc(
            Artist,
            MAX_ARTISTS_PER_GENRE,
        );
        errdefer allocator.free(emotional_spiritual);
        const functional = try allocator.alloc(FunctionalMusic, 8);
        errdefer allocator.free(functional);

        return MusicPreferences{
            .technical_mastery = technical_mastery,
            .technical_mastery_len = 0,
            .innovation = innovation,
            .innovation_len = 0,
            .emotional_spiritual = emotional_spiritual,
            .emotional_spiritual_len = 0,
            .functional = functional,
            .functional_len = 0,
        };
    }

    /// Initialize work context.
    fn init_work(allocator: std.mem.Allocator) !WorkContext {
        const primary_project = try allocator.dupe(u8, "Grain OS");
        errdefer allocator.free(primary_project);
        const role = try allocator.dupe(u8, "systems_architect_founder");
        errdefer allocator.free(role);
        const approach = try allocator.dupe(
            u8,
            "zero_technical_debt_patient_discipline",
        );
        errdefer allocator.free(approach);
        const research_interests = try allocator.alloc(ResearchInterest, 16);
        errdefer allocator.free(research_interests);

        return WorkContext{
            .primary_project = primary_project,
            .primary_project_len = @as(u32, @intCast(primary_project.len)),
            .role = role,
            .role_len = @as(u32, @intCast(role.len)),
            .approach = approach,
            .approach_len = @as(u32, @intCast(approach.len)),
            .research_interests = research_interests,
            .research_interests_len = 0,
        };
    }

    /// Deinitialize person profile and free memory.
    pub fn deinit(self: *PersonProfile) void {
        _ = self.allocator; // Allocator is used below

        // Free core fields
        if (self.name_len > 0) {
            self.allocator.free(self.name);
        }
        if (self.description_len > 0) {
            self.allocator.free(self.description);
        }

        // Free structured data
        self.deinit_values();
        self.deinit_inspirations();
        self.deinit_music();
        self.deinit_work();

        self.* = undefined;
    }

    /// Deinitialize values array.
    fn deinit_values(self: *PersonProfile) void {
        var i: u32 = 0;
        while (i < self.values_len) : (i += 1) {
            const value = &self.values[i];
            if (value.name_len > 0) {
                self.allocator.free(value.name);
            }
            if (value.description_len > 0) {
                self.allocator.free(value.description);
            }
        }
        self.allocator.free(self.values);
    }

    /// Deinitialize inspirations.
    fn deinit_inspirations(self: *PersonProfile) void {
        self.free_inspirations_category(
            &self.inspirations.technical,
            self.inspirations.technical_len,
        );
        self.free_inspirations_category(
            &self.inspirations.spiritual,
            self.inspirations.spiritual_len,
        );
        self.free_inspirations_category(
            &self.inspirations.ethical,
            self.inspirations.ethical_len,
        );
        self.free_inspirations_category(
            &self.inspirations.creative,
            self.inspirations.creative_len,
        );
        self.allocator.free(self.inspirations.technical);
        self.allocator.free(self.inspirations.spiritual);
        self.allocator.free(self.inspirations.ethical);
        self.allocator.free(self.inspirations.creative);
    }

    /// Deinitialize music preferences.
    fn deinit_music(self: *PersonProfile) void {
        self.free_artists(
            self.music.technical_mastery,
            self.music.technical_mastery_len,
        );
        self.free_artists(self.music.innovation, self.music.innovation_len);
        self.free_artists(
            self.music.emotional_spiritual,
            self.music.emotional_spiritual_len,
        );
        var j: u32 = 0;
        while (j < self.music.functional_len) : (j += 1) {
            const func_music = &self.music.functional[j];
            if (func_music.purpose_len > 0) {
                self.allocator.free(func_music.purpose);
            }
            self.free_artists(func_music.artists, func_music.artists_len);
            if (func_music.artists_len > 0) {
                self.allocator.free(func_music.artists);
            }
        }
        self.allocator.free(self.music.technical_mastery);
        self.allocator.free(self.music.innovation);
        self.allocator.free(self.music.emotional_spiritual);
        self.allocator.free(self.music.functional);
    }

    /// Deinitialize work context.
    fn deinit_work(self: *PersonProfile) void {
        if (self.work.primary_project_len > 0) {
            self.allocator.free(self.work.primary_project);
        }
        if (self.work.role_len > 0) {
            self.allocator.free(self.work.role);
        }
        if (self.work.approach_len > 0) {
            self.allocator.free(self.work.approach);
        }
        var k: u32 = 0;
        while (k < self.work.research_interests_len) : (k += 1) {
            const interest = &self.work.research_interests[k];
            if (interest.topic_len > 0) {
                self.allocator.free(interest.topic);
            }
            if (interest.description_len > 0) {
                self.allocator.free(interest.description);
            }
        }
        self.allocator.free(self.work.research_interests);
    }

    /// Free inspirations category.
    fn free_inspirations_category(
        self: *PersonProfile,
        inspirations: []Inspiration,
        len: u32,
    ) void {
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const insp = &inspirations[i];
            if (insp.name_len > 0) {
                self.allocator.free(insp.name);
            }
            if (insp.category_len > 0) {
                self.allocator.free(insp.category);
            }
            if (insp.description_len > 0) {
                self.allocator.free(insp.description);
            }
        }
    }

    /// Free artists array.
    fn free_artists(self: *PersonProfile, artists: []Artist, len: u32) void {
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const artist = &artists[i];
            if (artist.name_len > 0) {
                self.allocator.free(artist.name);
            }
            if (artist.genre_len > 0) {
                self.allocator.free(artist.genre);
            }
            if (artist.description_len > 0) {
                self.allocator.free(artist.description);
            }
        }
    }

    /// Serialize to Grainscript format (JSON-like structure).
    /// Returns a string that can be stored in Grain Silo Object.data field.
    pub fn serialize_to_grainscript(self: *const PersonProfile) ![]const u8 {
        // Assert: Profile must be valid
        std.debug.assert(self.name_len > 0);

        // Build Grainscript representation
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        const writer = buffer.writer();

        // Serialize all sections
        try serialize_header(writer, self);
        try serialize_values(writer, self);
        try serialize_inspirations_section(writer, self);
        try serialize_music_section(writer, self);
        try serialize_work_section(writer, self);
        try serialize_footer(writer, self);

        return buffer.toOwnedSlice();
    }

    /// Serialize header (name, description).
    fn serialize_header(writer: anytype, self: *const PersonProfile) !void {
        try writer.print("const keaton_profile = {{\n", .{});
        try writer.print("  name: \"{s}\",\n", .{self.name});
        try writer.print("  description: \"{s}\",\n", .{self.description});
    }

    /// Serialize values array.
    fn serialize_values(writer: anytype, self: *const PersonProfile) !void {
        try writer.print("  values: [\n", .{});
        var i: u32 = 0;
        while (i < self.values_len) : (i += 1) {
            const value = self.values[i];
            try writer.print("    {{\n", .{});
            try writer.print("      name: \"{s}\",\n", .{value.name});
            try writer.print("      description: \"{s}\",\n", .{value.description});
            try writer.print("      intensity: {},\n", .{value.intensity});
            try writer.print("    }},\n", .{});
        }
        try writer.print("  ],\n", .{});
    }

    /// Serialize inspirations section.
    fn serialize_inspirations_section(
        writer: anytype,
        self: *const PersonProfile,
    ) !void {
        try writer.print("  inspirations: {{\n", .{});
        try self.serialize_inspirations_category(
            writer,
            "technical",
            self.inspirations.technical,
            self.inspirations.technical_len,
        );
        try self.serialize_inspirations_category(
            writer,
            "spiritual",
            self.inspirations.spiritual,
            self.inspirations.spiritual_len,
        );
        try self.serialize_inspirations_category(
            writer,
            "ethical",
            self.inspirations.ethical,
            self.inspirations.ethical_len,
        );
        try self.serialize_inspirations_category(
            writer,
            "creative",
            self.inspirations.creative,
            self.inspirations.creative_len,
        );
        try writer.print("  }},\n", .{});
    }

    /// Serialize music section.
    fn serialize_music_section(writer: anytype, self: *const PersonProfile) !void {
        try writer.print("  music: {{\n", .{});
        try self.serialize_artists(
            writer,
            "technical_mastery",
            self.music.technical_mastery,
            self.music.technical_mastery_len,
        );
        try self.serialize_artists(
            writer,
            "innovation",
            self.music.innovation,
            self.music.innovation_len,
        );
        try self.serialize_artists(
            writer,
            "emotional_spiritual",
            self.music.emotional_spiritual,
            self.music.emotional_spiritual_len,
        );
        try serialize_functional_music(writer, self);
        try writer.print("  }},\n", .{});
    }

    /// Serialize functional music array.
    fn serialize_functional_music(
        writer: anytype,
        self: *const PersonProfile,
    ) !void {
        try writer.print("    functional: [\n", .{});
        var j: u32 = 0;
        while (j < self.music.functional_len) : (j += 1) {
            const func_music = self.music.functional[j];
            try writer.print("      {{\n", .{});
            try writer.print("        purpose: \"{s}\",\n", .{func_music.purpose});
            try writer.print("        artists: [\n", .{});
            var k: u32 = 0;
            while (k < func_music.artists_len) : (k += 1) {
                const artist = func_music.artists[k];
                try writer.print(
                    "          {{ name: \"{s}\", genre: \"{s}\" }},\n",
                    .{ artist.name, artist.genre },
                );
            }
            try writer.print("        ],\n", .{});
            try writer.print("      }},\n", .{});
        }
        try writer.print("    ],\n", .{});
    }

    /// Serialize work section.
    fn serialize_work_section(writer: anytype, self: *const PersonProfile) !void {
        try writer.print("  work: {{\n", .{});
        try writer.print(
            "    primary_project: \"{s}\",\n",
            .{self.work.primary_project},
        );
        try writer.print("    role: \"{s}\",\n", .{self.work.role});
        try writer.print("    approach: \"{s}\",\n", .{self.work.approach});
        try writer.print("    research_interests: [\n", .{});
        var l: u32 = 0;
        while (l < self.work.research_interests_len) : (l += 1) {
            const interest = self.work.research_interests[l];
            try writer.print("      {{\n", .{});
            try writer.print("        topic: \"{s}\",\n", .{interest.topic});
            try writer.print(
                "        description: \"{s}\",\n",
                .{interest.description},
            );
            try writer.print(
                "        status: \"{s}\",\n",
                .{@tagName(interest.status)},
            );
            try writer.print("      }},\n", .{});
        }
        try writer.print("    ],\n", .{});
        try writer.print("  }},\n", .{});
    }

    /// Serialize footer (timestamps, closing brace).
    fn serialize_footer(writer: anytype, self: *const PersonProfile) !void {
        try writer.print("  created_at: {},\n", .{self.created_at});
        try writer.print("  updated_at: {},\n", .{self.updated_at});
        try writer.print("}};\n", .{});
    }

    /// Serialize inspirations category.
    fn serialize_inspirations_category(
        self: *const PersonProfile,
        writer: anytype,
        category_name: []const u8,
        inspirations: []const Inspiration,
        len: u32,
    ) !void {
        _ = self; // Used via inspirations parameter
        try writer.print("    {}: [\n", .{category_name});
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const insp = inspirations[i];
            try writer.print("      {{\n", .{});
            try writer.print("        name: \"{s}\",\n", .{insp.name});
            try writer.print("        category: \"{s}\",\n", .{insp.category});
            try writer.print(
                "        description: \"{s}\",\n",
                .{insp.description},
            );
            try writer.print(
                "        resonance_strength: {},\n",
                .{insp.resonance_strength},
            );
            try writer.print("      }},\n", .{});
        }
        try writer.print("    ],\n", .{});
    }

    /// Serialize artists array.
    fn serialize_artists(
        self: *const PersonProfile,
        writer: anytype,
        category_name: []const u8,
        artists: []const Artist,
        len: u32,
    ) !void {
        _ = self; // Used via artists parameter
        try writer.print("    {}: [\n", .{category_name});
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            const artist = artists[i];
            try writer.print(
                "      {{ name: \"{s}\", genre: \"{s}\", description: \"{s}\" }},\n",
                .{ artist.name, artist.genre, artist.description },
            );
        }
        try writer.print("    ],\n", .{});
    }

    /// Convert to Grain Database GraphNode.
    /// This creates a GraphNode that can be stored in Grain Silo.
    pub fn to_graph_node(self: *const PersonProfile, node_id: u64) !GraphNode {
        // Assert: Node ID must be valid
        std.debug.assert(node_id > 0);

        // Serialize to Grainscript format
        const properties_json = try self.serialize_to_grainscript();
        errdefer self.allocator.free(properties_json);

        // Create GraphNode
        const graph_node = try GraphNode.init(
            self.allocator,
            node_id,
            "person_profile",
            properties_json,
        );

        return graph_node;
    }

    /// Create DAG edges for relationships.
    /// Returns array of GraphEdges connecting this profile to related entities.
    pub fn create_dag_edges(
        self: *const PersonProfile,
        from_node_id: u64,
        next_edge_id: *u64,
    ) ![]GraphEdge {
        // Assert: Node ID must be valid
        std.debug.assert(from_node_id > 0);
        std.debug.assert(next_edge_id.* > 0);

        // Pre-allocate edges array (bounded)
        const max_edges = self.inspirations.technical_len +
            self.inspirations.spiritual_len +
            self.inspirations.ethical_len +
            self.inspirations.creative_len +
            self.values_len +
            self.work.research_interests_len;
        var edges = std.ArrayList(GraphEdge).init(self.allocator);
        defer edges.deinit();
        try edges.ensureTotalCapacity(max_edges);

        // Create edges for values
        // Note: In real implementation, create value nodes first, then edges
        var i: u32 = 0;
        while (i < self.values_len) : (i += 1) {
            const value = self.values[i];
            // Placeholder: would be actual value node ID
            const target_node_id: u64 = 1000 + i;
            const edge = try GraphEdge.init(
                self.allocator,
                next_edge_id.*,
                from_node_id,
                target_node_id,
                "has_value",
                value.name,
            );
            next_edge_id.* += 1;
            try edges.append(edge);
        }

        return edges.toOwnedSlice();
    }
};
