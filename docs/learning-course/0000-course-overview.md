# Grain OS Learning Course: Overview

**Course Level**: Graduate  
**Language**: Zig (primary), Objective-C (macOS wrapper only), RISC-V assembly (compilation only)  
**Teaching Style**: GrainStyle (patient, explicit, code that teaches)  
**Prerequisites**: Systems programming experience, basic OS concepts

## Course Structure

This course provides the theoretical and practical foundation for understanding
Grain OS development. Each document builds on previous concepts, following
GrainStyle principles: explicit limits, patient discipline, code that teaches.

### Document Series

1. **0001-course-overview.md** (this document)
   - Course structure and learning path
   - Prerequisites and expectations

2. **0002-risc-v-architecture.md**
   - RISC-V instruction set architecture
   - Register file and memory model
   - Instruction encoding and formats
   - RISC-V64 vs RISC-V32

3. **0003-virtual-machine-fundamentals.md**
   - VM design principles
   - Instruction interpretation
   - State management (registers, memory, PC)
   - Execution loop patterns

4. **0004-jit-compilation-basics.md**
   - Just-in-time compilation concepts
   - Translation from RISC-V to AArch64
   - Code generation and optimization
   - Rosetta 2 analogy for macOS Tahoe

5. **0005-memory-management.md**
   - Virtual vs physical addresses
   - Address translation and mapping
   - Memory layout design
   - Bounds checking and safety

6. **0006-kernel-fundamentals.md**
   - Kernel architecture patterns
   - Boot sequence and initialization
   - System call interface
   - Process and memory management

7. **0007-framebuffer-graphics.md**
   - Framebuffer concepts
   - Pixel formats (RGBA, BGRA)
   - Memory-mapped display
   - Graphics primitives

8. **0008-macos-integration.md**
   - Cocoa/AppKit basics (Objective-C)
   - Window management
   - Event handling
   - Core Graphics integration

9. **0009-grainstyle-principles.md**
   - Explicit limits and bounds
   - Assertion density
   - Static allocation patterns
   - Code that teaches

10. **0010-grain-os-architecture.md**
    - Grain OS stack overview
    - VM + Kernel + IDE integration
    - Development workflow
    - Testing strategies

11. **0011-knowledge-graphs-and-blocks.md**
    - Block-based knowledge graph architecture
    - Block structure and storage
    - Bidirectional linking
    - Iterative graph traversal

12. **0012-social-threading-and-replies.md**
    - Reply relationships between blocks
    - Thread depth calculation (iterative)
    - Thread navigation
    - Cycle detection

13. **0013-transclusion-and-embedding.md**
    - Transclusion (embedding blocks)
    - Transclusion depth tracking
    - Content expansion
    - Cycle detection

14. **0014-export-import-formats.md** (PLANNED)
    - JSON and Markdown export
    - Serialization patterns
    - Import from external formats

15. **0015-dag-based-architectures.md** (PLANNED)
    - DAG-based UI architecture
    - Streaming updates
    - Node and edge management

16. **0016-grain-field-wse-compute.md**
    - WSE RAM-only spatial computing
    - SRAM allocation and management
    - Field topology (2D grid)
    - Parallel operations

17. **0017-grain-silo-object-storage.md**
    - Object storage abstraction
    - Hot/cold data separation
    - Promotion/demotion strategies
    - Integration with Grain Field

18. **0018-terminal-emulation.md** (PLANNED)
    - VT100/VT220 escape sequences
    - Character cell rendering
    - Scrollback buffer

19. **0019-grainscript-language.md** (PLANNED)
    - Grainscript DSL design
    - Lexer and parser
    - Interpreter and runtime

20. **0020-storage-integration-patterns.md** (PLANNED)
    - Block-to-object mapping
    - Hot cache integration
    - Persistence strategies

## Learning Path

### Phase 1: Foundations (Documents 0002-0005)
Understand the underlying architecture and VM concepts before diving into
kernel development.

