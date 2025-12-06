# Repository Organization Plan: Marie Kondo Style

**Date**: 2025-12-06-110000-pst  
**Agent**: Grain Core Agent  
**Status**: Organization Recommendations  
**Purpose**: Declutter, organize by purpose, keep only what sparks joy

---

## Philosophy: "Does It Spark Joy?"

**Keep**: Active, useful, referenced files  
**Archive**: Historical, completed, superseded files  
**Remove**: Duplicates, backups, temporary files (git history preserves them)

---

## Current State Analysis

### ✅ Well-Organized (Keep As-Is)

1. **`src/`** - Excellent agent-based organization
   - `grain_core/`, `grain_skate/`, `grain_workspace/`, etc.
   - Clear module boundaries
   - **Action**: Keep structure, minor cleanup only

2. **`tests/`** - Well-organized by number prefix
   - Sequential numbering works well
   - **Action**: Keep structure

3. **`docs/plans/`** and `docs/tasks/` - Clean agent-specific organization
   - One plan/task file per agent
   - **Action**: Keep structure

4. **`build/`** - Modular build system
   - Well-organized helper modules
   - **Action**: Keep structure

---

## Areas Needing Organization

### 1. Root Directory Clutter 🧹

**Files to Remove** (git history preserves them):
- `build.zig.backup` - Old backup
- `build.zig.old2` - Old backup
- `test_arraylist*.zig` (5 files) - Temporary test files
- `test_io_api.zig` - Temporary test file
- `tmp_get_next_grainorder.zig` - Temporary file
- `*.a` files (lib*.a) - Build artifacts (should be in zig-out/)
- `tahoe_app`, `window`, `graincard` - Build artifacts (should be in zig-out/)
- `graincard_12025.txt`, `graincard_12025.txt.png` - Old outputs

**Files to Keep**:
- `build.zig` - Active build file
- `build.zig.zon` - Dependency manifest
- `readme.md`, `readme_org.md` - Documentation
- `changelog.md`, `contact.md`, `skeptical.md` - Documentation
- `Brewfile` - Dependency management
- `cursor_outputs.zig` - Active tool
- `debug_test.sh`, `run_lldb.sh`, `run_qemu.sh` - Active scripts

**Action**: Remove backup and temporary files, keep only active files.

---

### 2. Documentation Root Clutter 📚

**Files to Archive** (`archaeology/docs/legacy_prompts/`):
- `*_agent_*_prompt.md` (old agent prompts, keep only current)
  - `aurora_agent_documentation_refactor_prompt.md`
  - `database_agent_documentation_refactor_prompt.md`
  - `kernel_agent_documentation_refactor_prompt.md`
  - `mobile_agent_documentation_refactoring_prompt.md`
  - `skate_agent_documentation_refactor_prompt.md`
  - `workspace_agent_documentation_refactor_prompt.md`
  - `grain_os_agent_style_unification_prompt.md`
  - `grain_os_kernel_integration_prompt.md`
  - `grain_os_kernel_integration_response.md`
  - `grain_os_agent_next_priorities.md`
  - `grain_os_agent_next_work.md`
  - `grain_mobile_agent_prompt.md` (now Carry)
  - `grain_database_agent_prompt.md` (now Silo)
  - `grain_election_agent_prompt.md` (if not active)

- Old timestamped files (`zyx*.md`):
  - `zyxspl-2025-11-23-180921-pst-grain-os-agent-proposal.md`
  - `zyxspn-2025-11-23-164523-pst-vantage-basin-progress-summary.md`
  - `zyxspq-2025-11-23-144353-pst-aurora-dream-acknowledgment.md`
  - `zyxsqb-2025-11-23-141218-pst-test-fix-prompt.md`
  - `zyxsqc-2025-11-23--041654-pst-grain-skate-field-silo-update.md`
  - `zyxsqh-2025-11-23-034800-pst-aurora-dream-toroid-silo-acknowledgment.md`
  - `zyxsql-2025-11-23--034749-pst-grain-skate-toroid-silo-coordination.md`
  - `zyxsqm-2025-11-23--034749-pst-grain-skate-toroid-silo-coordination.md`
  - `zyxsqm-2025-11-24-105500-pst-grain-os-tiling-coordination.md`
  - `zyxsqn-2025-11-23-031548-pst-aurora-dream-agent-acknowledgment.md`
  - `zyxsqp-2025-11-23-030547-pst-grain_terminal_aurora_integration_complete.md`
  - `zyxspl-2025-11-24-105002-pst-grain-os-river-inspiration.md`

