# Credits

## RISC-V SBI Wrapper

Our RISC-V SBI (Supervisor Binary Interface) wrapper (`src/kernel_vm/sbi.zig`) is inspired by [CascadeOS/zig-sbi](https://github.com/CascadeOS/zig-sbi), which is MIT licensed.

**CascadeOS/zig-sbi**: Zig wrapper around the RISC-V SBI specification (v3.0-rc1).

**Our Implementation**: We wrote our own minimal Tiger Style compliant SBI wrapper, taking inspiration from CascadeOS/zig-sbi's API design and SBI specification compliance, but ensuring full Tiger Style compliance (comprehensive assertions, type safety, minimal dependencies, explicit "why" comments).

**License**: MIT (CascadeOS/zig-sbi) - permissive, allows our implementation.

**Credit**: Thank you to CascadeOS for the excellent reference implementation and SBI specification compliance.

