# Grain Aurora GUI Plan — TigerStyle Execution

**Current Status**: Window rendering complete ✅. Focus: Interactive macOS Tahoe GUI foundation.

## macOS Tahoe GUI Foundation (Current Priority) 🎯

### 1. Input Handling 🔥 **IMMEDIATE PRIORITY**
- Mouse events: clicks, movement, drag operations
- Keyboard events: key presses, modifiers (Cmd, Option, Shift, Control)
- Window focus events: `windowDidBecomeKey:`, `windowDidResignKey:`
- Event routing: forward Cocoa events to Aurora's event system
- Files: `src/platform/macos_tahoe/window.zig` (add event handlers), `src/tahoe_window.zig` (event processing)

### 2. Animation/Update Loop 🔥 **HIGH PRIORITY**
- Timer-based update loop: `NSTimer` or `CADisplayLink` for smooth updates
- Continuous redraw: call `tick()` on timer interval (60fps target)
- Window resize handling: update buffer or scale rendering on resize
- Event-driven updates: redraw on input events, window changes
- Files: `src/tahoe_app.zig`, `src/tahoe_window.zig`, `src/platform/macos_tahoe/window.zig`

### 3. Window Resizing 🔥 **HIGH PRIORITY**
- Implement `windowDidResize:` delegate method
- Handle dynamic buffer resizing or fixed-size scaling
- Recreate CGImage/NSImage on window size changes
- Maintain aspect ratio or allow free resizing
- Files: `src/platform/macos_tahoe/window.zig` (delegate implementation)

### 4. Text Rendering Integration ⭐ **MEDIUM PRIORITY**
- Integrate existing `TextRenderer` into `tahoe_window.zig`
- Render text to RGBA buffer: fonts, basic layout, word wrapping
- Text input handling: keyboard → text buffer → render
- Cursor rendering: show text cursor position
- Files: `src/tahoe_window.zig`, `src/aurora_text_renderer.zig`

### 5. NSApplication Delegate ⭐ **MEDIUM PRIORITY**
- Implement `NSApplicationDelegate` protocol methods
- Handle `applicationShouldTerminate:` for clean shutdown
- Window delegate: `windowWillClose:`, `windowDidResize:`, etc.
- Menu bar integration: File, Edit, View menus
- Files: `src/platform/macos_tahoe/window.zig` (new delegate class), `src/tahoe_app.zig`

### 6. River Compositor Foundation ⭐ **MEDIUM PRIORITY**
- Multi-pane layout system: split windows horizontally/vertically
- Window tiling logic: deterministic layout algorithms
- Moonglow keybindings: `Cmd+Shift+H` (horizontal split), `Cmd+Shift+V` (vertical split)
- Workspace support: multiple workspaces with window groups
- Files: `src/tahoe_window.zig` (compositor logic), `src/platform/macos_tahoe/window.zig` (multi-window support)

## Completed Work ✅

### macOS Tahoe Window Rendering ✅ **COMPLETE**
- Rewrote `window.zig` from scratch to fix parser errors
- Fixed NSImage creation: use NSBitmapImageRep + NSImage instead of non-existent `imageWithCGImage:size:`
- Fixed struct return handling: added `objc_msgSend_returns_NSRect` for methods returning NSRect by value
- Switched to NSImageView: replaced manual drawing with `NSImageView.setImage:` for reliable rendering
- Window successfully displays 1024x768 RGBA buffer (dark blue-gray background with white rectangle)
- All compilation errors resolved, application runs successfully
- Files: `src/platform/macos_tahoe/window.zig`, `src/platform/macos_tahoe/objc_wrapper.c`, `src/platform/macos_tahoe/cocoa_bridge.zig`

### Cocoa Bridge Implementation ✅
- Implemented actual NSApplication, NSWindow, NSView calls
- Created `cocoa_bridge.zig` with typed `objc_msgSend` wrappers
- Build succeeds: `zig build tahoe` compiles successfully
- Executable runs: window shows, event loop implemented

### Experimental Randomized Fuzz Test 002 ✅
- Decoupled into `tests-experiments/002_macos.md` and `999_riscv.md`
- Implemented buffer content validation (FNV-1a checksum)
- Implemented memory leak detection (GeneralPurposeAllocator)
- Added error path coverage test
- Tests pass: validates platform abstraction boundaries

### Pre-VPS Launchpad ✅
- Scaffolded `src/kernel/` (`main.zig`, `syscall_table.zig`, `devx/abi.zig`)
- Extended `grain conduct` with `make kernel-rv64`, `run kernel-rv64`, `report kernel-rv64`

## Deferred Work (Lower Priority)

### Kernel Toolkit (paused)
- QEMU + rsync scripts are staged
- Resume once Framework 13 RISC-V board or VPS is available
- Focus on macOS Tahoe Aurora IDE work for now

### Grain Conductor & Pottery (future)
- Extend `grain conduct` (`brew|link|manifest|edit|make|ai|contracts|mmt|cdn`)
- Model Grain Pottery scheduling for CDN kilns, ledger mints, and AI copilots

### Grain Social Terminal (future)
- Keep social data typed in Zig, fuzz 11 `npub`s per run
- Share settlement encoders in `src/contracts.zig`; store secrets via `src/grainvault.zig`

### Onboarding & Care
- See `docs/get-started.md` for beginner guide
- Maintain onboarding scripts (Cursor Ultra, GitHub/Gmail/iCloud, 2FA, Ghostty setup)

### Poetry & Waterbending
- Thread ASCII bending art and Helen Atthowe quotes through docs/code

### Thread Weaver
- Regenerate `docs/ray_160.md` via `zig build thread`; enforce 160-character blocks

### Prompt Ledger
- Keep `docs/prompts.md` descending; append at index 0

### Timestamp Glow
- Maintain `src/ray.zig` timestamp grammar and fuzz coverage (`tests-experiments/000.md`)

### Archive Echoes
- Rotate `prototype_old/`, `prototype_older/`, and `prototype_oldest/`

### Delta Checks
- Run `zig build wrap-docs`, `zig build test`, and keep docs in sync

[^dcroma]: [DeepComputing DC-ROMA RISC-V Mainboard](https://deepcomputing.io/product/dc-roma-risc-v-mainboard/)
[^framework-mainboard]: [Framework Marketplace – DeepComputing RISC-V Mainboard](https://frame.work/products/deep-computing-risc-v-mainboard)
[^framework-blog]: [Framework Blog: RISC-V Mainboard for Framework Laptop 13](https://frame.work/blog/risc-v-mainboard-for-framework-laptop-13-is-now-available)