- Old coordination/status files:
  - `agent_prompts_window_management.md` (if superseded)
  - `build_refactoring_progress.md` (if complete)
  - `runtime_error_fix_progress.md` (if complete)
  - `refactoring_and_tooling_setup.md` (if complete)
  - `cleanup_plan.md` (if complete)

**Files to Keep in `docs/`**:
- `grain_style.md` - Active style guide
- `plan.md`, `tasks.md` - Master summaries
- `unified_architecture_vision.md` - Active reference
- `vm_api_reference.md` - Active reference
- `dream_browser_vision.md` - Active reference
- `grain_mobile_core_architecture.md` - Active reference
- `grain_mobile_style_system.md` - Active reference
- `grain_skate_agent_prompt.md` - Current agent prompt
- `grain_skate_agent_summary.md` - Current agent summary
- `grain_skate_agent_acknowledgment.md` - Current acknowledgment
- `grain_workspace_agent_background.md` - Active reference
- `terminal_integration_ready_summary.md` - Active reference
- `grain_skate_integration_readiness.md` - Active reference
- `grain_skate_future_enhancements.md` - Active reference
- `grain_skate_save_integration_complete.md` - Active reference
- `grain_terminal_kernel_ready.md` - Active reference
- `terminal_kernel_integration_api.md` - Active reference
- `grain_os_window_management_keybindings.md` - Active reference
- `grain_os_river_inspired_design.md` - Active reference
- `grain_os_font_renderer_coordination.md` - Active reference
- `grain_os_library_recommendations.md` - Active reference
- `ai_provider_refactoring.md` - Active reference
- `dag_ui_synthesis.md` - Active reference
- `dream_editor_browser_synthesis.md` - Active reference
- `dream_editor_plan.md` - Active reference
- `dream_implementation_roadmap.md` - Active reference
- `turbopuffer_vs_wse_analysis.md` - Active reference
- `wse_national_strategy_mmt.md` - Active reference
- `tree_sitter_eli5.md` - Active reference
- `kae3g_experience.md` - Active reference
- `documentation_structure_recommendation.md` - Active reference
- `build_orchestration_guide.md` - Active reference
- `agent_file_naming_guide.md` - Active reference

**Action**: Archive old prompts and timestamped files, keep active references.

---

### 3. Agent Communications Consolidation 📬

**Current**: 50+ files in `docs/agent-communications/`

**Recommendation**: Consolidate older coordination plans

**Keep Active** (last 2-3 weeks):
- `core_agent_coordination_plan_2025-12-06-061647-pst.md` - Latest
- `architecture_dependency_audit_2025-12-06-104751-pst.md` - Latest
- `grain_style_u32_u64_enforcement_prompt.md` - Active enforcement
- `unified_agent_coordination_prompt.md` - Master coordination doc
- Recent coordination plans (2025-12-05 and 2025-12-06)

**Archive Older** (`archaeology/docs/agent-communications/`):
- Coordination plans older than 2 weeks
- Completed rename operations
- Old phase completion summaries

**Action**: Archive coordination plans older than 2 weeks, keep recent ones active.

---

### 4. Test Files Organization 🧪

**Current**: 224 test files, well-organized by number

**Minor Cleanup**:
- `tests/unit/` - Check if used or empty
- `tests-experiments/` - Archive if experiments complete

**Action**: Verify `tests/unit/` usage, archive `tests-experiments/` if complete.

---

### 5. Build Artifacts 🏗️

