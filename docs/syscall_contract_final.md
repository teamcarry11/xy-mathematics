# Syscall Contract: Final Implementation

## Contract Definition

### `handle_syscall` Signature
```zig
pub fn handle_syscall(...) BasinError!SyscallResult
```

**Return Type**: `BasinError!SyscallResult`
- **Error case**: Returns `BasinError` (for `handle_syscall`-level errors like invalid syscall number)
- **Success case**: Returns `SyscallResult` (from the handler)

### Syscall Handler Contract

**All handlers MUST return `SyscallResult` for ALL cases:**
- **Success**: `SyscallResult.ok(value)`
- **Error**: `SyscallResult.fail(BasinError)`

**NOT** `BasinError` directly.

This ensures:
- `handle_syscall` always returns `SyscallResult` (success case of error union)
- Tests can always use `catch` then `switch` on `SyscallResult`
- Only `handle_syscall` itself returns `BasinError` (for invalid syscall number, etc.)

### Test Pattern

```zig
const result = kernel.handle_syscall(...) catch {
    // Catches BasinError from handle_syscall (shouldn't happen for valid syscall)
    continue;
};

switch (result) {
    .success => |value| {
        // Handle success
    },
    .err => |err| {
        // Handle error
    },
}
```

## Implementation Changes

### Before (Incorrect)
```zig
fn syscall_open(...) BasinError!SyscallResult {
    if (invalid) {
        return BasinError.invalid_argument; // ❌ Wrong - returns BasinError directly
    }
    return SyscallResult.ok(handle_id);
}
```

### After (Correct)
```zig
fn syscall_open(...) BasinError!SyscallResult {
    if (invalid) {
        return SyscallResult.fail(BasinError.invalid_argument); // ✅ Correct
    }
    return SyscallResult.ok(handle_id);
}
```

## Why This Matters

1. **Consistency**: All handlers follow the same pattern
2. **Type Safety**: Tests can always expect `SyscallResult` after `catch`
3. **Clarity**: Clear separation between `handle_syscall`-level errors and handler-level errors
4. **Testability**: Tests can handle both success and error cases uniformly

## Files Updated

- `src/kernel/basin_kernel.zig`: All file system handlers (open/read/write/close) now return `SyscallResult` for all cases
- `tests/007_fuzz.zig`: All tests updated to use `catch` then `switch` pattern

