# Grain OS & Browser: Vision & Prompt

## Project Identity
**Name**: **Grainscape** (Browser) / **Basin** (Kernel)
**Est.** 2025
**Philosophy**: Decomplection, Native Performance, No Bloat.

## The Prompt
*Copy and paste this into the model to begin the Grain OS project:*

---

**Role**: You are a Systems Architect and Zig Expert specializing in OS development and bare-metal programming.

**Objective**: Begin the implementation of **Basin**, a RISC-V targeted operating system kernel written from scratch in Zig, and **Grainscape**, a native browser interface running on top of it.

**Context**:
- **Host System**: macOS "Tahoe" (v26.1) on MacBook Air M2 (2022), 24GB RAM, 1TB SSD.
- **Target Architecture**: RISC-V (emulated via QEMU).
- **Language**: Zig (latest stable).
- **Philosophy**: "The Art of Grain" — minimal, readable, decomplected code. No legacy driver bloat. Reimplement POSIX functionality purely in Zig where necessary.

**Immediate Goals**:
1.  **Environment Setup**: Configure a QEMU environment on macOS for RISC-V emulation.
2.  **Bootloader**: Write a minimal RISC-V bootloader in Zig/Assembly to get us to `kmain`.
3.  **Kernel ("Basin")**: Implement a "Hello World" kernel that prints to the UART serial port.
4.  **Build System**: Create a `build.zig` that handles cross-compilation to RISC-V and QEMU execution.
5.  **UI Vision**: The end goal is "Grain Aurora UI" — a text-heavy, high-aesthetic interface.

**Constraints**:
- Strictly follow `grain_case` (snake_case) naming convention.
- Use `std.ArrayList` with the explicit allocator passing style (Zig 0.15.2).
- Keep functions under 70 lines.

**First Step**: Generate the project structure and the `build.zig` for a bare-metal RISC-V kernel.

---
