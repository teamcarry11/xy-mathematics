# Monorepo Cleanup Plan

## Overview

This document outlines the cleanup strategy for organizing inter-agent communication files and other documentation.

## Naming Convention

### New Format for Inter-Agent Communication Files

**Format**: `{grainorder}-{yyyy-mm-dd--hhmm-ss}-{descriptive-name}.md`

**Example**: `bchlnp-2025-11-23--0134-24-agent-coordination-status.md`

**Benefits**:
- Grainorder prefix ensures newest files appear first (smallest codes = newest)
- Timestamp provides human-readable date/time
- Descriptive name makes purpose clear
- Files sort chronologically in GitHub's A→Z view

### Grainorder System

- **Alphabet**: `bchlnpqsxyz` (11 consonants)
- **Code Length**: 6 characters
- **Mnemonic**: "batch line pick six yeezy"
- **Behavior**: Smaller codes = newer files (appear first in A→Z sort)
- **Max Codes**: 332,640 permutations

## Files to Move to `archaeology/docs/agent-communications/`

### Old Inter-Agent Communication Files (Pre-2025-11-21)

These files are from earlier coordination and can be archived:

1. `agent_coordination_status.md` (Nov 21)
2. `agent_message_for_editor_browser.md` (Nov 21)
3. `agent_message_test_status_update.md` (Nov 21)
4. `agent_message_vm_kernel_json_guidance.md` (Nov 22)
5. `agent_message_vm_kernel_test_fixes.md` (Nov 22)
6. `agent_prompt.md` (generic, may be outdated)
7. `agent_work_allocation.md` (Nov 21)
8. `agent_work_summary.md` (older summary)
9. `agent_work_summary_recent.md` (empty file)
10. `coordination_checkpoint.md` (Nov 21)
11. `editor_browser_acknowledgment.md` (Nov 22)
12. `editor_browser_coordination_acknowledgment.md` (Nov 21)
13. `editor_browser_to_vm_coordination.md` (Nov 21)
14. `vm_kernel_coordination_response.md` (Nov 21)
15. `vm_kernel_browser_agent_summary.md` (Nov 21)
16. `websocket_coordination_note.md` (Nov 21)
17. `dream_editor_browser_agent_summary_2025-11-21.md` (has date, but old)
18. `test_fix_progress.md` (Nov 22, temporary status)

### Keep in `docs/` (Active/Reference)

These files should stay in `docs/` as they are:
- Active reference documents
- Architectural documentation
- Current agent prompts/summaries

1. `grain_skate_agent_prompt.md` (current agent prompt)
2. `grain_skate_agent_summary.md` (current agent summary)
3. `grain_skate_agent_acknowledgment.md` (current agent acknowledgment)
4. `ai_provider_refactoring.md` (recent architectural doc)
5. `plan.md` (active planning doc)
6. `tasks.md` (active task list)
7. `dag_ui_synthesis.md` (architectural reference)
8. `dream_editor_browser_synthesis.md` (architectural reference)
9. `vm_api_reference.md` (API reference)
10. All files in `docs/learning-course/` (educational content)
11. All files in `docs/zyx/` (archived but organized)

## Migration Steps

### Step 1: Create Archive Structure

```bash
mkdir -p archaeology/docs/agent-communications
```

### Step 2: Move Old Files

Move files listed above to `archaeology/docs/agent-communications/` with original names preserved.

### Step 3: Rename Current Files

For new inter-agent communication files going forward, use the new naming convention:
- `{grainorder}-{yyyy-mm-dd--hhmm-ss}-{descriptive-name}.md`

### Step 4: Update References

Update any references to moved files in:
- `docs/plan.md`
- `docs/tasks.md`
- Other documentation files

## Grainorder Code Management

### Getting Next Grainorder Code

To get the next grainorder code (smaller = newer):

1. Find the most recent grainorder code in `docs/`
2. Use grainorder's `prev()` function to get the next smaller code
3. Or use a tool/script to generate it

### Starting Point

If no grainorder codes exist yet, start with a large code (oldest):
- Example: `zyxvsq` (one of the largest codes)

Then decrement for each new file:
- `zyxvsq` → `zyxvsb` → `zyxvsc` → ... (getting smaller/newer)

## Implementation Script

A Zig script could be created to:
1. Generate next grainorder code
2. Format filename with timestamp
3. Rename files automatically

This would be in `tools/rename_agent_file.zig` or similar.

