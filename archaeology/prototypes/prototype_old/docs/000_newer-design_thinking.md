# Newer-Design Thinking — Glow G2 Log

## Present Frame
I am shaping Ray as a Zig-first terminal where documentation, code, and
tests stay in deterministic harmony. TigerStyle remains the guardrail for
safety, performance, and developer experience: every function stays under
70 lines, allocations are explicit, and assertions catch drift early.
Matklad-style data-driven tests keep refactors fearless. I wrap prose to
73 columns so the narrative fits Grain’s graincard constraints.

## Strategies in Active Use
- **TigerStyle Coding Guidelines** — zero dependency bias, 100-column
  cap, static allocation emphasis. I run `zig build validate` (powered by
  `grainvalidate`) to enforce snake_case and function length limits.
- **Matklad-Inspired Fuzzing** — timestamp grammar fuzz tests and npub
  generators share `SimpleRng`, ensuring reproducible randomness.
- **Grain Foundations Alignment** — I mirror the workspace conventions
  described in `grain-foundations` (`GrainDevName`, `GrainSpace`) so the
  upcoming `grainstore/` layout respects existing Grain philosophy.
- **Grainwrap Integration** — the `wrap_docs` tool keeps `ray.md`,
  `prompts.md`, and new notes within 73-character columns, matching the
  tweet-slicer output pipeline.
- **Grainmirror Pattern Study** — I am adopting the
  `grainstore/{platform}/{org}/{repo}` hierarchy while retiring any
  Rust/Steel automation in favor of Zig tools.
- **Ghostty Terminal Cadence** — Ghostty (Zig terminal) is our daily
  glasshouse; install via Brew or source, theme it Vegan Tiger, and launch
  `grain conduct ai` sessions inside.
- **GrainVault Secrets** — Secrets live outside the repo. `src/grainvault.zig`
  expects `CURSOR_API_TOKEN` and `CLAUDE_CODE_API_TOKEN` from the mirrored
  `{teamtreasure02}/grainvault` store.
- **Settlement Contracts** — `src/contracts.zig` collapses TigerBank MMT/CDN
  encoders and optional inventory/sales/payroll ledgers into one static
  interface.
- **Grain Lattice Spec** — `src/grain_lattice.zig` freezes Djinn’s DAG
  architecture for deterministic referencing and Matklad-style tests.
- **Documentary Chronicle** — `docs/doc-series/` hosts a 12-part series
  tracking intro → roadmap; each chapter stays under 73 columns so it
  flows with the rest of the plan.
- **Direct Messages Module** — `src/dm.zig` couples X25519 key exchange
  with ChaCha20-Poly1305 to power Nostr-style DMs in the upcoming GUI.
- **GrainBuffer** — `src/grain_buffer.zig` brings sticky read-only spans
  to the Ray terminal so command/status behave like Matklad’s Emacs
  dream.
- **GrainLoom** — `src/grain_loom.zig` is the general Grain network loom
  linking daemon, loop, and buffer for single-threaded builds.
- **Deterministic Recovery** — storyboard one-survivor rebuild workflows
  in Grain Conductor to match Jepsen-grade safety guarantees.
- **Bounded Retries** — clients must cap retries and surface faults; no
  infinite loops against TigerBank services.
- **Aurora Framework** — Svelte-like GrainAurora/Route/Orchestrator
  scaffolding captured in `docs/plan.md` with a stub preprocessor tool.
- **Unified Docs** — `docs/doc.md` folds the narrative into one file while
  the original series lives at `prototype_old/docs/design/` for history.
- **Declarative Brewfile Setup** — Inspired by Matthias Portzel’s
  Homebrew workflow, I plan to codify macOS dependencies in a Brewfile so
  the bootstrap remains deterministic and TigerStyle-clear.
- **Grain Conductor CLI** — I’m mapping Matklad’s `config` tool into a
  Zig “grain conduct” command suite with interactive and non-interactive
  modes for brew sync, linking, manifest inspection, and a deterministic
  build suite (`conduct make`).
- **Vegan Tiger Palette** — keep @vegan_tiger’s South Korean streetwear
  references on deck so Tahoe visuals stay ethical and covetable
  [^vegan-tiger].
- **Static Grainstore Manifest** — Instead of JSON, we rely on compiled
  Zig arrays (re-castable over the wire) to scaffold
  `grainstore/{platform}/{org}/{repo}`.

## Workflow Loop
1. **Draft in Docs** — add plan items to `docs/ray.md`, wrap with
   `zig build wrap-docs`, regenerate `ray_160.md`.
2. **Implement in Zig** — rename exports to snake_case, factor shared
   helpers (`SimpleRng`, `GrainStore`) and keep tests close to the code.
3. **Validate** — `zig test src/*.zig`, `zig build validate`, and
   `zig build wrap-docs` ensure TigerStyle compliance and formatted docs.
4. **Document and Repeat** — record new insights here, update prompts for
   O(1) append, and plan the next iteration in the Ray plan.

## Forward Notes
- Finish the grainmirror-inspired sync command so cloned repos land in
  `xy/grainstore`.
- Integrate Grain Foundations types directly into Ray’s metadata modules
  for shared struct consistency.
- Expand the CLI experience so rollbacks, grainstore scaffolding, and
  doc wrapping all ship via `zig build` targets.
- Capture a Brewfile under version control so fresh machines get the
  exact Homebrew + CLI stack via `brew bundle` with explicit comments.
- Expand static manifest arrays as we learn more about the repos we want
  to mirror; plan serialization for network casting later.
- Translate Vegan Tiger moodboards into shader and UI color studies
  before we prototype the Tahoe compositor.
- Flesh out the new `TahoeSandbox` stub (`src/tahoe_window.zig`) into a real Mach/Metal window.
- Shape the TigerBank Nostr + TigerBeetle payment protocol (`docs/nostr_mmt_tigerbank.md`)
  and fold its CLI stubs into `grain conduct`, now driven by `tigerbank_client.zig`.
- Finalize CDN bundle automation via `grain conduct cdn` with static buffer
  encoders so Ghostty panes can purchase bandwidth kiln-by-kiln.
- Harden `grain conduct ai` so Cursor CLI / Claude Code spawn through
  Ghostty tabs with GrainVault-fed keys.
- Hook Matklad fuzzers across `contracts.zig`, `grain_lattice.zig`, and the
  CLI to keep the enveloped codecs honest.
- Prototype `grain conduct` commands (e.g. `conduct brew`, `conduct link`,
  `conduct edit`) so interactive prompts and scripted modes both follow
  TigerStyle expectations.

Glow G2 keeps the tempo calm: test, wrap, validate, document. Every pass
brings Ray closer to the ethical Tahoe terminal we envisioned.

[^vegan-tiger]: Vegan Tiger Instagram profile highlighting South Korean
ethical streetwear inspiration. <http://instagram.com/vegan_tiger>
