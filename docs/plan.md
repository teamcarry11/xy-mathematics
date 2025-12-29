# Grain OS Development Plan

**Last Updated**: 2025-12-29-133812-pst  
**Structure**: Hybrid approach with core overview and agent-specific plans  
**See**: `docs/plans/plan_{agent}.md` for detailed agent plans

---

## Overall Status

**Goal**: RISC-V-targeted Grain OS with graphical interface running in macOS Tahoe 26.3 Beta VM, with path toward Framework 13 RISC-V hardware.

**Current Status**: Multiple agents working in parallel on different components.

**Active Agents**: 12 L1 agents + 3 L2 sub-agents = 15 total agents/sub-agents

**L1 Agents (Full Agents)**:
1. **Grain Core Agent** (System Services)
2. **Grain Silo Agent** (Database)
3. **Grain Vantage Core Agent** (VM/Kernel) — L1 Coordinator with L2 sub-agents
4. **Grain Skate Agent** (Knowledge Graph)
5. **Grain Bubble Agent** (Design Tool)
6. **Grain Carry Agent** (Mobile Framework)
7. **Grain Aurora Agent** (IDE/Browser)
8. **Grain Workspace Agent** (Desktop Apps)
9. **Grain Flow Agent** (Workflow Orchestration)
10. **Grain Research Agent** (Research & Analysis)
11. **Grain Court Agent** (LLM Infrastructure)
12. **Grain Free Agent** (Creative Playground)

**L2 Sub-Agents (Under Vantage Core)**:
- **3a. Grain Basin Kernel Agent** (RISC-V kernel development)
- **3b. Grain VM Runtime Agent** (Vantage VM development tool)
- **3c. Grain System Integration Agent** (Kernel/VM integration, RISC-V compliance)

**Architecture Evolution**: L1/L2 sub-agent pattern implemented for Vantage Core to enable parallelization of foundational work. See `docs/zyx/grain_agent_architecture_evolution_2025-12-29-130647-pst.md` for details.

---

## Critical Architecture Principle: RISC-V-Only Grain OS

**Fundamental Rule**: All Grain OS software is **RISC-V-only**. There is no ARM64-specific code in Grain OS.

**Vantage VM Role**:
- **Vantage** is a **development tool** (RISC-V emulator/VM) that runs on ARM64 (macOS)
- **Purpose**: Enable Basin kernel development and testing on Apple Silicon
- **NOT part of Grain OS**: Vantage is a development tool, not Grain OS software
- **When Vantage works**: All Grain OS software can run on ARM64 machines via emulation, but the software itself is exclusively RISC-V

**Grain OS Software**:
- **Basin Kernel**: RISC-V64 kernel (pure RISC-V)
- **Core Agent**: RISC-V system services (uses RISC-V syscalls)
- **All other agents**: RISC-V-only code
- **Production target**: RISC-V hardware (Framework 13, etc.)

**This principle applies to all agent work**: No agent should introduce ARM64-specific code into Grain OS. Vantage VM development is separate from Grain OS development.

---

## Agent Status Summary

### 1. Grain Core Agent (System Services)

**Status**: Active — Coordination Decisions Implementation Complete ✅  
**Current Work**: Update HTTP/WebSocket clients to use error types consistently (1 day), JG Project Phase 1 planning  
**Details**: See [`docs/plans/plan_core.md`](plans/plan_core.md)

**Recent Progress**:
- Phase 59: HTTP/REST API Server ✅ (COMPLETE — 2025-12-05-120808-pst)
- Phase 60: Authentication Service ✅ (COMPLETE — 2025-12-05-134449-pst)
- Phase 61: Network Stack Enhancements ✅ (COMPLETE — TCP/UDP socket support, WebSocket support, DNS resolution, socket options, HTTP client — 2025-12-07-004326-pst)
- Phase 62: File System Enhancements ✅ (COMPLETE — File storage, WAL, index management, backup/restore — 2025-12-06-113038-pst)
- HTTP/WebSocket Timeout Implementation ✅ (COMPLETE — 2025-12-28-235609-pst)
- Error Types Implementation ✅ (COMPLETE — 2025-12-28-235609-pst)
- Service-to-Service Authentication ✅ (COMPLETE — 2025-12-29-001544-pst)
- Async Pattern Integration Module ✅ (COMPLETE — 2025-12-29-001544-pst)
- Payment/Passwords/Bank Design ✅ (COMPLETE — 2025-12-28-213448-pst)
- JG Project Design ✅ (COMPLETE — 2025-12-28-232324-pst)

