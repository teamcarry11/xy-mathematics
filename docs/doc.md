# Grain Handbook — Glow G2 Edition

## Current Roadmap: macOS Tahoe GUI Foundation 🎯

**Status**: Window rendering complete ✅. Next: Interactive input handling.

### Immediate Priorities

1. **Input Handling** 🔥 **IMMEDIATE**
   - Mouse events (clicks, movement, drag)
   - Keyboard events (key presses, modifiers)
   - Window focus events
   - Event routing to Aurora's event system

2. **Animation/Update Loop** 🔥 **HIGH PRIORITY**
   - Timer-based updates (60fps target)
   - Continuous redraw via `tick()` calls
   - Window resize handling
   - Event-driven updates

3. **Window Resizing** 🔥 **HIGH PRIORITY**
   - `windowDidResize:` delegate implementation
   - Dynamic buffer resizing or scaling
   - CGImage/NSImage recreation on resize

4. **Text Rendering Integration** ⭐ **MEDIUM PRIORITY**
   - Integrate `TextRenderer` into `tahoe_window.zig`
   - Render text to RGBA buffer
   - Text input handling
   - Cursor rendering

5. **NSApplication Delegate** ⭐ **MEDIUM PRIORITY**
   - Proper app lifecycle handling
   - Clean shutdown support
   - Window delegate methods
   - Menu bar integration

6. **River Compositor Foundation** ⭐ **MEDIUM PRIORITY**
   - Multi-pane layout system
   - Window tiling logic
   - Moonglow keybindings
   - Workspace support

### Future Work

7. Defer QEMU testing until Framework 13 or VPS is ready; meanwhile keep
   notes in `docs/boot/notes.md` and focus on macOS Tahoe Aurora work.
8. Implement Grain Pottery kiln orchestration and GrainVault secrets
   wiring.
9. Harden Graindaemon transport backends (TCP, debug) and expose CLI
   toggles.
10. Document deterministic single-copy recovery steps and automate them in
    Grain Conductor.
11. Expand TigerBank bounded retry tests and publish Jepsen-aligned
    assertions.
