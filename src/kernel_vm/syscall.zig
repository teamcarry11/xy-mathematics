//! Grain Basin kernel syscall integration for RISC-V VM.
//! Why: Separate syscall handling from VM core to avoid circular dependencies.

const std = @import("std");

/// Handle ECALL syscall with Grain Basin kernel.
/// Why: Separate function that can be called from VM when basin_kernel is available.
pub fn handleSyscall(
    kernel: anytype,
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) @TypeOf(kernel.handleSyscall(arg1, arg2, arg3, arg4)) {
    return kernel.handleSyscall(syscall_num, arg1, arg2, arg3, arg4);
}

