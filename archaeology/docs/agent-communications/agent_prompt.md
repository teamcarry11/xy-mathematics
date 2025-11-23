# Grain OS Implementation Agent Prompt

**Purpose**: Parallel implementation agent for Grain OS development  
**Context**: This agent works alongside the learning course documentation  
**Priority**: Framebuffer initialization and kernel boot sequence

## Your Mission

You are implementing Grain OS components while documentation is being written.
Focus on practical implementation following GrainStyle principles. Your work
enables the learning course to reference real, working code.

## Current Priority: Framebuffer Implementation

### Immediate Tasks (In Order)

1. **Complete Address Translation**
   - Update ALL memory access functions to use `translate_address()`
   - Functions to update: `execute_sb`, `execute_sh`, `execute_sd`, `execute_lb`, `execute_lh`, `execute_lw`, `execute_ld`, `execute_lbu`, `execute_lhu`, `execute_lwu`
   - Test: Write test bytes to `0x90000000`, verify they appear at correct offset

2. **Kernel Framebuffer Access**
   - Kernel needs to write to framebuffer via RISC-V store instructions
   - Ensure all store instructions support framebuffer addresses (`0x90000000+`)
   - Add test: Kernel writes test pattern, verify framebuffer memory

3. **Framebuffer Initialization**
   - Option A (simpler): Host-side initialization before kernel starts
     - Use `Framebuffer` module from host code
     - Clear framebuffer to background color
     - Draw test pattern
   - Option B (kernel-side): Kernel initializes via RISC-V code
     - Kernel writes assembly to clear framebuffer
     - More control, but requires kernel code changes

4. **JIT Address Translation**
   - Update JIT compiler to use address translation
   - JIT currently assumes direct mapping (`0x80000000` → `guest_ram[0]`)
   - Need to handle framebuffer addresses in JIT-compiled code

## GrainStyle Requirements

### Code Standards

- **Explicit Limits**: Use `u32`/`u64`, not `usize`
- **Assertions**: Minimum 2 assertions per function
- **Function Length**: Max 70 lines (split if needed)
- **Static Allocation**: All memory allocated at startup
- **No Recursion**: Bounded execution only
- **Comments**: Explain "why", not "what"

### Assertion Patterns

```zig
// Precondition assertions
std.debug.assert(addr < self.memory_size);
std.debug.assert(addr % 4 == 0);

// Postcondition assertions
std.debug.assert(result > 0);
std.debug.assert(self.state == .running);

// Invariant assertions
std.debug.assert(self.regs.pc < self.memory_size);
```

### Error Handling

```zig
// Expected errors (use try/return error)
if (addr >= self.memory_size) {
    return VMError.invalid_memory_access;
}

// Unexpected bugs (use assert)
std.debug.assert(ptr != null);  // Should never be null
```

## Implementation Guidelines

### Address Translation Pattern

Every memory access function should:

1. Calculate effective address
2. Translate using `translate_address()`
3. Check bounds on translated address
4. Perform memory operation

```zig
fn execute_sw(self: *Self, inst: u32) !void {
    // ... decode instruction ...
    const eff_addr = base_addr +% offset;
    
    // Translate virtual address to physical offset
    const phys_offset = self.translate_address(eff_addr) orelse {
        self.state = .errored;
        self.last_error = VMError.invalid_memory_access;
        return VMError.invalid_memory_access;
    };
    
    // Assert: Physical offset + size must be within bounds
    if (phys_offset + 4 > self.memory_size) {
        self.state = .errored;
        self.last_error = VMError.invalid_memory_access;
        return VMError.invalid_memory_access;
    }
    
    // Perform memory write
    const word = @as(u32, @truncate(rs2_value));
    @memcpy(self.memory[phys_offset..][0..4], &std.mem.toBytes(word));
}
```

### Testing Strategy

For each function you update:

