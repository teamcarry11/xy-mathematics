# Matklad's "Almost Rules" Analysis for Grain Basin Kernel

**Date**: 2025-11-13  
**Source**: [Matklad, "Almost Rules"](https://matklad.github.io/2022/07/10/almost-rules.html)  
**Purpose**: Extract insights for Zig monolith TigerStyle RISC-V virtualization development

## Key Insights from Matklad's Post

### 1. Internal Boundaries Are Fragile

**Matklad's Point:**
- Internal boundaries (unlike external APIs) are easy to violate
- "Internal boundary" is often just informal rules like "module A shall not import module B"
- Hard to notice when boundaries are breached
- Boundaries crumble under feature pressure unless physically enforced

**Application to Our Project:**

**Our Internal Boundaries:**
- **SBI vs Kernel Syscalls**: Function ID < 10 → SBI, >= 10 → kernel
- **VM vs Kernel**: VM handles instruction emulation, kernel handles syscalls
- **GUI vs VM**: GUI displays VM state, VM executes kernel code
- **Tiger Style**: Comprehensive assertions, static allocation, <70 line functions

**How We Enforce Boundaries:**

1. **Physical Enforcement (Good):**
   - Separate modules: `src/kernel_vm/`, `src/kernel/`, `src/platform/`
   - Build system: Modules must explicitly import dependencies
   - Type system: Zig's type system enforces module boundaries

2. **Informal Rules (Fragile):**
   - Tiger Style guidelines (assertions, function length, etc.)
   - SBI vs kernel syscall dispatch (function ID < 10)
   - Static allocation preference

**Recommendation:**
- **Enforce boundaries physically where possible**: Use Zig's module system, type system
- **Document boundaries explicitly**: Clear comments explaining "why" boundaries exist
- **Validate boundaries**: Assertions, tests, build-time checks (grainwrap/grainvalidate)

### 2. Boundaries Help Understanding

**Matklad's Point:**
- Well-placed boundaries create "hourglass shape" - narrow interface, wide implementation
- Understanding just the boundary allows imagining subsystem implementation
- Mental map helps peel off glue code, find core logic

**Application to Our Project:**

**Our Hourglass Boundaries:**

```
┌─────────────────────────────────┐
│  GUI (macOS Tahoe)              │  Wide: Full GUI implementation
└─────────────────────────────────┘
              ↕ (narrow interface)
┌─────────────────────────────────┐
│  VM (RISC-V Emulator)           │  Wide: Instruction emulation
└─────────────────────────────────┘
              ↕ (narrow interface: ECALL)
┌─────────────────────────────────┐
│  Kernel (Grain Basin)           │  Wide: Kernel services
└─────────────────────────────────┘
              ↕ (narrow interface: SBI)
┌─────────────────────────────────┐
│  Platform (SBI)                 │  Wide: Platform services
└─────────────────────────────────┘
```

**Benefits:**
- **Clear separation**: Each layer has clear responsibility
- **Easy to understand**: Can understand VM without knowing kernel details
- **Easy to test**: Can test VM independently of kernel
- **Easy to replace**: Could swap kernel without changing VM

**Recommendation:**
- **Maintain narrow interfaces**: ECALL dispatch, SBI calls, VM-GUI interface
- **Document boundaries**: Clear "why" comments explaining boundaries
- **Keep interfaces stable**: Don't violate boundaries for "quick fixes"

### 3. External vs Internal Boundaries

**Matklad's Point:**
- External boundaries (user-facing APIs) are protected by semver/backwards compatibility
- Internal boundaries are "ever in danger of being violated"
- Microservices reify internal boundaries as processes (physical enforcement)

**Application to Our Project:**

**Our External Boundaries:**
- **Kernel Syscall Interface**: User applications call kernel syscalls
- **SBI Interface**: Kernel calls SBI functions (standard RISC-V)
- **VM Interface**: GUI interacts with VM (our own interface)

**Our Internal Boundaries:**
- **Module organization**: `kernel_vm/`, `kernel/`, `platform/`
- **Tiger Style rules**: Assertions, function length, static allocation
- **SBI vs kernel dispatch**: Function ID < 10 vs >= 10

**Recommendation:**
- **Protect external boundaries**: Kernel syscall interface, SBI interface
- **Enforce internal boundaries**: Use Zig's type system, build system
- **Document boundaries**: Clear "why" comments, explicit rules

### 4. Boundary Violations Happen Gradually

**Matklad's Examples:**
- Rust namespaces: Started strict, then ad-hoc disambiguation added
- Patterns/expressions: Started separate, then unified in some cases
- Lexer/parser: Started separate, then parser hacks lexer tokens

**Application to Our Project:**

**Potential Boundary Violations:**

1. **SBI vs Kernel Dispatch:**
   - **Risk**: Kernel syscall accidentally uses function ID < 10
   - **Prevention**: Assertions, explicit dispatch logic, tests

2. **VM vs Kernel:**
   - **Risk**: VM directly calls kernel functions (bypassing syscall interface)
   - **Prevention**: Type system, module boundaries, explicit callbacks

3. **Tiger Style Rules:**
   - **Risk**: "Quick fix" violates function length limit, skips assertions
   - **Prevention**: grainwrap/grainvalidate, code review, explicit "why" comments

**Recommendation:**
- **Be vigilant**: Watch for gradual boundary erosion
- **Enforce early**: Catch violations at build time, test time
- **Document violations**: If boundary must be violated, document "why" explicitly

## Takeaways for Grain Basin Kernel

### 1. Maintain Clear Boundaries

**Do:**
- Use Zig's module system to enforce boundaries
- Document boundaries with "why" comments
- Use assertions to validate boundary contracts
- Keep interfaces narrow (hourglass shape)

**Don't:**
- Violate boundaries for "quick fixes"
- Add ad-hoc exceptions to boundary rules
- Let boundaries erode gradually

### 2. Enforce Boundaries Physically

**Do:**
- Use Zig's type system (modules, types, imports)
- Use build system (explicit dependencies)
- Use tests (validate boundary contracts)
- Use tools (grainwrap/grainvalidate)

**Don't:**
- Rely only on informal rules
- Let boundaries be "suggestions"
- Ignore boundary violations

### 3. Document Boundaries Explicitly

**Do:**
- Explain "why" boundaries exist
- Document boundary contracts (what each side expects)
- Show examples of correct boundary usage
- Document exceptions (if any)

**Don't:**
- Assume boundaries are obvious
- Let boundaries be implicit
- Forget to update documentation when boundaries change

## Conclusion

**Matklad's "Almost Rules" teaches us:**
- Internal boundaries are fragile and need protection
- Well-placed boundaries help understanding (hourglass shape)
- Boundaries erode gradually unless physically enforced
- External boundaries are easier to protect than internal ones

**For Grain Basin Kernel:**
- **Maintain clear boundaries**: SBI vs kernel, VM vs kernel, GUI vs VM
- **Enforce physically**: Zig's type system, build system, tests
- **Document explicitly**: "Why" comments, boundary contracts
- **Be vigilant**: Watch for gradual erosion, catch violations early

**Result**: Strong boundaries → Clear architecture → Easy to understand → Easy to maintain → Tiger Style compliance

