# Grain OS Agent Proposal

**Date**: 2025-11-23-173916-pst  
**Agent**: Grain OS (Fourth Agent)  
**Status**: Proposal - Ready for Implementation  
**Grainorder Prefix**: zyxspl

---

## Overview

Create a fourth agent dedicated to **Grain OS** - a Zig-Wayland implemented GNOME-like operating system environment. While macOS Tahoe 26.1 and previous macOS versions are more user-friendly and intuitive, Grain OS will provide a fully open-source, Zig-native desktop environment that can run on RISC-V hardware via Grain Kernel and Grain Vantage VM.

## Inspiration: ravynOS

**ravynOS** (https://ravynos.com/) is an open-source macOS-like operating system that provides:
- macOS-inspired user interface and experience
- FreeBSD-based foundation
- Open-source alternative to macOS
- Active development (v0.6.1 "Hyperpop Hyena" released)

**Key Links**:
- Website: https://ravynos.com/
- FAQ: https://ravynos.com/faq
- Releases: https://ravynos.com/releases
- GitHub: https://github.com/ravynsoft/ravynos
- v0.6.1 Release: https://github.com/ravynsoft/ravynos/releases/tag/v0.6.1
- Source Archive: https://github.com/ravynsoft/ravynos/archive/refs/tags/v0.6.1.tar.gz
- ISO Download: https://github.com/ravynsoft/ravynos/releases/download/v0.6.1/ravynOS_0.6.1_amd64.iso

**Note**: The ISO is for AMD x86_64, but we need to adapt the source code to work with:
- **Target**: RISC-V (via Grain Vantage VM)
- **Kernel**: Grain Kernel (Basin Kernel)
- **Language**: Zig (complete rewrite from ravynOS source)
- **Display Server**: Wayland (Zig-native implementation)

## Mission

Port ravynOS functionality entirely to Zig, creating **Grain OS** - a complete desktop environment that:

1. **Runs on Grain Kernel** (RISC-V)
2. **Uses Wayland** (Zig-native implementation)
3. **Provides GNOME-like desktop environment**
4. **Includes GUI application loader** for:
   - Aurora (IDE)
   - Dream (Browser)
   - Skate (Terminal)
   - Terminal (Grain Terminal)
5. **Has equivalent of `~/Applications/`** for Zig apps
6. **Maintains Grain Style compliance** (grain_case, u32/u64, max 70 lines, max 100 chars)

## Repository Setup

### Step 1: Clone ravynOS for Study

```bash
# Clone to external location
mkdir -p ~/github/ravynsoft
cd ~/github/ravynsoft
git clone https://github.com/ravynsoft/ravynos.git
cd ravynos
git checkout v0.6.1  # Checkout specific release for study
```

### Step 2: Grainmirror into Monorepo

```bash
# Mirror into grainstore for study (not committed to main repo)
# Pattern: grainstore/github/ravynsoft/ravynos
cd /Users/bhagavan851c05a/github/teamcarry11/xy-mathematics
cp -r ~/github/ravynsoft/ravynos grainstore/github/ravynsoft/
```

**Note**: The `grainstore/` directory should be in `.gitignore` to avoid committing external code.

## Architecture Goals

### 1. Wayland Implementation (Zig-Native)

- **Compositor**: Zig-native Wayland compositor
- **Protocol**: Full Wayland protocol support
- **Input**: Keyboard, mouse, touch input
- **Output**: Multi-monitor support, display management

### 2. Desktop Environment

- **Window Manager**: GNOME-like window management
- **Application Launcher**: GUI loader for Aurora, Dream, Skate, Terminal
- **File Manager**: Basic file browser
- **System Settings**: Configuration UI
- **Application Menu**: `~/Applications/` equivalent

### 3. Integration with Grain Kernel

- **Syscalls**: Use Grain Kernel syscalls for:
  - Process spawning
  - Memory management
  - File I/O
  - IPC (channels)
  - Input/output events
- **VM Integration**: Run on Grain Vantage VM (RISC-V)
- **No VM Modifications**: Grain Vantage VM should work as-is (or with minimal changes)

### 4. Application Framework

- **GUI Toolkit**: Zig-native GUI framework (Wayland-based)
- **Application API**: Standard API for Grain OS apps
- **Application Store**: `~/Applications/` directory structure
- **App Launcher**: GUI to browse and launch applications

## Implementation Phases

### Phase 1: Study and Analysis
- ✅ Clone ravynOS v0.6.1
- ✅ Analyze architecture and components
- ✅ Identify key subsystems to port
- ✅ Document dependencies and requirements
- ✅ Create porting plan

### Phase 2: Wayland Foundation
- Implement basic Wayland compositor in Zig
- Support basic window management
- Handle input events
- Display output to framebuffer/display

### Phase 3: Desktop Shell
- Window manager
- Application launcher
- Basic desktop UI
- System tray/status bar

### Phase 4: Application Framework
- Application API
- Application loader
- `~/Applications/` directory structure
- App launcher GUI

### Phase 5: Integration
- Integrate with Grain Kernel syscalls
- Test on Grain Vantage VM
- Verify RISC-V compatibility
- Performance optimization

### Phase 6: Applications
- Port/adapt Aurora for Grain OS
- Port/adapt Dream for Grain OS
- Port/adapt Skate for Grain OS
- Port/adapt Terminal for Grain OS

## Grain Style Requirements

All code must follow **Grain Style** (inspired by Tiger Style):
- ✅ **Function names**: `grain_case` (snake_case)
- ✅ **Types**: Explicit `u32`/`u64`, avoid `usize`
- ✅ **Function length**: Max 70 lines (enforced by `grainvalidate-70`)
- ✅ **Line length**: Max 100 characters (enforced by `grainwrap-100`)
- ✅ **No recursion**: Iterative algorithms only
- ✅ **Static allocation**: Prefer static buffers
- ✅ **Bounded operations**: All loops have explicit bounds
- ✅ **Comprehensive assertions**: Validate all assumptions
- ✅ **All compiler warnings**: `-Wall -Wextra -Werror` equivalent

## Technical Considerations

### RISC-V Porting

ravynOS v0.6.1 is for AMD x86_64. We need to:
- Port all x86_64-specific code to RISC-V
- Use RISC-V calling conventions
- Adapt memory management for RISC-V
- Ensure RISC-V instruction compatibility

### VM Compatibility

Grain Vantage VM should work as-is because:
- VM provides RISC-V instruction set
- Kernel provides syscall interface
- Memory management is abstracted
- File I/O is abstracted

If VM modifications are needed, they should be minimal and coordinated with Vantage Basin agent.

### Wayland vs X11

- **Choice**: Wayland (modern, secure, better for embedded)
- **Implementation**: Zig-native (no C dependencies if possible)
- **Protocol**: Full Wayland protocol support
- **Compositor**: Custom compositor for Grain OS

## Coordination with Other Agents

### Vantage Basin (VM/Kernel)
- **Coordination needed**: Syscall interface, VM capabilities
- **Conflicts**: Minimal (different domains)
- **Dependencies**: Grain Kernel syscalls, VM RISC-V support

### Aurora Dream (Editor/Browser)
- **Coordination needed**: Application integration, GUI framework
- **Conflicts**: Possible (GUI toolkit choices)
- **Dependencies**: Wayland client library, application API

### Grain Skate/Silo/Field (Terminal/Compute)
- **Coordination needed**: Application integration
- **Conflicts**: Minimal
- **Dependencies**: Application launcher, system integration

## Success Criteria

1. ✅ **Wayland compositor** running on Grain Vantage VM
2. ✅ **Desktop environment** with window manager
3. ✅ **Application launcher** that can launch Aurora, Dream, Skate, Terminal
4. ✅ **`~/Applications/`** directory structure working
5. ✅ **All Grain OS apps** running in the environment
6. ✅ **Grain Style compliance** throughout codebase
7. ✅ **RISC-V compatibility** verified
8. ✅ **Performance** acceptable on VM (target: 60fps UI)

## Next Steps

1. **Clone ravynOS** (if not already done)
2. **Grainmirror** into `grainstore/github/ravynsoft/ravynos`
3. **Study architecture** and create detailed porting plan
4. **Begin Phase 1** implementation
5. **Coordinate** with other agents as needed

## References

- ravynOS: https://ravynos.com/
- ravynOS GitHub: https://github.com/ravynsoft/ravynos
- ravynOS v0.6.1: https://github.com/ravynsoft/ravynos/releases/tag/v0.6.1
- Wayland Protocol: https://wayland.freedesktop.org/
- Grain Style: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md
- Hacker News Discussion: https://news.ycombinator.com/item?id=45997212

---

**Agent**: Grain OS (Fourth Agent)  
**Grainorder**: zyxspl  
**Status**: Proposal Ready  
**Date**: 2025-11-23-173916-pst

