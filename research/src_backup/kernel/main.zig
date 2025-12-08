const Panic = @import("panic.zig");
const Trap = @import("trap.zig");
const BasinKernel = @import("basin_kernel.zig").BasinKernel;
const Debug = @import("debug.zig");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const boot = @import("boot.zig");

// Global kernel instance
var kernel: BasinKernel = undefined;

// Global framebuffer (initialized in kmain)
// Why: Static allocation for framebuffer state.
var framebuffer: ?Framebuffer = null;

pub export fn kmain() noreturn {
    // 1. Early boot banner (serial output)
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
    
    // 3. Execute boot sequence (validate all subsystems initialized).
    // Why: Ensure all subsystems are initialized in correct order.
    boot.boot_kernel(&kernel);
    
    Debug.log(.info, "Users initialized: {d}", .{kernel.user_count});

    // 4. Initialize framebuffer (access at 0x90000000)
    // Why: Display boot messages and kernel output on screen.
    // Note: Framebuffer memory is mapped by VM at 0x90000000.
    // The kernel accesses it via store instructions, which the VM translates.
    // For now, framebuffer is initialized host-side by VM.init_framebuffer().
    // Kernel can write to it via store instructions to 0x90000000+ addresses.
    // Note: Direct pointer access in kernel requires unsafe code.
    // We'll use a syscall-based approach for kernel framebuffer access in the future.
    
    Debug.log(.info, "Framebuffer available at 0x90000000 (initialized by VM).", .{});
    Debug.log(.info, "System ready. Entering trap loop.", .{});

    // 5. Enter trap loop (handles interrupts and exceptions)
    // Why: Process pending interrupts and handle exceptions in main loop.
    Trap.loop_with_kernel(&kernel);
}
