# Grain OS Research Directory

**Purpose**: Exploratory research, analysis, and documentation for Grain OS development.

---

## Directory Structure

### Research Documents

**Location**: `docs/research/`

**Purpose**: Formal research deliverables, analysis documents, and specifications.

**Examples**:
- `dream_browser_spec_v0_research_2025-12-10-083733-pst.md` — Dream Browser specification
- `slc_product_financial_analysis_2025-12-20-150727-pst.md` — SLC product financial analysis
- `grain_government_systems_integration_2025-12-20-145246-pst.md` — Government systems integration analysis
- `first_principles_product_development_2025-12-19-200151-pst.md` — First-principles product development
- `slc_grain_style_developer_tools_coordination_2025-12-20-162641-pst.md` — Grain Style Developer Tools coordination

### Research Session Summaries

**Location**: `research/`

**Purpose**: Session summaries, exploratory work, and research artifacts.

**Examples**:
- `2025-12-07-055806-pst-keaton_research_session_summary.gr` — Research session summary (Grainscript)
- `2025-12-07-103707-pst-keaton_profile_gallery.md` — Profile gallery with images and quines

### Archive Files

**Location**: `research/`

**Purpose**: Archive files and backups.

**Examples**:
- `grain_os_single_file.zig` — Single-file archive for Y Combinator application (132,384 lines)
- `src_backup/` — Backup copy of `src/` directory (387 files)

---

## Key Files

### `grain_os_single_file.zig`

**Purpose**: Y Combinator application artifact — single-file archive of all `src/` directory `.zig` files.

**Why**: Y Combinator doesn't accept zip bundles. This is the whole codebase in one file.

**Details**:
- 132,384 lines
- All `.zig` files from `src/` concatenated
- Line-wrapped at 73 characters (`grainwrap-73`)
- Grain Style documentation header
- Path separators demarking original file locations

**Status**: Archive artifact, not for compilation.

### `src_backup/`

**Purpose**: Backup copy of `src/` directory.

**Details**:
- 387 files
- Created during single-file archive generation
- May be archived if no longer needed

**Status**: Backup, evaluate for archiving.

---

## Research Workflow

### Creating Research Documents

1. **Use timestamp prefix**: `yyyy-mm-dd-hhmmss-pst-` for filenames
2. **Location**: `docs/research/` for formal deliverables
3. **Format**: Markdown with clear structure
4. **Grain Style**: Follow Grain Style principles where applicable

### Research Session Summaries

1. **Use timestamp prefix**: `yyyy-mm-dd-hhmmss-pst-` for filenames
2. **Location**: `research/` for session summaries
3. **Format**: Grainscript (`.gr`) or Markdown (`.md`)
4. **Content**: Session context, decisions, insights

---

## Integration with Research Agent

**Research Agent** (`src/grain_research/`) provides:
- Research Engine: Data collection, storage, query
- Data Analysis: Performance, usage patterns, metrics
- Research Tools: Code analysis, profiling, system behavior
- Insights Generator: Recommendations, reports

**Research Directory** (`research/`, `docs/research/`) provides:
- Exploratory research documents
- Session summaries
- Archive files
- Research artifacts

**Relationship**: Research Agent can analyze research directory content, generate insights, and provide recommendations based on research patterns.

---

## References

- **Research Agent Plan**: `docs/plans/plan_research.md`
- **Research Agent Tasks**: `docs/tasks/tasks_research.md`
- **Grain Style Guide**: `docs/grain_style.md`

---

**Last Updated**: 2025-12-20-162641-pst  
**Maintained By**: Grain Research Agent