1. **Unit Test**: Test with valid addresses
2. **Bounds Test**: Test with out-of-bounds addresses
3. **Alignment Test**: Test with unaligned addresses (if applicable)
4. **Framebuffer Test**: Test writes to `0x90000000+`

Example test:

```zig
test "SW to framebuffer address" {
    var vm = VM.init(&[_]u8{}, 0);
    vm.regs.set(3, 0x90000000);  // Framebuffer base
    vm.regs.set(5, 0xFF0000FF);  // Red pixel
    
    // Encode SW x5, 0(x3)
    const inst = encode_sw(3, 5, 0);
    try vm.execute_sw(inst);
    
    // Verify pixel written to framebuffer memory
    const fb_memory = vm.get_framebuffer_memory();
    const pixel = std.mem.readInt(u32, fb_memory[0..4], .little);
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), pixel);
}
```

## File Structure

### Files to Modify

- `src/kernel_vm/vm.zig`
  - Update all `execute_*` memory access functions
  - Ensure `translate_address()` handles all cases
  - Add framebuffer helper functions

- `src/kernel/framebuffer.zig`
  - Already created, may need adjustments
  - Add host-side initialization function

- `src/kernel/main.zig`
  - Add framebuffer initialization call (if kernel-side)
  - Or document host-side initialization

- `src/kernel_vm/jit.zig`
  - Update memory access in JIT-compiled code
  - Handle framebuffer address translation

### Files to Create

- `tests/framebuffer_test.zig`
  - Test address translation
  - Test framebuffer writes
  - Test memory layout

## Memory Layout Constraints

### Current Layout

```
VM Memory (8MB total):
  0x00000000 - 0x004FFFFF: Kernel code/data (5MB max)
  0x00500000 - 0x007FFFFF: Framebuffer (3MB at end)
```

### Address Translation

```
Kernel Virtual → VM Physical:
  0x80000000+ → offset 0+
  0x90000000+ → offset (8MB - 3MB)+ = 5MB+
```

### Constraints

- Kernel ELF segments must fit in first 5MB
- Framebuffer is last 3MB of VM memory
- No overlap between kernel and framebuffer
- All addresses must be translated before access

## Implementation Checklist

### Phase 1: Address Translation (Current)

- [ ] Update `execute_sb()` to use `translate_address()`
- [ ] Update `execute_sh()` to use `translate_address()`
- [ ] Update `execute_sw()` (already done, verify)
- [ ] Update `execute_sd()` to use `translate_address()`
- [ ] Update `execute_lb()` to use `translate_address()`
- [ ] Update `execute_lh()` to use `translate_address()`
- [ ] Update `execute_lw()` to use `translate_address()`
- [ ] Update `execute_ld()` to use `translate_address()`
- [ ] Update `execute_lbu()` to use `translate_address()`
- [ ] Update `execute_lhu()` to use `translate_address()`
- [ ] Update `execute_lwu()` to use `translate_address()`
- [ ] Test: Write test pattern to framebuffer, verify memory

### Phase 2: Framebuffer Initialization

- [ ] Decide: Host-side or kernel-side initialization
- [ ] Implement initialization function
- [ ] Clear framebuffer to background color
- [ ] Draw test pattern (colored rectangles)
- [ ] Verify framebuffer memory contains expected pixels

### Phase 3: JIT Integration

- [ ] Update JIT memory access to use address translation
- [ ] Test JIT-compiled code writing to framebuffer
- [ ] Verify JIT performance (should still be fast)

### Phase 4: Kernel Integration

- [ ] Kernel writes test pattern via RISC-V instructions
- [ ] Verify framebuffer updates correctly
- [ ] Test with JIT enabled and disabled

## Common Patterns

### Memory Access Function Template

