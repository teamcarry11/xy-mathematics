# Memory Management

**Prerequisites**: Virtual machine fundamentals (0003), address spaces  
**Focus**: Memory layout and address translation in Grain OS  
**GrainStyle**: Explicit bounds, static allocation, comprehensive checking

## Memory Models

### Flat Memory Model

Grain OS VM uses a **flat memory model** (no paging initially):

- Single contiguous address space
- Direct physical addressing
- Simple to implement and reason about

**Why Flat?**
- Simpler than paging (no page tables)
- Sufficient for kernel development
- Can add paging later if needed

### Virtual vs Physical Addresses

**Virtual Address**: What the kernel sees (`0x80000000+`, `0x90000000+`)

**Physical Address**: Actual offset in VM memory array (`0+`, `5MB+`)

**Translation**: Map virtual → physical for memory access

## Memory Layout

### Grain OS Layout

```
Virtual Address Space (Kernel View):
  0x00000000 - 0x7FFFFFFF: Reserved (not used)
  0x80000000 - 0x8FFFFFFF: Kernel code/data (128MB virtual)
  0x90000000 - 0x900BBFFF: Framebuffer (3MB)

Physical Memory (VM Array):
  0x00000000 - 0x004FFFFF: Kernel code/data (5MB max)
  0x00500000 - 0x007FFFFF: Framebuffer (3MB at end)
```

### Why This Layout?

**Kernel at 0x80000000**:
- RISC-V convention (high memory)
- Leaves low memory for userspace (future)
- Matches real RISC-V hardware expectations

**Framebuffer at 0x90000000**:
- Separate from kernel (clear boundary)
- Large address space (room for growth)
- Easy to identify (starts with 0x9)

## Address Translation

### Translation Function

```zig
fn translate_address(self: *const VM, virt_addr: u64) ?usize {
    const KERNEL_BASE: u64 = 0x80000000;
    const FRAMEBUFFER_BASE: u64 = 0x90000000;
    const FRAMEBUFFER_SIZE: u32 = 1024 * 768 * 4; // 3MB
    
    if (virt_addr >= FRAMEBUFFER_BASE) {
        // Framebuffer: map to end of VM memory
        const fb_offset = self.memory_size - FRAMEBUFFER_SIZE;
        const offset_in_fb = virt_addr - FRAMEBUFFER_BASE;
        
        if (offset_in_fb >= FRAMEBUFFER_SIZE) {
            return null;  // Out of framebuffer bounds
        }
        
        return fb_offset + @as(usize, @intCast(offset_in_fb));
    } else if (virt_addr >= KERNEL_BASE) {
        // Kernel: direct mapping (0x80000000 -> 0)
        const offset = virt_addr - KERNEL_BASE;
        if (offset >= self.memory_size) {
            return null;  // Out of memory bounds
        }
        return @as(usize, @intCast(offset));
    } else {
        // Low memory: direct mapping
        if (virt_addr >= self.memory_size) {
            return null;
        }
        return @as(usize, @intCast(virt_addr));
    }
}
```

**GrainStyle**: Explicit mapping rules, null for invalid addresses.

### Translation Examples

```zig
// Kernel code access
translate_address(0x80000000) → 0          // Kernel start
translate_address(0x80001000) → 0x1000     // Kernel + 4KB

// Framebuffer access
translate_address(0x90000000) → 0x00500000 // Framebuffer start (5MB)
translate_address(0x90000004) → 0x00500004 // First pixel + 4 bytes

// Invalid addresses
translate_address(0x900BBFFF + 1) → null  // Beyond framebuffer
translate_address(0xA0000000) → null       // Beyond memory
```

## Bounds Checking

### Why Bounds Checking?

- **Safety**: Prevent memory corruption
- **Debugging**: Catch bugs early
- **Correctness**: Ensure valid memory access

### Check Pattern

```zig
fn check_bounds(addr: u64, size: u32, memory_size: usize) bool {
    // Check: address + size must not overflow
    if (addr > std.math.maxInt(u64) - size) {
        return false;  // Overflow
    }
    
    // Check: address + size must be within memory
    if (addr + size > memory_size) {
        return false;  // Out of bounds
    }
    
    return true;  // Valid
}
```

**GrainStyle**: Explicit overflow checks, no undefined behavior.

### Alignment Checking

RISC-V requires natural alignment:

