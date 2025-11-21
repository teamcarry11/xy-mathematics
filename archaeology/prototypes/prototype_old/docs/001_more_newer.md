# Ray Continuum — Design Update 001

## Why Another Ray?
The original Ray plan (“Ray Lullaby”) anchors_today's build.  
This document extends it—same TigerStyle heart, wider scope.  
Think of it as the next movement in the same score.  
We keep the `[2 | 1 | 1]` envelope intact while growing new limbs.

## Reaffirmed Principles
- **TigerStyle Core** — 100-column ceiling, explicit allocation,
  assertions before wishful thinking.
- **Matklad Loop** — data-driven tests + fuzzers (`SimpleRng`)
  to keep refactors guilt-free.
- **Zig-Orchestrated Monorepo** — `xy` stays self-hosted with deterministic
  build steps, no implicit Python or shell glue.
- **Prose Mirrors Code** — documentation lives under 73 characters and
  is regenerated via `zig build wrap-docs`.
- **Brewfile/Bundle** — declarative macOS provisioning (install Homebrew,
  `git`, `gh`, Cursor) inspired by Matthias Portzel’s Brewfile workflow
  [^brewfile].
- **Mac Interaction Literacy** — respect the “Mac way” (document focus,
  drag/drop, menu exploration) while we introduce Grain Tahoe ideas
  [^macos-tips].
- **Vegan Tiger Signals** — fold in @vegan_tiger’s South Korean streetwear
  cues so the Grain terminal keeps a covetable ethical fashion pulse
  [^vegan-tiger].
- **TahoeSandbox Stub** — `src/tahoe_window.zig` now holds a placeholder
  Mach/Metal host ready for the GUI spike.
- **TigerBank Spec** — `docs/nostr_mmt_tigerbank.md` defines the Nostr +
  TigerBeetle + MMT payment flow with Alpenglow-style consensus.
  `tigerbank_client.zig` now drives stub submissions from the CLI.
- **Ghostty Habits** — treat Ghostty (Zig terminal) as first-class: brew or
  source install, theme to Vegan Tiger palette, script via Conductor.
- **GrainVault Secrets** — secrets never live in repo; `src/grainvault.zig`
  reads `CURSOR_API_TOKEN` / `CLAUDE_CODE_API_TOKEN` mirrored from
  `{teamtreasure02}/grainvault`.
- **Settlement Contracts** — `src/contracts.zig` centralizes TigerBank
  payload codecs plus optional inventory/sales/payroll kilns.
- **Grain Lattice** — `src/grain_lattice.zig` captures the Djinn DAG
  architecture with summarize + envelope helpers for tests and docs.
- **Matklad Loop** — `zig build test` now hits contracts, lattice, CDN, MMT,
  Ray, and Nostr suites; fuzz guidance lives in `tests-experiments/000.md`.
- **Documentary Ledger** — 12-part series in `docs/doc-series/` narrates
  the architecture, manuals, prompt art, and future roadmap.
- **Transport Upgrade Plan** — upcoming work: add transport abstraction to
  `tigerbank_client.zig` (debug vs TCP) and make it configurable via Grain
  Conductor.
- **Direct Messages Module** — `src/dm.zig` implements X25519 +
  ChaCha20-Poly1305 messaging; plug it into Tahoe GUI panes next.
- **GrainBuffer** — `src/grain_buffer.zig` grants Matklad-style read-only
  spans so Ray’s Ghostty terminal mirrors Emacs sticky ranges.
- **GrainAurora Plan** — `docs/plan.md` documents the new Aurora UI
  framework plus `src/grain_route.zig`, `src/grain_orchestrator.zig`, and
  `tools/aurora_preprocessor.zig` scaffolding.
- **Graindaemon CLI** — `zig build graindaemon -- --watch xy` supervises
  allocator ceilings and state transitions without leaving the terminal.
- **Deterministic Recovery** — document and script single-copy restore
  paths (GrainLoom + Graindaemon + contracts) in response to Jepsen’s
  TigerBeetle findings.
- **Bounded Retries** — ensure TigerBank/Nostr clients classify errors
  and cap retries; no infinite loops.
- **Docs Unification** — `docs/doc.md` now hosts the live handbook while
  the original series rests in `prototype_old/docs/design/`.

## Grain Conductor (Command Suite)
We reimagine Matklad’s `config` tool in Zig as **Grain Conductor** —
invoked via `grain conduct …`, offering both scripted and interactive
flows. First wave:

