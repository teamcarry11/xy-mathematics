# Grain OS Window Management Keybindings

**Date**: 2025-11-24  
**Purpose**: Document window management keyboard shortcuts for application integration  
**Target Agents**: Grain Skate Silo Field Agent, Grain Aurora IDE Dream Browser Agent

## Overview

Grain OS implements a Rectangle-inspired window management system with keyboard shortcuts for positioning and resizing windows. These keybindings are available system-wide and should be respected by all applications running in the Grain OS compositor.

## Keybinding System

The window management system uses **Ctrl+Alt** (or **Ctrl+Alt+Shift** for some actions) as the modifier combination. All keybindings are registered in `src/grain_os/keyboard_shortcuts.zig` and implemented in `src/grain_os/window_actions.zig`.

## Available Keybindings

### Half-Screen Positioning

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Ctrl+Alt+Left** | Left Half | Move window to left half of screen |
| **Ctrl+Alt+Right** | Right Half | Move window to right half of screen |
| **Ctrl+Alt+Up** | Top Half | Move window to top half of screen |
| **Ctrl+Alt+Down** | Bottom Half | Move window to bottom half of screen |

### Quarter-Screen Positioning

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Ctrl+Alt+U** | Top Left | Move window to top-left quarter |
| **Ctrl+Alt+I** | Top Right | Move window to top-right quarter |
| **Ctrl+Alt+J** | Bottom Left | Move window to bottom-left quarter |
| **Ctrl+Alt+K** | Bottom Right | Move window to bottom-right quarter |

### Third-Screen Positioning

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Ctrl+Alt+D** | First Third | Move window to left third (1/3 width) |
| **Ctrl+Alt+F** | Center Third | Move window to center third (1/3 width) |
| **Ctrl+Alt+G** | Last Third | Move window to right third (1/3 width) |
| **Ctrl+Alt+E** | First Two Thirds | Move window to left two-thirds (2/3 width) |
| **Ctrl+Alt+T** | Last Two Thirds | Move window to right two-thirds (2/3 width) |

### Window Operations

| Keybinding | Action | Description |
|------------|--------|-------------|
| **Ctrl+Alt+Return** | Maximize | Maximize window to full screen |
| **Ctrl+Alt+C** | Center | Center window on screen |
| **Ctrl+Alt+=** | Larger | Increase window size by 10% |
| **Ctrl+Alt+-** | Smaller | Decrease window size by 10% |
| **Ctrl+Alt+Shift+Up** | Maximize Height | Maximize window height only |

## Technical Implementation

### Key Codes

The keybindings use the following key codes (defined in `keyboard_shortcuts.zig`):

```zig
KEY_LEFT: u32 = 0x25
KEY_UP: u32 = 0x26
KEY_RIGHT: u32 = 0x27
KEY_DOWN: u32 = 0x28
KEY_RETURN: u32 = 0x0D
KEY_EQUALS: u32 = 0x3D
KEY_MINUS: u32 = 0x2D
KEY_U: u32 = 0x55
KEY_I: u32 = 0x49
KEY_J: u32 = 0x4A
KEY_K: u32 = 0x4B
KEY_D: u32 = 0x44
KEY_F: u32 = 0x46
KEY_G: u32 = 0x47
KEY_E: u32 = 0x45
KEY_T: u32 = 0x54
KEY_C: u32 = 0x43
```

### Modifier Flags

```zig
MODIFIER_CTRL: u8 = 0x01
MODIFIER_ALT: u8 = 0x02
MODIFIER_SHIFT: u8 = 0x04
MODIFIER_META: u8 = 0x08
```

### Window Actions

All window actions are implemented as functions in `src/grain_os/window_actions.zig`:

