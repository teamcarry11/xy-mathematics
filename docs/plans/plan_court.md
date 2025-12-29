# Grain Court Agent: Development Plan

**Agent**: Grain Court Agent (11th Agent)  
**Status**: Phase 1 COMPLETE ✅ — Phase 2 COMPLETE ✅ — Phase 3 IN PROGRESS — Phase 4 FOUNDATION STARTED  
**Last Updated**: 2025-12-29-110000-pst  
**Coordination Plans**: 
- `docs/agent-communications/core_agent_coordination_plan_2025-12-29-041147-pst.md` (ZON Format Integration Complete ✅)
- `docs/agent-communications/core_agent_coordination_plan_2025-12-29-105655-pst.md` (Kernel Refactoring Complete ✅, JG Project Design Complete ✅)

---

## Overview

Grain Court Agent is responsible for building the scalable fast agentic compute infrastructure—the LLM backend that powers AI features across Grain OS. Court Agent provides multi-provider LLM API abstraction, ZON format integration for token-efficient communication, and future WSE-wafer-scale SRAM spatial computing support.

**Key Goals**:
- Multi-provider LLM API abstraction (OpenAI, Anthropic, Mistral, self-hosted Cerebras GLM-4.6)
- ZON format integration for 35-70% token reduction ✅
- Token efficiency optimization and cost tracking ⏳
- Provider abstraction layer for seamless switching ✅
- Payment Integration Phase 1 (Grain Passwords) ⏳
- JG Project LLM Planning (Months 4-12) 🆕
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

**Status**: **COMPLETE** ✅ (2025-12-21-150000-pst)  
**Estimated Time**: 2-3 weeks  
**Actual Time**: Started 2025-12-21, Completed 2025-12-21

**Features**:
- ✅ Provider abstraction interface (`src/grain_court/llm_provider.zig`)
- ✅ OpenAI provider implementation (`src/grain_court/provider_openai.zig`)
- ✅ Anthropic provider implementation (`src/grain_court/provider_anthropic.zig`)
- ✅ Mistral provider implementation (`src/grain_court/provider_mistral.zig`)
- ✅ Provider switching and fallback (`send_request_with_fallback`)
- ✅ Error handling (LlmProviderError enum, consistent error types)
- ⏳ Retry logic (deferred to Phase 2)
- ✅ Request/response abstraction (LlmRequest, LlmResponse)

**Dependencies**:
- Core Agent: HTTP Client ✅
- Core Agent: WebSocket Support ✅ (not yet used)
- Core Agent: API Server ✅ (not yet used)

**Location**: `src/grain_court/llm_provider.zig`, `src/grain_court/provider_*.zig`

**Tests**: `tests/049_grain_court_test.zig` (15 tests covering all providers and pool operations)

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

**Status**: **COMPLETE** ✅ (2025-12-29-003500-pst)  
**Estimated Time**: 2-3 weeks  
**Actual Time**: Started 2025-12-21, Completed 2025-12-29

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

**Status**: **IN PROGRESS** ⏳ — Optimization utilities complete, Research Agent validation testing in progress  
**Estimated Time**: 1-2 weeks  
**Started**: 2025-12-28

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

**Phase 1: Multi-Provider LLM API Foundation** — ~95% COMPLETE ✅
- ✅ Provider abstraction interface complete
- ✅ OpenAI provider implementation complete
- ✅ Anthropic provider implementation complete
- ✅ Mistral provider implementation complete
- ✅ Provider switching and fallback complete
- ✅ Comprehensive tests added (15 tests)
- ✅ Error handling complete
- ⏳ Integration tests pending (requires network stack setup)
- ⏳ Retry logic deferred to Phase 2

**Next Steps**:
1. **IMMEDIATE**: Complete Phase 1 documentation
2. **SHORT-TERM**: Coordinate with Flow Agent on ZON format integration (Phase 2)
3. **SHORT-TERM**: Coordinate with Research Agent on token efficiency (Phase 3)
4. **MEDIUM-TERM**: Integration testing with HTTP client when network stack is ready

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

