const std = @import("std");

pub const Mode = enum { none, darkroom };

pub fn apply(mode: Mode, pixels: []u8) void {
    if (mode == .none) return;
    if (pixels.len % 4 != 0) return;

    var i: usize = 0;
    while (i < pixels.len) : (i += 4) {
        const r = pixels[i];
        const g = pixels[i + 1];
        const b = pixels[i + 2];

        switch (mode) {
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

test "darkroom filter dims blue/green" {
    var buf = [_]u8{ 200, 180, 160, 255 };
    apply(.darkroom, &buf);
    try std.testing.expect(buf[0] > buf[1]);
    try std.testing.expect(buf[1] < 40);
    try std.testing.expect(buf[2] < 25);
}