**Provides**: Compositor, system services, API server ✅, authentication ✅, network stack ✅, file system ✅, timeout/error handling ✅, service-to-service auth ✅, async pattern ✅

**Dependencies**:
- **Needs**: Network Manager (exists), Process Manager (exists)
- **Provides**: API Server (for Silo Agent, Carry Agent) ✅, Authentication Service ✅, Network Stack ✅, File System ✅

**Next Phases**:
- Update HTTP/WebSocket clients to use error types consistently (1 day)
- JG Project Phase 1: Grainbank MMT integration (2 months)

---

### 2. Grain Silo Agent (Database)

**Status**: Production Ready ✅ — Payment/Vault Storage Schema Complete ✅  
**Current Work**: JG project storage schema design (Priority 1, HIGH, Month 1)  
**Details**: See [`docs/plans/plan_silo.md`](plans/plan_silo.md)

**Recent Progress**:
- Phase 1-9: All core database phases complete ✅
- SLC Product Integration ✅ (COMPLETE — 2025-12-20-161207-pst)
- Design Gaps Implementation ✅ (COMPLETE)
- Circuit Breaker Pattern Documentation ✅ (COMPLETE)
- Error Types Documentation ✅ (COMPLETE)
- Payment/Vault/Bank Storage Schema Design ✅ (COMPLETE — 2025-12-28-230000-pst)
- **Status**: All core phases (1-9) complete, SLC integration complete — **PRODUCTION READY** ✅

**Provides**: Database backend (for Carry Agent), REST API (via Core Agent), storage helpers

**Dependencies**:
- **Needs**: API Server (Core Agent — Phase 59 ✅), File Storage (Core Agent — Phase 62 ✅), Network Stack (Core Agent — Phase 61 ✅)
- **Provides**: Database backend (for Carry Agent)

**Next Phases**:
- JG Project: Storage schema design for all JG modules (Month 1)
- JG Project: Storage helper implementation (Months 2-3)

---

### 3. Grain Vantage Core Agent (VM/Kernel) — L1 Coordinator

**Status**: All Kernel Features Complete ✅ — Kernel Refactoring Complete ✅ — Production Ready  
**Current Work**: Architecture evolution to Vantage Core + L2 sub-agents, JG project kernel support monitoring  
**Details**: See [`docs/plans/plan_vantage.md`](plans/plan_vantage.md)

**Recent Progress**:
- Phase 1: Kernel Statistics & Health Check ✅ (COMPLETE)
- Phase 2: Resource Usage Tracking ✅ (COMPLETE)
- Phase 3: Syscall Timeout Mechanism ✅ (COMPLETE)
- Phase 4: Resource Limits ✅ (COMPLETE)
- Phase 4: Network Syscalls ✅ (COMPLETE)
- Phase 5: Audio Device Management ✅ (COMPLETE)
- Phase 6.4: Cross-Platform Compatibility ✅ (COMPLETE)
- Vantage VM Adaptation Framework ✅ (COMPLETE)
- **Kernel Refactoring (All 8 Phases)** ✅ (COMPLETE — 2025-12-29-070000-pst)
  - Reduced main file from 7,273 lines to 1,590 lines (78% reduction)
  - Organized code into 8 maintainable modules
  - Maintained 100% backward compatibility

**Architecture Evolution**:
- **Planned**: Rename to Vantage Core (L1 coordinator)
- **Planned**: Create L2 sub-agents (Basin Kernel, VM Runtime, System Integration)
- **Goal**: Enable parallelization of foundational work

**Provides**: Kernel syscalls, VM capabilities, file I/O, network syscalls, timeout mechanisms, resource limits

**L2 Sub-Agents** (To Be Created):
- **3a. Grain Basin Kernel Agent**: RISC-V kernel development
- **3b. Grain VM Runtime Agent**: Vantage VM development tool
- **3c. Grain System Integration Agent**: Kernel/VM integration, RISC-V compliance