---

## Payment Integration: Grain Passwords (Phase 1)

**Status**: ⏳ **COORDINATION IN PROGRESS** — Waiting on dependencies

**Priority**: HIGH  
**Estimated Time**: 2-3 days (once dependencies available)

**Goal**: Secure encryption and secret management for LLM API keys

**Features**:
- API key encryption using Grain Passwords module
- Secure storage using Silo Agent's PasswordStorage helper API
- Key rotation support
- Environment separation (dev, staging, prod)
- Security Manager integration for access control

**Dependencies**:
- ⏳ Core Agent: Grain Passwords module implementation (2-3 days)
- ⏳ Silo Agent: PasswordStorage helper API design (1-2 days expected)

**Design Documents**:
- `docs/zyx/grain_payment_vault_design_2025-12-28-213448-pst.md`
- `docs/grain_database/payment_vault_storage_schema.md` (Silo Agent, COMPLETE ✅)

**Location**: `src/grain_court/api_key_manager.zig` (to be created)

**Tests**: `tests/050_grain_court_api_key_manager_test.zig` (to be created)

---

## JG Project: LLM Planning Responsibilities

**Status**: 🆕 **PLANNING PHASE** (Months 4-12)

**Priority**: MEDIUM (Months 4-12 timeline)  
**Design Document**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`

**Goal**: Provide LLM planning services for JG project design optimization, supply chain optimization, and policy analysis

### Phase 1: Design Optimization (Months 4-6)

**Features**:
- LLM-assisted design optimization suggestions
- Material quantity takeoff assistance
- Energy efficiency analysis recommendations
- Traditional urbanism design guidance

**Integration Points**:
- `grain_jg_architect` module (Core Agent)
- Workspace Agent desktop dashboards
- Court Agent multi-provider LLM API
- ZON format for efficient data transfer

**Location**: `src/grain_court/jg_design_optimization.zig` (to be created)

**Tests**: `tests/051_grain_court_jg_design_optimization_test.zig` (to be created)

### Phase 2: Supply Chain Optimization (Months 7-9)

**Features**:
- Supply chain route optimization
- Transportation scheduling recommendations
- Processing facility capacity optimization
- Carbon footprint calculation assistance

**Integration Points**:
- `grain_jg_supply_chain` module (Core Agent)
- Flow Agent workflow orchestration
- Court Agent cost tracking for supply chain analysis
- Provider recommendation for cost-optimized LLM selection

**Location**: `src/grain_court/jg_supply_chain_optimization.zig` (to be created)

**Tests**: `tests/052_grain_court_jg_supply_chain_optimization_test.zig` (to be created)

### Phase 3: Policy Analysis (Months 10-12)

**Features**:
- Inflation analysis and recommendations
- Policy analysis and recommendations
- Regional wage adjustment analysis
- Benefits administration optimization

**Integration Points**:
- `grainbank` MMT integration (Core Agent)
- Research Agent analysis and optimization
- Court Agent token efficiency tools for cost-effective analysis
- Cost reporting for policy impact analysis

**Location**: `src/grain_court/jg_policy_analysis.zig` (to be created)

**Tests**: `tests/053_grain_court_jg_policy_analysis_test.zig` (to be created)

**Coordination Required**:
- Core Agent: API contracts for JG modules
- Workspace Agent: Desktop dashboard integration (Months 4-6)
- Flow Agent: Workflow orchestration integration (Months 7-9)
- Research Agent: Analysis collaboration (Months 10-12)

---

**Date**: 2025-12-29-110000-pst  
**Agent**: Grain Court Agent (11th Agent)  
**Status**: Phase 1 COMPLETE ✅ — Phase 2 COMPLETE ✅ — Phase 3 IN PROGRESS — Phase 4 FOUNDATION STARTED — Payment Integration Phase 1 Coordination In Progress — JG Project LLM Planning Responsibilities Assigned (Months 4-12)
