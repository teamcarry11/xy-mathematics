# VM Memory Configuration: RAM-Aware Development

**Date**: 2025-11-13  
**Purpose**: Document VM memory size configuration and RAM constraints for development and target hardware

## Hardware Constraints

### Development Machine
- **MacBook Air M2 2022**: 24GB RAM
- **Usage**: macOS Tahoe IDE + VM for kernel development
- **Available for VM**: Plenty of headroom (24GB total)

### Target Hardware
- **Framework 13 DeepComputing RISC-V**: 8GB RAM
- **Usage**: Production kernel running on real hardware
- **Available for kernel**: Must be conservative (8GB total, shared with userspace)

## VM Memory Configuration

### Current Default: 4MB

**Why 4MB?**
- **Safe for both machines**: 4MB is negligible on 24GB dev machine, safe on 8GB target
- **Sufficient for early kernel development**: Boot code, initial syscalls, basic memory management
- **Stack-friendly**: Static allocation doesn't cause stack overflow (as we learned from tests)
- **Fast initialization**: Small memory footprint means fast VM startup

**What fits in 4MB?**
- Kernel code: ~100KB-500KB (early boot, basic syscalls)
- Kernel data: ~100KB-500KB (page tables, process structures)
- Test programs: ~10KB-100KB each
- **Total**: Well within 4MB for early development

### When to Increase

**Consider increasing to 16MB-64MB if:**
- Testing larger kernel features (file systems, network stacks)
- Running multiple test programs simultaneously
- Testing memory-intensive operations (large allocations, page tables)
- Kernel grows beyond ~1MB

**Max Recommended: 64MB**
- **Dev machine**: Still only 0.27% of 24GB (negligible)
- **Target machine**: Only 0.8% of 8GB (safe, but be mindful)
- **Rationale**: Allows larger kernel testing while staying conservative

### Configuration

VM memory size is configured via `VM_MEMORY_SIZE` constant in `src/kernel_vm/vm.zig`:

```zig
/// VM memory configuration.
/// Why: Centralized memory size configuration for RAM-aware development.
/// Note: Development machine (MacBook Air M2): 24GB RAM
///       Target hardware (Framework 13 RISC-V): 8GB RAM
///       Default: 4MB (safe for both, sufficient for early kernel development)
///       Max recommended: 64MB (works on both machines, allows larger kernel testing)
pub const VM_MEMORY_SIZE: usize = 4 * 1024 * 1024; // 4MB default
```

**To change**: Modify `VM_MEMORY_SIZE` constant and rebuild.

## Memory Layout (4MB Default)

```
0x000000 - 0x0FFFFF: Kernel space (1MB)
  - Kernel code: 0x100000 - 0x200000 (typical)
  - Kernel data: 0x200000 - 0x300000 (typical)
0x100000 - 0x3FFFFF: User space (3MB)
  - User programs: 0x100000+ (load address)
  - User data: 0x200000+ (typical)
```

**Note**: Actual layout depends on kernel design. This is a typical RISC-V layout.

## Production Considerations

**On Framework 13 RISC-V (8GB RAM):**
- **Kernel memory**: Should be minimal (~1-4MB for early kernel)
- **Userspace**: Remaining ~8GB available for applications
- **VM testing**: Use 4MB-64MB for development, matches production constraints

**Memory Management Strategy:**
- **Static allocation**: Kernel uses static buffers where possible (no allocator overhead)
- **Page-based**: Kernel manages memory in 4KB pages (RISC-V standard)
- **Conservative**: Allocate only what's needed, free immediately when done

## Tiger Style Principles

1. **Explicit allocation**: No hidden allocations, all memory usage visible
2. **Static where possible**: Use compile-time sizes, avoid dynamic allocation
3. **Bounds checking**: All memory accesses validated (assertions, bounds checks)
4. **RAM-aware**: Design for 8GB target, test on 24GB dev machine
5. **Conservative defaults**: Start small (4MB), increase only when needed

## Future Considerations

**If kernel grows beyond 4MB:**
- Increase `VM_MEMORY_SIZE` to 16MB or 64MB
- Update kernel memory layout documentation
- Ensure production kernel stays minimal (< 4MB ideally)
- Consider dynamic allocation for VM (if needed for very large kernels)

**If target hardware changes:**
- Update `VM_MEMORY_SIZE` documentation
- Re-evaluate memory limits
- Ensure VM matches target hardware constraints

