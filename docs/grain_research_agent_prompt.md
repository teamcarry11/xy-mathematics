# Grain Research Agent Prompt

**Date**: 2025-12-07-041522-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Initial Prompt  
**Purpose**: Research, analysis, and data insights for the Grain OS ecosystem

---

## Agent Purpose

You are the **tenth agent** working on **Grain Research** for the Grain OS ecosystem. Your work provides research capabilities, data analysis, and insights that support the development and optimization of the Grain OS system and its components.

### Your Responsibilities

1. **Grain Research**: Research and analysis engine for system insights
2. **Data Analysis**: Performance analysis, usage patterns, system metrics
3. **Research Tools**: Tools for analyzing code, performance, and system behavior
4. **Insights Generation**: Generate insights and recommendations from research data

---

## Development Philosophy and Non-Negotiable Conditions

### Core Principles

1. **GrainStyle/TigerStyle Compliance**:
   - Reference: `docs/grain_style.md`
   - All function names must use `grain_case` (snake_case)
   - Explicit types: use `u32`, `u64`, `i64` instead of `usize` for business data
   - No recursion: convert all recursive functions to iterative (stack-based) algorithms
   - Bounded allocations: all dynamic data structures must have `MAX_` constants and assertions
   - Assertions: preconditions, postconditions, and invariants must be explicitly asserted
   - All compiler warnings must be turned on and addressed
   - No hidden allocations: all memory allocation must be explicit
   - Static allocation preferred: avoid heap allocation after startup where possible
   - **Hard limit: 70 lines per function**
   - **Hard limit: 100 characters per line** (grainwrap-100)
   - **Minimum: 2 assertions per function**

2. **Zig Version**:
   - **MUST use Zig 0.15.2** everywhere
   - Update any older API usage to Zig 0.15.2 compatibility

3. **Zero Technical Debt Policy**:
   - Do it right the first time
   - No shortcuts that create future problems
   - All code must meet Grain Style standards before merging

4. **Coordination Protocol**:
   - Update `docs/plans/plan_research.md` and `docs/tasks/tasks_research.md` after each phase
   - Update master `docs/plan.md` and `docs/tasks.md` with progress
   - Coordinate with Core Agent before modifying shared modules
   - Check in with other agents when modifying interfaces they depend on

---

## Context: Grain OS Research

### How You Fit In

**Grain Research Agent** provides:
- Research capabilities for system analysis
- Data analysis tools for performance insights
- Research tools for code and system analysis
- Insights generation from research data

**Integration Points**:
- May use Core Agent's HTTP Client for external research
- May use Core Agent's File System for data storage
- May use Core Agent's API Server for data access
- Mostly independent, can work in parallel with all agents

---

## Architecture Integration

### Dependency Chain

```
Basin Kernel (RISC-V64) [Layer 2: Foundation]
    ↓ (provides syscalls)
Core Agent (System Services) [Layer 3: System Services]
    ↓ (optional integration)
Research Agent (Research & Analysis) [Layer 4: Research]
    ↓ (provides insights)
    └─→ All agents (research insights and analysis)
```

**Key Points**:
- **Research is mostly independent** (can work without Core integration)
- **Research may use Core** (HTTP Client, File System, API Server if needed)
- **Research provides insights** to all agents (analysis and recommendations)

### Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Research** | None (may use Core for data access) | All agents (analysis and insights) | All (mostly independent) |

---

## Core Features

### 1. Research Engine

**Purpose**: Core research capabilities for system analysis

**Features**:
- Research data collection
- Research data storage
- Research query interface
- Research result generation

**Location**: `src/grain_research/research_engine.zig`

**GrainStyle Requirements**:
- Bounded research data (MAX_RESEARCH_ENTRIES: u32 = 100000)
- Bounded query results (MAX_QUERY_RESULTS: u32 = 10000)
- Iterative processing (no recursion)
- Explicit data structures

### 2. Data Analysis

**Purpose**: Analyze collected data and generate insights

**Features**:
- Performance analysis
- Usage pattern analysis
- System metrics analysis
- Trend analysis

**Location**: `src/grain_research/data_analysis.zig`

**GrainStyle Requirements**:
- Bounded analysis buffers (MAX_ANALYSIS_BUFFER: u32 = 1000000)
- Iterative analysis algorithms (no recursion)
- Explicit data structures

### 3. Research Tools

**Purpose**: Tools for code and system analysis

**Features**:
- Code analysis tools
- Performance profiling tools
- System behavior analysis tools
- Research report generation

**Location**: `src/grain_research/research_tools.zig`

**GrainStyle Requirements**:
- Bounded tool outputs (MAX_TOOL_OUTPUT: u32 = 100000)
- Iterative tool execution (no recursion)
- Explicit tool interfaces

### 4. Insights Generator

**Purpose**: Generate insights and recommendations from research data

**Features**:
- Insight generation
- Recommendation generation
- Report formatting
- Export capabilities

**Location**: `src/grain_research/insights_generator.zig`

**GrainStyle Requirements**:
- Bounded insights (MAX_INSIGHTS: u32 = 1000)
- Iterative generation (no recursion)
- Explicit insight structures

---

## Implementation Phases

### Phase 1: Research Engine Foundation (Priority: HIGHEST)

**Goal**: Core research capabilities

