/// Pure Zig RISC-V64 emulator for kernel development.
/// Grain Style: Static allocation, comprehensive assertions, deterministic.
/// ~<~ Glow Earthbend: VM state is explicit, no hidden allocations.

pub const VM = @import("vm.zig").VM;
pub const loadKernel = @import("loader.zig").loadKernel;
pub const SerialOutput = @import("serial.zig").SerialOutput;
pub const handleSyscall = @import("syscall.zig").handleSyscall;
pub const Integration = @import("integration.zig").Integration;
pub const loadUserspaceELF = @import("integration.zig").loadUserspaceELF;

