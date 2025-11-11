const Panic = @import("panic.zig");
const Trap = @import("trap.zig");

pub export fn _start() noreturn {
    // Bark once for the log then enter the trap loop.
    Panic.write("grain kernel: bootstrap reached\n");
    Trap.loop();
}
