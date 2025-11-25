/// Pure Zig RISC-V64 emulator for kernel development.
/// Grain Style: Static allocation, comprehensive assertions, deterministic.
/// ~<~ Glow Earthbend: VM state is explicit, no hidden allocations.

pub const VM = @import("vm.zig").VM;
pub const VMError = @import("vm.zig").VM.VMError;
pub const FramebufferDirtyRegion = @import("vm.zig").FramebufferDirtyRegion;
pub const loadKernel = @import("loader.zig").loadKernel;
pub const SerialOutput = @import("serial.zig").SerialOutput;
pub const handleSyscall = @import("syscall.zig").handleSyscall;
pub const Integration = @import("integration.zig").Integration;
pub const loadUserspaceELF = @import("integration.zig").loadUserspaceELF;
pub const performance = @import("performance.zig");
pub const error_log = @import("error_log.zig");
pub const state_snapshot = @import("state_snapshot.zig");
pub const exception_stats = @import("exception_stats.zig");
pub const memory_stats = @import("memory_stats.zig");
pub const instruction_stats = @import("instruction_stats.zig");
pub const syscall_stats = @import("syscall_stats.zig");
pub const execution_flow = @import("execution_flow.zig");
pub const stats_aggregator = @import("stats_aggregator.zig");
pub const branch_stats = @import("branch_stats.zig");
pub const register_stats = @import("register_stats.zig");