- `action_left_half(comp: *Compositor, window_id: u32) bool`
- `action_right_half(comp: *Compositor, window_id: u32) bool`
- `action_top_half(comp: *Compositor, window_id: u32) bool`
- `action_bottom_half(comp: *Compositor, window_id: u32) bool`
- `action_top_left(comp: *Compositor, window_id: u32) bool`
- `action_top_right(comp: *Compositor, window_id: u32) bool`
- `action_bottom_left(comp: *Compositor, window_id: u32) bool`
- `action_bottom_right(comp: *Compositor, window_id: u32) bool`
- `action_first_third(comp: *Compositor, window_id: u32) bool`
- `action_center_third(comp: *Compositor, window_id: u32) bool`
- `action_last_third(comp: *Compositor, window_id: u32) bool`
- `action_first_two_thirds(comp: *Compositor, window_id: u32) bool`
- `action_last_two_thirds(comp: *Compositor, window_id: u32) bool`
- `action_center(comp: *Compositor, window_id: u32) bool`
- `action_larger(comp: *Compositor, window_id: u32) bool`
- `action_smaller(comp: *Compositor, window_id: u32) bool`
- `action_maximize_height(comp: *Compositor, window_id: u32) bool`

## Integration Requirements

### For Application Developers

1. **Do NOT intercept these keybindings**: Applications should not capture or handle **Ctrl+Alt** combinations that match the window management shortcuts. The compositor handles these at the system level.

2. **Window ID tracking**: Applications should be aware of their window ID (assigned by the compositor) but do not need to manage it directly.

3. **Window position/size changes**: Applications should respond to window position and size changes from the compositor. When the compositor moves or resizes a window, the application should:
   - Update its internal layout
   - Re-render content to fit the new dimensions
   - Adjust UI elements as needed

4. **Input event routing**: Keyboard events matching window management shortcuts are handled by the compositor before being routed to applications. Applications will not receive these events.

### For Grain Skate Silo Field Agent

**Grain Skate** windows should:
- Respect window position/size changes from the compositor
- Re-layout the graph visualization when the window is resized
- Adjust the modal editor viewport when the window is repositioned
- Not capture Ctrl+Alt key combinations

**Implementation notes**:
- The window management system will call `compositor.recalculate_layout()` after each action
- Grain Skate should listen for window resize events and update its rendering accordingly
- The graph visualization should adapt to the new window dimensions

### For Grain Aurora IDE Dream Browser Agent

**Aurora IDE** and **Dream Browser** windows should:
- Respect window position/size changes from the compositor
- Re-layout editor panes when the window is resized
- Adjust browser viewport when the window is repositioned
- Not capture Ctrl+Alt key combinations

**Implementation notes**:
- Editor panes should redistribute space when the window is resized
- Browser viewport should update to match new window dimensions
- LSP integration should continue to work after window moves/resizes

## Compositor Integration

The compositor automatically:
1. Registers all shortcuts on initialization
2. Processes keyboard events before routing to applications
3. Calls the appropriate window action when a shortcut is detected
4. Recalculates the layout after each action
5. Updates window positions and sizes

## Example Usage

When a user presses **Ctrl+Alt+Left**:
1. The compositor's `process_input()` method detects the key combination
2. The `ShortcutRegistry.find_shortcut()` method matches it to `action_left_half`
3. The compositor calls `action_left_half(compositor, focused_window_id)`
4. The window's position and size are updated
5. The compositor calls `recalculate_layout()`
6. The application receives a window resize event and updates its UI

## Testing

All keybindings are tested in `tests/059_grain_os_keyboard_shortcuts_test.zig`. The tests verify:
- Shortcut registry initialization
- Shortcut lookup
- Window action execution
- Window position/size updates

## Future Enhancements

Potential additions to the keybinding system:
- Custom keybinding configuration (runtime config)
- Window snapping to edges
- Multi-monitor support
- Workspace-specific keybindings
- Application-specific keybinding overrides

## Coordination Notes

- **No conflicts**: These keybindings are compositor-level and do not interfere with application-specific shortcuts
- **System-wide**: All applications benefit from consistent window management
- **Extensible**: New keybindings can be added via the `ShortcutRegistry`

## References

- `src/grain_os/keyboard_shortcuts.zig` - Keybinding registry
- `src/grain_os/window_actions.zig` - Window action implementations
- `src/grain_os/compositor.zig` - Compositor integration
- `tests/059_grain_os_keyboard_shortcuts_test.zig` - Test suite

---

**Note**: This document is for application developers integrating with Grain OS. The compositor handles all keybinding processing automatically. Applications only need to respond to window position/size changes.