---

### 4. Grain Skate Agent (Knowledge Graph)

**Status**: Active — Knowledge graph and terminal  
**Current Work**: Feature coordination with Bubble, Aurora, and Core agents  
**Details**: See [`docs/plans/plan_skate.md`](plans/plan_skate.md)

**Recent Progress**:
- Bracket matching ✅ (2025-12-03-162613-pst)
- Language-specific syntax highlighting ✅ (2025-12-03-141818-pst)
- Shared font renderer (Phase 1.1) ✅ (2025-12-02-183358-pst)
- Core editor features ✅
- Graph visualization ✅
- Main entry point ✅

**Provides**: Knowledge graph application, terminal, shared modules

**Next Phases**:
- JG Project: Material knowledge graph (Months 5-7)
- JG Project: Worker skill network (Months 8-9)
- JG Project: Project relationship mapping (Months 10-12)

---

### 5. Grain Bubble Agent (Design Tool)

**Status**: Active — Phase 2 In Progress 🔄  
**Current Work**: Component System — Foundation implementation  
**Details**: See [`docs/plans/plan_bubble.md`](plans/plan_bubble.md)

**Recent Progress**:
- Phase 1: Core Canvas (SLC v1.0) ✅ COMPLETE (2025-12-06-121132-pst)
  - Module structure created (`src/grain_bubble/`) ✅
  - Canvas engine with infinite canvas, zoom/pan ✅
  - Hit testing, shape manipulation, rendering ✅
  - Undo/redo system, PDF export framework ✅
  - Comprehensive tests ✅

**Provides**: Native visual design tool with infinite canvas, vector graphics, layer management, and export capabilities

**Dependencies**:
- **Needs**: Grain Core compositor, framebuffer renderer, input handler, font renderer
- **Provides**: Design tool for creating visual designs and exporting to PDF/HTML

**Next Phases**:
- Phase 2: Component System (IN PROGRESS)
- JG Project: 3D visualization components (Months 7-9)
- JG Project: Dashboard components (Months 10-11)
- JG Project: Mobile UI components (Month 12)

---

### 6. Grain Carry Agent (Mobile Framework)

**Status**: Production Ready ✅ (Synchronous Mode) — Event Bus Integration Complete ✅  
**Current Work**: Mobile framework development, JG project mobile app planning  
**Details**: See [`docs/plans/plan_carry.md`](plans/plan_carry.md)

**Recent Progress**:
- Database integration foundation complete ✅
- Timeout handling integrated ✅ (2025-12-29-170803-pst)
- Error handling integrated ✅ (2025-12-29-170803-pst)
- Retry logic implementation complete ✅ (2025-12-29-170803-pst)
- Event Bus integration complete ✅ (2025-12-29-003407-pst)
- Service-to-service authentication ready ✅
- Async pattern ready ✅

**Provides**: Mobile app framework, shared business logic (Zig), platform bindings, mobile apps (Android, iOS)

**Dependencies**:
- **Needs**: API Server (Core Agent — Phase 59 ✅), Authentication Service (Core Agent — Phase 60 ✅), Network Stack (Core Agent — Phase 61 ✅)
- **Provides**: Mobile applications (Android, iOS)

**Next Phases**:
- JG Project: Worker mobile app (Months 6-8)
- JG Project: Resident mobile app (Months 9-10)
- JG Project: Cooperative mobile app (Months 11-12)

---

### 7. Grain Aurora Agent (IDE/Browser)

**Status**: Active — Editor and browser development  
**Current Work**: Shared module refactoring, Component API integration ready  
**Details**: See [`docs/plans/plan_aurora.md`](plans/plan_aurora.md)

**Recent Progress**:
- Font renderer migration (Phase 1.2) ✅
- Layout system comprehensive tests (Phase 2.2) ✅
- RenderResult Grain/Tiger Style refactoring ✅
- LSP visual rendering features ✅
- Complete LSP implementation ✅
- Editor enhancements (undo/redo, go-to-definition, hover) ✅
- HTTP/WebSocket/GLM-4.6 timeout/error handling complete ✅
- Component API integration ready ✅

