# Runtime Error Fix Progress

**Date**: 2025-11-23  
**Issue**: Signal 4 (SIGILL) and Signal 6 (SIGABRT) errors in tests  
**Root Cause**: `RawIO.write_byte()` tries to access hardware UART at `0x10000000` which doesn't exist in test environment

## Solution

Added `RawIO.disable()` / `RawIO.enable()` mechanism to allow tests to disable hardware access.

### Changes Made

1. **`src/kernel/raw_io.zig`**:
   - Added `raw_io_enabled` global flag
   - Added `disable()` and `enable()` functions
   - Modified `write()` and `write_byte()` to check flag before accessing hardware

2. **`src/kernel/basin_kernel.zig`**:
   - Exported `RawIO` module for tests to access

3. **Test Files Updated** (added `RawIO.disable()` / `defer RawIO.enable()`):
   - ✅ `tests/022_process_scheduler_test.zig`
   - ✅ `tests/024_process_elf_test.zig`
   - ✅ `tests/047_terminal_kernel_integration_test.zig`
   - ✅ `tests/020_timer_driver_test.zig` (3 tests)
   - ✅ `tests/025_storage_filesystem_test.zig` (2 tests)
   - ✅ `tests/026_keyboard_mouse_driver_test.zig`
   - ✅ `tests/029_trap_handler_test.zig`
   - ✅ `tests/027_memory_allocator_test.zig`
   - ✅ `tests/028_boot_sequence_test.zig` (1 test, 4 more needed)

### Remaining Work

Need to add `RawIO.disable()` to all remaining tests that call `BasinKernel.init()`:
- `tests/028_boot_sequence_test.zig` - 4 more tests
- Any other tests that call `BasinKernel.init()` without RawIO.disable()

### Test Status

- **Before**: 169/171 tests passing (2 runtime failures)
- **Current**: 149/151 tests passing (some tests may have been re-enabled)
- **Target**: All tests passing

### Pattern for Fixing Tests

```zig
const RawIO = basin_kernel.RawIO;

test "test name" {
    // Disable RawIO to avoid SIGILL in tests.
    RawIO.disable();
    defer RawIO.enable();
    
    var kernel = BasinKernel.init();
    // ... rest of test
}
```

