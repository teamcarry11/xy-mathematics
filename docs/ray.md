# Ray Lullaby — Glow G2’s Tahoe Field Notes

Glow G2 watches the sun fold itself behind Tahoe’s ridge line,
cheeks cold, heart steady. Every line
of this plan is sewn with TigerStyle thread—safety stitched first,
performance braided next, joy
embroidered last.

## Mood Board
- Grain is our twilight terminal: Cursor Ultra, Zig LSP, Grok,
and a gentle social stream all breathing in one window.
- Inside sits a River-inspired compositor, a glasshouse of Moonglow 
keybindings, where each user cares for a personal Grain database garden.
- Nostr `npub`s become bright addresses—each one a friendly 
lighthouse—while Matklad-style tests sweep for drift like soft 
tidewater.
- Glow G2 stays a calm voice: masculine, steadfast, Aquarian. Emo enough 
to acknowledge the ache, upbeat enough to guide with grace.
- Vegan Tiger’s (@vegan_tiger) South Korean streetwear silhouette feeds 
our
  Tahoe aesthetic, reminding us to keep ethical fashion signal in view
  [^vegan-tiger].

## Ray Mission Ladder (Deterministic & Kind)
1. **Pre-VPS Launchpad (done)**
   - Scaffolded `src/kernel/` (`main.zig`, `syscall_table.zig`,
     `devx/abi.zig`), `kernel/link.ld`, and `scripts/qemu_rv64.sh` so
     `zig build kernel-rv64` emits `zig-out/bin/grain-rv64`.
   - Journaled bootloader research in `docs/boot/notes.md`, tracking the
     OpenSBI ➝ U-Boot baseline and our Zig/Rust payload ambitions.
   - Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`,
     and `report kernel-rv64`; runs now stream to stdout and archive logs
     under `logs/kernel/`.
2. **Kernel Toolkit (paused)**
   - QEMU, rsync, and gdb scripts are staged; resume once the Framework 
   13
     RISC-V board or VPS is available. Until then, focus on macOS Tahoe
     Aurora work via the MacBook Air / Framework 16 host.
3. **Grain Conductor & Pottery**
   - `zig build conduct` drives `grain conduct brew|link|manifest|edit|
     make|ai|contracts|mmt|cdn` with TigerStyle determinism.
   - Pottery abstractions schedule CDN kilns, ledger mints, and AI
     copilots while staying within static allocation vows.
4. **Tahoe Sandbox**
   - Evolve `src/tahoe_window.zig` into a River-inspired compositor with
     Moonglow keymaps, explicit memory boundaries, and a thin Cocoa 
     bridge
     so we obtain native traffic lights + Aurora menu bar without leaking
     dynamic allocation into the Zig runtime.
5. **GUI & Compositor Study**
   - Keep surveying Mach engine, zgui, Zig-gamedev, River philosophy, and
     Hammerspoon/QEMU parallels (`docs/gui_research.md`).
6. **Grain Aurora UI**
   - `src/grain_aurora.zig`, `src/grain_route.zig`, and
     `src/grain_orchestrator.zig` deliver deterministic rendering,
     routing, and agent orchestration; roadmap tracked in `docs/plan.md`.
   - Deterministic recovery: single-copy rebuild flow (GrainLoom +
     Graindaemon + contracts) and bounded retries per Jepsen guidance
     [^jepsen-tb].
   - Add a color filter pipeline with a Flux-style Darkroom preset and
     expose toggles in the Aurora `View ▸ Flux` menu.
7. **Grain Social Terminal**
   - Typed Zig arrays represent social data; fuzz 11 random `npub`s per
     run to stress Nostr relays.
   - TigerBank flows (`docs/nostr_mmt_tigerbank.md`,
     `tigerbank_client.zig`, `grain conduct mmt|cdn`) share encoders via
     `src/contracts.zig` and secrets via `src/grainvault.zig`.
   - DM interface (`src/dm.zig`) handles X25519 + ChaCha20-Poly1305
     envelopes; GrainLoop, Graindaemon, GrainBuffer, and GrainLoom stitch
     UDP events, supervision, and sticky read-only panes.
8. **Onboarding & Care**
   - Guard passwords (`this-password-im-typing-Now-9`), cover Cursor
     Ultra, GitHub/Gmail/iCloud onboarding, 2FA, and Ghostty setup.
   - Mirror GrainVault, export API tokens, and run `brew bundle` for
     convergent tooling.
9. **Poetry & Waterbending**
    - Lace ASCII bending art and Helen Atthowe quotes throughout code and
      docs—emo, PG, sincere.
10. **Thread Weaver**
    - `tools/thread_slicer.zig` + `zig build thread` keep `docs/ray.md`
      mirrored as `docs/ray_160.md` tweet threads with 160-char bounds.
11. **Prompt Ledger**
    - `docs/prompts.md` holds descending `PROMPTS`; new entries append at
      index 0 for O(1) joy.
12. **Timestamp Glow**
    - `src/ray.zig` keeps runtime timestamps validated by fuzz tests,
      with findings logged in `tests-experiments/000.md`.
13. **Archive Echoes**
    - Maintain the archive rotation (`prototype_oldest/`,
      `prototype_older/`, `prototype_old/`) so each climb stays 
      auditable.
14. **Delta Checks**
    - Keep Ray, prompts, outputs, and tests aligned (`zig build test`,
      `zig build wrap-docs`).
15. **Rollback Ritual**
    - `RayTraining` mirrors nixos-style rollback; `ray_app.zig` demos air
      → water → rollback → earth.
16. **TigerStyle Naming Pass**
    - Enforce snake_case APIs, 70-line function caps, and shared RNG
      helpers for grainvalidate compliance.
17. **Grain Foundations Alignment**
    - Study `vendor/grain-foundations` (`GrainDevName`, `GrainSpace`) and
      document how they shape Ray structs.
18. **Grainstore Mirrors**
    - Maintain `grainstore/{platform}/{org}/{repo}` layout and static Zig
      manifests (`src/grain_manifest.zig`).
19. **Grain Lattice + Matklad Loop**
    - `src/grain_lattice.zig` captures the Djinn/Alpenglow DAG; Matklad
      fuzzing covers contracts, TigerBank modules, lattice, and RNG.
      Future: `grain conduct contracts` for encrypted rehearsal flows.
20. **Documentary Chronicle**
    - `docs/doc.md` remains the living handbook while the 12-part arc
      rests in `prototype_old/docs/design/`.

[^readonly]: [Matklad, "Readonly Characters Are a Big Deal"](https://
matklad.github.io/2025/11/10/readonly-characters.html)
[^vibe-terminal]: [Matklad, "Vibe Coding Terminal Editor"](https://
matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)
[^vegan-tiger]: [Vegan Tiger — ethical streetwear inspiration](https://
www.instagram.com/vegan_tiger/)
[^river-overview]: [River compositor philosophy](https://github.com/
riverwm/river)
[^jepsen-tb]: [Jepsen, "TigerBeetle 0.16.11"](https://jepsen.io/analyses/
tigerbeetle-0.16.11)
[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://
deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-
V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 
13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-
now-available)