**Provides**: Editor framework, browser engine, AI provider integration, shared modules, DAG integration (planned)

**Next Phases**:
- Component API integration
- JG Project: 3D visualization components (Months 7-9)
- JG Project: Dashboard components (Months 10-11)
- JG Project: Mobile UI components (Month 12)

---

### 8. Grain Workspace Agent (Desktop Apps)

**Status**: Phase 36 Complete ✅ — Code Folding Complete ✅  
**Current Work**: Component API implementation complete, ready for Bubble/Aurora integration, JG project desktop dashboards  
**Details**: See [`docs/plans/plan_workspace.md`](plans/plan_workspace.md)

**Recent Progress**:
- Phase 1-9: All desktop applications complete ✅
- Phase 10: WebSocket Integration for Real-Time Features ✅ (2025-12-07-025947-pst)
- Phase 11: HTTP Client Integration (Network Tools) ✅ (2025-12-07-040000-pst)
- Phase 12: HTTP Client Integration (Package Manager UI) ✅ (2025-12-07-050000-pst)
- Phase 13: File Storage Integration (File Manager) ✅ (2025-12-07-071409-pst)
- Phase 14: Backup Manager Integration (File Manager) ✅ (2025-12-07-084440-pst)
- Phase 25-35: Performance Optimizations, Enhanced JSON Output, Text Editor features ✅
- Phase 35: Code Folding Complete ✅
- Phase 36: Error Handling Integration Complete ✅
- Component API Implementation Complete ✅

**Provides**: Desktop applications (Notes, File Manager, Network Tools, Terminal, Browser, Text Editor) with real-time WebSocket support

**Next Phases**:
- JG Project: Desktop dashboard design (Months 3-4)
- JG Project: Desktop dashboard implementation (Months 5-8)

---

### 9. Grain Flow Agent (Workflow Orchestration)

**Status**: All Phases Complete ✅ — Research Agent Coordination Complete ✅  
**Current Work**: All core phases complete, ready for integration and enhancements, JG project workflow orchestration planning  
**Details**: See [`docs/plans/plan_flow.md`](plans/plan_flow.md)

**Recent Progress**:
- Phase 1: Event Bus Foundation ✅ COMPLETE (2025-12-07-054000-pst)
- Phase 2: Agent Coordinator ✅ COMPLETE (2025-12-07-071000-pst)
- Phase 3: Workflow Engine ✅ COMPLETE (2025-12-07-072000-pst)
- Phase 4: Workflow Visualizer ✅ COMPLETE (2025-12-08-140000-pst)
- Phase 5: Workflow Templates & Integration Examples ✅ COMPLETE (2025-12-20-144320-pst)
- ZON Format Integration ✅ COMPLETE
- Research Agent Failure Data Collection ✅ COMPLETE
- Carry Agent Event Bus Initialization ✅ COMPLETE
- Code Quality Improvement ✅ COMPLETE

**Provides**: Complete workflow orchestration, agent coordination, event bus, and visualization services

**Dependencies**:
- **Needs**: Core Agent API Server ✅, WebSocket ✅, Auth ✅
- **Provides**: Complete workflow orchestration system (for all agents)

**Next Phases**:
- JG Project: Task workflow orchestration (Months 4-6)
- JG Project: Supply chain workflow orchestration (Months 7-8)
- JG Project: Democratic process workflows (Months 9-10)

---

### 10. Grain Research Agent (Research & Analysis)

**Status**: All Integration Phases Complete ✅ — Validation Testing In Progress ⏳  
**Current Work**: Validation testing (Phase 2 Token Counting, Phase 3 Cost Tracking), JG project analysis framework planning  
**Details**: See [`docs/plans/plan_research.md`](plans/plan_research.md)

**Recent Progress**:
- Phase 1: Research Engine Foundation — Core Implementation Complete ✅
- Phase 3: Code Analysis Module — Complete (Early for SLC Product) ✅
- Codebase Analyzer — Created for codebase-wide analysis ✅
- SLC Product Research Complete ✅
- Open-Source Service Model Complete ✅
- Flow Agent Collaboration Complete ✅
- Workflow Observability Metrics Research Complete ✅
- Phase 2 LLM Integration Implementation ✅ COMPLETE
- Phase 2 Token Counting Integration Implementation ✅ COMPLETE
- Phase 3 Cost Tracking Integration Implementation ✅ COMPLETE
- Validation testing guide created ✅

