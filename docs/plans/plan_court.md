# Grain Court Agent: Development Plan

**Agent**: Grain Court Agent (11th Agent)  
**Status**: Phase 1 IN PROGRESS — Multi-Provider LLM API Foundation  
**Last Updated**: 2025-12-21  
**Coordination Plan**: `docs/agent-communications/core_agent_coordination_plan_2025-12-20-215819-pst.md`

---

## Overview

Grain Court Agent is responsible for building the scalable fast agentic compute infrastructure—the LLM backend that powers AI features across Grain OS. Court Agent provides multi-provider LLM API abstraction, ZON format integration for token-efficient communication, and future WSE-wafer-scale SRAM spatial computing support.

**Key Goals**:
- Multi-provider LLM API abstraction (OpenAI, Anthropic, Mistral, self-hosted Cerebras GLM-4.6)
- ZON format integration for 35-70% token reduction
- Token efficiency optimization and cost tracking
- Provider abstraction layer for seamless switching
- WSE spatial computing abstraction (future)

**Integration**: Provides LLM infrastructure services to Aurora, Skate, Flow, Research, and all agents needing AI capabilities.

---

## Architecture Integration

### Dependency Chain

```
Basin Kernel (RISC-V64) [Layer 2: Foundation]
    ↓ (provides syscalls)
Core Agent (System Services) [Layer 3: System Services]
    ↓ (provides HTTP Client, WebSocket, API Server)
Court Agent (LLM Infrastructure) [Layer 4: AI Services]
    ↓ (provides LLM services)
    ├─→ Aurora Agent (AI provider abstraction)
    ├─→ Skate Agent (AI-powered graph insights)
    ├─→ Flow Agent (ZON format integration)
    └─→ Research Agent (Token efficiency validation)
```

