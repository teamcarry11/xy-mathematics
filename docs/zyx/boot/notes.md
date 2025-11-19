# Grain RISC-V Boot Notes

- Baseline chain: OpenSBI ➝ U-Boot ➝ Linux/Grain payload on StarFive/
  SiFive hardware.
- Framework / DC-ROMA boards ship with vendor firmware; coreboot + EDK2
  ports are emerging, so GRUB-compatible images remain useful.
- Future experiments: author Zig SBI payloads and Rust hand-off stages.
  Track prototypes here before wiring them into `grain conduct`.

## Kernel Toolkit Status
- QEMU, rsync, and gdb scripts are staged; pause until a Framework 13
  RISC-V board or VPS is live. Focus on macOS Tahoe Aurora work in the
  interim.

## TODO
- flesh out trap/interrupt logging in `src/kernel/main.zig` before
  pushing to hardware.
- capture per-board firmware quirks here as we test JH7110, HiFive, and
  Ventana targets.
