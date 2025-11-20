const Panic = @import("panic.zig");
const Trap = @import("trap.zig");
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const Debug = @import("debug.zig");

// Global kernel instance
var kernel: BasinKernel = undefined;

pub export fn kmain() noreturn {
    // 1. Early boot banner
    Debug.kprint("\n", .{});
    Debug.kprint("   ______           _          ____  _____\n", .{});
    Debug.kprint("  / ____/________ _(_)___     / __ \\/ ___/\n", .{});
    Debug.kprint(" / / __/ ___/ __ `/ / __ \\   / / / /\\__ \\ \n", .{});
    Debug.kprint("/ /_/ / /  / /_/ / / / / /  / /_/ /___/ / \n", .{});
    Debug.kprint("\\____/_/   \\__,_/_/_/ /_/   \\____//____/  \n", .{});
    Debug.kprint("                                          \n", .{});
    Debug.kprint("Grain Basin Kernel v0.1.0 (RISC-V64)\n", .{});
    Debug.kprint("Copyright (c) 2025 Team Carry\n\n", .{});

    // 2. Initialize Kernel
    Debug.log(.info, "Initializing Basin...", .{});
    kernel = BasinKernel.init();
    
    Debug.log(.info, "Users initialized: {d}", .{kernel.user_count});

    Debug.log(.info, "System ready. Entering trap loop.", .{});

    // 3. Enter trap loop
    Trap.loop();
}
