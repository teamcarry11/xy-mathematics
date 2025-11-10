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

## Grain Conductor (Command Suite)
We reimagine Matklad’s `config` tool in Zig as **Grain Conductor** —
invoked via `grain conduct …`, offering both scripted and interactive
flows. First wave:

| Command                            | Behavior                                                         |
| ---------------------------------- | ---------------------------------------------------------------- |
| `conduct brew`                     | Run Brewfile sync (`brew bundle --cleanup --file=Brewfile`) and upgrade casks. |
| `conduct brew --assume-yes`        | Non-interactive mode for CI or scripted bootstrap.               |
| `conduct link`                     | Symlink home dotfiles from `vendor/grain-foundations` into place and provision static GrainStore entries. |
| `conduct link --manifest=path`     | Flag accepted for future network re-casting, currently ignored.  |
| `conduct edit`                     | Open the Grain workspace in Cursor (or fallback editor).         |
| `conduct make`                     | Build/install helper tools (future `grain conduct` subcommands). |

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
   - Extend `GrainStore` with static manifest entries (compiled arrays).
   - Mirror code into `grainstore/{platform}/{org}/{repo}`; plan network casting later.
5. **GUI / Nostr Roadmap**
   - Begin mapping River-inspired compositor tasks into actionable
     prototypes (`docs/gui_research.md` → issues/tasks).

## Tests & Tooling Targets
| Command               | Purpose                                      |
| --------------------- | -------------------------------------------- |
| `zig build test`      | Run `ray` and `nostr` suites (timestamp + npub fuzz). |
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