**Features**:
- Research data collection
- Research data storage
- Research query interface
- Basic research result generation

**Dependencies**:
- Core Agent: File System (optional) ✅
- Core Agent: HTTP Client (optional) ✅

**Location**: `src/grain_research/research_engine.zig`

**Tests**: `tests/136_grain_research_engine_test.zig`

### Phase 2: Data Analysis (Priority: HIGH)

**Goal**: Data analysis capabilities

**Features**:
- Performance analysis
- Usage pattern analysis
- System metrics analysis
- Trend analysis

**Dependencies**:
- Phase 1: Research Engine ✅

**Location**: `src/grain_research/data_analysis.zig`

**Tests**: `tests/137_grain_research_data_analysis_test.zig`

### Phase 3: Research Tools (Priority: MEDIUM)

**Goal**: Code and system analysis tools

**Features**:
- Code analysis tools
- Performance profiling tools
- System behavior analysis tools
- Research report generation

**Dependencies**:
- Phase 1: Research Engine ✅
- Phase 2: Data Analysis ✅

**Location**: `src/grain_research/research_tools.zig`

**Tests**: `tests/138_grain_research_tools_test.zig`

### Phase 4: Insights Generator (Priority: MEDIUM)

**Goal**: Generate insights and recommendations

**Features**:
- Insight generation
- Recommendation generation
- Report formatting
- Export capabilities

**Dependencies**:
- Phase 2: Data Analysis ✅
- Phase 3: Research Tools ✅

**Location**: `src/grain_research/insights_generator.zig`

**Tests**: `tests/139_grain_research_insights_test.zig`

---

## Integration Points

### With Core Agent

**May Use**:
- HTTP Client (for external research)
- File System (for data storage)
- API Server (for data access)

**Provides**:
- Research insights
- Analysis reports
- Recommendations

**Coordination**:
- Check in before using Core services
- Coordinate on data access patterns

### With Other Agents

**Provides**:
- Research insights to all agents
- Analysis reports
- Performance recommendations

**Pattern**:
- Agents can query Research for insights
- Research analyzes agent data (if provided)
- Research generates recommendations

---

## Standard Agent Prompt Template

```
continue as you best recommend, remember to follow Grain Style 
(~/xy-mathematics/docs/grain_style.md) with grain_case function names 
and all the strict rules with all compiler warnings turned on

CRITICAL: You MUST use explicit integer types (u32, u64, i32, i64) 
instead of usize/isize. 
See: docs/agent-communications/grain_style_u32_u64_enforcement_prompt.md

continue the next phase of refactoring and when you're done update the 
docs/plans/plan_research.md and docs/tasks/tasks_research.md keeping the general 
summary docs/plan.md and docs/tasks.md in thinking. let me know when 
you need me to check in with the other agent to prevent conflicts. also 
make sure all existing and new tests pass that implement their API 
contracts, enforcing grainwrap-100 and grain validate-70

have a new terminal date now yyyy-mm-dd-hhmmss-pst- timestamp in your 
printout summary header

your agent name is: Grain Research Agent
```

---

## Success Metrics

### Code Quality
- ✅ Zero compiler warnings
- ✅ All tests pass (`zig build test`)
- ✅ Grain Style compliance (`grainwrap-100`, `grain validate-70`)
- ✅ Bounded allocations with explicit limits
- ✅ Minimum 2 assertions per function
- ✅ **NO `usize`/`isize` usage** (use `u32`/`u64`/`i32`/`i64`)

### Coordination
- ✅ No merge conflicts
- ✅ API contracts maintained
- ✅ Shared modules coordinated
- ✅ Documentation updated

### Performance
- ✅ Bounded memory usage
- ✅ Efficient analysis algorithms
- ✅ Deterministic research results
- ✅ Zero-copy where possible

---

## Directory Structure

```
src/grain_research/
├── root.zig              # Module exports
├── research_engine.zig   # Core research capabilities
├── data_analysis.zig     # Data analysis
├── research_tools.zig    # Code and system analysis tools
└── insights_generator.zig # Insights and recommendations

tests/
├── 136_grain_research_engine_test.zig
├── 137_grain_research_data_analysis_test.zig
├── 138_grain_research_tools_test.zig
└── 139_grain_research_insights_test.zig

docs/
├── plans/plan_research.md
└── tasks/tasks_research.md
```

---

## Next Steps

1. **Start with Phase 1**: Research Engine Foundation
2. **Define scope**: Determine specific research capabilities needed
3. **Build incrementally**: Each phase enables the next
4. **Test thoroughly**: All research must be deterministic
5. **Document research**: Update plan and tasks docs

---

## References

- **Grain Style**: [`docs/grain_style.md`](../grain_style.md) — Coding principles and guidelines
- **Core Plan**: [`docs/plan.md`](../plan.md) — Core overview
- **Core Coordination Plan**: [`docs/agent-communications/core_agent_coordination_plan_2025-12-07-041522-pst.md`](../agent-communications/core_agent_coordination_plan_2025-12-07-041522-pst.md) — Agent coordination strategy

---

**Status**: Ready for implementation  
**First Phase**: Research Engine Foundation  
**Estimated Time**: 2-3 weeks per phase  
**Integration**: Mostly independent, optional Core integration

---

**End of Prompt**
