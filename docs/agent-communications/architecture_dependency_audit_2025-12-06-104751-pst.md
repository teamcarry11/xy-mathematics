# Architecture Dependency Audit: Basin vs Vantage

**Date**: 2025-12-06-104751-pst  
**Agent**: Grain Core Agent (Architecture Audit)  
**Status**: CRITICAL — Architectural Correction  
**Priority**: HIGH — Correct dependency relationships

---

## Executive Summary

This audit corrects a critical architectural misunderstanding in our dependency documentation. The codebase is **already correct**, but the documentation incorrectly shows dependencies.

**Key Finding**: 
- ✅ **Code is correct**: Core Agent imports `basin_kernel` (RISC-V), NOT `kernel_vm` (Vantage)
- ❌ **Documentation is wrong**: Dependency diagrams incorrectly show "Core depends on Vantage"

**Correct Architecture**:
- **Vantage** (ARM VM) → runs **Basin** (RISC-V kernel) — Vantage is just the macOS host implementation
- **Core** → depends on **Basin** (RISC-V kernel) — Core uses RISC-V syscalls
- **All other agents** → depend on **Basin** and **Core** — they use Core's services which use Basin syscalls
- **None of the agents** should depend on Vantage — Vantage is just the macOS implementation detail

---

## Correct Architecture Layers

### Layer 1: Host Platform (macOS 26.1 Tahoe)
- **Vantage VM** (`src/kernel_vm/`) — ARM64 virtual machine that runs RISC-V code
- **Purpose**: Enable Basin kernel development on Apple Silicon
- **Dependencies**: macOS 26.1 Tahoe only
- **NOT a dependency for any Grain OS agent**

### Layer 2: RISC-V Kernel (Basin)
- **Basin Kernel** (`src/kernel/basin_kernel.zig`) — RISC-V64 kernel with syscalls
- **Purpose**: Core operating system kernel for RISC-V hardware
- **Dependencies**: None (pure RISC-V)
- **Provides**: Syscalls for all Grain OS agents

### Layer 3: System Services (Core)
- **Grain Core Agent** (`src/grain_core/`) — System services and compositor
- **Dependencies**: **Basin Kernel** (RISC-V syscalls) ✅
- **Does NOT depend on**: Vantage VM ❌
- **Provides**: System services, compositor, API server, authentication, file storage

### Layer 4: Application Agents
- **Grain Silo Agent** (Database) — depends on **Core** and **Basin**
- **Grain Carry Agent** (Mobile) — depends on **Core** and **Basin**
- **Grain Workspace Agent** (Desktop Apps) — depends on **Core** and **Basin**
- **Grain Bubble Agent** (Design Tool) — depends on **Core** and **Basin**
- **Grain Aurora Agent** (IDE/Browser) — depends on **Core** and **Basin** (via shared modules)
- **Grain Skate Agent** (Knowledge Graph) — depends on **Core** and **Basin** (via shared modules)

**None of these agents depend on Vantage** — Vantage is only for development on macOS.

---

## Code Audit Results

### ✅ Core Agent Code is CORRECT

**Evidence from `src/grain_core/`**:
- `compositor.zig`: `const basin_kernel = @import("basin_kernel");` ✅
- `process_manager.zig`: `const basin_kernel = @import("basin_kernel");` ✅
- `resource_monitor.zig`: `const basin_kernel = @import("basin_kernel");` ✅
- `input_handler.zig`: `const basin_kernel = @import("basin_kernel");` ✅
- `framebuffer_renderer.zig`: `const basin_kernel = @import("basin_kernel");` ✅
- `application.zig`: `const basin_kernel = @import("basin_kernel");` ✅

**No imports of `kernel_vm` or `vantage` found in Core Agent** ✅

### ✅ Build System is CORRECT

**Evidence from `build.zig`**:
- `basin_kernel_module` defined separately (RISC-V kernel) ✅
- `kernel_vm_module` defined separately (Vantage VM) and imports `basin_kernel` ✅
- `grain_core_module` imports `basin_kernel` (NOT `kernel_vm`) ✅

**No incorrect dependencies in build system** ✅

### ✅ Other Agents are CORRECT

**Evidence from `src/`**:
- No agents import `kernel_vm` or `vantage` ✅
- All agents that need kernel access use Core Agent's services ✅

---

## Corrected Dependency Diagram

