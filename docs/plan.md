# Grain Aurora GUI Plan — TigerStyle Execution

## 1. Bundle Pipeline (macOS Tahoe)
- Add `tools/macos_bundle.zig` to package Ray/GrainAurora as a `.app`.
- Expose via `zig build mac-app` and `grain conduct make mac-app`.

## 2. GrainAurora Framework
- New module `src/grain_aurora.zig` defining component structs, node tree,
  deterministic reconcile.
- Component lifecycle: `init`, `render`, `event`, `teardown` (no hidden
  allocations).

## 3. Routing Layer
- `src/grain_route.zig`: map Nostr `npub` multi-path segments → component
  entry points (static array of routes, referential transparency).
- Persist last route snapshot in GrainBuffer read-only segments.

## 4. Template Preprocessor
- `tools/aurora_preprocessor.zig` transforms `.aurora` markup into Zig
  modules; deterministic codegen, no runtime eval.

## 5. RISC-V Syscall Boundary
- `src/riscv_sys.zig` defines syscall stubs used by GrainAurora so the
  same interface works on the future monolith kernel.

## 6. Tahoe Moonglow Windowing
- Expand `src/tahoe_window.zig` with River-like tiling, Moonglow keyboard
  maps, integration hooks for GrainAurora view roots.

## 7. GrainOrchestrator
- `src/grain_orchestrator.zig` coordinates Graindaemon, GrainAurora,
  Cursor CLI, Ghostty, Claude Code, and bounded retry policy.

## 8. Brewfile Bundle Modules
- Extend `grain conduct brew` to emit versioned bundle definitions with
  semantic + Holocene-Vedic versions into `docs/BREW_LOCK.zig`.

## 9. Letta Agent Spec
- Mirror Letta agent manifests (tools, memory, persona) in
  `src/grain_orchestrator.zig` and `docs/doc.md`.
- Provide `grain orchestrator deploy` command for declarative agent
  provisioning.

## 10. Asset Pipeline & Tests
- `zig build aurora-assets` compiles templates to Zig and bundles static
  data.
- Add Matklad-style snapshot tests under `tests/ui/` plus route fuzzing in
  `tests-experiments/002.md`.

## 11. Documentation Sync
- Update `docs/ray.md`, `docs/doc.md`, and `docs/outputs.md` after each
  milestone.
- Log prompts in `docs/prompts.md` with descending IDs.

## 12. RISC-V Monolith Kernel Expedition
- Provision an Ubuntu 24.04 LTS build host reachable through the VPN.
- Install toolchain: `sudo apt install qemu-system-misc gdb-multiarch`
  and mirror Zig 0.15.2 into `/opt/zig` for reproducible builds.
- Create `scripts/vpn_rsync.sh` to sync `xy/` → remote `~/grain-rv64/`
  with deterministic excludes (`zig-cache`, build artifacts).
- Introduce `build.zig` target `zig build kernel-rv64` compiling
  `src/kernel/main.zig` for `riscv64-freestanding` with static allocs.
- Add linker script `kernel/link.ld` and QEMU-ready flat binary output
  under `out/kernel/grain-rv64.bin`.
- Layer in `kernel/syscall_table.zig` so the Grain kernel exposes
  Zig stdlib-friendly syscalls (I/O, timers, virtual memory probes) with
  explicit errno contracts and bounded buffers.
- Embed a “safety lattice”: compile-time feature flags for guard pages,
  deterministic allocator selection (std.heap.page_allocator shim), and
  structured crash dumps routed into `logs/kernel/`.
- Add `kernel/devx/abi.zig` documenting calling conventions so the Zig
  compiler’s freestanding runtime can reuse the same startup scaffolding
  (`_start`, panic handlers, dbg I/O) without forks.
- Author `scripts/qemu_rv64.sh` to boot the binary with:
  `qemu-system-riscv64 -machine virt -cpu rv64 -m 512M \
   -nographic -bios default -kernel out/kernel/grain-rv64.bin \
   -serial mon:stdio -monitor telnet:127.0.0.1:5555,server,nowait`.
- Use `scripts/riscv_gdb.sh` to attach `gdb-multiarch` via
  `target remote :1234` for stepping through Zig symbols.
- Expose orchestrated commands via `grain conduct make kernel-rv64`
  (build + rsync) and `grain conduct run kernel-rv64` (SSH + QEMU).
- Log boot traces and crash dumps back into `logs/kernel/` for Ray
  journaling.
- Track firmware landscape: baseline boot chain = OpenSBI ➝ U-Boot on
  StarFive/SiFive boards, with coreboot + EDK2 efforts underway for
  Framework / DC-ROMA RISC-V mainboards so GRUB-or EFI payloads stay
  viable [^dcroma][^framework-mainboard][^framework-blog].
- Reserve `docs/boot/` for bootloader experiments (Zig SBI payloads,
  Rust handoffs) once the vendor firmware exposes stable hooks.

[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)
