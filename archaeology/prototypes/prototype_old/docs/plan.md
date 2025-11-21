# Grain Aurora GUI Plan — TigerStyle Execution

## 1. Pre-VPS Launchpad
- Scaffold `src/kernel/main.zig`, `src/kernel/syscall_table.zig`,
  `src/kernel/devx/abi.zig`, `kernel/link.ld`, and `scripts/qemu_rv64.sh`
  so `zig build kernel-rv64` builds locally.
- Document bootloader findings in `docs/boot/notes.md`.
- Add `grain conduct make kernel-rv64` / `run kernel-rv64` (remote step
  can be stubbed until the droplet is active).

## 2. RISC-V Kernel Airlift
- Stand up the Ubuntu 24.04 VPS, sync via `scripts/vpn_rsync.sh`, and
  emit `out/kernel/grain-rv64.bin` with `zig build kernel-rv64`.
- Provide `scripts/qemu_rv64.sh` and `scripts/riscv_gdb.sh` for headless
  boots and postmortems.
- Harden kernel ergonomics for Zig stdlib: explicit syscall table,
  guard-page toggles, deterministic allocators, structured crash dumps.
- Track firmware expectations (OpenSBI ➝ U-Boot today, coreboot + EDK2
  emerging for JH7110/Framework boards) and stash GRUB-compatible payload
  experiments in `docs/boot/` [^dcroma] [^framework-mainboard]
  [^framework-blog].

## 3. Kernel Lab Notebook
- Collect boot traces in `logs/kernel/`, capture crash dumps, and note
  recovery learnings in `docs/boot/notes.md`.
- Introduce `grain conduct report kernel-rv64` to summarize latest boots.

## 4. Grain Conductor & Pottery
- Extend `grain conduct` (`brew|link|manifest|edit|make|ai|contracts|mmt|
  cdn`) and keep `zig build conduct` deterministic.
- Model Grain Pottery scheduling for CDN kilns, ledger mints, and AI
  copilots with static allocation guarantees.

## 5. Grain Social Terminal
- Keep social data typed in Zig, fuzz 11 `npub`s per run, and deepen
  TigerBank/TigerCDN tooling (`grain conduct mmt|cdn`).
- Share settlement encoders in `src/contracts.zig`; store secrets via
  `src/grainvault.zig`.
- Maintain DM flows, GrainLoop, Graindaemon, GrainBuffer, and GrainLoom.

## 6. Tahoe Sandbox
- Grow `src/tahoe_window.zig` into a River-inspired compositor with
  Moonglow keymaps and explicit allocation bounds.

## 7. GUI & Compositor Study
- Keep researching Mach engine, zgui, Zig-gamedev, River philosophy, and
  Hammerspoon/QEMU parallels; log updates in `docs/gui_research.md`.

## 8. Grain Aurora UI
- Advance `src/grain_aurora.zig`, `src/grain_route.zig`, and
  `src/grain_orchestrator.zig`; maintain roadmap in `docs/plan.md`.
- Script deterministic recovery + bounded retries (Jepsen lessons).

## 9. Onboarding & Care
- Maintain onboarding scripts (Cursor Ultra, GitHub/Gmail/iCloud, 2FA,
  Ghostty setup, Brewfile lockstep) and password guidance.

## 10. Poetry & Waterbending
- Thread ASCII bending art and Helen Atthowe quotes through docs/code.

## 11. Thread Weaver
- Regenerate `docs/ray_160.md` via `zig build thread`; enforce
  160-character blocks.

## 12. Prompt Ledger
- Keep `docs/prompts.md` descending; append at index 0.

## 13. Timestamp Glow
- Maintain `src/ray.zig` timestamp grammar and fuzz coverage
  (`tests-experiments/000.md`).

## 14. Archive Echoes
- Rotate `prototype_old/`, `prototype_older/`, and `prototype_oldest/`.

## 15. Delta Checks
- Run `zig build wrap-docs`, `zig build test`, and keep docs in sync.

## 16. Rollback Ritual
- Guard `RayTraining` rollback flow; keep `ray_app.zig` demo current.

## 17. TigerStyle Naming Pass
- Enforce snake_case exports, 70-line functions, shared RNG helpers for
  grainvalidate.

## 18. Grain Foundations Alignment
- Continue absorbing `vendor/grain-foundations` (`GrainDevName`,
  `GrainSpace`) and documenting their impact.

## 19. Grainstore Mirrors
- Maintain static manifests and filesystem layout in `grainstore/` and
  `src/grain_manifest.zig`.

## 20. Grain Lattice + Matklad Loop
- Fuzz `src/grain_lattice.zig`, contracts, TigerBank modules, and RNG via
  `zig build test`; plan for `grain conduct contracts` rehearsals.

## 21. Documentary Chronicle
- Update `docs/doc.md`; keep the 12-part archive in
  `prototype_old/docs/design/` wrapped at 73 columns.

[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)