**Key Points**:
- **Court depends on Core** (uses Core's HTTP Client, WebSocket, API Server)
- **Court provides to all agents** (LLM infrastructure services)
- **Court can work in parallel with** most agents (except when coordinating integrations)

### Dependency Matrix

| Agent | Depends On | Provides To | Can Work In Parallel With |
|-------|------------|-------------|--------------------------|
| **Court** | **Core** (HTTP Client ✅, WebSocket ✅, API Server ✅), **Basin** (via Core) | All agents (LLM services) | Silo, Vantage, Workspace, Bubble (when not coordinating) |

---

## Implementation Phases

### Phase 1: Multi-Provider LLM API Foundation (Priority: HIGHEST)

**Goal**: Core LLM provider abstraction and multi-provider support

**Status**: **IN PROGRESS**  
**Estimated Time**: 2-3 weeks

**Features**:
- Provider abstraction interface
- OpenAI provider implementation
- Anthropic provider implementation
- Mistral provider implementation
- Provider switching and fallback
- Error handling and retry logic
- Request/response abstraction

**Dependencies**:
- Core Agent: HTTP Client ✅
- Core Agent: WebSocket Support ✅
- Core Agent: API Server ✅

**Location**: `src/grain_court/llm_provider.zig`, `src/grain_court/provider_*.zig`

**Tests**: `tests/139_grain_court_llm_provider_test.zig`

**GrainStyle Requirements**:
- Bounded provider pool (MAX_PROVIDERS: u32 = 10)
- Bounded request queue (MAX_REQUESTS: u32 = 10000)
- Iterative processing (no recursion)
- Explicit data structures
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 2: ZON Format Integration (Priority: HIGHEST)

**Goal**: ZON format encoding/decoding for token-efficient LLM communication

**Status**: **PLANNED** — Waiting for Phase 1  
**Estimated Time**: 2-3 weeks

**Features**:
- ZON encoder (`src/grain_court/zon_format.zig`)
- ZON decoder (`src/grain_court/zon_format.zig`)
- Zig data structure ↔ ZON conversion
- Automatic ZON encoding for LLM input
- Provider-specific output handling (ZON/JSON)
- Integration with LLM provider abstraction

**Dependencies**:
- Phase 1: Multi-Provider LLM API ✅
- Flow Agent: ZON Format Proposal ✅
- Research Agent: ZON Validation Research ✅
- ZON Format repository: `grainstore/github/ZON-Format/ZON` ✅

**Location**: `src/grain_court/zon_format.zig`

**Tests**: `tests/140_grain_court_zon_format_test.zig`

**GrainStyle Requirements**:
- Bounded encoding buffers (MAX_ENCODE_BUFFER: u32 = 1000000)
- Bounded decoding buffers (MAX_DECODE_BUFFER: u32 = 1000000)
- Iterative encoding/decoding (no recursion)
- Explicit data structures
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

**Coordination**:
- Flow Agent: ZON format proposal and integration plan
- Research Agent: Token efficiency validation methodology
- Grainscript Agent: Serialization format coordination (future)

---

### Phase 3: Token Efficiency Optimization (Priority: HIGH)

**Goal**: Token counting, cost tracking, and optimization

**Status**: **PLANNED** — Waiting for Phase 2  
**Estimated Time**: 1-2 weeks

**Features**:
- Token counting utilities
- Cost tracking per provider
- Token efficiency metrics
- Optimization recommendations
- Integration with Research Agent validation

**Dependencies**:
- Phase 2: ZON Format Integration ✅
- Research Agent: Token efficiency validation ✅

**Location**: `src/grain_court/token_efficiency.zig`

**Tests**: `tests/141_grain_court_token_efficiency_test.zig`

**GrainStyle Requirements**:
- Bounded token counts (MAX_TOKENS: u32 = 1000000)
- Bounded cost tracking (MAX_COST_ENTRIES: u32 = 10000)
- Iterative calculations (no recursion)
- Explicit data structures
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 4: Self-Hosted Provider (Cerebras GLM-4.6) (Priority: MEDIUM)

**Goal**: Self-hosted LLM provider for Cerebras GLM-4.6 API

**Status**: **PLANNED** — Future work (when funded)  
**Estimated Time**: 3-4 weeks

**Features**:
- Cerebras GLM-4.6 API integration
- WSE hardware abstraction
- Self-hosted provider implementation
- Cost elimination (no API fees)

**Dependencies**:
- Phase 1: Multi-Provider LLM API ✅
- Phase 2: ZON Format Integration ✅
- Funding for Cerebras hardware access

**Location**: `src/grain_court/provider_self_hosted.zig`

**Tests**: `tests/142_grain_court_self_hosted_test.zig`

**GrainStyle Requirements**:
- Bounded WSE core management (MAX_CORES: u32 = 1000000)
- Bounded SRAM allocation (MAX_SRAM: u64 = 47185920000)
- Iterative processing (no recursion)
- Explicit data structures
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

### Phase 5: WSE Spatial Computing Enhancements (Priority: LOW)

**Goal**: Enhanced WSE-wafer-scale SRAM spatial computing abstraction

**Status**: **PLANNED** — Future work  
**Estimated Time**: 4-6 weeks

**Features**:
- Enhanced compute abstraction (`src/grain_court/compute.zig`)
- Court topology optimization
- Parallel execution improvements
- Performance monitoring

**Dependencies**:
- Phase 4: Self-Hosted Provider ✅
- WSE hardware access

**Location**: `src/grain_court/compute.zig` (enhancements)

**Tests**: `tests/143_grain_court_compute_test.zig`

**GrainStyle Requirements**:
- Bounded core management (MAX_CORES: u32 = 1000000)
- Bounded SRAM allocation (MAX_SRAM: u64 = 47185920000)
- Iterative algorithms (no recursion)
- Explicit data structures
- Minimum 2 assertions per function
- Max 70 lines per function
- Max 100 characters per line

---

## Integration Points

### Providing To

**Aurora Agent**:
- AI provider abstraction integration
- LLM services for code completion and refactoring

**Skate Agent**:
- AI-powered graph insights
- LLM services for knowledge graph analysis

**Flow Agent**:
- ZON format integration coordination
- LLM services for workflow automation

**Research Agent**:
- Token efficiency validation support
- LLM services for research analysis

**All Agents**:
- LLM infrastructure services
- Multi-provider API access

### Using From

**Core Agent**:
- HTTP Client (Phase 61) ✅
- WebSocket Support (Phase 61) ✅
- API Server (Phase 59) ✅
- Authentication Service (Phase 60) ✅

**Flow Agent**:
- ZON format proposal and integration plan

**Research Agent**:
- Token efficiency validation methodology

**ZON Format Repository**:
- ZON format specification and implementation reference

---

## Current Status

**Phase 1: Multi-Provider LLM API Foundation** — IN PROGRESS
- Provider abstraction interface design
- OpenAI provider implementation (in progress)
- Anthropic provider implementation (planned)
- Mistral provider implementation (planned)

**Next Steps**:
1. Complete provider abstraction interface
2. Implement OpenAI provider
3. Implement Anthropic provider
4. Implement Mistral provider
5. Add provider switching and fallback
6. Add comprehensive tests
7. Coordinate with Aurora Agent on integration

---

## Coordination Notes

**Active Coordination**:
- Flow Agent: ZON format integration proposal received
- Research Agent: Token efficiency validation research received
- Aurora Agent: AI provider abstraction integration needs

**Upcoming Coordination**:
- Grainscript Agent: Serialization format coordination (when Grainscript Agent is created)
- All agents: LLM service integration needs

**No Conflicts Detected** — Court Agent can work in parallel with most agents while building LLM infrastructure.

---

**Date**: 2025-12-21  
**Agent**: Grain Court Agent (11th Agent)  
**Status**: Phase 1 IN PROGRESS — Multi-Provider LLM API Foundation