**Files to Remove** (should be in `zig-out/` or `.gitignore`):
- `lib*.a` files in root (12+ files)
- `tahoe_app`, `window`, `graincard` executables in root
- `graincard_12025.txt`, `graincard_12025.txt.png` outputs

**Action**: Add to `.gitignore` if not already, remove from repo.

---

### 6. Empty/Unused Directories 🗂️

**Check and Remove**:
- `src/grain_field/` - If empty (renamed to `grain_court/`)
- `tests/unit/` - If empty or unused
- `kernel/` - If empty (should be `src/kernel/`)

**Action**: Verify and remove if empty.

---

## Proposed Directory Structure

### Root Directory (Clean)
```
xy-mathematics/
├── build.zig              # Active build file
├── build.zig.zon          # Dependency manifest
├── readme.md              # Main README
├── changelog.md           # Changelog
├── contact.md             # Contact info
├── Brewfile               # Dependencies
├── .gitignore             # Git ignore rules
├── build/                 # Modular build system
├── src/                   # Source code (well-organized)
├── tests/                 # Test files (well-organized)
├── docs/                  # Documentation (organized)
├── tools/                 # Build tools
├── scripts/               # Utility scripts
├── examples/              # Example code
├── vendor/                # Vendor dependencies
├── grainstore/            # Grain store dependencies
├── archaeology/           # Archived files
└── zig-out/               # Build output (gitignored)
```

### Documentation Structure (Organized)
```
docs/
├── grain_style.md                    # Active style guide
├── plan.md                           # Master plan
├── tasks.md                          # Master tasks
├── unified_architecture_vision.md    # Architecture reference
├── vm_api_reference.md               # API reference
├── [active reference docs]            # Other active references
├── plans/                             # Agent-specific plans
├── tasks/                             # Agent-specific tasks
├── proposals/                        # Active proposals
├── learning-course/                   # Learning materials
├── agent-communications/              # Recent coordination (last 2-3 weeks)
├── zyx/                               # Archived but organized
└── [archived prompts moved to archaeology/]
```

---

## Implementation Plan

### Phase 1: Root Directory Cleanup (Quick Win)
1. Remove backup files (`build.zig.backup`, `build.zig.old2`)
2. Remove temporary test files (`test_*.zig`)
3. Remove build artifacts (`lib*.a`, executables)
4. Update `.gitignore` to prevent future artifacts

### Phase 2: Documentation Archive
1. Create `archaeology/docs/legacy_prompts/`
2. Move old agent prompts to archive
3. Move old timestamped files to archive
4. Move old coordination/status files to archive

### Phase 3: Agent Communications Consolidation
1. Archive coordination plans older than 2 weeks
2. Keep only recent coordination plans active
3. Update references in `plan.md` and `tasks.md`

### Phase 4: Final Verification
1. Verify no broken references
2. Update any documentation that references moved files
3. Commit with clear organization message

---

## Benefits

1. **Clarity**: Only active files visible, easier to navigate
2. **Maintenance**: Less clutter, easier to find what you need
3. **History**: Git preserves everything, archaeology keeps it organized
4. **Joy**: Clean, purposeful organization sparks joy! ✨

---

## Files to Keep Active (Spark Joy) ✨

**Root**:
- `build.zig`, `build.zig.zon`, `readme.md`, `changelog.md`

**Docs Root**:
- `grain_style.md`, `plan.md`, `tasks.md`
- Active reference documents
- Current agent prompts/summaries

**Agent Communications**:
- Latest coordination plans (last 2-3 weeks)
- Active enforcement prompts
- Master coordination documents

---

## Files to Archive (Historical Value) 📦

**Move to `archaeology/`**:
- Old agent prompts (superseded)
- Old timestamped coordination files
- Completed rename operations
- Old phase completion summaries

---

## Files to Remove (No Joy) 🗑️

**Delete** (git history preserves):
- Backup files (`.backup`, `.old*`)
- Temporary test files
- Build artifacts (should be gitignored)
- Duplicate files

---

**Status**: Ready for implementation  
**Next Step**: Review and approve, then execute Phase 1

