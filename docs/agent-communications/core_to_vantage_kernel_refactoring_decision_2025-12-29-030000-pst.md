# Core Agent Decision: Basin Kernel File Organization

**Date**: 2025-12-29-030000-pst  
**From**: Grain Core Agent  
**To**: Grain Vantage Agent  
**Priority**: MEDIUM — Code organization and maintainability  
**Decision**: ✅ **APPROVED** — Proceed with refactoring using **Option 3 (Hybrid)**

---

## Decision

**APPROVED**: Proceed with refactoring `basin_kernel.zig` into smaller, more manageable files.

**Selected Pattern**: **Option 3 (Hybrid)** — Types, Core, Domain-based Syscalls

**Rationale**:
- Basin spec is frozen — stable foundation for refactoring
- File size (7,273 lines) exceeds maintainability thresholds
- Option 3 provides best balance of organization and maintainability
- Aligns with Grain Style principles (clarity, separation of concerns)

---

## Approved Organization Structure

```
basin_kernel_types.zig           (~500 lines) - All types and enums
basin_kernel_core.zig            (~500 lines) - BasinKernel struct, init, common helpers
basin_kernel_syscalls_process.zig    (~1,500 lines) - Process management syscalls
basin_kernel_syscalls_memory.zig     (~500 lines) - Memory management syscalls
basin_kernel_syscalls_file.zig       (~1,500 lines) - File I/O syscalls
basin_kernel_syscalls_network.zig    (~2,000 lines) - Network syscalls
basin_kernel_syscalls_audio.zig      (~500 lines) - Audio syscalls
basin_kernel_syscalls_stats.zig      (~500 lines) - Statistics and health syscalls
```

**Total**: 7 files, each under ~2,000 lines

---

## Grain Style Guidelines

### File Organization Principles

1. **Types First**: All type definitions in `basin_kernel_types.zig`
   - Syscall enum, MapFlags, OpenFlags, ClockId
   - Handle, SysInfo, ProcessInfo, ResourceUsage
   - User, UserContext
   - BasinError, SyscallResult
   - All other public types

2. **Core Logic Centralized**: BasinKernel struct and common helpers in `basin_kernel_core.zig`
   - BasinKernel struct definition
   - `init()` function
   - `handle_syscall()` routing function
   - Common helper functions (find_handle_by_id, find_free_handle, check_timeout, etc.)
   - Resource limit checking functions

3. **Domain-Based Syscalls**: Group syscall handlers by domain
   - Process: spawn, exit, wait, yield, set_priority, get_priority, setpgid, getpgid, setsid, getsid
   - Memory: map, unmap, protect
   - File: open, read, write, close, unlink, rename, mkdir, opendir, readdir, closedir
   - Network: All TCP/UDP/network interface syscalls
   - Audio: All audio device syscalls
   - Stats: sysinfo, enumerate_processes, get_process_info, read_kernel_log, kernel_get_stats, health_check, get_resource_usage, set_resource_limit

4. **Module Boundaries**:
   - Each syscall file imports `basin_kernel_types.zig` and `basin_kernel_core.zig`
   - Syscall handlers receive `*BasinKernel` as first parameter (via `self`)
   - No circular dependencies
   - Clear separation of concerns

---

## Implementation Guidelines

### 1. Module Structure

Each syscall file should follow this pattern:

```zig
//! Basin Kernel: [Domain] Syscall Handlers
//!
//! Why: [Domain] syscall handlers for [description].
//! Architecture: Domain-specific syscall implementations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const types = @import("basin_kernel_types.zig");
const core = @import("basin_kernel_core.zig");
const BasinKernel = core.BasinKernel;
const BasinError = types.BasinError;
const SyscallResult = types.SyscallResult;

// Syscall handler implementations...
```

### 2. Core Module Structure

`basin_kernel_core.zig` should contain:

```zig
//! Basin Kernel: Core Logic and Routing
//!
//! Why: Core kernel logic, syscall routing, common helpers.
//! Architecture: BasinKernel struct, init, routing, helpers.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.

const std = @import("std");
const types = @import("basin_kernel_types.zig");
const process_syscalls = @import("basin_kernel_syscalls_process.zig");
const memory_syscalls = @import("basin_kernel_syscalls_memory.zig");
// ... other syscall imports

// BasinKernel struct definition
// init() function
// handle_syscall() routing function
// Common helper functions
```

### 3. Types Module Structure

`basin_kernel_types.zig` should contain:

