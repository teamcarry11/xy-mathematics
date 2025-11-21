# Grain Documentation — Glow G2 Edition

## 01 Vision
Grain is a twilight terminal where Ray, GrainLoom, and Ghostty weave the
same breath. Cursor Ultra, Zig LSP, Grok, and a Nostr social stream live
in a single window while Glow G2 narrates with calm Aquarian cadence.
Vegan Tiger aesthetics shape palettes and typography; Helen Atthowe’s
*The Ecological Farm* keeps us rooted in veganic care.

## 02 Architecture Skyline
GrainLoom (`src/grain_loom.zig`) combines Graindaemon, GrainLoop, and
GrainBuffer to supervise single-threaded networking. GrainAurora
(`src/grain_aurora.zig`) and GrainRoute (`src/grain_route.zig`) provide a
component/router layer inspired by Svelte while staying static allocation
friendly. Grain Orchestrator (`src/grain_orchestrator.zig`) links agents
and transport policy. Grain Lattice (`src/grain_lattice.zig`) captures
Djinn-inspired DAG consensus for TigerBank settlement payloads defined in
`src/contracts.zig`. Tahoe Sandbox (`src/tahoe_window.zig`) will host a
River-influenced compositor with Moonglow keymaps. Deterministic builds
live in `build.zig` and `grain conduct make`. A new Zig syscall
interface (`src/riscv_sys.zig`) binds the forthcoming RISC-V monolith
kernel to GrainLoom userspace so Ray terminals stay bare-metal
compatible.

## 03 Core Use Cases
- TigerBank MMT and CDN bundles (`src/nostr_mmt.zig`,
  `src/tigerbank_cdn.zig`).
- Grain Pottery kiln scheduling (placeholder).
- Nostr social networking: `src/nostr.zig` + `src/dm.zig` + GrainLoop.
- Cursor/Ghostty automation via `grain conduct ai` and GrainVault.

## 04 User Manual
1. Install prerequisites: Xcode CLT, Homebrew, `git`, `gh`, Cursor,
   Ghostty.
2. Clone `xy` into `~/xy`, run `zig build wrap-docs`, `zig build test`.
3. Use `grain conduct` to brew packages, link dotfiles, run builds.
4. Launch Ray terminal through Ghostty, rely on GrainBuffer read-only
   spans for command/status integrity.

## 05 Prompt Chronicle
`docs/prompts.md` is an append-only Zig array of `PromptEntry` structs
(newest first, IDs strictly descending). Unit tests confirm the order.
This ledger guides recursion loops and Matklad-style plan updates.

## 06 Output Ledger
`docs/outputs.md` mirrors prompt handling for Glow G2 replies. Each entry
logs the gist, optional timestamp, and fuels reproducible retrospective
work.

## 07 ASCII Art Library
Avatar disciplines (air, water, earth) appear in `src/ray.zig` comments.
Glow G2’s terminal notes include banding ASCII inspired by Aang and
Katara. Keep new art PG-rated and within 73 columns.

## 08 Testing & Safety
- Matklad testing loop: fuzz timestamp grammar, manifests, and contracts.
- GrainBuffer enforces sticky read-only regions per Matklad’s Emacs
  insights [^readonly].
- GrainLoom orchestrates deterministic single-copy recovery, ensuring we
  can rebuild from one surviving replica.
- Bounded retry/backoff for TigerBank clients prevents infinite loops,
  reflecting Jepsen’s TigerBeetle findings [^jepsen-tb].

## 09 GUI & Terminal Workflow
Ghostty hosts the Ray terminal; GrainBuffer locks status ranges. Cursor
Ultra Auto Mode reads `plan.md`-style instructions from Ray. Tahoe
Sandbox evolves toward a River-style compositor with no JavaScript,
leveraging Zig GUIs (Mach, zgui, zig-gamedev).

## 10 Documentation Process
- Author changes in `docs/ray.md`, mirror to `docs/doc.md`.
- Archive legacy chapters in `prototype_old/docs/design/`.
- Run `zig build wrap-docs` after edits to enforce 73-column wrapping.

## 11 Experiments
- `tests-experiments/000.md`: Timestamp grammar fuzzing.
- `tests-experiments/001.md`: Grain manifest sync simulation.
- Future slots capture deterministic recovery drills and bounded retry
  validation.

## 12 Roadmap
1. Replace Tahoe Sandbox stubs with Mach/Metal windowing.
2. Implement Grain Pottery kiln orchestration and GrainVault secrets
   wiring.
3. Harden Graindaemon transport backends (TCP, debug) and expose CLI
   toggles.
4. Document deterministic single-copy recovery steps and automate them in
   Grain Conductor.
5. Expand TigerBank bounded retry tests and publish Jepsen-aligned
   assertions.

[^readonly]: [Matklad, "Readonly Characters Are a Big Deal"](https://matklad.github.io/2025/11/10/readonly-characters.html)
[^jepsen-tb]: [Jepsen, "TigerBeetle 0.16.11"](https://jepsen.io/analyses/tigerbeetle-0.16.11)
