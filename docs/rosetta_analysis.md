# Rosetta 2 Design Patterns for TigerStyle JIT

> Analysis of Apple's Rosetta 2 architecture and how its principles align with TigerStyle for the Grain RISC-V JIT.

## 1. Ahead-of-Time (AOT) Translation

**Rosetta 2**: Translates the entire executable at installation time (or first launch), rather than purely Just-In-Time. This eliminates runtime compilation overhead for the majority of code.

**TigerStyle Application**:
- **Principle**: "Do work upfront" and "Deterministic performance."
- **Grain JIT**: We can implement a **Pre-JIT** phase. When `init_with_jit` is called, instead of waiting for execution to hit a block, we can recursively follow branches from the entry point and compile all statically reachable code immediately.
- **Benefit**: Removes "warm-up" time and makes performance predictable (no random JIT pauses).

## 2. Hardware-Assisted Memory Ordering

**Rosetta 2**: Apple Silicon cores have a special mode to enforce Total Store Ordering (TSO) to match x86 behavior, preventing subtle concurrency bugs.

**TigerStyle Application**:
- **Principle**: "Safety first" and "Explicit constraints."
- **Grain JIT**: RISC-V has a weak memory model (RVWMO), similar to ARM. However, to ensure **deterministic debugging**, we can optionally emit `DMB` (Data Memory Barrier) instructions at block boundaries or volatile access points. This trades a small amount of performance for guaranteed ordering, reducing "heisenbugs."

## 3. Precise Exception Handling

**Rosetta 2**: Maintains precise state mapping to handle signals and exceptions exactly as the guest expects.

**TigerStyle Application**:
- **Principle**: "Assertions detect programmer errors."
- **Grain JIT**: We currently sync `GuestState` only on block exit or JIT call. To enhance safety, we can implement **Checkpoint Assertions**:
  - Before every memory store, assert that the address is within the valid guest RAM range (already done).
  - On any trap (e.g., invalid instruction), ensure the `GuestState` PC points exactly to the faulting instruction, allowing the interpreter fallback to handle it cleanly without state corruption.

## 4. Static Register Mapping

**Rosetta 2**: Statically maps x86 registers to specific ARM registers (e.g., RAX -> x0) to avoid expensive register allocation logic at runtime.

**TigerStyle Application**:
- **Principle**: "Static allocation" and "Simplicity."
- **Grain JIT**: We partially do this (`x27`=base, `x28`=state). We can go further by permanently mapping the most frequently used RISC-V registers (e.g., `sp`, `ra`, `a0`-`a7`) to fixed AArch64 registers globally, rather than allocating them per-block. This reduces the complexity of the `RegisterAllocator` and makes the JIT code easier to reason about.

## 5. 4KB Page Emulation

**Rosetta 2**: Emulates x86 4KB pages on ARM (which historically used 16KB on iOS) to ensure compatibility.

**TigerStyle Application**:
- **Principle**: "Explicit limits."
- **Grain JIT**: Our `SoftTLB` enforces 4KB page granularity. We should strictly maintain this and assert alignment everywhere. The `SoftTLB` design is already very "TigerStyle" (fixed size, direct mapped, no dynamic resizing).

## Recommendation for Next Steps

1. **Implement Global Register Mapping**: Pin RISC-V `sp` (x2) to AArch64 `x20` and `ra` (x1) to `x21` to simplify stack operations.
2. **Explore Pre-JIT**: Add a `compile_all_reachable()` function to `JitContext` to pre-compile the kernel entry point.