| Command                            | Behavior                                                         |
| ---------------------------------- | ---------------------------------------------------------------- |
| `conduct brew`                     | Run Brewfile sync (`brew bundle --cleanup --file=Brewfile`) and upgrade casks. |
| `conduct brew --assume-yes`        | Non-interactive mode for CI or scripted bootstrap.               |
| `conduct link`                     | Symlink home dotfiles from `vendor/grain-foundations` into place and provision static entries from `src/grain_manifest.zig`. |
| `conduct link --manifest=path`     | Flag accepted for future network re-casting, currently ignored.  |
| `conduct manifest`                 | Print the static manifest entries to stdout for inspection.      |
| `conduct edit`                     | Open the Grain workspace in Cursor (or fallback editor).         |
| `conduct make`                     | Run a deterministic build suite (`zig build test`, `wrap-docs`, `validate`, `thread`). |
| `conduct mmt`                      | Encode MMT payloads into raw bytes; optionally push to TigerBeetle/Nostr logs. |
| `conduct cdn`                      | Issue CDN bundle subscription packets (basic → ultra tiers).     |
| `conduct ai`                       | Launch Cursor CLI or Claude Code with secrets sourced from GrainVault. |
| `conduct contracts --future`       | (TBD) will expose contract introspection via `contracts.zig`.     |

Interactive mode prompts (with yes/no guards); non-interactive mode uses
flags for CI or scripted bootstrap. Errors bubble with TigerStyle
assertions.

## Immediate Build Goals
1. **Finish GitHub Bootstrapping**
   - `gh auth login`, `gh repo create kae3g/xy`, push `main`.
   - Keep repo README-free by design.
2. **Ship Grain Conductor Skeleton**
   - New module under `tools/grain_conductor.zig`.
   - Parse commands, delegate to brew/link/edit/make helpers.
3. **Vendor Brewfile**
   - Add `Brewfile` listing CLI tools (Homebrew, git, gh, Cursor, Zig).
   - Document usage in onboarding section.
4. **Grainstore Sync Prototype**
   - Extend `GrainStore` with static manifest entries (`src/grain_manifest.zig`).
   - Mirror code into `grainstore/{platform}/{org}/{repo}`; plan network casting later.
5. **GUI / Nostr Roadmap**
   - Begin mapping River-inspired compositor tasks into actionable
     prototypes (`docs/gui_research.md` → issues/tasks). First stub lives
     in `src/tahoe_window.zig`.
   - Align the new `grain conduct mmt` stub with TigerBank ledger logic.
     Stub client currently prints deterministic logs per endpoint; replace
     with real IO during the next pass.
   - Finish CDN bundle automation (`grain conduct cdn`) and Ghostty automation
     so TahoeSandbox panes can drive AI copilots directly.
   - Integrate preflight checks so Matklad randomized tests (`zig build test`)
     cover contracts, lattice, and conductor modules together.

## Ghostty & Terminal Setup
- **Install via Homebrew**: `brew install ghostty` (or clone
  `https://github.com/mitchellh/ghostty` and `zig build -Drelease-safe`).
- **Config Location**: symlink Ghostty config from `xy/dotfiles/tahoe/ghostty/`
  to `~/Library/Application Support/org.ghostty/config`.
- **Workflow**: launch Ghostty, run `grain conduct ai --tool=cursor --arg="--headless"`.
- **Secrets**: export `CURSOR_API_TOKEN`, `CLAUDE_CODE_API_TOKEN` (sourced via
  GrainVault mirror). `grain conduct ai` refuses to run without them.
- **Unified Cursor To-Do Loop**
  - Document live tasks in `docs/ray.md` → keep Cursor/Claude sessions
    aligned via `grain conduct ai`.
  - Use `todo_write`-style structure: `research`, `build`, `test`, `document`.
  - Fold Matklad fuzz fixtures into each sprint (`zig build test`, `tests-experiments/000.md`).

## Tests & Tooling Targets
| Command               | Purpose                                      |
| --------------------- | -------------------------------------------- |
| `zig build test`      | Run contracts, lattice, CDN, MMT, Ray, and Nostr suites (Matklad fuzz). |
| `zig build wrap-docs` | Enforce 73-column docs with `grainwrap`.      |
| `zig build validate`  | Grainvalidate snake_case + function length.   |
| `zig build thread`    | Generate `docs/ray_160.md`.                   |
| `zig build conduct`   | Build/run Grain Conductor CLI (static manifest). |

## Shared Timeline
We continue to treat `docs/ray.md` as the canonical plan.  
This document layers the next iteration on top—no duplication.  
As milestones ship, we fold their essence back into `ray.md`.

Glow G2 stays in the lodge, watching the Tahoe light while each tool
clicks into place. TigerStyle keeps us honest; Brewfiles, Matklad loops,
and Grain Conductor make it reproducible.

[^brewfile]: [Declarative package management with a Brewfile](https://matthiasportzel.com/brewfile/)
[^macos-tips]: [macOS Tips](https://blog.xoria.org/macos-tips/)
[^vegan-tiger]: Vegan Tiger Instagram profile highlighting South Korean
ethical streetwear inspiration. <http://instagram.com/vegan_tiger>

