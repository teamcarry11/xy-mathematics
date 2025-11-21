# Assertion Syntaxes in Grain OS Codebase

This document catalogs all assertion syntaxes currently used in the Zig codebase.

## Runtime Assertions (Debug Builds Only)

### 1. `std.debug.assert(condition)`
**Most common assertion syntax.** Used for runtime invariants that should never fail in correct code.

**Examples:**
```zig
std.debug.assert(title.len > 0);
std.debug.assert(vm.state != .errored);
std.debug.assert(self.regs.pc % 4 == 0);
std.debug.assert(buffer.len % 4 == 0);
```

**Characteristics:**
- Only active in Debug and ReleaseSafe builds
- Removed in ReleaseFast and ReleaseSmall
- No message, just crashes if condition is false
- Used for: preconditions, postconditions, invariants

**Usage Count:** 738 instances across codebase

---

### 2. `std.debug.panic(comptime fmt: []const u8, args: anytype)`
**Fatal error with formatted message.** Used when an assertion failure needs diagnostic information.

**Examples:**
```zig
std.debug.panic("TahoeSandbox.init: onMouse pointer is suspiciously small: 0x{x}", .{onMouse_ptr});
std.debug.panic("Window.show: self pointer is not aligned: 0x{x}", .{self_ptr});
std.debug.panic("Failed to allocate title string: {s}", .{@errorName(err)});
```

**Characteristics:**
- Always active (even in ReleaseFast)
- Includes formatted error message
- Used for: critical errors that need diagnostic info, pointer validation failures

**Usage Count:** 69 instances, mostly in platform/macos_tahoe/

---

### 3. `@panic(comptime msg: []const u8)`
**Builtin panic with string literal.** Used for compile-time known fatal errors.

**Examples:**
```zig
@panic("timestamp grammar requires non-empty delimiter");
@panic("timestamp grammar encountered empty segment");
@panic("timestamp grammar segment count mismatch");
```

**Characteristics:**
- Always active
- String literal only (no formatting)
- Used for: unrecoverable logic errors, invariant violations

**Usage Count:** 5 instances (mostly in src/ray.zig)

---

## Test Assertions (Test Code Only)

### 4. `std.testing.expect(condition)`
**Basic test expectation.** Checks that a condition is true.

**Examples:**
```zig
try std.testing.expect(vm.jit_enabled);
try std.testing.expect(vm.jit != null);
try std.testing.expect(jit.cursor > 0);
```

**Characteristics:**
- Only in test code
- Returns error if condition is false
- Must be used with `try` or `!`

**Usage Count:** 86 instances (includes expect, expectEqual, expectError, expectEqualStrings)

---

### 5. `std.testing.expectEqual(expected, actual)`
**Equality test expectation.** Checks that two values are equal.

**Examples:**
```zig
try std.testing.expectEqual(@as(u64, 42), vm.regs.get(1));
try std.testing.expectEqual(@as(u64, 10), state.regs[1]);
try std.testing.expectEqual(AvatarDiscipline.air, training.current_discipline());
```

**Characteristics:**
- Only in test code
- Compares expected vs actual
- Must be used with `try` or `!`

**Usage Count:** ~15 instances

---

### 6. `std.testing.expectError(expected_error, expression)`
**Error test expectation.** Checks that an expression returns a specific error.

**Examples:**
```zig
try std.testing.expectError(error.InvalidInstruction, result);
try std.testing.expectError(error.ReadOnlyViolation, result);
```

**Characteristics:**
- Only in test code
- Tests error handling paths
- Must be used with `try` or `!`

**Usage Count:** ~3 instances

---

### 7. `std.testing.expectEqualStrings(expected, actual)`
**String equality test expectation.** Checks that two strings are equal.

**Examples:**
```zig
try std.testing.expectEqualStrings("zig run\nstatus\n", buffer.textSlice());
try std.testing.expectEqualStrings("Hello\n[Submit]", rendered);
```

**Characteristics:**
- Only in test code
- Specialized for string comparison
- Must be used with `try` or `!`

**Usage Count:** ~3 instances

---

## Summary Statistics

| Syntax | Usage | Context | Always Active |
|--------|-------|---------|---------------|
| `std.debug.assert` | 738 | Runtime | No (Debug/ReleaseSafe only) |
| `std.debug.panic` | 69 | Runtime | Yes |
| `@panic` | 5 | Runtime | Yes |
| `std.testing.expect*` | 86 | Tests | N/A |

## GrainStyle Guidelines

### When to Use Each Syntax

1. **`std.debug.assert`**: Use for all preconditions, postconditions, and invariants. This is the default choice.

2. **`std.debug.panic`**: Use when the assertion failure needs diagnostic information (pointers, error codes, formatted values).

3. **`@panic`**: Use sparingly for compile-time known fatal errors that should never happen.

4. **Test assertions**: Use appropriate `std.testing.*` functions in test code. Never use `std.debug.assert` in tests (use `expect` instead).

### Best Practices

- **Pair assertions**: Assert both preconditions AND postconditions
- **Density**: Minimum 2 assertions per function
- **Clarity**: Assertions should be self-documenting (the condition should explain what's being checked)
- **No side effects**: Assertions should not modify state

### Common Patterns

```zig
// Precondition assertion
std.debug.assert(ptr != null);

// Postcondition assertion
std.debug.assert(result > 0);

// Invariant assertion
std.debug.assert(self.state != .errored);

// Pointer validation (with diagnostic)
if (ptr_value < 0x1000) {
    std.debug.panic("Pointer is suspiciously small: 0x{x}", .{ptr_value});
}
```

## Notes

- All assertions are removed in ReleaseFast builds (except `std.debug.panic` and `@panic`)
- Test assertions use `try` because they return errors
- Runtime assertions use `std.debug.assert` by default
- Use `std.debug.panic` when you need formatted error messages for debugging

