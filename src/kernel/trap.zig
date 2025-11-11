const Panic = @import("panic.zig");

pub fn loop() noreturn {
    Panic.write("grain kernel: entering trap loop\n");
    while (true) {}
}
