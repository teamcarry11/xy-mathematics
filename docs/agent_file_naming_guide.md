# Inter-Agent Communication File Naming Guide

## Naming Convention

**Format**: `{grainorder}-{yyyy-mm-dd--hhmm-ss}-{descriptive-name}.md`

**Example**: `bchlnp-2025-11-23--0134-24-agent-coordination-status.md`

## Components

### 1. Grainorder Prefix (6 characters)

- **Purpose**: Ensures newest files appear first in GitHub's A→Z sort
- **Alphabet**: `bchlnpqsxyz` (11 consonants)
- **Mnemonic**: "batch line pick six yeezy"
- **Behavior**: Smaller codes = newer files
- **Max Codes**: 332,640 permutations

**How to get next grainorder**:
1. Find the most recent grainorder code in `docs/`
2. Use grainorder's `prev()` function to get the next smaller code
3. Or use `tools/generate_agent_filename.sh` helper script

### 2. Timestamp (19 characters)

- **Format**: `yyyy-mm-dd--hhmm-ss`
- **Example**: `2025-11-23--0134-24`
- **Purpose**: Human-readable date/time for quick reference
- **Timezone**: Use local time (PST/PDT for this project)

**Generate with**:
```bash
date +"%Y-%m-%d--%H%M-%S"
```

### 3. Descriptive Name (kebab-case)

- **Format**: Lowercase, hyphens for spaces
- **Examples**:
  - `agent-coordination-status`
  - `vm-kernel-coordination-response`
  - `editor-browser-acknowledgment`
- **Purpose**: Clear, searchable description of file content

## Usage

### Creating a New File

1. **Generate filename**:
   ```bash
   ./tools/generate_agent_filename.sh agent-coordination-status
   # Output: bchlnp-2025-11-23--0134-24-agent-coordination-status.md
   ```

2. **Create file with that name**:
   ```bash
   touch "docs/$(./tools/generate_agent_filename.sh agent-coordination-status)"
   ```

### Renaming an Existing File

1. **Generate new filename**:
   ```bash
   NEW_NAME=$(./tools/generate_agent_filename.sh agent-coordination-status)
   ```

2. **Rename file**:
   ```bash
   mv docs/old_name.md "docs/$NEW_NAME"
   ```

## File Organization

### Active Files (in `docs/`)

- Current agent prompts/summaries
- Active coordination files
- Reference documentation

### Archived Files (in `archaeology/docs/agent-communications/`)

- Old coordination files (older than ~1 week)
- Completed coordination cycles
- Historical agent communications

## Examples

### Current Files (Keep in `docs/`)

- `bchlnp-2025-11-23--0134-24-grain-skate-agent-prompt.md`
- `bchlnq-2025-11-23--0134-25-grain-skate-agent-summary.md`

### Archived Files (Move to `archaeology/`)

- `agent_coordination_status.md` (old format, move to archaeology)
- `agent_message_for_editor_browser.md` (old format, move to archaeology)

## Migration

When migrating old files:

1. **Don't rename old files** - preserve original names in archaeology
2. **Use new format for new files** - going forward
3. **Update references** - in plan.md, tasks.md, etc.

## Benefits

1. **Chronological Sorting**: Newest files appear first in GitHub
2. **Human Readable**: Timestamp provides quick date reference
3. **Searchable**: Descriptive name makes purpose clear
4. **Unique**: Grainorder ensures no collisions
5. **Scalable**: 332,640 possible codes (enough for ~900 years at 1 file/day)