**Time Estimate**: 4-6 hours reading + exercises

### Phase 2: Kernel Development (Documents 0006-0007)
Learn kernel patterns and graphics concepts needed for Grain Basin Kernel.

**Time Estimate**: 3-4 hours reading + exercises

### Phase 3: Integration (Documents 0008-0010)
Understand macOS integration and GrainStyle principles applied to Grain OS.

**Time Estimate**: 2-3 hours reading + exercises

### Phase 4: Knowledge Graphs & Social Features (Documents 0011-0013)
Learn knowledge graph architecture, social threading, and transclusion.

**Time Estimate**: 3-4 hours reading + exercises

### Phase 5: Storage & Compute (Documents 0016-0017)
Understand Grain Field (WSE compute) and Grain Silo (object storage).

**Time Estimate**: 2-3 hours reading + exercises

## Prerequisites

### Required Knowledge

- **Systems Programming**: Understanding of low-level programming concepts
- **Computer Architecture**: Basic CPU, memory, and I/O concepts
- **Operating Systems**: Kernel vs userspace, system calls, processes
- **Zig Language**: Basic syntax, error handling, comptime (we'll cover advanced topics)

### Recommended Experience

- Written systems-level code (C, Rust, or Zig)
- Debugged memory issues
- Worked with pointers and manual memory management
- Read assembly code (any architecture)

### What We'll Teach

- RISC-V architecture (from scratch)
- VM implementation patterns
- JIT compilation techniques
- Kernel development practices
- GrainStyle coding discipline

## Teaching Philosophy

### GrainStyle Approach

Every concept is explained with:

1. **Why**: The rationale behind design decisions
2. **What**: Clear definitions and boundaries
3. **How**: Step-by-step implementation patterns
4. **Examples**: Real code from Grain OS

### Code That Teaches

Code examples are:

- **Explicit**: No hidden behavior or magic
- **Commented**: "Why" comments explain intent
- **Asserted**: Invariants are checked and documented
- **Bounded**: All limits are explicit

### Patient Discipline

We build understanding incrementally:

- Start with simple concepts
- Add complexity gradually
- Reinforce with examples
- Connect to real implementation

## Reading Strategy

### Sequential Reading

Documents are designed to be read in order. Each builds on previous concepts.

### Reference Reading

You can also use documents as references:

- Jump to specific topics as needed
- Review concepts while implementing
- Use as lookup for implementation details

### Active Learning

Each document includes:

- **Key Concepts**: Core ideas to understand
- **Code Examples**: Real Grain OS code
- **Exercises**: Thought experiments and questions
- **Connections**: Links to related concepts

## Course Goals

By the end of this course, you should be able to:

1. **Understand RISC-V architecture** and instruction encoding
2. **Implement a simple VM** with instruction interpretation
3. **Explain JIT compilation** concepts and translation patterns
4. **Design memory layouts** with address translation
5. **Write kernel code** following GrainStyle principles
6. **Integrate graphics** via framebuffer management
7. **Connect to macOS** via Cocoa/AppKit wrappers
8. **Apply GrainStyle** to your own systems code

## Grain OS Context

This course is specifically designed for understanding **Grain OS**:

- **Target**: RISC-V64 kernel running in VM
- **Host**: macOS Tahoe 26.1 (AArch64)
- **JIT**: RISC-V → AArch64 translation
- **IDE**: Native macOS Cocoa application
- **Style**: GrainStyle (explicit, bounded, safe)

We focus on concepts directly relevant to Grain OS implementation, not
general computer science theory.

## Next Steps

1. Read **0002-risc-v-architecture.md** to understand the instruction set
2. Follow the learning path sequentially
3. Reference documents as needed during implementation
4. Apply concepts to Grain OS codebase

---

**Remember**: This is a journey. Understanding comes through patient study
and practice. Each concept builds on the last. Take your time, ask questions,
and connect theory to implementation.

*now == next + 1*