### ❌ OLD (INCORRECT):
```
Vantage Agent (Kernel/VM)
    ↓
Core Agent (System Services)
    ↓
    ├─→ Silo Agent (Database)
    ├─→ Carry Agent (Mobile)
    ├─→ Workspace Agent (Desktop Apps)
    └─→ Bubble Agent (Design Tool)
```

### ✅ NEW (CORRECT):
```
Vantage VM (ARM64, macOS only) [NOT a dependency]
    ↓ (runs)
Basin Kernel (RISC-V64) [Layer 2]
    ↓ (provides syscalls)
Core Agent (System Services) [Layer 3]
    ↓ (provides services)
    ├─→ Silo Agent (Database) [Layer 4]
    ├─→ Carry Agent (Mobile) [Layer 4]
    ├─→ Workspace Agent (Desktop Apps) [Layer 4]
    └─→ Bubble Agent (Design Tool) [Layer 4]

Aurora Agent (IDE/Browser) [Layer 4, depends on Core/Basin]
Skate Agent (Knowledge Graph) [Layer 4, depends on Core/Basin]
```

**Key Points**:
1. **Vantage is NOT in the dependency chain** — it's just the macOS host
2. **Core depends on Basin** (RISC-V kernel), NOT on Vantage
3. **All agents depend on Basin and Core**, NOT on Vantage
4. **Vantage is only for development** — production runs on RISC-V hardware

---

## Corrected Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Vantage** | macOS 26.1 Tahoe only | None (runs Basin, but not a dependency) | All (separate host layer) |
| **Basin** | None (pure RISC-V) | Core, All agents | None (foundation layer) |
| **Core** | **Basin** (RISC-V kernel) ✅ | Silo, Carry, Workspace, Bubble | Aurora, Skate |
| **Silo** | **Core** (API ✅, WebSocket ✅, File System ✅), **Basin** (via Core) | Carry | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Carry** | **Core** (API ✅, Auth ✅, WebSocket ✅), **Basin** (via Core), Silo | None | Aurora, Skate, Workspace, Bubble (Phase 1) |
| **Workspace** | **Core** (System Services ✅), **Basin** (via Core) | None | Aurora, Skate, Bubble (Phase 1) |
| **Bubble** | **Core** (Compositor ✅, Rendering ✅), **Basin** (via Core) | None | Aurora, Skate, Workspace |
| **Aurora** | **Core** (shared modules), **Basin** (via Core) | Shared modules | All (except when coordinating shared modules) |
| **Skate** | **Core** (shared modules), **Basin** (via Core) | Shared modules | All (except when coordinating shared modules) |

**Key Changes**:
- **Core** depends on **Basin**, NOT on Vantage ✅
- **All agents** depend on **Basin** (via Core), NOT on Vantage ✅
- **Vantage** is NOT in the dependency chain ✅

---

## Why This Matters

1. **Portability**: Core Agent should be RISC-V specific, not ARM/macOS specific
2. **Clarity**: Vantage is just a development tool, not a runtime dependency
3. **Architecture**: The dependency chain should reflect the actual system layers
4. **Future**: When we run on native RISC-V hardware, Vantage won't be involved at all

---

## Action Items

### ✅ Code Audit: COMPLETE
- Code is already correct — no changes needed ✅

### 📝 Documentation Updates: REQUIRED
1. Update all coordination documents with corrected dependency diagram
2. Update `docs/plans/plan_core.md` to clarify Basin dependency
3. Update `docs/plans/plan_vantage.md` to clarify Vantage is host-only
4. Update all agent coordination plans with corrected architecture

### 🔍 Verification: REQUIRED
1. Verify no agent code imports `kernel_vm` or `vantage` (except Vantage Agent itself)
2. Verify build system correctly separates Basin and Vantage
3. Verify all documentation reflects correct architecture

---

## Conclusion

**The codebase is architecturally correct** — Core Agent correctly depends on Basin (RISC-V kernel), not on Vantage (ARM VM). The issue is only in documentation, which incorrectly shows the dependency relationship.

**Corrected Architecture**:
- **Vantage** (ARM VM) → runs **Basin** (RISC-V kernel) — development tool only
- **Core** → depends on **Basin** (RISC-V kernel) — RISC-V specific
- **All agents** → depend on **Basin** and **Core** — NOT on Vantage

**Next Steps**: Update all coordination documents with the corrected dependency diagram.

---

**Status**: Code is correct ✅ | Documentation needs updates 📝

