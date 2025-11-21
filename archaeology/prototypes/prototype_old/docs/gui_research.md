# GUI & Compositor Research Notes

## River Compositor Inspiration
- River is an actively maintained Wayland compositor written in Zig (≈93% of the codebase) focused on
  dynamic tiling, runtime configuration with `riverctl`, and modular layout generators
  [^river-overview].
- The upcoming 0.4.0 roadmap aims to push even more window-management policy into a separate
  “window manager” process, aligning with our goal of sandboxing policy within the Grain GUI while
  keeping the compositor core lean [^river-overview].
- Packaging guidance shows River already builds against Zig 0.15, wlroots 0.19, and xkbcommon—useful
  baselines for our Tahoe sandbox environment [^river-overview].

## Zig GUI & Windowing Ecosystem (2025 Snapshot)
- **Mach Engine**: GPU-first framework targeting macOS/Metal with cross-platform ambitions. It offers
  window creation, input handling, and render loops suitable for compositor prototyping.
- **zgui (Dear ImGui bindings)**: Part of the `zig-gamedev` suite, providing immediate-mode GUI
  widgets atop GPU backends (Metal, Vulkan). Useful for in-app tooling panels even if the main UI is
  custom.
- **libui / minimal-window bindings**: Community crates surface native macOS Cocoa bridges; although
  not as feature-rich, they demonstrate piping Zig through Objective‑C runtime for lightweight
  window shells.
- **River’s architecture** suggests using wlroots-like abstractions even on macOS by mimicking the
  compositor in-process—this informs our plan to emulate River semantics inside a sandboxed
  environment rather than relying on system-wide privileges.

## Key Takeaways for Grain Tahoe Sandbox
- Adopt River’s separation of policy (layout generator) from compositor core; expose Moonglow-style
  keybindings via scripting akin to `riverctl`.
- Layer Mach (Metal) or zig-gamedev window APIs to render the sandboxed desktops, while hosting Grain
  terminal panes and Nostr dashboards inside.
- Reuse River’s focus on runtime configuration and per-tag workspace logic for our “veganic
  workstation” metaphor.

## Next Actions
- Draft a minimal compositor loop using Mach/Metal that can host one Grain terminal pane.
- Placeholder `TahoeSandbox` module (`src/tahoe_window.zig`) created; wire real Mach/Metal window logic here.
- Prototype a `riverctl`-style Zig API for Moonglow keybindings (focus swap, layout cycle).
- Spike a GUI pane showing Nostr feed slices using the current `[N]ZigTweet` structures.
- Identify security boundaries for sandboxing (entitlements, process separation) before Metal work.
- Integrate TigerBank transaction dashboards once `grain conduct mmt` 
  is capable of broadcasting payloads. `tigerbank_client.zig` currently
  prints deterministic logs we can surface in a developer console widget.
- Add Ghostty automation hooks so `grain conduct ai --tool=cursor` /
  `--tool=claude` can launch copilots inside Tahoe panes with GrainVault
  keys loaded from the mirrored secrets store.

[^river-overview]: River project overview and build requirements, including dynamic tiling focus and
                   Zig 0.15 toolchain updates, in *River README* (Codeberg, 2025-08-30)  
                   <https://codeberg.org/river/river>

