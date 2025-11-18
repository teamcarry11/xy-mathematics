# Tahoe Window Architecture

## Overview

Tahoe is a macOS native GUI application that hosts a RISC-V VM for kernel development. It provides a visual interface to load, run, and debug the Grain Basin kernel.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│  macOS NSApplication Event Loop          │  ← macOS Cocoa framework
├─────────────────────────────────────────┤
│  Platform Layer (window.zig)           │  ← Window creation, events
├─────────────────────────────────────────┤
│  TahoeSandbox (tahoe_window.zig)        │  ← Main application logic
│    - Event handlers (keyboard/mouse)    │
│    - Rendering (tick/render)            │
│    - VM management                      │
├─────────────────────────────────────────┤
│  RISC-V VM (kernel_vm)                  │  ← Instruction execution
├─────────────────────────────────────────┤
│  Grain Basin Kernel (basin_kernel)      │  ← Syscall handling
└─────────────────────────────────────────┘
```

## Event Flow

### 1. Application Startup (`tahoe_app.zig`)
```
main() → init TahoeSandbox → show window → start animation loop → run event loop
```

### 2. Event Loop (60fps)
```
Every frame:
  1. tick() - Update state, step VM if running
  2. render() - Draw to buffer
  3. Platform presents buffer to window
```

### 3. Keyboard Events
```
macOS keypress → Platform layer → handle_keyboard_event() → Process shortcuts
```

## Key Components

### TahoeSandbox
- **Purpose**: Main application container
- **Responsibilities**:
  - Window management
  - Event handling (keyboard/mouse)
  - VM lifecycle (load/start/stop)
  - Rendering (draw UI, VM state, stdout)

### RISC-V VM
- **Purpose**: Execute RISC-V64 instructions
- **State**: `halted`, `running`, `errored`
- **Integration**: Syscalls routed to Grain Basin kernel

### Grain Basin Kernel
- **Purpose**: Handle syscalls from VM
- **Integration**: VM ECALL → kernel syscall handler

## User Workflow

### Step 1: Load Kernel
1. Window opens (shows instructions)
2. User presses **Cmd+L**
3. Code reads `zig-out/bin/grain-rv64` ELF file
4. ELF loaded into VM memory
5. VM state: `halted`, PC set to entry point
6. Status updates: "VM loaded"

### Step 2: Start VM
1. User presses **Cmd+K**
2. VM state: `halted` → `running`
3. `tick()` starts executing instructions
4. Each frame: `vm.step()` executes one instruction
5. Status updates: "VM running"

### Step 3: Observe Output
- Kernel printf → Serial output buffer → Displayed in VM pane
- Userspace stdout → Stdout buffer → Displayed in VM pane

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+L** | Load kernel from `zig-out/bin/grain-rv64` |
| **Cmd+K** | Toggle VM execution (start/stop) |
| **Cmd+Q** | Quit application |

## Debugging

### Check if events are received:
- Look for `[tahoe_window] Keyboard event:` in console
- If no events: Window may not have focus

### Check if kernel loads:
- Look for `[tahoe_window] Load kernel command (Cmd+L) received.`
- Look for `[tahoe_window] Kernel loaded successfully!`

### Check VM execution:
- Look for `[tahoe_window] VM started.`
- Check status text in window: "VM running"

## Common Issues

### Window not responding to keyboard
- **Cause**: Window doesn't have focus
- **Fix**: Click on window first, then press shortcuts

### Kernel doesn't load
- **Cause**: `zig-out/bin/grain-rv64` doesn't exist
- **Fix**: Run `zig build` to build kernel first

### No keyboard events in console
- **Cause**: Event handler not registered or window not accepting first responder
- **Fix**: Check `window.zig` - view must accept first responder

## File Structure

```
src/
├── tahoe_app.zig          # Entry point, event loop
├── tahoe_window.zig       # Main application logic
├── platform/
│   └── macos_tahoe/
│       ├── window.zig     # Window creation, event routing
│       └── objc_wrapper.c # Cocoa bridge
└── kernel_vm/             # RISC-V VM implementation
```

## Rendering Pipeline

1. **tick()** called every frame (60fps)
2. Fill buffer with background color
3. Draw instructions text (if no VM loaded)
4. Draw VM pane (if VM loaded)
5. Draw stdout text (if any)
6. Draw mouse cursor
7. Platform presents buffer to NSImageView

## Memory Management

- **VM**: Allocated on heap (4MB struct)
- **BasinKernel**: Allocated on heap (large static arrays)
- **Buffers**: Static allocation (stdout_buffer, serial_output)