**Provides**: Research capabilities, data analysis, insights generation, code analysis, codebase analysis, workflow observability research, token counting for LLM providers

**Dependencies**:
- **Needs**: Core Agent File System (optional) ✅, HTTP Client (optional) ✅
- **Provides**: Research insights and analysis (for all agents), code analysis (for Grain Style Linter), workflow observability metrics (for Flow Agent)

**Next Phases**:
- Complete validation testing (Priority 1, HIGH)
- JG Project: Economic analysis (Months 6-8)
- JG Project: Housing indicators analysis (Months 9-10)
- JG Project: Environmental & social analysis (Months 11-12)

---

### 11. Grain Court Agent (LLM Infrastructure)

**Status**: Phase 1 Complete ✅ — Phase 2 Complete ✅ — Phase 3 In Progress ⏳  
**Current Work**: Phase 3 Token Efficiency Optimization, Payment/Passwords/Bank integration planning, JG project LLM planning  
**Details**: See [`docs/plans/plan_court.md`](plans/plan_court.md)

**Recent Progress**:
- Phase 1: Multi-Provider LLM API Foundation ✅ COMPLETE (2025-12-21-150000-pst)
- Phase 2: ZON Format Integration ✅ COMPLETE (2025-12-29-003500-pst)
- Phase 3: Token Efficiency Optimization ⏳ IN PROGRESS
  - Token counting utilities ✅
  - Cost tracking per provider ✅
  - Provider cost comparison utilities ✅
  - Token savings calculation ✅
  - Provider recommendation ✅
- LLM Timeout/Error Handling ✅ COMPLETE
- Flow Agent Integration ✅ COMPLETE
- Research Agent Integration Support ✅ COMPLETE

**Provides**: Multi-provider LLM API, ZON format support, token efficiency optimization, LLM infrastructure services

**Next Phases**:
- Continue Phase 3 Token Efficiency Optimization
- Payment/Passwords/Bank integration planning
- JG Project: Design optimization (Months 4-6)
- JG Project: Supply chain optimization (Months 7-9)
- JG Project: Policy analysis (Months 10-12)

---

### 12. Grain Free Agent (Creative Playground)

**Status**: 🆕 **CREATED** — Creative playground and experimental space  
**Current Work**: Creative experimentation, prototypes, artistic expression, flow state work  
**Details**: See [`docs/grain_free_agent_prompt.md`](grain_free_agent_prompt.md)

**Purpose**: Dedicated space for personal creativity, experimentation, and flow without blocking production work.

**Key Characteristics**:
- No production constraints (not bound by Grain Style unless experimenting)
- Optional coordination (coordinate when inspired, not required)
- Creative freedom (artistic, experimental, playful work welcome)
- Integration path (valuable work can be refactored to production by appropriate agents)

**Provides**: Creative experiments, prototypes, artistic work, learning projects, inspiration for production features

**Dependencies**: None (completely independent, optional coordination)

---

## Grainbank MMT Job Guarantee (JG) Housing Program

**Status**: ✅ **DESIGN COMPLETE** (2025-12-28-232324-pst)

