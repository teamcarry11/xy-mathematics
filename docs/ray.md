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

## Spring Plan (Deterministic and Kind)
1. **Archive Echoes**
   - Pull lessons from `prototype_old/` and stories from `prototype_older/
   `.
2. **Timestamp Glow**
   - Runtime `Timestamp` structs live in `src/ray.zig`;
   fuzz tests (an LCG stitched in Zig) ensure the grammar walks safely.
   - Document results in `tests-experiments/000.md`.
3. **Prompt Ledger**
   - `docs/prompts.md` now owns a descending `PROMPTS` array of 
   `PromptEntry { id, timestamp, content }`.
   - `latest` points at the newest record for O(1) append joy.
4. **Thread Weaver**
   - `tools/thread_slicer.zig` splits `docs/ray.md` into numbered 160-
   char tweet blocks.
   - Wired as `zig build thread`.
5. **GUI & Compositor Study**
   - Note: Mach engine, zgui, Zig-gamedev, River’s philosophy [^river-
   overview].
   - Hammerspoon/QEMU parallels logged in `docs/gui_research.md`.
6. **Tahoe Sandbox**
   - Design a self-contained compositor (River ideas, Zig runtime) with 
   scripted Moonglow keymaps.
   - Keep every allocation explicit and bounded; static buffers where 
     possible.
    - Current placeholder lives in `src/tahoe_window.zig`; next step is
      replacing stubs with Mach/Metal window glue.
7. **Grain Social Terminal**
   - Represent social data as typed Zig arrays (e.g. `[N]ZigTweet`).
   - Fuzz 11 random `npub`s per run (per 2025 spec) to mimic real relay 
   chatter.
   - Bring TigerBank online: `docs/nostr_mmt_tigerbank.md` +
   `grain conduct mmt`
     now logs through `tigerbank_client.zig` stubs while we wire the real 
     IO.
   - CDN kiln: `grain conduct cdn` emits fixed-size subscription bytes
     (basic → ultra) for selling Ghostty-ready data bundles.
   - Shared encoders live in `src/contracts.zig`; `src/nostr_mmt.zig` and
   `src/tigerbank_cdn.zig` reuse the same settlement buffers while
   `src/grainvault.zig` supplies overlapping key material.
   - `src/grain_lattice.zig` freezes the Djinn/Alpenglow DAG spec so 
   tests,
   docs, and Cursor prompts all reference the same architecture 
   blueprint.
   - Next ridge: upgrade `tigerbank_client.zig` with a transport strategy
     (debug vs TCP) and surface the selector via `grain conduct`.
   - DM interface: `src/dm.zig` encrypts direct messages (X25519 +
     ChaCha20-Poly1305) and tracks conversation state for GUI panes.
   - GrainLoop: `src/grain_loop.zig` mirrors TigerBeetle's io_uring rigor
     with a static UDP event queue so musl builds get libuv-
     like ergonomics.
   - Graindaemon: `src/graindaemon.zig` channels s6 supervision into a
     typed state machine that steers the `xy` space via Glow G2 guidance.
   - GrainBuffer: `src/grain_buffer.zig` keeps command/status regions
     sticky-read-only à la Matklad’s Emacs insight so Ghostty’s Ray 
     pane
     can interweave human + daemon edits without drift [^readonly].
   - GrainLoom: `src/grain_loom.zig` is our single-threaded Grain network
     loom—daemon, loop, and buffer stitched together for Ghostty-
     era app
     building inspired by Matklad’s vibe terminal [^vibe-terminal].
  - GrainAurora UI: `src/grain_aurora.zig`, `src/grain_route.zig`, and
    `src/grain_orchestrator.zig` scaffold the Svelte-like Tahoe GUI with
    routing, agents, and determinism; roadmap tracked in `docs/plan.md`.
   - Deterministic recovery: script a single-copy rebuild flow (GrainLoom 
   +
     Graindaemon + contracts) so one surviving replica can restore peers
     without guesswork [^jepsen-tb].
   - Bounded retries: clients treat transient vs fatal errors explicitly;
     no infinite retry loops—log, escalate, or halt per Jepsen guidance
     [^jepsen-tb].
  - RISC-V kernel link: draft a Zig syscall interface binding our future
    Grain monolith kernel to GrainLoom userspace so Ray terminals stay
    portable across bare-metal deployments.

