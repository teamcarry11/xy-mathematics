# Test Fix Prompt for Aurora Dream & Grain Skate Agents

**File**: `docs/zyxsqb-2025-11-23-141218-pst-test-fix-prompt.md`  
**Date**: 2025-11-23 14:12:18 PST  
**From**: Vantage Basin Agent  
**To**: Aurora Dream Agent & Grain Skate Agent  
**Status**: Test Fix Request

---

## Summary

There are **2 test failures** in the build that need to be fixed. These are compilation errors in modules outside the VM/Kernel domain. Please fix these errors to ensure all tests pass.

**Current Test Status**: 133/135 tests passing (2 failures from other agents' work)

---

## Test Failures to Fix

### 1. Grain Terminal Module (Grain Skate Agent)

**Location**: `src/grain_terminal/`  
**Errors**: 8 compilation errors

**Issues**:
1. **`window.zig:2:27`**: Import path error - `import of file outside module path`
   ```zig
   const MacWindow = @import("../platform/macos_tahoe/window.zig");
   ```
   - **Fix**: Use proper module import path or add to build.zig module paths

2. **`window.zig:33:26`**: Import path error - `import of file outside module path`
   ```zig
   buffer: *@import("../grain_buffer.zig").GrainBuffer,
   ```
   - **Fix**: Use proper module import path or add to build.zig module paths

3. **`pane.zig:141:17`**: Unused variable - `local variable is never mutated`
   ```zig
   var right_pane = try Pane.init_leaf(...);
   ```
   - **Fix**: Use `const` instead of `var`, or actually use the variable

4. **`pane.zig:151:17`**: Unused variable - `local variable is never mutated`
   - **Fix**: Use `const` instead of `var`, or actually use the variable

5. **`plugin.zig:29:14`**: Syntax error - `expected '.', found ','`
   - **Fix**: Check syntax around line 29

6. **`session.zig:209:13`**: Pointless discard - `pointless discard of function parameter`
   - **Fix**: Remove `_ = param;` or actually use the parameter

7. **`terminal.zig:360:13`**: Pointless discard - `pointless discard of function parameter`
   - **Fix**: Remove `_ = param;` or actually use the parameter

8. **`window.zig:213:19`**: Unused local constant
   - **Fix**: Remove unused constant or use it

**GrainStyle Requirements**:
- Use `const` instead of `var` when variable is never mutated
- Remove pointless discards (either use the parameter or remove the discard)
- Fix import paths to use proper module system
- All compiler warnings must be resolved

---

### 2. Grain Skate Module (Grain Skate Agent)

**Location**: `src/grain_skate/`  
**Errors**: 5 compilation errors

**Issues**:
1. **`editor.zig:306:17`**: Pointless discard - `pointless discard of function parameter`
   - **Fix**: Remove `_ = param;` or actually use the parameter

2. **`editor.zig:319:17`**: Pointless discard - `pointless discard of function parameter`
   - **Fix**: Remove `_ = param;` or actually use the parameter

3. **`editor.zig:45:50`**: ArrayList API error - `struct 'array_list.Aligned([]const u8,null)' has no member named 'init'`
   - **Fix**: Update to Zig 0.15.2 ArrayList API
   - **Note**: Zig 0.15.2 changed ArrayList API - use `ArrayList([]const u8).init(allocator)` instead of `ArrayList([]const u8).init()`

4. **`storage_integration.zig:85:17`**: Pointless discard - `pointless discard of function parameter`
   - **Fix**: Remove `_ = param;` or actually use the parameter

5. **`block.zig:262:49`**: Comparison error - `comparison of '*anyopaque' with null`
   - **Fix**: Use proper null check for `*anyopaque` (cast to optional pointer or use `@ptrFromInt(0)` check)

**GrainStyle Requirements**:
- Remove pointless discards (either use the parameter or remove the discard)
- Update to Zig 0.15.2 API (ArrayList changes)
- Fix null comparisons for opaque pointers
- All compiler warnings must be resolved

---

### 3. Aurora LSP Test (Aurora Dream Agent)

**Location**: `tests/aurora_lsp_test.zig` or related  
**Error**: Test failure - `signal 6` (SIGABRT)

**Issue**:
- Test is crashing with signal 6 (SIGABRT)
- This typically indicates an assertion failure or abort call

**Fix**:
- Check for assertion failures in the test
- Verify allocator usage (no double-free, use-after-free)
- Check for null pointer dereferences
- Verify test setup/teardown is correct

**GrainStyle Requirements**:
- All assertions must be valid
- Proper error handling (no crashes)
- Static allocation where possible
- Bounded operations

---

## GrainStyle/TigerStyle Requirements

All fixes must follow **GrainStyle/TigerStyle** guidelines:

1. **Function Names**: `grain_case` (snake_case)
2. **Explicit Types**: Use `u32`/`u64` instead of `usize` where possible
3. **No Pointless Discards**: Either use the parameter or remove the discard
4. **Const vs Var**: Use `const` when variable is never mutated
5. **Zig 0.15.2 API**: Update to latest API (especially ArrayList)
6. **All Compiler Warnings**: Must be resolved (no warnings allowed)
7. **Assertions**: Minimum 2 assertions per function
8. **Max Function Length**: 70 lines per function
9. **Max Line Length**: 100 characters per line

---

## Testing

After fixing, verify with:
```bash
zig build test
```

**Target**: All 135 tests should pass (currently 133/135 passing)

---

## Coordination

**No Conflicts Expected**:
- These fixes are in separate domains (Grain Terminal, Grain Skate, Aurora LSP)
- VM/Kernel work is complete and doesn't conflict
- Fixes are isolated to specific modules

**Status After Fix**:
- All tests should pass
- No compilation errors
- GrainStyle compliance maintained

---

## Priority

**High Priority**: These are blocking the full test suite from passing. Please fix as soon as possible.

---

**Summary**: Fix 2 test failures (Grain Terminal + Grain Skate compilation errors, Aurora LSP test crash). Follow GrainStyle guidelines. Update to Zig 0.15.2 API where needed. All compiler warnings must be resolved.

