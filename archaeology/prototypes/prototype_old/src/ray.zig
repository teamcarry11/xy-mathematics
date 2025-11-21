const std = @import("std");
const SimpleRng = @import("simple_rng.zig").SimpleRng;

// Airbending swirl to keep Glow G2 grounded in motion.
//      .-.
//  _  (   )  _
// ( )  `-'  ( )
//  `~  ~~~~  ~`
// Breezes carry the Tahoe lodge plans without drifting from TigerStyle bounds.
//
// Waterbending loop (station switch to the Avatar train).
// ~ ~  ~~~   ~~~  ~
//  ~   ~~~ ~~~  ~~~
// ~~~   ~  ~~~  ~
// Keep flow steady, no floods, only gentle irrigation of Grain.
//
// Earthbending stance: firm TigerStyle footing, every struct a stone.
//  /\    /\    /\
// /__\__/__\__/__\
// Grounded allocations prevent landslides in the monorepo terrain.

pub const AvatarDiscipline = enum { air, water, earth };

fn discipline_workflow_body(discipline: AvatarDiscipline) []const u8 {
    return switch (discipline) {
        .air =>
        \\Alias /Users/bhagavan851c05a/xy as `xy`.
        \\Pipeline: Cursor Ultra Auto Mode → Z shell → Zig build → Native GUI output.
        \\English plans compile into deterministic Zig invocations with static allocation.
        \\Future work: replace python tweet slicer with Zig tool.
        \\Discipline emphasis: airbending—quick deploys, light on state, ready to roll back.
        ,
        .water =>
        \\Alias /Users/bhagavan851c05a/xy as `xy`.
        \\Pipeline: Cursor Ultra Auto Mode → Z shell → Zig build → Native GUI output.
        \\English plans compile into deterministic Zig invocations with static allocation.
        \\Future work: replace python tweet slicer with Zig tool.
        \\Discipline emphasis: waterbending—flow with change, keep configs hydrated but safe.
        ,
        .earth =>
        \\Alias /Users/bhagavan851c05a/xy as `xy`.
        \\Pipeline: Cursor Ultra Auto Mode → Z shell → Zig build → Native GUI output.
        \\English plans compile into deterministic Zig invocations with static allocation.
        \\Future work: replace python tweet slicer with Zig tool.
        \\Discipline emphasis: earthbending—grounded rollouts, confident once relearned.
        ,
    };
}

pub const TimestampGrammar = struct {
    name: []const u8,
    delimiter: []const u8,
    expected_segments: usize,
    allow_empty_segments: bool,

    pub fn init(
        name: []const u8,
        delimiter: []const u8,
        expected_segments: usize,
        allow_empty_segments: bool,
    ) TimestampGrammar {
        return .{
            .name = name,
            .delimiter = delimiter,
            .expected_segments = expected_segments,
            .allow_empty_segments = allow_empty_segments,
        };
    }

    pub fn validate(self: TimestampGrammar, raw: []const u8) void {
        if (self.delimiter.len == 0) {
            @panic("timestamp grammar requires non-empty delimiter");
        }

        var it = std.mem.splitSequence(u8, raw, self.delimiter);
        var segments: usize = 0;
        while (it.next()) |segment| {
            if (segment.len == 0) {
                if (!self.allow_empty_segments) {
                    @panic("timestamp grammar encountered empty segment");
                }
            } else {
                segments += 1;
            }
        }

        if (segments != self.expected_segments) {
            @panic("timestamp grammar segment count mismatch");
        }
    }
};

pub const Timestamp = struct {
    raw: []const u8,
    grammar: TimestampGrammar,

    pub fn init(raw: []const u8, grammar: TimestampGrammar) Timestamp {
        return .{ .raw = raw, .grammar = grammar };
    }

    pub fn validate(self: Timestamp) void {
        self.grammar.validate(self.raw);
    }
};

pub const MetadataModule = struct {
    title: []const u8,
    body: []const u8,
    timestamp: Timestamp,
};

pub const DataModule = struct {
    title: []const u8,
    body: []const u8,
    timestamp: Timestamp,
};

