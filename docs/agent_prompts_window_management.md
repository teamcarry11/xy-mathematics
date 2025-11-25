# Agent Prompts: Window Management Keybindings Integration

**Date**: 2025-11-24  
**For**: Grain Skate Silo Field Agent, Grain Aurora IDE Dream Browser Agent

## Prompt for Both Agents

You are integrating your application with Grain OS's window management system. The compositor provides Rectangle-inspired keyboard shortcuts for window positioning and resizing that work system-wide.

### Key Requirements

1. **Do NOT intercept Ctrl+Alt keybindings**: The compositor handles these at the system level. Your application should not capture or process Ctrl+Alt combinations that match window management shortcuts.

2. **Respond to window resize/move events**: When the compositor moves or resizes your application window, you must:
   - Update your internal layout
   - Re-render content to fit new dimensions
   - Adjust UI elements accordingly

3. **Respect window dimensions**: Always use the window dimensions provided by the compositor. Do not override or ignore compositor-managed window positions/sizes.

### Available Keybindings

**Half-Screen**:
- `Ctrl+Alt+Left` → Left half
- `Ctrl+Alt+Right` → Right half
- `Ctrl+Alt+Up` → Top half
- `Ctrl+Alt+Down` → Bottom half

**Quarter-Screen**:
- `Ctrl+Alt+U` → Top-left quarter
- `Ctrl+Alt+I` → Top-right quarter
- `Ctrl+Alt+J` → Bottom-left quarter
- `Ctrl+Alt+K` → Bottom-right quarter

**Third-Screen**:
- `Ctrl+Alt+D` → Left third
- `Ctrl+Alt+F` → Center third
- `Ctrl+Alt+G` → Right third
- `Ctrl+Alt+E` → Left two-thirds
- `Ctrl+Alt+T` → Right two-thirds

**Window Operations**:
- `Ctrl+Alt+Return` → Maximize
- `Ctrl+Alt+C` → Center
- `Ctrl+Alt+=` → Larger (10% increase)
- `Ctrl+Alt+-` → Smaller (10% decrease)
- `Ctrl+Alt+Shift+Up` → Maximize height only

### Implementation Tasks

1. **Review the keybinding documentation**: Read `docs/grain_os_window_management_keybindings.md` for complete technical details.

2. **Ensure input handling doesn't capture these shortcuts**: Check your keyboard event handling code. Make sure Ctrl+Alt combinations are not intercepted before the compositor can process them.

3. **Implement window resize handlers**: Add handlers that respond to window dimension changes:
   - For Grain Skate: Update graph visualization layout, adjust modal editor viewport
   - For Aurora/Dream: Re-layout editor panes, update browser viewport

4. **Test window management**: Verify that all keybindings work correctly with your application windows.

5. **Update documentation**: Document that your application supports Grain OS window management keybindings.

### Technical Details

- Keybindings are registered in `src/grain_os/keyboard_shortcuts.zig`
- Window actions are implemented in `src/grain_os/window_actions.zig`
- The compositor processes these shortcuts before routing events to applications
- Window IDs are managed by the compositor

### Expected Behavior

When a user presses `Ctrl+Alt+Left`:
1. The compositor detects the shortcut
2. The compositor moves/resizes your window
3. Your application receives a window resize event
4. Your application updates its layout and re-renders

### Questions to Answer

- [ ] Does your application capture any Ctrl+Alt key combinations?
- [ ] Does your application respond to window resize events?
- [ ] Does your application update its layout when the window is resized?
- [ ] Have you tested all window management keybindings with your application?

### Next Steps

1. Review `docs/grain_os_window_management_keybindings.md`
2. Check your input handling code for Ctrl+Alt interception
3. Implement window resize handlers if not already present
4. Test window management keybindings
5. Update your application documentation

---

## Specific Notes for Grain Skate Silo Field Agent

**Grain Skate** should:
- Update graph visualization layout when window is resized
- Adjust modal editor viewport when window is repositioned
- Recalculate graph node positions if needed
- Ensure graph rendering adapts to new window dimensions

**Files to check**:
- `src/grain_skate/window.zig` - Window event handling
- `src/grain_skate/graph_viz.zig` - Graph layout updates
- `src/grain_skate/app.zig` - Application window management

---

## Specific Notes for Grain Aurora IDE Dream Browser Agent

**Aurora IDE** and **Dream Browser** should:
- Re-layout editor panes when window is resized
- Update browser viewport when window is repositioned
- Adjust LSP integration viewport if needed
- Ensure editor/browser content fits new window dimensions

**Files to check**:
- `src/aurora_ide/editor.zig` - Editor pane layout
- `src/dream_browser/viewport.zig` - Browser viewport updates
- `src/platform/macos_tahoe/window.zig` - Window event handling (if applicable)

---

**Coordination**: No conflicts expected. These keybindings are compositor-level and work with all applications. Both agents should implement window resize handlers independently.

