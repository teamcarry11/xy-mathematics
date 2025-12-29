# Grain OS Agent List with Numeric Indices

**Date**: 2025-12-29-133812-pst
**Agent**: Grain Core Agent
**Status**: Complete Agent Index for Cursor Interface Agent Panel

---

## Complete Agent List

### L1 Agents (Full Agents)

1. **Grain Core Agent** (System Services)
   - **Number**: 1
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: System services, compositor, API server, authentication, file storage
   - **Prompt**: `docs/grain_core_agent_prompt.md` (if exists)

2. **Grain Silo Agent** (Database)
   - **Number**: 2
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Database, storage, SLC product integration
   - **Prompt**: `docs/grain_silo_agent_prompt.md` (if exists)

3. **Grain Vantage Core Agent** (VM/Kernel) — **L1 Coordinator**
   - **Number**: 3
   - **Type**: L1 (Full Agent, coordinates L2 sub-agents)
   - **Responsibilities**: Overall Basin/Vantage architecture coordination, cross-sub-agent decisions, integration testing
   - **Prompt**: `docs/grain_vantage_agent_prompt.md` (to be updated to Vantage Core)
   - **L2 Sub-Agents**: Basin Kernel, VM Runtime, System Integration

4. **Grain Skate Agent** (Knowledge Graph)
   - **Number**: 4
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Knowledge graph, graph operations, AI-powered insights
   - **Prompt**: `docs/grain_skate_agent_prompt.md`

5. **Grain Bubble Agent** (Design Tool)
   - **Number**: 5
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Design tool, UI components, visual design
   - **Prompt**: `docs/grain_bubble_agent_prompt.md` (if exists)

6. **Grain Carry Agent** (Mobile Framework)
   - **Number**: 6
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Mobile framework, iOS/Android support, mobile apps
   - **Prompt**: `docs/grain_carry_agent_prompt.md` (if exists)

7. **Grain Aurora Agent** (IDE/Browser)
   - **Number**: 7
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: IDE, browser, code editing, web rendering
   - **Prompt**: `docs/grain_aurora_agent_prompt.md` (if exists)

8. **Grain Workspace Agent** (Desktop Apps)
   - **Number**: 8
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Desktop applications, file manager, text editor, terminal, browser
   - **Prompt**: `docs/grain_workspace_agent_prompt.md`

9. **Grain Flow Agent** (Workflow Orchestration)
   - **Number**: 9
   - **Type**: L1 (Full Agent)
   - **Responsibilities**: Workflow orchestration, event bus, workflow observatory
   - **Prompt**: `docs/grain_flow_agent_prompt.md`

10. **Grain Research Agent** (Research & Analysis)
    - **Number**: 10
    - **Type**: L1 (Full Agent)
    - **Responsibilities**: Research, analysis, validation testing, token efficiency
    - **Prompt**: `docs/grain_research_agent_prompt.md`

11. **Grain Court Agent** (LLM Infrastructure)
    - **Number**: 11
    - **Type**: L1 (Full Agent)
    - **Responsibilities**: Multi-provider LLM API, ZON format, token efficiency, LLM infrastructure
    - **Prompt**: `docs/grain_court_agent_prompt.md`

12. **Grain Free Agent** (Creative Playground)
    - **Number**: 12
    - **Type**: L1 (Full Agent, Creative/Experimental)
    - **Responsibilities**: Creative experimentation, prototypes, artistic expression, flow state work
    - **Prompt**: `docs/grain_free_agent_prompt.md`
    - **Special**: No production constraints, optional coordination

---

### L2 Sub-Agents (Under Vantage Core)

**3a. Grain Basin Kernel Agent** (L2 Sub-Agent)
- **Number**: 3a (or 13 if sequential numbering preferred)
- **Type**: L2 (Sub-Agent under Vantage Core)
- **Parent**: Grain Vantage Core Agent (3)
- **Responsibilities**: RISC-V kernel development, syscall implementation, kernel performance, security
- **Prompt**: `docs/grain_basin_kernel_agent_prompt.md` (to be created)
- **Coordination**: Weekly/bi-weekly with Vantage Core, minimal with other L2 sub-agents