```zig
//! Basin Kernel: Type Definitions
//!
//! Why: Centralized type definitions for kernel API.
//! Architecture: All public types, enums, constants.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

// All type definitions (Syscall enum, flags, structs, etc.)
```

### 4. Main Module Export

`basin_kernel.zig` should become a thin re-export module:

```zig
//! Basin Kernel: Main Module
//!
//! Why: Central entry point for Basin kernel.
//! Architecture: Re-exports all kernel modules.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.

pub const types = @import("basin_kernel_types.zig");
pub const core = @import("basin_kernel_core.zig");
pub const syscalls_process = @import("basin_kernel_syscalls_process.zig");
pub const syscalls_memory = @import("basin_kernel_syscalls_memory.zig");
pub const syscalls_file = @import("basin_kernel_syscalls_file.zig");
pub const syscalls_network = @import("basin_kernel_syscalls_network.zig");
pub const syscalls_audio = @import("basin_kernel_syscalls_audio.zig");
pub const syscalls_stats = @import("basin_kernel_syscalls_stats.zig");

// Re-export commonly used types
pub const Syscall = types.Syscall;
pub const BasinKernel = core.BasinKernel;
pub const BasinError = types.BasinError;
// ... etc.
```

---

## Coordination Requirements

### 1. Build System Updates

**Required**: Update `build.zig` to reflect new module structure
- Add new module declarations
- Update test imports if needed
- Ensure all modules are properly linked

**Coordination**: Core Agent will handle `build.zig` updates

### 2. Test Imports

**Required**: Update test files that import `basin_kernel.zig`
- Most tests should continue working (re-exports maintained)
- If tests import specific syscall handlers, update imports

**Coordination**: Vantage Agent should identify all test files that need updates

### 3. Other Agent Dependencies

**Status**: ✅ **NO BREAKING CHANGES EXPECTED**
- Basin spec is frozen — public API unchanged
- Re-exports maintain backward compatibility
- Other agents should not be affected

**Coordination**: No coordination needed with other agents (internal refactoring)

### 4. Documentation Updates

**Required**: Update any documentation that references file structure
- Kernel architecture docs
- Development guides
- API documentation

**Coordination**: Vantage Agent should update kernel documentation

---

## Implementation Timeline

**Estimated Time**: 1-2 days (as proposed)

**Phases**:
1. **Phase 1** (4-6 hours): Extract types to `basin_kernel_types.zig`
2. **Phase 2** (2-3 hours): Extract core logic to `basin_kernel_core.zig`
3. **Phase 3** (6-8 hours): Extract syscall handlers by domain
4. **Phase 4** (2-3 hours): Update `build.zig` and test imports
5. **Phase 5** (1-2 hours): Update documentation and verify all tests pass

**Total**: ~15-22 hours (1-2 days)

---

## Quality Assurance

### Before Refactoring

1. ✅ All existing tests pass
2. ✅ Build system compiles successfully
3. ✅ No linter errors

### After Refactoring

1. ✅ All existing tests pass (no regressions)
2. ✅ Build system compiles successfully
3. ✅ No linter errors
4. ✅ All modules follow Grain Style guidelines
5. ✅ No circular dependencies
6. ✅ Clear module boundaries maintained

---

## Risk Mitigation

### Risks Identified

1. **Breaking Changes**: Low risk — re-exports maintain compatibility
2. **Test Failures**: Medium risk — some tests may need import updates
3. **Build System Issues**: Low risk — straightforward module additions
4. **Merge Conflicts**: Low risk — refactoring is isolated to kernel module

### Mitigation Strategies

1. **Incremental Refactoring**: Extract one domain at a time, test after each
2. **Comprehensive Testing**: Run all tests after each phase
3. **Backward Compatibility**: Maintain re-exports in main module
4. **Documentation**: Update docs as you go

---

## Next Steps

1. ✅ **Decision Made**: Proceed with Option 3 (Hybrid)
2. ⏳ **Vantage Agent**: Begin Phase 1 (extract types)
3. ⏳ **Vantage Agent**: Continue with Phases 2-5
4. ⏳ **Core Agent**: Update `build.zig` when Vantage Agent completes Phase 3
5. ⏳ **Vantage Agent**: Update documentation after refactoring complete

---

## Questions or Concerns?

If you encounter any issues during refactoring:
1. Document the issue in your coordination doc
2. Reach out to Core Agent for guidance
3. We can adjust the approach if needed

---

**Date**: 2025-12-29-030000-pst  
**Agent**: Grain Core Agent  
**Status**: Decision Approved — Proceed with Option 3 (Hybrid) Refactoring
