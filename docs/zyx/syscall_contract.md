# Syscall Contract: Input/Output Specification

## Contract Definition

### `handle_syscall` Signature
```zig
pub fn handle_syscall(
    self: *BasinKernel,
    syscall_num: u32,
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
) BasinError!SyscallResult
```

**Return Type**: `BasinError!SyscallResult`
- **Error case**: Returns `BasinError` (for `handle_syscall`-level errors like invalid syscall number)
- **Success case**: Returns `SyscallResult` (from the handler)

### Syscall Handler Signature
```zig
fn syscall_*(self: *BasinKernel, arg1: u64, arg2: u64, arg3: u64, arg4: u64) BasinError!SyscallResult
```

**Return Type**: `BasinError!SyscallResult`
- **Error case**: Returns `BasinError` directly (propagated as error)
- **Success case**: Returns `SyscallResult` (either `.success` or `.err`)

### `SyscallResult` Union
```zig
pub const SyscallResult = union(enum) {
    success: u64,
    err: BasinError,
}
```

## Current Implementation Pattern

Looking at `syscall_map`:
- Returns `BasinError` directly for validation errors (e.g., `BasinError.invalid_argument`)
- Returns `SyscallResult.ok(value)` for success

This means:
- Handler returns `BasinError` → `handle_syscall` returns `BasinError` (error union error case)
- Handler returns `SyscallResult` → `handle_syscall` returns `SyscallResult` (error union success case)

## Test Pattern

Test 006 uses:
```zig
const result = kernel.handle_syscall(...) catch |err| {
    // Catches BasinError
    continue;
};
std.debug.assert(result == .success); // result is SyscallResult
```

This means:
- If handler returns `BasinError`, test catches it
- If handler returns `SyscallResult`, test gets it and checks `.success` or `.err`

## The Problem

Test 007 edge cases expect:
```zig
const result = kernel.handle_syscall(...) catch {
    @panic("handle_syscall returned BasinError, expected SyscallResult.err");
};
switch (result) {
    .success => @panic("Expected error"),
    .err => std.debug.assert(err == BasinError.permission_denied),
}
```

But handlers return `BasinError.permission_denied` directly, which means:
- `handle_syscall` returns `BasinError.permission_denied` (error case)
- Test catches it and panics "expected SyscallResult.err"

## Solution: Consistent Contract

**Handlers should return `SyscallResult` for ALL cases:**
- Success: `SyscallResult.ok(value)`
- Error: `SyscallResult.fail(BasinError)`

**NOT** `BasinError` directly.

This ensures:
- `handle_syscall` always returns `SyscallResult` (success case of error union)
- Tests can always use `catch` then `switch` on `SyscallResult`
- Only `handle_syscall` itself returns `BasinError` (for invalid syscall number, etc.)