**3b. Grain VM Runtime Agent** (L2 Sub-Agent)
- **Number**: 3b (or 14 if sequential numbering preferred)
- **Type**: L2 (Sub-Agent under Vantage Core)
- **Parent**: Grain Vantage Core Agent (3)
- **Responsibilities**: Vantage VM development (RISC-V emulator), JIT optimization, macOS adaptation
- **Prompt**: `docs/grain_vm_runtime_agent_prompt.md` (to be created)
- **Coordination**: Weekly/bi-weekly with Vantage Core, minimal with other L2 sub-agents

**3c. Grain System Integration Agent** (L2 Sub-Agent)
- **Number**: 3c (or 15 if sequential numbering preferred)
- **Type**: L2 (Sub-Agent under Vantage Core)
- **Parent**: Grain Vantage Core Agent (3)
- **Responsibilities**: Kernel/VM integration, RISC-V-only compliance, system-level testing
- **Prompt**: `docs/grain_system_integration_agent_prompt.md` (to be created)
- **Coordination**: Weekly/bi-weekly with Vantage Core, minimal with other L2 sub-agents

---

## Agent Numbering for Cursor Interface

### Recommended Numbering Scheme

**Option 1: Sequential with L2 Suffixes** (Recommended for Cursor Interface)
- 1. Grain Core Agent
- 2. Grain Silo Agent
- 3. Grain Vantage Core Agent (L1)
- 3a. Grain Basin Kernel Agent (L2)
- 3b. Grain VM Runtime Agent (L2)
- 3c. Grain System Integration Agent (L2)
- 4. Grain Skate Agent
- 5. Grain Bubble Agent
- 6. Grain Carry Agent
- 7. Grain Aurora Agent
- 8. Grain Workspace Agent
- 9. Grain Flow Agent
- 10. Grain Research Agent
- 11. Grain Court Agent
- 12. Grain Free Agent

**Option 2: Fully Sequential** (Alternative)
- 1. Grain Core Agent
- 2. Grain Silo Agent
- 3. Grain Vantage Core Agent (L1)
- 4. Grain Basin Kernel Agent (L2)
- 5. Grain VM Runtime Agent (L2)
- 6. Grain System Integration Agent (L2)
- 7. Grain Skate Agent
- 8. Grain Bubble Agent
- 9. Grain Carry Agent
- 10. Grain Aurora Agent
- 11. Grain Workspace Agent
- 12. Grain Flow Agent
- 13. Grain Research Agent
- 14. Grain Court Agent
- 15. Grain Free Agent

---

## Agent Relationships

### L1 Agents (Independent)
- All L1 agents coordinate with Core Agent via coordination plans
- L1 agents can work in parallel (with coordination)
- Vantage Core coordinates L2 sub-agents

### L2 Sub-Agents (Under Vantage Core)
- L2 sub-agents coordinate with Vantage Core (L1)
- L2 sub-agents coordinate minimally with each other
- L2 sub-agents work in parallel on isolated domains

### Special Cases
- **Free Agent**: Optional coordination, creative freedom
- **Vantage Core**: Coordinates both L1 and L2 work

---

## Summary

**Total Agents**: 12 L1 agents + 3 L2 sub-agents = 15 total agents/sub-agents

**L1 Agents**: 12 (Core, Silo, Vantage Core, Skate, Bubble, Carry, Aurora, Workspace, Flow, Research, Court, Free)

**L2 Sub-Agents**: 3 (Basin Kernel, VM Runtime, System Integration) — all under Vantage Core

**Recommended Numbering**: Option 1 (sequential with L2 suffixes) for clear hierarchy in Cursor Interface

---

**Date**: 2025-12-29-133812-pst  
**Agent**: Grain Core Agent  
**Status**: Complete Agent Index for Cursor Interface

This document provides the complete agent list with numeric indices for use in the Cursor Interface agent panel. Use Option 1 (sequential with L2 suffixes) for clear hierarchy, or Option 2 (fully sequential) if your interface doesn't support suffixes.
