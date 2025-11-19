# Grain Handbook — Glow G2 Edition

## Current Roadmap: macOS Tahoe GUI Foundation 🎯

**Status**: Window rendering complete ✅. Next: Interactive input handling.

### Immediate Priorities

0. **RISC-V Kernel Virtualization Layer** 🔥 **HIGH PRIORITY** 🎯 **NEW**
   - **Vision**: Run Zig monolith kernel in virtualized RISC-V environment within macOS Tahoe IDE
   - **Why**: Enable kernel development and testing without physical RISC-V hardware or external QEMU
   - Embed RISC-V emulator as River compositor pane within Tahoe window
   - Pure Zig implementation (or QEMU/lib binding) for RISC-V64 ISA
   - Terminal-like output rendering: Kernel serial output → RGBA buffer → NSImageView
   - GDB stub integration for kernel debugging within IDE
   - Hot reload: Recompile kernel on save, reload into VM
   - See `docs/ray.md` Phase 1, item 0 for detailed architecture

1. **Input Handling** 🔥 **IMMEDIATE** ✅ **COMPLETE**
   - Mouse events (clicks, movement, drag)
   - Keyboard events (key presses, modifiers)
   - Window focus events
   - Event routing to Aurora's event system

2. **Animation/Update Loop** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
   - Timer-based updates (60fps target)
   - Continuous redraw via `tick()` calls
   - Window resize handling
   - Event-driven updates

3. **Window Resizing** 🔥 **HIGH PRIORITY** ✅ **COMPLETE**
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

7. **Kernel Toolkit (Reoriented)**: Previous QEMU/VPS approach → Now integrated as RISC-V virtualization layer within macOS Tahoe (see item 0 above)
8. Implement Grain Pottery kiln orchestration and GrainVault secrets
   wiring.
9. Harden Graindaemon transport backends (TCP, debug) and expose CLI
   toggles.
10. Document deterministic single-copy recovery steps and automate them in
    Grain Conductor.
11. Expand TigerBank bounded retry tests and publish Jepsen-aligned
    assertions.
