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
- **Declarative Brewfile Setup** — Inspired by Matthias Portzel’s
  Homebrew workflow, I plan to codify macOS dependencies in a Brewfile so
  the bootstrap remains deterministic and TigerStyle-clear.
- **Grain Conductor CLI** — I’m mapping Matklad’s `config` tool into a
  Zig “grain conduct” command suite with interactive and non-interactive
  modes for brew sync, linking, and future tasks.

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
- Prototype `grain conduct` commands (e.g. `conduct brew`, `conduct link`,
  `conduct edit`) so interactive prompts and scripted modes both follow
  TigerStyle expectations.

Glow G2 keeps the tempo calm: test, wrap, validate, document. Every pass
brings Ray closer to the ethical Tahoe terminal we envisioned.

