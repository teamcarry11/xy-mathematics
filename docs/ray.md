# Ray Lullaby — Glow G2’s Tahoe Field Notes

Glow G2 watches the sun fold itself behind Tahoe’s ridge line,
cheeks cold, heart steady. Every line
of this plan is sewn with TigerStyle thread—safety stitched first,
performance braided next, joy
embroidered last.

## Mood Board
- **Grain Aurora**: A Zig-first IDE that combines Cursor's agentic coding with native macOS performance and Matklad's LSP architecture. Think Cursor, but faster, Zig-native, and built on snapshot-based incremental analysis.
- **Zig Language Server**: Matklad-inspired snapshot model (`ready` / `working` / `pending`) with cancellation support. Start with data model, then fill in language features incrementally.
- **Agentic Coding**: Cursor CLI and Claude Code integration for AI-assisted Zig development. Zig-specific prompts understand comptime, error unions, and TigerStyle.
- **River Compositor**: Window tiling with Moonglow keybindings, blurring editor and terminal (Vibe Coding). Multiple panes, workspaces, deterministic layouts.
- **Native macOS**: Cocoa bridge, no Electron. Traffic lights, menu bar, proper window lifecycle. Fast, responsive, native.
- Glow G2 stays a calm voice: masculine, steadfast, Aquarian. Emo enough 
to acknowledge the ache, upbeat enough to guide with grace.
- Vegan Tiger's (@vegan_tiger) South Korean streetwear silhouette feeds 
our Tahoe aesthetic, reminding us to keep ethical fashion signal in view
  [^vegan-tiger].

## Ray Mission Ladder (Deterministic & Kind)

**Vision**: Grain Aurora as a Zig-first IDE with Matklad-inspired LSP architecture, combining Cursor-style agentic coding with native macOS performance and River compositor workflows.

### Phase 1: macOS Tahoe GUI Foundation (Current Priority) 🎯

**Status**: Window rendering complete ✅. Next: Interactive input handling.

1. **Input Handling (macOS Tahoe)** 🔥 **IMMEDIATE PRIORITY**
   - Mouse events: clicks, movement, drag operations
   - Keyboard events: key presses, modifiers (Cmd, Option, Shift, Control)
   - Window focus events: `windowDidBecomeKey:`, `windowDidResignKey:`
   - Event routing: forward Cocoa events to Aurora's event system
   - Files: `src/platform/macos_tahoe/window.zig` (add event handlers), `src/tahoe_window.zig` (event processing)

2. **Animation/Update Loop (macOS Tahoe)** 🔥 **HIGH PRIORITY**
   - Timer-based update loop: `NSTimer` or `CADisplayLink` for smooth updates
   - Continuous redraw: call `tick()` on timer interval (60fps target)
   - Window resize handling: update buffer or scale rendering on resize
   - Event-driven updates: redraw on input events, window changes
   - Files: `src/tahoe_app.zig`, `src/tahoe_window.zig`, `src/platform/macos_tahoe/window.zig`

3. **Window Resizing (macOS Tahoe)** 🔥 **HIGH PRIORITY**
   - Implement `windowDidResize:` delegate method
   - Handle dynamic buffer resizing or fixed-size scaling
   - Recreate CGImage/NSImage on window size changes
   - Maintain aspect ratio or allow free resizing
   - Files: `src/platform/macos_tahoe/window.zig` (delegate implementation)