```zig
fn check_alignment(addr: u64, alignment: u32) bool {
    return addr % alignment == 0;
}

// Usage
if (!check_alignment(addr, 4)) {
    return VMError.unaligned_memory_access;
}
```

**Why Alignment?**
- Hardware requirement (unaligned access is slow or illegal)
- Simpler memory access logic
- Matches RISC-V specification

## Memory Access Functions

### Read Pattern

```zig
pub fn read32(self: *const VM, virt_addr: u64) VMError!u32 {
    // 1. Translate address
    const phys_offset = self.translate_address(virt_addr) orelse {
        return VMError.invalid_memory_access;
    };
    
    // 2. Check alignment
    if (virt_addr % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // 3. Check bounds
    if (phys_offset + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // 4. Read from memory
    const bytes = self.memory[phys_offset..][0..4];
    const value = std.mem.readInt(u32, bytes, .little);
    
    return value;
}
```

### Write Pattern

```zig
pub fn write32(self: *VM, virt_addr: u64, value: u32) VMError!void {
    // 1. Translate address
    const phys_offset = self.translate_address(virt_addr) orelse {
        return VMError.invalid_memory_access;
    };
    
    // 2. Check alignment
    if (virt_addr % 4 != 0) {
        return VMError.unaligned_memory_access;
    }
    
    // 3. Check bounds
    if (phys_offset + 4 > self.memory_size) {
        return VMError.invalid_memory_access;
    }
    
    // 4. Write to memory
    const bytes = self.memory[phys_offset..][0..4];
    std.mem.writeInt(u32, bytes, value, .little);
    
    // 5. Assert: verify write succeeded
    const read_back = try self.read32(virt_addr);
    std.debug.assert(read_back == value);
}
```

**GrainStyle**: Pair assertions (write then read back to verify).

## Framebuffer Memory Access

### Framebuffer Helper

```zig
pub fn get_framebuffer_memory(self: *VM) []u8 {
    const FRAMEBUFFER_SIZE: u32 = 1024 * 768 * 4; // 3MB
    const framebuffer_offset = self.memory_size - FRAMEBUFFER_SIZE;
    
    std.debug.assert(framebuffer_offset + FRAMEBUFFER_SIZE <= self.memory_size);
    
    return self.memory[framebuffer_offset..][0..FRAMEBUFFER_SIZE];
}
```

**Why Helper?**
- Encapsulates framebuffer location
- Host code can access directly (for rendering)
- Kernel accesses via store instructions (translated)

### Pixel Access

```zig
// Write pixel at (x, y) with color
fn write_pixel(vm: *VM, x: u32, y: u32, color: u32) void {
    const FRAMEBUFFER_WIDTH: u32 = 1024;
    const FRAMEBUFFER_BPP: u32 = 4; // RGBA
    
    std.debug.assert(x < FRAMEBUFFER_WIDTH);
    std.debug.assert(y < FRAMEBUFFER_HEIGHT);
    
    // Calculate pixel offset
    const pixel_offset = (y * FRAMEBUFFER_WIDTH + x) * FRAMEBUFFER_BPP;
    
    // Virtual address: framebuffer base + offset
    const virt_addr = FRAMEBUFFER_BASE + pixel_offset;
    
    // Write via VM (uses address translation)
    vm.write32(virt_addr, color) catch {
        std.debug.panic("Failed to write pixel", .{});
    };
}
```

## Memory Safety

### Static Allocation

All VM memory is statically allocated:

```zig
pub const VM_MEMORY_SIZE: usize = 8 * 1024 * 1024; // 8MB

pub const VM = struct {
    memory: [VM_MEMORY_SIZE]u8 = [_]u8{0} ** VM_MEMORY_SIZE,
    // ... other fields ...
};
```

**Why Static?**
- Predictable memory usage
- No allocator dependency
- Bounded execution guarantees
- Easier to reason about

### Bounds Guarantees

With static allocation, we can prove bounds:

```zig
// Assert: Memory size is constant
std.debug.assert(VM_MEMORY_SIZE == 8 * 1024 * 1024);

// Assert: All accesses are within bounds (if checked)
if (phys_offset + size > self.memory_size) {
    return VMError.invalid_memory_access;  // Caught!
}
```

**GrainStyle**: Explicit bounds, no hidden allocations.

## Memory Layout Constraints

### Kernel Size Limit

Kernel must fit in first 5MB (to leave room for framebuffer):

