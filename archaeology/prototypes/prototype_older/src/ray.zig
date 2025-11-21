const std = @import("std");

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
            .title = "Persona And Signals",
            .body =
                \\Glow G2: masculine, stoic, aquarian. Mic check “mic 1 2” confirmed.
                \\Letta surface: https://docs.letta.com/api-reference/overview.
                \\Contact set: Twitter @risc_love, email kj3x39@gmail.com.
                \\GPG 26F201F13AE3AFF90711006C1EE2C9E3486517CB.
                \\Testing ethos: Matklad “How to Test” data-driven refactors.
            ,
            .timestamp = canonical_timestamp,
        };

        const workflow = MetadataModule{
            .title = "Cursor ↔ Zig Workflow Covenant",
            .body =
                \\Alias /Users/bhagavan851c05a/xy as `xy`.
                \\Pipeline: Cursor Ultra Auto Mode → Z shell → Zig build → Native GUI output.
                \\English plans compile into deterministic Zig invocations with static allocation.
                \\Future work: replace python tweet slicer with Zig tool.
            ,
            .timestamp = canonical_timestamp,
        };

        const expedition = DataModule{
            .title = "Grain Expedition Data",
            .body =
                \\Mandate: veganic energy, zero runoff, District of Columbia PBC charter.
                \\Ledger: TigerBeetle-style Modern Monetary Theory flows plus Grain general storage.
                \\Networking: HTTP, WebSocket, Nostr, UDP in Zig with Tahoe-managed dotfiles.
                \\Team metaphor: @kae3g age 29, Aquarius rising, final acclimation lodge.
            ,
            .timestamp = canonical_timestamp,
        };

        const audit = MetadataModule{
            .title = "Audit And True Goals",
            .body =
                \\Audit: Jepsen-style deterministic sims, clock skew, disk corruption, flexible quorums.
                \\Goals: disciplined `xy` monorepo, ethical Grain infrastructure, reproducible docs, summit launch readiness.
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
            \\holocene_vedic_calendar--12025-11-09--2311--pst--
            \\tropical_zodiac_sidereal_sanskrit_nakshatra_astrology_
            \\ascendant-leo_15_degrees_out_of_thirty--
            \\moon_lunar_mansion_sanskrit_nakshatra_sutra_vic_dicara-
            \\punarvasu--whole_sign_diurnal_nocturnal_solar_house_system-
            \\4th_house--github_kae3g_xy
            ,
            TimestampGrammar.init("HoloceneVedicComposite", "--", 8, true),
        ),
    };
};