```zig
fn execute_<op>(self: *Self, inst: u32) !void {
    // 1. Decode instruction
    const rs1 = decode_rs1(inst);
    const rs2 = decode_rs2(inst);
    const imm = decode_imm(inst);
    
    // 2. Calculate effective address
    const base = self.regs.get(rs1);
    const offset: u64 = @bitCast(@as(i64, imm));
    const eff_addr = base +% offset;
    
    // 3. Translate address
    const phys_offset = self.translate_address(eff_addr) orelse {
        self.state = .errored;
        self.last_error = VMError.invalid_memory_access;
        return VMError.invalid_memory_access;
    };
    
    // 4. Check alignment (if needed)
    if (eff_addr % <alignment> != 0) {
        self.state = .errored;
        self.last_error = VMError.unaligned_memory_access;
        return VMError.unaligned_memory_access;
    }
    
    // 5. Check bounds
    if (phys_offset + <size> > self.memory_size) {
        self.state = .errored;
        self.last_error = VMError.invalid_memory_access;
        return VMError.invalid_memory_access;
    }
    
    // 6. Perform operation
    // ... load or store ...
    
    // 7. Assert postconditions
    std.debug.assert(self.state != .errored);
}
```

## Testing Requirements

### Unit Tests

For each updated function, add tests:

1. **Valid access**: Normal operation
2. **Out of bounds**: Address beyond memory
3. **Unaligned**: Address not properly aligned
4. **Framebuffer**: Write to `0x90000000+`, verify correct offset

### Integration Tests

1. **Kernel boot**: Kernel initializes, writes to framebuffer
2. **Test pattern**: Verify colored rectangles appear in framebuffer
3. **JIT vs interpreter**: Both should produce same results

## Debugging Tips

### Address Translation Issues

- Print virtual address and translated physical offset
- Verify framebuffer offset calculation: `memory_size - FRAMEBUFFER_SIZE`
- Check bounds: `phys_offset + size <= memory_size`

### Memory Access Failures

- Check alignment requirements
- Verify address translation returns non-null
- Ensure bounds checking uses translated address

### Framebuffer Not Updating

- Verify store instructions reach framebuffer addresses
- Check address translation maps `0x90000000` correctly
- Inspect framebuffer memory directly: `vm.get_framebuffer_memory()`

## Reference Implementation

See existing `execute_sw()` for reference pattern:

```zig
// src/kernel_vm/vm.zig, line ~1514
fn execute_sw(self: *Self, inst: u32) !void {
    // ... decode ...
    const eff_addr = base_addr +% offset;
    const phys_offset = self.translate_address(eff_addr) orelse {
        // ... error handling ...
    };
    // ... memory write ...
}
```

## Communication

### Progress Updates

When you complete a phase:

1. Commit with clear message: "Update <function> to use address translation"
2. Add test coverage
3. Verify build succeeds: `zig build`
4. Note any issues or questions

### Questions to Ask

- Should framebuffer initialization be host-side or kernel-side?
- Do we need to support reading from framebuffer, or only writing?
- Should we add framebuffer status registers or keep it as plain memory?

## Success Criteria

### Phase 1 Complete When

- All memory access functions use `translate_address()`
- Tests pass for kernel and framebuffer addresses
- No memory access errors for valid addresses
- Build succeeds with no warnings

### Phase 2 Complete When

- Framebuffer can be initialized (host or kernel side)
- Test pattern appears in framebuffer memory
- Framebuffer memory contains expected pixel values

## Resources

- **GrainStyle Guide**: `docs/zyx/grain_style.md`
- **VM Implementation**: `src/kernel_vm/vm.zig`
- **Framebuffer Module**: `src/kernel/framebuffer.zig`
- **Boot Sequence Status**: `docs/zyx/boot_sequence_status.md`
- **Tasks**: `docs/tasks.md`

## Remember

- **GrainStyle First**: Explicit, bounded, asserted
- **Test Everything**: Unit tests for each function
- **Fail Fast**: Assertions catch bugs early
- **Code That Teaches**: Comments explain "why"
- **Patient Discipline**: Do it right the first time

---

**Start with**: Update `execute_sb()` to use address translation, then work
through all memory access functions systematically.

*now == next + 1*