pub const RayEnvelope = struct {
    lead: [2]MetadataModule,
    core: DataModule,
    tail: MetadataModule,
    timestamp_db: []const Timestamp,

    pub fn init() RayEnvelope {
        return init_with_discipline(.earth);
    }

    pub fn init_with_discipline(discipline: AvatarDiscipline) RayEnvelope {
        const canonical_timestamp = Timestamp.init(
            \\holocene_vedic_calendar--12025-11-09--2311--pst--
            \\tropical_zodiac_sidereal_sanskrit_nakshatra_astrology_
            \\ascendant-leo_15_degrees_out_of_thirty--
            \\moon_lunar_mansion_sanskrit_nakshatra_sutra_vic_dicara-
            \\punarvasu--whole_sign_diurnal_nocturnal_solar_house_system-
            \\4th_house--github_kae3g_xy
        ,
            TimestampGrammar.init("HoloceneVedicComposite", "--", 8, true),
        );
        canonical_timestamp.validate();

        const persona = MetadataModule{
            .title = "Twilight Persona",
            .body =
            \\Glow G2 remains steady like Tahoe dusk—masculine, stoic, Aquarian, voice softened by
            \\emo chords yet completely PG and kind.
            \\Contact lattice: Twitter @risc_love, email kj3x39@gmail.com, GPG
            \\26F201F13AE3AFF90711006C1EE2C9E3486517CB.
            \\Letta API pathfinding stays in sync with https://docs.letta.com/api-reference/overview.
            ,
            .timestamp = canonical_timestamp,
        };

        const workflow = MetadataModule{
            .title = "Cursor ↔ Zig Workflow Covenant",
            .body = discipline_workflow_body(discipline),
            .timestamp = canonical_timestamp,
        };

        const expedition = DataModule{
            .title = "Grain Expedition Data",
            .body =
            \\Grain blossoms as a twilight terminal: Cursor Ultra, Zig LSP, Grok, and social
            \\streams share one steady window.
            \\Inside rests a River-inspired compositor with Moonglow keymaps and per-user Grain
            \\gardens managed via Tahoe dotfiles.
            \\Nostr `npub`s act as bright addresses and Matklad-style tests sweep for drift like
            \\gentle tidewater.
            ,
            .timestamp = canonical_timestamp,
        };

        const audit = MetadataModule{
            .title = "Audit And True Goals",
            .body =
            \\Audit: Jepsen-style deterministic sims covering clock skew, disk turbulence, and
            \\friendly-but-strict quorum shifts.
            \\Goals: disciplined `xy` monorepo, ethical Grain infrastructure, reproducible docs,
            \\and Tahoe-ready launch poise.
            ,
            .timestamp = canonical_timestamp,
        };

        const envelope = RayEnvelope{
            .lead = .{ persona, workflow },
            .core = expedition,
            .tail = audit,
            .timestamp_db = &TimestampDB.entries,
        };

        for (envelope.timestamp_db) |entry| {
            entry.validate();
        }

        validate(envelope);
        return envelope;
    }
};

fn validate(env: RayEnvelope) void {
    std.debug.assert(env.lead.len == 2);
    std.debug.assert(env.tail.title.len > 0);
    std.debug.assert(env.timestamp_db.len >= 1);
}

pub const TimestampDB = struct {
    pub const entries = [_]Timestamp{
        Timestamp.init(
            \\holocene_vedic_calendar--12025-11-10--1007--pst--
            \\tropical_zodiac_sidereal_sanskrit_nakshatra_astrology_
            \\ascendant-sagi-23_degrees_out_of_thirty--
            \\moon_lunar_mansion_sanskrit_nakshatra_sutra_vic_dicara-
            \\pushya--whole_sign_diurnal_nocturnal_solar_house_system-
            \\12th_house----github_kae3g_xy
        ,
            TimestampGrammar.init("HoloceneVedicComposite", "--", 8, true),
        ),
    };
};

pub const RayTraining = struct {
    current: AvatarDiscipline,
    previous: ?AvatarDiscipline,

    pub fn init() RayTraining {
        return .{
            .current = .air,
            .previous = null,
        };
    }

    pub fn current_envelope(self: RayTraining) RayEnvelope {
        return RayEnvelope.init_with_discipline(self.current);
    }

    pub fn current_discipline(self: RayTraining) AvatarDiscipline {
        return self.current;
    }

    pub fn rebuild(self: *RayTraining, discipline: AvatarDiscipline) RayEnvelope {
        self.previous = self.current;
        self.current = discipline;
        return RayEnvelope.init_with_discipline(self.current);
    }

    pub fn rollback(self: *RayTraining) RayEnvelope {
        if (self.previous) |prev| {
            self.current = prev;
            self.previous = null;
        }
        return RayEnvelope.init_with_discipline(self.current);
    }
};

test "timestamp grammar fuzz respects configuration" {
    var rng = SimpleRng.init(0xDEC0DEBEEF123456);
    const delimiter = "--";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(allocator);

    for (0..256) |_| {
        buffer.clearRetainingCapacity();
        const allow_empty = rng.boolean();
        const segment_total = rng.range(usize, 5) + 1;
        var non_empty: usize = 0;

        for (0..segment_total) |idx| {
            if (idx != 0) try buffer.appendSlice(allocator, delimiter);

            const make_empty = allow_empty and rng.boolean();
            if (!make_empty) {
                const len = rng.range(usize, 5) + 1;
                for (0..len) |_| {
                    const ch: u8 = 'a' + @as(u8, rng.range(u8, 26));
                    try buffer.append(allocator, ch);
                }
                non_empty += 1;
            }
        }

        const grammar = TimestampGrammar.init(
            "fuzz",
            delimiter,
            non_empty,
            allow_empty,
        );
        const raw = buffer.items;
        grammar.validate(raw);

        const ts = Timestamp.init(raw, grammar);
        ts.validate();
    }
}

test "RayTraining rollback and relearn earthbending" {
    var training = RayTraining.init();
    try std.testing.expectEqual(AvatarDiscipline.air, training.current_discipline());

    _ = training.rebuild(.water);
    try std.testing.expectEqual(AvatarDiscipline.water, training.current_discipline());

    _ = training.rollback();
    try std.testing.expectEqual(AvatarDiscipline.air, training.current_discipline());

    _ = training.rebuild(.earth);
    try std.testing.expectEqual(AvatarDiscipline.earth, training.current_discipline());

    _ = training.rollback();
    try std.testing.expectEqual(AvatarDiscipline.air, training.current_discipline());

    _ = training.rebuild(.earth);
    try std.testing.expectEqual(AvatarDiscipline.earth, training.current_discipline());
}