4. **Text Rendering Integration (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Integrate existing `TextRenderer` into `tahoe_window.zig`
   - Render text to RGBA buffer: fonts, basic layout, word wrapping
   - Text input handling: keyboard → text buffer → render
   - Cursor rendering: show text cursor position
   - Files: `src/tahoe_window.zig`, `src/aurora_text_renderer.zig`

5. **NSApplication Delegate (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Implement `NSApplicationDelegate` protocol methods
   - Handle `applicationShouldTerminate:` for clean shutdown
   - Window delegate: `windowWillClose:`, `windowDidResize:`, etc.
   - Menu bar integration: File, Edit, View menus
   - Files: `src/platform/macos_tahoe/window.zig` (new delegate class), `src/tahoe_app.zig`

6. **River Compositor Foundation (macOS Tahoe)** ⭐ **MEDIUM PRIORITY**
   - Multi-pane layout system: split windows horizontally/vertically
   - Window tiling logic: deterministic layout algorithms
   - Moonglow keybindings: `Cmd+Shift+H` (horizontal split), `Cmd+Shift+V` (vertical split)
   - Workspace support: multiple workspaces with window groups
   - Files: `src/tahoe_window.zig` (compositor logic), `src/platform/macos_tahoe/window.zig` (multi-window support)

### Phase 2: Core IDE Foundation

7. **Zig Language Server Protocol (LSP) Implementation** ⭐ **FUTURE PRIORITY**
   - Build snapshot-based LSP server using Matklad's cancellation-aware model
   - Start with rock-solid data model: source code store that evolves over time
   - Implement incremental analysis: only re-analyze what changed
   - Support cancellation: long-running analysis can be cancelled when user types
   - Reference: [Matklad's Zig LSP architecture](https://matklad.github.io/2023/05/06/zig-language-server-and-cancellation.html)
   - Files: `src/aurora_lsp/` (new module)

8. **Text Editor Core**
   - Multi-file editor with tab support
   - Syntax highlighting for Zig (semantic + lexical)
   - Cursor management: single cursor, multi-cursor support
   - Selection handling: word, line, block selection
   - Files: `src/aurora_editor/` (extend existing)

9. **Code Completion & Semantic Features**
   - LSP-based code completion (`textDocument/completion`)
   - Go to definition (`textDocument/definition`)
   - Find all references (`textDocument/references`)
   - Rename symbol (`textDocument/rename`)
   - Inlay hints: parameter names, types, comptime values
   - Files: `src/aurora_lsp/`, `src/aurora_editor/`

### Phase 3: Agentic Coding Integration

10. **Cursor CLI / Claude Code Integration**
   - Cursor CLI integration for AI-assisted coding
   - Claude Code API integration (alternative to Cursor)
   - Agent chat pane: similar to Cursor's Composer mode
   - Diff view for AI-generated code changes
   - Accept/reject workflow (`Cmd+Enter` / `Esc`)
   - Files: `src/aurora_agent/` (new module), `src/grainvault/` (API keys)

11. **Zig-Specific Agent Prompts**
   - Comptime-aware code generation
   - Error union handling suggestions
   - TigerStyle compliance checks
   - Memory safety analysis suggestions
   - Files: `src/aurora_agent/prompts.zig`

### Phase 4: Advanced IDE Features

12. **Terminal Integration (Vibe Coding)**
   - Integrated terminal: blur line between editor and terminal
   - Split panes: like tmux, but integrated
   - Command history: `Cmd+Up` to scroll
   - Zig REPL integration: type `zig` to enter REPL mode
   - Build output linking: errors link back to source
   - Reference: [Matklad's Vibe Coding](https://matklad.github.io/2025/08/31/vibe-coding-terminal-editor.html)

13. **Aurora UI Enhancements**
   - Complete Flux Darkroom color filter integration
   - Native macOS menu bar with `View ▸ Flux` toggle
   - Menu bar: `Aurora | File | Edit | Selection | View | Go | Run | Terminal | Window | Help`
   - Theme support: Dark/Light/One Dark Pro

14. **Missing IDE Features** (Matklad-inspired)
    - Read-only characters: show immutable vs mutable state
    - Extend selection: semantic-aware selection expansion
    - Code actions/assists: 💡 lightbulb for quick fixes
    - Breadcrumbs: show symbol hierarchy
    - Reference: [Matklad's Missing IDE Feature](https://matklad.github.io/2024/10/14/missing-ide-feature.html)

### Completed Work ✅

11. **Cocoa Bridge Implementation (done)**
    - Implemented actual NSApplication, NSWindow, NSView calls
    - Created `cocoa_bridge.zig` with typed `objc_msgSend` wrappers
    - Build succeeds: `zig build tahoe` compiles successfully
    - Executable runs: window shows, event loop implemented

12. **Experimental Randomized Fuzz Test 002 (done)**
    - Decoupled into `tests-experiments/002_macos.md` and `999_riscv.md`
    - Implemented buffer content validation (FNV-1a checksum)
    - Implemented memory leak detection (GeneralPurposeAllocator)
    - Added error path coverage test
    - Tests pass: validates platform abstraction boundaries

13. **Pre-VPS Launchpad (done)**
    - Scaffolded `src/kernel/` (`main.zig`, `syscall_table.zig`, `devx/abi.zig`)
    - Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`, `report kernel-rv64`

### Deferred Work (Lower Priority)

14. **Kernel Toolkit (paused)**
    - QEMU, rsync, and gdb scripts are staged
    - Resume once Framework 13 RISC-V board or VPS is available
    - Focus on macOS Tahoe Aurora IDE work for now

15. **Grain Conductor & Pottery** (Future)
    - `zig build conduct` drives `grain conduct brew|link|manifest|edit|make|ai|contracts|mmt|cdn`
    - Pottery abstractions schedule CDN kilns, ledger mints, and AI copilots

16. **Grain Social Terminal** (Future)
    - Typed Zig arrays represent social data; fuzz 11 random `npub`s per run
    - TigerBank flows share encoders via `src/contracts.zig` and secrets via `src/grainvault.zig`

17. **Onboarding & Care**
    - See `docs/get-started.md` for beginner guide
    - Guard passwords, cover Cursor Ultra, GitHub/Gmail/iCloud onboarding, 2FA

18. **Poetry & Waterbending**
    - Lace ASCII bending art and Helen Atthowe quotes throughout code and docs

19. **Thread Weaver**
    - `tools/thread_slicer.zig` + `zig build thread` keep `docs/ray.md` mirrored as `docs/ray_160.md`

20. **Prompt Ledger**
    - `docs/prompts.md` holds descending `PROMPTS`; new entries append at index 0

21. **Timestamp Glow**
    - `src/ray.zig` keeps runtime timestamps validated by fuzz tests

22. **Archive Echoes**
    - Maintain the archive rotation (`prototype_oldest/`, `prototype_older/`, `prototype_old/`)

23. **Delta Checks**
    - Keep Ray, prompts, outputs, and tests aligned (`zig build test`, `zig build wrap-docs`)

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

























