# Build System Orchestration Guide

**Date**: 2025-12-04-141613-pst  
**Agent**: Grain Core Agent  
**Status**: Modular structure complete, orchestration guide ready

---

## Summary

The build system has been refactored into modular files. This guide shows how to use the modular structure and migrate existing `build.zig` content.

---

## Modular Structure

### Files Created

1. **`build/helpers.zig`** - Common helper functions
2. **`build/modules.zig`** - Shared and agent-specific modules
3. **`build/kernel.zig`** - Kernel and VM configuration
4. **`build/userspace.zig`** - Userspace utilities
5. **`build/macos_apps.zig`** - macOS applications
6. **`build/tools.zig`** - Build tools
7. **`build/tests.zig`** - Test helpers

---

## Usage Examples

### Example: Using Modular Files in build.zig

```zig
const std = @import("std");
const helpers = @import("build/helpers.zig");
const modules = @import("build/modules.zig");
const kernel = @import("build/kernel.zig");
const userspace = @import("build/userspace.zig");
const macos_apps = @import("build/macos_apps.zig");
const tools = @import("build/tools.zig");
const tests = @import("build/tests.zig");

pub fn build(b: *std.Build) void {
    // Initialize build context
    const ctx = helpers.init_build_context(b);
    
    // Create shared modules
    const shared_modules = modules.create_shared_modules(ctx);
    
    // Create kernel modules
    const kernel_modules = kernel.create_kernel_modules(ctx);
    
    // Create agent modules (depends on shared and kernel)
    const agent_modules = modules.create_agent_modules(
        ctx,
        shared_modules,
        kernel_modules,
    );
    
    // Create kernel executable
    const kernel_exe = kernel.create_kernel_executable(ctx, kernel_modules);
    kernel.add_kernel_build_step(b, kernel_exe);
    
    // Create userspace modules and utilities
    const userspace_modules = userspace.create_userspace_modules(ctx);
    const userspace_target = userspace.get_userspace_target(b);
    const utilities = userspace.create_all_userspace_utilities(
        ctx,
        userspace_modules,
        userspace_target,
    );
    userspace.add_build_essential_step(b, utilities);
    
    // Create macOS applications
    const tahoe_exe = macos_apps.create_tahoe_executable(ctx, kernel_modules);
    macos_apps.add_tahoe_steps(b, tahoe_exe);
    
    const grain_skate_exe = macos_apps.create_grain_skate_executable(
        ctx,
        agent_modules.grain_skate,
        shared_modules.events,
    );
    macos_apps.add_grain_skate_steps(b, grain_skate_exe);
    
    // Create test step
    const test_step = b.step("test", "Run all tests");
    
    // Add tests using modular helpers (example)
    // tests.add_test(ctx, test_step, "tests/001_example_test.zig", &.{
    //     .{ .name = "grain_os", .module = agent_modules.grain_os },
    // });
    
    // ... existing test structure continues ...
}
```

---

## Migration Strategy

### Phase 1: Module Creation (✅ Complete)

- All modules created using `modules.create_shared_modules()` and `modules.create_agent_modules()`
- Kernel modules created using `kernel.create_kernel_modules()`
- Userspace modules created using `userspace.create_userspace_modules()`

### Phase 2: Executable Creation (⏳ In Progress)

- Kernel executable: Use `kernel.create_kernel_executable()`
- Userspace utilities: Use `userspace.create_all_userspace_utilities()`
- macOS apps: Use `macos_apps.create_tahoe_executable()` and `macos_apps.create_grain_skate_executable()`

### Phase 3: Test Migration (⏳ Planned)

- Gradually migrate tests to use `tests.add_test()` helper
- Keep existing test structure for now (343 tests)
- Migrate tests incrementally as they are modified

### Phase 4: Full Orchestration (⏳ Planned)

- Create new `build.zig` that uses all modular files
- Verify all tests pass
- Remove old `build.zig` backup

---

## Benefits

1. **Reduced File Size**: Modular structure reduces main `build.zig` size
2. **Better Organization**: Domain-specific files improve clarity
3. **Reduced Conflicts**: Agent-specific modules reduce merge conflicts
4. **Reusability**: Helper functions reduce code duplication
5. **Maintainability**: Easier to understand and modify

---

## Current Status

- **Modular Files**: 7 of 7 created ✅
- **Module Creation**: Ready to use ✅
- **Executable Creation**: Ready to use ✅
- **Test Migration**: Helper functions ready, migration pending ⏳
- **Full Orchestration**: Guide ready, implementation pending ⏳

---

## Next Steps

1. **Gradual Migration**: Migrate sections of `build.zig` to use modular helpers as they are modified
2. **Test Verification**: Ensure all tests pass after each migration step
3. **Documentation**: Update build documentation as migration progresses
4. **Full Orchestration**: Create new `build.zig` when ready

---

## Notes

- The existing `build.zig` (3,237 lines) is kept as-is for now
- Modular files are ready to use for new additions
- Migration can proceed incrementally without breaking existing functionality
- All modular files follow Grain Style guidelines

---

**Grain Core Agent**  
2025-12-04-141613-pst

