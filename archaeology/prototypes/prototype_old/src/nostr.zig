const std = @import("std");
const SimpleRng = @import("simple_rng.zig").SimpleRng;

pub const Npub = struct {
    /// Stored as `npub1` + 58 bech32 characters (lowercase alphanum minus 1/b/o).
    bytes: [63]u8,

    pub fn init(prefix: []const u8, payload: []const u8) !Npub {
        if (!std.mem.eql(u8, prefix, "npub1")) {
            return error.InvalidPrefix;
        }
        if (payload.len != 58) {
            return error.InvalidLength;
        }
        for (payload) |c| {
            if (!is_bech32_char(c)) return error.InvalidCharacter;
        }

        var out: [63]u8 = undefined;
        std.mem.copyForwards(u8, out[0..5], prefix);
        std.mem.copyForwards(u8, out[5..], payload);
        return .{ .bytes = out };
    }

    pub fn slice(self: *const Npub) []const u8 {
        return self.bytes[0..];
    }
};

pub fn random_npub(random: *SimpleRng) Npub {
    var payload: [58]u8 = undefined;
    for (payload[0..]) |*slot| {
        const idx = random.uint_less_than(u8, bech32_alphabet.len);
        slot.* = bech32_alphabet[idx];
    }
    return Npub.init("npub1", payload[0..]) catch unreachable;
}

const bech32_alphabet = "023456789acdefghjklmnpqrstuvwxyz";

fn is_bech32_char(c: u8) bool {
    return std.mem.indexOfScalar(u8, bech32_alphabet, c) != null;
}

test "generate 11 random npub keys" {
    var random = SimpleRng.init(0x5A11F00D);

    var tally: usize = 0;
    while (tally < 11) : (tally += 1) {
        var key = random_npub(&random);
        const slice = key.slice();
        try std.testing.expectEqual(@as(usize, 63), slice.len);
        try std.testing.expect(std.mem.startsWith(u8, slice, "npub1"));
        for (slice[5..]) |c| {
            try std.testing.expect(is_bech32_char(c));
        }
    }
}
