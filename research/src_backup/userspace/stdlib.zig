//! Minimal Standard Library for Grain Basin Userspace
//! Why: Provide syscall wrappers and basic functionality for Zig programs running in VM.
//! Grain Style: Comprehensive contracts, explicit types, input/output validation.

const std = @import("std");

/// Syscall numbers (must match kernel/basin_kernel.zig).
/// Why: Explicit syscall enumeration for type safety.
pub const Syscall = enum(u32) {
    // Process & Thread Management
    spawn = 1,
    exit = 2,
    yield = 3,
    wait = 4,

    // Memory Management
    map = 10,
    unmap = 11,
    protect = 12,

    // Inter-Process Communication
    channel_create = 20,
    channel_send = 21,
    channel_recv = 22,

    // I/O Operations
    open = 30,
    read = 31,
    write = 32,
    close = 33,
    unlink = 34,
    rename = 35,
    mkdir = 36,
    opendir = 37,
    readdir = 38,
    closedir = 39,

    // Time & Scheduling
    clock_gettime = 40,
    sleep_until = 41,

    // System Information
    sysinfo = 50,
};

/// Make a syscall (RISC-V convention: syscall number in a7, args in a0-a3, result in a0).
/// Contract:
///   Input: syscall_num must be valid Syscall enum value, args are syscall-specific
///   Output: Returns u64 result (negative for errors, non-negative for success)
///   Errors: Invalid syscall number, invalid arguments
/// Why: Low-level syscall interface for userspace programs.
/// Note: This uses inline assembly to emit ECALL instruction.
pub fn syscall(
    syscall_num: Syscall,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) u64 {
    // Contract: syscall_num must be valid enum value.
    const syscall_val = @intFromEnum(syscall_num);

    // RISC-V syscall convention: ECALL with syscall number in a7 (x17), args in a0-a3 (x10-x13)
    // Inline assembly: load syscall number into a7, args into a0-a3, execute ECALL, result in a0
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> u64),
        : [syscall] "{x17}" (syscall_val),
          [arg1] "{x10}" (arg1),
          [arg2] "{x11}" (arg2),
          [arg3] "{x12}" (arg3),
          [arg4] "{x13}" (arg4),
        : .{ .memory = true }
    );
}

/// Exit the current process.
/// Contract:
///   Input: exit_code is the process exit status
///   Output: Never returns (process terminates)
/// Why: Clean process termination.
pub fn exit(exit_code: u32) noreturn {
    _ = syscall(.exit, exit_code, 0, 0, 0);
    // Should never return, but if it does, loop forever
    while (true) {}
}

