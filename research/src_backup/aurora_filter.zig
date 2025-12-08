const std = @import("std");

pub const Mode = enum { none, darkroom };

pub const FluxState = struct {
    mode: Mode = .none,

    pub fn toggle(self: *FluxState, mode: Mode) void {
        self.mode = mode;
    }
};

pub fn apply(state: FluxState, pixels: []u8) void {
    if (state.mode == .none) return;
    if (pixels.len % 4 != 0) return;

    var i: usize = 0;
    while (i < pixels.len) : (i += 4) {
        const r = pixels[i];
        const g = pixels[i + 1];
        const b = pixels[i + 2];

        switch (state.mode) {
            .none => {},
            .darkroom => {
                const new_r = std.math.clamp(@as(i32, r) + 20, 0, 255);
                pixels[i] = @as(u8, @intCast(new_r));
                pixels[i + 1] = @divFloor(g, 6);
                pixels[i + 2] = @divFloor(b, 12);
            },
        }
    }
}

test "darkroom filter toggles" {
    var state = FluxState{};
    var buf = [_]u8{ 200, 180, 160, 255 };
    apply(state, &buf);
    try std.testing.expectEqual(@as(u8, 200), buf[0]);

    state.toggle(.darkroom);
    apply(state, &buf);
    try std.testing.expect(buf[0] > buf[1]);
    try std.testing.expect(buf[1] < 40);
    try std.testing.expect(buf[2] < 25);
}
