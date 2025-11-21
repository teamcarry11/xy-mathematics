/// SimpleRng: tiny linear congruential generator for fuzz/style tests.
///
/// TigerStyle prefers explicit determinism and no hidden allocations.
/// This helper centralizes the wrap-safe arithmetic shared between
/// timestamp fuzzing and npub generation.
pub const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        return .{ .state = seed };
    }

    fn next(self: *SimpleRng) u64 {
        self.state = self.state *% 6364136223846793005 +% 1;
        return self.state;
    }

    pub fn boolean(self: *SimpleRng) bool {
        return (self.next() & 1) == 1;
    }

    pub fn range(self: *SimpleRng, comptime T: type, upper: T) T {
        return self.uint_less_than(T, upper);
    }

    pub fn uint_less_than(self: *SimpleRng, comptime T: type, bound: T) T {
        return @intCast(self.next() % @as(u64, bound));
    }
};