/// Write data to a file handle.
/// Contract:
///   Input: handle must be valid file handle, data must be valid slice
///   Output: Returns number of bytes written, or negative error code
///   Errors: Invalid handle, permission denied, out of memory
/// Why: File I/O for userspace programs.
pub fn write(handle: u32, data: []const u8) i64 {
    // Contract: data.len must be reasonable (prevent overflow).
    if (data.len > 0x7FFFFFFF) {
        return -2; // invalid_argument (length too large)
    }

    // Contract: len must be <= data.len (implicitly true for slice).
    const result = syscall(.write, handle, @intFromPtr(data.ptr), data.len, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Read data from a file handle.
/// Contract:
///   Input: handle must be valid file handle, buffer must be valid slice
///   Output: Returns number of bytes read, or negative error code
///   Errors: Invalid handle, permission denied, end of file
/// Why: File I/O for userspace programs.
pub fn read(handle: u32, buffer: []u8) i64 {
    // Contract: buffer.len must be reasonable (prevent overflow).
    if (buffer.len > 0x7FFFFFFF) {
        return -2; // invalid_argument (length too large)
    }

    // Contract: len must be <= buffer.len (implicitly true for slice).
    const result = syscall(.read, handle, @intFromPtr(buffer.ptr), buffer.len, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Open a file.
/// Contract:
///   Input: path must be null-terminated string, flags must be valid
///   Output: Returns file handle (non-negative), or negative error code
///   Errors: File not found, permission denied, out of memory
/// Why: File system access for userspace programs.
pub fn open(path: [*:0]const u8, flags: u32) i64 {
    // Calculate path length (null-terminated string).
    var len: u64 = 0;
    while (path[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 4096) {
            return -2; // invalid_argument (path too long)
        }
    }

    const result = syscall(.open, @intFromPtr(path), len, flags, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Close a file handle.
/// Contract:
///   Input: handle must be valid file handle
///   Output: Returns 0 on success, or negative error code
///   Errors: Invalid handle
/// Why: Resource cleanup for userspace programs.
pub fn close(handle: u32) i64 {
    const result = syscall(.close, handle, 0, 0, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Unlink (delete) a file.
/// Contract:
///   Input: path must be null-terminated string
///   Output: Returns 0 on success, or negative error code
///   Errors: File not found, permission denied
/// Why: File deletion for userspace programs.
pub fn unlink(path: [*:0]const u8) i64 {
    // Calculate path length (null-terminated string).
    var len: u64 = 0;
    while (path[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 4096) {
            return -2; // invalid_argument (path too long)
        }
    }

    const result = syscall(.unlink, @intFromPtr(path), len, 0, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Rename a file or directory.
/// Contract:
///   Input: old_path and new_path must be null-terminated strings
///   Output: Returns 0 on success, or negative error code
///   Errors: File not found, permission denied
/// Why: File renaming/moving for userspace programs.
pub fn rename(old_path: [*:0]const u8, new_path: [*:0]const u8) i64 {
    // Calculate old path length (null-terminated string).
    var old_len: u64 = 0;
    while (old_path[old_len] != 0) : (old_len += 1) {
        // Bounds check (prevent infinite loop).
        if (old_len >= 4096) {
            return -2; // invalid_argument (path too long)
        }
    }

    // Calculate new path length (null-terminated string).
    var new_len: u64 = 0;
    while (new_path[new_len] != 0) : (new_len += 1) {
        // Bounds check (prevent infinite loop).
        if (new_len >= 4096) {
            return -2; // invalid_argument (path too long)
        }
    }

    const result = syscall(.rename, @intFromPtr(old_path), old_len, @intFromPtr(new_path), new_len);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Create a directory.
/// Contract:
///   Input: path must be null-terminated string
///   Output: Returns 0 on success, or negative error code
///   Errors: Directory already exists, permission denied
/// Why: Directory creation for userspace programs.
pub fn mkdir(path: [*:0]const u8) i64 {
    // Calculate path length (null-terminated string).
    var len: u64 = 0;
    while (path[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 4096) {
            return -2; // invalid_argument (path too long)
        }
    }

    const result = syscall(.mkdir, @intFromPtr(path), len, 0, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Open a directory.
/// Contract:
///   Input: path must be null-terminated string
///   Output: Returns directory handle (non-negative), or negative error code
///   Errors: Directory not found, permission denied
/// Why: Directory access for userspace programs.
pub fn opendir(path: [*:0]const u8) i64 {
    // Calculate path length (null-terminated string).
    var len: u64 = 0;
    while (path[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 256) {
            return -2; // invalid_argument (path too long)
        }
    }

    const result = syscall(.opendir, @intFromPtr(path), len, 0, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Read a directory entry.
/// Contract:
///   Input: dir_handle must be valid directory handle, entry_buffer must be valid slice
///   Output: Returns number of bytes written to buffer, or 0 if end of directory, or negative error code
///   Errors: Invalid handle, permission denied
/// Why: Directory listing for userspace programs.
pub fn readdir(dir_handle: u32, entry_buffer: []u8) i64 {
    // Contract: entry_buffer.len must be reasonable (prevent overflow).
    if (entry_buffer.len > 0x7FFFFFFF) {
        return -2; // invalid_argument (length too large)
    }

    const result = syscall(.readdir, dir_handle, @intFromPtr(entry_buffer.ptr), entry_buffer.len, 0);

    // Convert u64 result to i64 (negative = error, 0 = end of directory, positive = bytes written)
    return @as(i64, @bitCast(result));
}

/// Close a directory handle.
/// Contract:
///   Input: dir_handle must be valid directory handle
///   Output: Returns 0 on success, or negative error code
///   Errors: Invalid handle
/// Why: Resource cleanup for userspace programs.
pub fn closedir(dir_handle: u32) i64 {
    const result = syscall(.closedir, dir_handle, 0, 0, 0);

    // Convert u64 result to i64 (negative = error, non-negative = success)
    return @as(i64, @bitCast(result));
}

/// Write a string to stdout (handle 1).
/// Contract:
///   Input: str must be non-null, null-terminated string
///   Output: Returns number of bytes written, or negative error code
/// Why: Convenience function for printing to stdout.
pub fn print(str: [*:0]const u8) i64 {
    // Calculate string length (null-terminated).
    var len: u64 = 0;
    while (str[len] != 0) : (len += 1) {
        // Bounds check (prevent infinite loop).
        if (len >= 4096) {
            return -2; // invalid_argument (string too long)
        }
    }

    // Write to stdout (handle 1).
    const stdout_handle: u32 = 1;
    return write(stdout_handle, str[0..len]);
}

/// Minimal stdio module (stub for now).
pub const io = struct {
    /// Standard output handle (stdout).
    pub const stdout_handle: u32 = 1;

    /// Standard error handle (stderr).
    pub const stderr_handle: u32 = 2;

    /// Standard input handle (stdin).
    pub const stdin_handle: u32 = 0;
};