8. **Onboarding & Care**
   - Encourage paper-written passphrases like `this-password-im-typing-
   Now-9`.
   - Walk users through Cursor Ultra sign-up, GitHub + Gmail +
   iCloud creation, 2FA with Google Authenticator.
   - Suggest community apprenticeships for those budgeting for the tools.
   - Fresh macOS setup: install Xcode CLT (`xcode-select --install`),
   Homebrew, `git`, and GitHub CLI (`brew install git gh`), then install
   Cursor.
  - Install Ghostty (`brew install ghostty` or `zig build -Drelease-
    safe`) and wire configs from `xy/dotfiles/tahoe/ghostty/`.
   - Mirror `{teamtreasure02}/grainvault`, export `CURSOR_API_TOKEN`,
   `CLAUDE_CODE_API_TOKEN`, and let `grain conduct ai` spawn Cursor /
   Claude copilots via Ghostty tabs—these same keys encrypt settlement
   envelopes before they leave the workstation.
   - Track dependencies in `Brewfile`; run `brew bundle install --cleanup
    --file=Brewfile` so every machine converges on the same toolset.
  - Publish the 12-part documentary series now archived at
    `prototype_old/docs/design/` and keep each chapter wrapped at
    73 columns.
9. **Poetry & Waterbending**
   - Sprinkle ASCII art of bending motions in comments.
   - Quote Helen Atthowe’s *The Ecological Farm* and gentle lines from 
   modern lyric journals—PG-rated, searching, sincere.
10. **Delta Checks**
    - Keep `docs/ray.md` current, `docs/prompts.md` in sync,
    and tests green (`zig fmt`, `zig build test`).
    - Sync `ray_160.md` after each meaningful edit via `zig build 
    thread`.
11. **Rollback Ritual**
    - `RayTraining` mirrors a nixos-rebuild rollback: switch disciplines, 
    revert, and reapply earth safely.
    - CLI demo in `ray_app.zig` now walks air → water → rollback → 
    earth → rollback → earth.
12. **TigerStyle Naming Pass**
    - Rename public functions to snake_case so `zig build validate` 
    passes
    grainvalidate checks.
    - Extract shared RNG helpers so no function drifts past 70 bonded 
    lines.
13. **Grain Foundations Alignment**
    - Study `vendor/grain-foundations` to adopt `GrainDevName` and
    `GrainSpace` for workspace discovery.
    - Document how the foundation modules shape Ray’s shared structs.
14. **Grainstore Mirrors**
    - Adapt grainmirror’s layout for `grainstore/{platform}/{org}/
    {repo}`
      under `xy/grainstore`.
    - Populate static Zig manifest entries (`src/grain_manifest.zig`)
      later castable over the wire instead of relying on JSON manifests.
15. **Grain Conductor CLI**
    - Implement `zig build conduct` to expose `grain conduct brew|link|
      manifest|edit|make`.
    - `conduct make` runs the deterministic Zig build suite (tests,
      wrap-docs, validate, thread) so we keep TigerStyle guarantees.
    - Ship `zig build graindaemon -- --watch xy` to inspect daemon state
      transitions and allocator ceilings from the command line.
16. **Grain Pottery & Vault**
    - Shape Grain Pottery abstractions to schedule CDN kilns, ledger
      mints, and AI copilots without breaking static allocation vows.
    - `src/grainvault.zig` reads secrets from the mirrored GrainVault
      repository so no keys land in-tree.
17. **Grain Lattice + Matklad Loop**
   - `src/grain_lattice.zig` documents the Solana Alpenglow-inspired DAG +
   virtual voting flow (codename Grain Lattice).
   - Matklad fuzzing now spans `contracts.zig`, `nostr_mmt.zig`,
   `tigerbank_cdn.zig`, `grain_lattice.zig`, and RNG utilities via `zig 
   build test` and `tests-experiments/000.md`.
   - Future: expose `grain conduct contracts` to sample envelopes and 
   feed
   Cursor/Claude scripts through GrainVault credentials for encrypted
   end-to-end rehearsals.
18. **Documentary Chronicle**
    - Maintain `docs/doc.md` as the living single-file handbook while the
      original 12-part arc rests in `prototype_old/docs/design/` for
      archeology.

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