**Design Document**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`

**Program Vision**: Build beautiful, affordable, sustainable housing using fastest-growing renewable materials (hemp, bamboo, timber, rammed earth) through a federal Job Guarantee program that creates jobs, builds communities, and restores traditional urbanism principles.

**Multi-Agent Integration Plan**: See `docs/agent-communications/core_agent_coordination_plan_2025-12-29-105655-pst.md`

**Agent Responsibilities**:
- **Core Agent**: Grainbank MMT integration, JG module foundation (Months 1-6)
- **Silo Agent**: Storage schemas for all JG modules (Months 1-3)
- **Workspace Agent**: Desktop dashboards (Months 3-8)
- **Court Agent**: LLM planning (Months 4-12)
- **Flow Agent**: Workflow orchestration (Months 4-10)
- **Research Agent**: Analysis & optimization (Months 6-12)
- **Carry Agent**: Mobile apps (Months 6-12)
- **Bubble/Aurora Agents**: UI components (Months 7-12)
- **Skate Agent**: Knowledge graph (Months 5-12)
- **Vantage Core**: Kernel support (as needed)

---

## Cross-Agent Dependencies

### Critical Path

1. **Grain Core Agent → Silo Agent**:
   - API Server (Phase 59) enables Silo Agent REST API
   - File Storage (Phase 62) enables database persistence
   - Network Stack (Phase 61) enables WebSocket for livestream

2. **Grain Core Agent → Carry Agent**:
   - API Server (Phase 59) enables mobile app backend connection
   - Authentication Service (Phase 60 ✅) enables secure mobile app authentication
   - Network Stack (Phase 61) enables HTTP/WebSocket for mobile apps

3. **Silo Agent → Carry Agent**:
   - Database backend provides data for mobile apps
   - REST API (via Core Agent) provides endpoints for mobile apps

### Integration Points

- **API Server (Core) → Database (Silo) → Mobile App (Carry)**
- **Authentication Service (Core) → Database (Silo) → Mobile App (Carry)**
- **Network Stack (Core) → Database (Silo) → Mobile App (Carry)**

---

## Coordination Notes

### Active Coordination

- **Grain Core Agent ↔ Silo Agent**: API contracts, authentication flow, file storage interface
- **Grain Core Agent ↔ Carry Agent**: REST API contracts, authentication flow, WebSocket protocol
- **Grain Core Agent ↔ Vantage Core**: File system integration, network stack, RISC-V compliance
- **Vantage Core ↔ L2 Sub-Agents**: Weekly/bi-weekly check-ins, architecture decisions
- **All Agents**: Coordination via Core Agent coordination plans

### Shared Modules

- **Font Renderer**: Shared implementation (`src/shared/font_renderer.zig`) — Skate Agent Phase 1 ✅
- **Text Buffer**: Planned unification (Skate Agent Phase 2)
- **DAG Core**: Shared DAG implementation
- **UI Rendering**: Planned unification (Skate Agent Phase 4)

---

## Next Milestones

### Immediate (This Week)

1. **Core Agent**: Update HTTP/WebSocket clients to use error types consistently (1 day)
2. **Silo Agent**: Begin JG project storage schema design (Priority 1, HIGH)
3. **Vantage Core**: Plan architecture evolution (rename to Vantage Core, create L2 sub-agents)

### Short-Term (Next 2 Weeks)

1. **Core Agent**: Begin JG Project Phase 1 planning (Grainbank MMT integration)
2. **Silo Agent**: Complete JG project storage schema design
3. **Vantage Core**: Implement architecture evolution (Vantage Core + L2 sub-agents)
4. **All Agents**: Review JG project design document

### Medium-Term (Next Month)

1. **Core Agent**: Begin JG Project Phase 1 implementation (Grainbank MMT integration)
2. **Silo Agent**: Begin JG project storage helper implementation
3. **Workspace Agent**: Begin JG project desktop dashboard design
4. **Court Agent**: Plan JG project LLM integration points
5. **Flow Agent**: Plan JG project workflow orchestration points

---

## References

- **Agent Plans**: `docs/plans/plan_{agent}.md` — Detailed agent development plans
- **Agent Tasks**: `docs/tasks/tasks_{agent}.md` — Detailed agent task lists
- **Grain Style**: `docs/grain_style.md` — Coding principles and guidelines
- **Agent Architecture Evolution**: `docs/zyx/grain_agent_architecture_evolution_2025-12-29-130647-pst.md` — L1/L2 pattern and future agents
- **Agent List**: `docs/zyx/grain_agent_list_with_numbers_2025-12-29-133812-pst.md` — Complete agent index with numbers
- **JG Project Design**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md` — JG project comprehensive design
- **Documentation Structure**: `docs/documentation_structure_recommendation.md` — Structure rationale

---

**Note**: This is a high-level overview. For detailed phase descriptions, implementation details, and task lists, see the agent-specific plan and task files in `docs/plans/` and `docs/tasks/`.