```
VM Memory (8MB):
  [0, 5MB):     Kernel code/data
  [5MB, 8MB):   Framebuffer
```

**Constraint**: Kernel ELF segments must not exceed 5MB

### Framebuffer Size

Framebuffer is fixed at 3MB:

```
1024 × 768 × 4 bytes = 3,145,728 bytes ≈ 3MB
```

**Why Fixed?**
- Simple implementation
- Matches display resolution
- Can resize later if needed

## Address Space Considerations

### 64-bit Addresses

RISC-V64 uses 64-bit addresses, but typically only 48 bits are used:

- **Virtual**: 48-bit effective (upper 16 sign-extended)
- **Physical**: Implementation-defined (we use 8MB flat)

### Address Validation

```zig
fn is_valid_virtual_address(addr: u64) bool {
    // Check: address must be in valid ranges
    if (addr >= 0x80000000 and addr < 0x90000000) {
        return true;  // Kernel region
    }
    if (addr >= 0x90000000 and addr < 0x90000000 + FRAMEBUFFER_SIZE) {
        return true;  // Framebuffer region
    }
    return false;  // Invalid
}
```

## Memory Access Patterns

### Sequential Access

```zig
// Clear framebuffer (sequential writes)
for (0..FRAMEBUFFER_SIZE / 4) |i| {
    const virt_addr = FRAMEBUFFER_BASE + @as(u64, i * 4);
    try vm.write32(virt_addr, COLOR_DARK_BG);
}
```

### Random Access

```zig
// Write pixel at random location
const x = rng.random().intRangeAtMost(u32, 0, FRAMEBUFFER_WIDTH - 1);
const y = rng.random().intRangeAtMost(u32, 0, FRAMEBUFFER_HEIGHT - 1);
const virt_addr = FRAMEBUFFER_BASE + calculate_pixel_offset(x, y);
try vm.write32(virt_addr, color);
```

## Performance Considerations

### Translation Overhead

Address translation adds overhead:

- **Function call**: `translate_address()`
- **Bounds checking**: Multiple comparisons
- **Cache misses**: Translation not cached

**Optimization**: Cache translations for hot addresses (future work)

### Memory Access Speed

VM memory access is slower than native:

- **Bounds checking**: Extra comparisons
- **Translation**: Address calculation
- **Array indexing**: Bounds-checked array access

**Mitigation**: JIT compilation (covered in 0004)

## Testing Memory Access

### Unit Tests

```zig
test "address translation kernel region" {
    var vm = VM.init(&[_]u8{}, 0);
    
    // Kernel address
    const virt = 0x80001000;
    const phys = vm.translate_address(virt);
    
    try std.testing.expect(phys != null);
    try std.testing.expectEqual(@as(usize, 0x1000), phys.?);
}

test "address translation framebuffer" {
    var vm = VM.init(&[_]u8{}, 0);
    
    // Framebuffer address
    const virt = 0x90000000;
    const phys = vm.translate_address(virt);
    
    try std.testing.expect(phys != null);
    try std.testing.expectEqual(@as(usize, 0x00500000), phys.?);
}
```

### Integration Tests

```zig
test "framebuffer write and read" {
    var vm = VM.init(&[_]u8{}, 0);
    
    // Write pixel
    const virt = 0x90000000;
    try vm.write32(virt, 0xFF0000FF);  // Red pixel
    
    // Read back
    const value = try vm.read32(virt);
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), value);
    
    // Verify in framebuffer memory
    const fb_mem = vm.get_framebuffer_memory();
    const pixel = std.mem.readInt(u32, fb_mem[0..4], .little);
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), pixel);
}
```

## Exercises

1. **Translation**: Calculate physical offset for virtual address `0x90000100`.

2. **Bounds**: Why check `addr + size` instead of just `addr`?

3. **Alignment**: What happens if we try to write a word to address `0x90000001`?

4. **Layout**: If kernel grows to 6MB, what happens to framebuffer?

## Key Takeaways

- Flat memory model: simple, direct addressing
- Virtual → physical translation: kernel sees virtual, VM uses physical
- Bounds checking: prevent memory corruption
- Alignment: required for word/doubleword access
- Static allocation: predictable, bounded
- Framebuffer: last 3MB of VM memory, mapped to `0x90000000+`

## Next Document

**0006-kernel-fundamentals.md**: Learn kernel architecture, boot sequence, and
system call interface.

---

*now == next + 1*

