# ZON Format Integration Proposal: Grain Court + Grainscript

**Date**: 2025-12-20-210116-pst  
**Agent**: Grain Flow Agent (on behalf of Grain Court/Research integration)  
**Status**: Proposal — ZON Format for LLM-Efficient Serialization in Grain OS

---

## Executive Summary

**ZON (Zero Overhead Notation)** is a token-efficient serialization format achieving **35-70% fewer tokens than JSON** for LLM communication while remaining **100% human-readable**. This proposal outlines integrating ZON format support into **Grain Court** (LLM backend infrastructure) with native **Grainscript** integration, enabling cost-effective LLM communication across Grain OS.

**Key Value**: Save ~50% on LLM API costs by using ZON for input data while maintaining JSON compatibility for backend systems.

---

## The Opportunity

### Current State

**Grain OS LLM Integration**:
- **Skate Agent**: Uses GLM-4.6 via HTTP Client for AI-powered graph insights
- **Aurora Agent**: AI provider abstraction with GLM-4.6 support
- **Flow Agent**: JSON export for workflow metrics (Research Agent analysis)
- **Grainscript**: Unified configuration/data format, but JSON serialization only

**Current Serialization**:
- Agents use JSON for data export and LLM communication
- Workflow metrics export JSON (just implemented)
- Grainscript can serialize to JSON
- **Problem**: JSON is token-expensive for LLMs (35-70% more tokens than needed)

### The Problem ZON Solves

**LLM Token Costs**:
- Large context windows = more data = higher costs
- JSON is verbose (quotes, brackets, commas add tokens)
- Metrics, logs, configs sent to LLMs waste tokens

**ZON Solution**:
- **35-70% fewer tokens** than JSON (validated across GPT-4o, Claude 3.5, Llama 3)
- **100% human-readable** (unlike binary formats)
- **99%+ retrieval accuracy** (better than compact JSON)
- **Lossless round-trip** (ZON ↔ JSON conversion)

---

## Integration Architecture

### Layer 1: Grain Court ZON Module

**Location**: `src/grain_court/zon_format.zig`

**Purpose**: Core ZON encoding/decoding for Grain Court LLM infrastructure

**Responsibilities**:
- Encode Zig data structures to ZON format
- Decode ZON format to Zig data structures
- Provider abstraction (external APIs + future self-hosted)
- Token efficiency validation

**Integration Points**:
- Grain Court LLM backend (GLM-4.6 API, future self-hosted)
- Multiple provider support (OpenAI, Anthropic, Mistral, self-hosted)
- Grainscript serialization backend

### Layer 2: Grainscript ZON Integration

**Location**: `src/grainscript/zon_serializer.zig`

**Purpose**: Native ZON serialization for Grainscript AST/data structures

**Responsibilities**:
- Serialize Grainscript AST to ZON
- Deserialize ZON to Grainscript AST
- ZON as native Grainscript format (`.gr` files can export to `.zonf`)
- Bidirectional conversion (Grainscript ↔ ZON ↔ JSON)

**Unified Format Vision**:
- Grainscript already unifies all config/data formats
- ZON becomes the **LLM-optimized export format** for Grainscript
- One source (Grainscript), multiple outputs (JSON for backends, ZON for LLMs)

### Layer 3: Provider Abstraction

**Location**: `src/grain_court/llm_provider.zig` (new, or extend existing)

**Purpose**: Multi-provider LLM API with ZON support

**Provider Support**:
1. **External APIs** (Immediate):
   - OpenAI (GPT-4o, GPT-5-nano)
   - Anthropic (Claude 3.5)
   - Mistral
   - Other LLM APIs

2. **Self-Hosted** (Future, when funded):
   - Cerebras GLM-4.6 API (Grain Court's target)
   - Other self-hosted models

**ZON Integration**:
- Automatically use ZON for input data (save tokens)
- Providers can request JSON or ZON output
- Fallback to JSON if provider doesn't support ZON

---

## ZON Format Overview

### Core Principles

**From ZON Specification**:
1. **Tabular Encoding**: Arrays of objects → table format (declare fields once, stream rows)
2. **Single-Character Primitives**: `T`/`F` for booleans (not `true`/`false`)
3. **Minimal Syntax**: No redundant colons, brackets where possible
4. **Explicit Headers**: `@(N):field1,field2` for arrays (eliminates ambiguity)

### Example: Workflow Metrics in ZON vs JSON

**JSON** (current, verbose):
```json
{
  "total_executions": 1000,
  "success_rate_percent": 95,
  "avg_execution_time_ms": 450,
  "executions": [
    {"workflow_id": 1, "name": "backup", "execution_time_ms": 500, "status": "success"},
    {"workflow_id": 2, "name": "sync", "execution_time_ms": 400, "status": "success"}
  ]
}
```
**Tokens**: ~150 (GPT-4o)

**ZON** (efficient):
```
total_executions:1000
success_rate_percent:95
avg_execution_time_ms:450
executions:@(2):workflow_id,name,execution_time_ms,status
1,backup,500,success
2,sync,400,success
```
**Tokens**: ~75 (GPT-4o) — **50% reduction**

---

## Implementation Plan

### Phase 1: Core ZON Encoder/Decoder (Grain Court)

**Module**: `src/grain_court/zon_format.zig`

**Features**:
- ZON encoding (Zig data → ZON string)
- ZON decoding (ZON string → Zig data)
- Tabular array encoding
- Nested object encoding
- Type-safe conversion (u32/u64, bool → T/F, null handling)

**Grain Style Compliance**:
- `grain_case` function names
- `u32`/`u64` explicit types
- Bounded allocations (`MAX_ZON_SIZE`, `MAX_TABLE_ROWS`)
- Max 70 lines per function
- Max 100 characters per line
- Minimum 2 assertions per function

**Data Types Supported**:
- Primitive: `u32`, `u64`, `i32`, `i64`, `f32`, `f64`, `bool`, `null`
- Strings: UTF-8 with escape sequences
- Arrays: Tabular encoding for uniform arrays
- Objects: Nested object encoding
- Mixed structures: Intelligent format selection

### Phase 2: Grainscript ZON Serializer

**Module**: `src/grainscript/zon_serializer.zig`

**Features**:
- Grainscript AST → ZON conversion
- ZON → Grainscript AST conversion
- Grainscript `.gr` files → `.zonf` export
- Bidirectional Grainscript ↔ ZON ↔ JSON

**Integration**:
- Extend `grainscript/parser.zig` to accept ZON input
- Extend `grainscript/interpreter.zig` to serialize to ZON
- Add ZON as native Grainscript export format

### Phase 3: Multi-Provider LLM API with ZON

**Module**: `src/grain_court/llm_provider.zig` (or extend existing)

**Features**:
- Provider abstraction (OpenAI, Anthropic, Mistral, self-hosted)
- Automatic ZON encoding for input data
- Provider-specific output format handling
- Token counting and cost estimation
- Fallback to JSON if needed

**Provider Interface**:
```zig
pub const LLMProvider = struct {
    provider_type: ProviderType,
    api_key: []const u8, // For external APIs
    use_zon: bool, // Use ZON for input
    
    pub fn send_request(
        self: *LLMProvider,
        prompt: []const u8,
        data: anytype, // Grainscript AST or Zig struct
        use_zon: bool,
    ) !LLMResponse;
};
```

### Phase 4: Integration with Existing Agents

**Flow Agent Integration**:
- Replace JSON export with ZON export (or offer both)
- Workflow metrics → ZON format for Research Agent
- 50% token savings on metric analysis

**Skate Agent Integration**:
- AI-powered graph insights use ZON for input data
- Graph data → ZON → LLM (save tokens)

**Aurora Agent Integration**:
- AI provider abstraction uses ZON
- Code context → ZON → LLM (save tokens)

---

## Grainscript Integration Details

### Why Grainscript + ZON is Perfect

**Grainscript's Vision**:
> "Unify all configuration and data file formats into a single, statically-typed, explicitly-allocated DSL"

**ZON's Role**:
- **LLM-Optimized Export**: Grainscript data → ZON format → LLM
- **Native Format Option**: ZON as first-class Grainscript serialization
- **Backward Compatible**: Grainscript still exports to JSON for non-LLM use

### Example: Grainscript Config → ZON → LLM

**Grainscript File** (`.gr`):
```
config {
  database {
    host: "localhost"
    port: 5432
  }
  features {
    darkMode: true
  }
}
users: [
  {id: 1, name: "Alice", active: true},
  {id: 2, name: "Bob", active: false}
]
```

**ZON Export** (`.zonf`):
```
config.database{host:localhost,port:5432}
config.features{darkMode:T}
users:@(2):active,id,name
T,1,Alice
F,2,Bob
```

**Token Savings**: ~50% vs JSON export

### Grainscript ZON API

```zig
// Serialize Grainscript AST to ZON
pub fn serialize_to_zon(
    ast: *const grainscript.AST,
    output: []u8,
) u32;

// Deserialize ZON to Grainscript AST
pub fn deserialize_from_zon(
    zon_str: []const u8,
    allocator: std.mem.Allocator,
) !grainscript.AST;

// Convert Grainscript to ZON (file conversion)
pub fn grainscript_to_zon(
    gr_file: []const u8,
    output: []u8,
) u32;
```

---

## Multi-Provider Architecture

### Provider Abstraction

**Interface**:
```zig
pub const LLMProviderType = enum(u8) {
    openai = 0,
    anthropic = 1,
    mistral = 2,
    self_hosted_glm46 = 3,
    custom = 4,
};

pub const LLMProvider = struct {
    provider_type: LLMProviderType,
    base_url: []const u8,
    api_key: []const u8,
    use_zon_input: bool, // Use ZON for input data
    use_zon_output: bool, // Accept ZON output format
    
    pub fn send_request(
        self: *LLMProvider,
        prompt: []const u8,
        context_data: anytype, // Grainscript or Zig data
        options: RequestOptions,
    ) !LLMResponse;
};
```

### Provider-Specific Implementation

**OpenAI**:
- Supports JSON input/output
- Use ZON for input (automatic conversion)
- Request JSON output (convert ZON to JSON if needed)

**Anthropic (Claude)**:
- Supports JSON input/output
- Use ZON for input (automatic conversion)
- Request JSON output

**Self-Hosted (Future)**:
- Full ZON support (native)
- No conversion overhead
- Maximum token efficiency

### Cost Savings Estimation

**Assumptions**:
- LLM API: $0.01 per 1K tokens (input), $0.03 per 1K tokens (output)
- Average workflow metrics export: 1000 tokens (JSON)
- Monthly metric analysis: 1000 requests

**Current (JSON)**:
- Input: 1000 tokens × $0.01/1K = $0.01 per request
- Monthly: $0.01 × 1000 = $10/month

**With ZON (50% reduction)**:
- Input: 500 tokens × $0.01/1K = $0.005 per request
- Monthly: $0.005 × 1000 = $5/month
- **Savings: $5/month per use case**

**Scale Impact**:
- 10 use cases: $50/month savings
- 100 use cases: $500/month savings
- 1000 use cases: $5000/month savings

---

## Implementation Phases

### Phase 1: Core ZON Module (Grain Court)

**Timeline**: 1-2 weeks  
**Priority**: HIGH (enables all other work)

**Tasks**:
- [ ] Create `src/grain_court/zon_format.zig`
- [ ] Implement ZON encoder (Zig data → ZON string)
- [ ] Implement ZON decoder (ZON string → Zig data)
- [ ] Tabular array encoding
- [ ] Nested object encoding
- [ ] Type conversion (bool → T/F, null handling)
- [ ] Comprehensive tests
- [ ] Update `build.zig`
- [ ] Update `src/grain_court/root.zig`

**Grain Style Requirements**:
- Bounded allocations: `MAX_ZON_SIZE: u32 = 10MB`, `MAX_TABLE_ROWS: u32 = 100000`
- Explicit types: `u32`/`u64` (no `usize`/`isize`)
- Max 70 lines per function
- Max 100 characters per line
- Minimum 2 assertions per function
- No recursion (iterative algorithms)

### Phase 2: Grainscript ZON Serializer

**Timeline**: 1-2 weeks  
**Priority**: HIGH (unified format vision)

**Tasks**:
- [ ] Create `src/grainscript/zon_serializer.zig`
- [ ] Implement Grainscript AST → ZON
- [ ] Implement ZON → Grainscript AST
- [ ] File conversion (`.gr` → `.zonf`)
- [ ] Bidirectional conversion tests
- [ ] Update `build.zig`
- [ ] Update `src/grainscript/root.zig`

### Phase 3: Multi-Provider LLM API

**Timeline**: 2-3 weeks  
**Priority**: MEDIUM (enables production use)

**Tasks**:
- [ ] Create/extend `src/grain_court/llm_provider.zig`
- [ ] Provider abstraction interface
- [ ] OpenAI provider implementation
- [ ] Anthropic provider implementation
- [ ] Mistral provider implementation
- [ ] ZON input/output handling
- [ ] Token counting and cost estimation
- [ ] Comprehensive tests
- [ ] Update `build.zig`

### Phase 4: Agent Integration

**Timeline**: 1-2 weeks  
**Priority**: MEDIUM (immediate value)

**Tasks**:
- [ ] Flow Agent: Add ZON export option to metrics
- [ ] Skate Agent: Use ZON for AI graph insights
- [ ] Aurora Agent: Use ZON for AI provider
- [ ] Integration tests
- [ ] Documentation

---

## Grain Style Compliance

### Code Structure

**Module Organization**:
```
src/grain_court/
├── compute.zig          # Existing (WSE compute)
├── zon_format.zig       # NEW: ZON encoder/decoder
├── llm_provider.zig     # NEW: Multi-provider LLM API
└── root.zig             # Updated exports

src/grainscript/
├── lexer.zig            # Existing
├── parser.zig           # Existing
├── interpreter.zig      # Existing
├── zon_serializer.zig   # NEW: Grainscript ↔ ZON
└── root.zig             # Updated exports
```

### Grain Style Requirements

**All ZON modules MUST**:
1. Use `grain_case` function names
2. Use explicit `u32`/`u64` types (no `usize`/`isize`)
3. Bounded allocations (`MAX_ZON_SIZE`, `MAX_TABLE_ROWS`, etc.)
4. Maximum 70 lines per function
5. Maximum 100 characters per line
6. Minimum 2 assertions per function
7. No recursion (iterative algorithms only)
8. All compiler warnings enabled

### Example Function Signature

```zig
// Encode Zig value to ZON format (bounded buffer).
pub fn encode_to_zon(
    value: anytype,
    output: []u8,
) u32 {
    std.debug.assert(output.len > 0);
    std.debug.assert(@typeInfo(@TypeOf(value)) != .Void);
    // ... implementation ...
    return offset;
}
```

---

## Value Proposition

### For Grain OS

**Cost Savings**:
- 35-70% reduction in LLM token costs
- Scales with LLM usage (more data = more savings)
- Self-hosted option (future) eliminates API costs entirely

**Performance**:
- Faster LLM processing (fewer tokens = faster responses)
- Lower latency (smaller payloads)

**Architecture**:
- Unified serialization (Grainscript → ZON → LLM)
- Multiple provider support (flexibility)
- Future-proof (self-hosted path)

### For Grainscript

**Native LLM Format**:
- ZON as first-class Grainscript export format
- Unifies data formats for LLM communication
- Maintains JSON compatibility for non-LLM use

**Unified Vision**:
- Grainscript unifies config/data formats
- ZON unifies LLM communication format
- Perfect synergy

### For Grain Court

**LLM Infrastructure**:
- Efficient data format for LLM backend
- Multi-provider abstraction
- Path to self-hosted (Cerebras GLM-4.6)

**Differentiation**:
- Most efficient LLM communication format
- Cost-effective infrastructure
- Production-ready multi-provider support

---

## Technical Specifications

### ZON Encoding Strategy

**Tabular Arrays** (best for arrays of objects):
```
users:@(2):id,name,active
1,Alice,T
2,Bob,F
```

**Nested Objects** (best for configuration):
```
config.database{host:localhost,port:5432}
```

**Mixed Structures**:
- Intelligent format selection
- Tabular for uniform arrays
- Nested for complex objects
- Hybrid for mixed data

### Grainscript Integration Points

**AST → ZON**:
- Convert Grainscript AST nodes to ZON format
- Preserve type information
- Handle nested structures

**ZON → AST**:
- Parse ZON format
- Build Grainscript AST
- Type inference and validation

### Provider Integration

**Request Flow**:
1. Agent prepares data (Grainscript or Zig struct)
2. Convert to ZON format (if provider supports)
3. Send to LLM provider API
4. Receive response (JSON or ZON)
5. Convert to native format

**Fallback**:
- If provider doesn't support ZON: use JSON
- Automatic detection and conversion

---

## Success Criteria

### Observable

✅ We can encode Zig data structures to ZON format  
✅ We can decode ZON format to Zig data structures  
✅ Grainscript can export to ZON format  
✅ LLM providers accept ZON input  
✅ Token counts are 35-70% lower than JSON

### Testable

✅ Round-trip tests (Zig → ZON → Zig, lossless)  
✅ Grainscript → ZON → Grainscript (lossless)  
✅ Token count validation (vs JSON baseline)  
✅ Provider integration tests  
✅ Integration with Flow Agent metrics export

### Measurable

✅ Token reduction: 35-70% vs JSON (measured across GPT-4o, Claude 3.5, Llama 3)  
✅ Cost savings: $X/month per use case  
✅ Encoding performance: < 10ms for 10KB data  
✅ Decoding performance: < 10ms for 10KB data

---

## Dependencies

**Required**:
- ✅ Grain Court module (`src/grain_court/`)
- ✅ Grainscript module (`src/grainscript/`)
- ✅ Core Agent HTTP Client (for external API providers)

**Optional**:
- Research Agent (for token efficiency validation)
- Flow Agent (for integration testing with metrics export)
- Skate Agent (for integration testing with AI insights)

---

## Coordination Requirements

### With Grain Court Agent

**Discussion Points**:
1. ZON module location (`src/grain_court/zon_format.zig`?)
2. LLM provider abstraction design
3. Self-hosted provider interface (future)
4. Integration with existing Court compute infrastructure

### With Grainscript/Terminal Agent

**Discussion Points**:
1. ZON serializer location (`src/grainscript/zon_serializer.zig`?)
2. Grainscript AST → ZON mapping
3. File format integration (`.gr` → `.zonf`)
4. Backward compatibility (JSON export still available)

### With Research Agent

**Discussion Points**:
1. Token efficiency validation methodology
2. Benchmark comparison (ZON vs JSON vs TOON)
3. Retrieval accuracy testing
4. Cost savings estimation

### With Flow Agent

**Discussion Points**:
1. Metrics export ZON integration
2. Workflow Observatory ZON support
3. Test integration scenarios

---

## Risks and Mitigations

### Risk 1: ZON Format Evolution

**Risk**: ZON format spec may change  
**Mitigation**: Version detection, migration support, fallback to JSON

### Risk 2: Provider Compatibility

**Risk**: Some LLM providers may not handle ZON well  
**Mitigation**: Automatic fallback to JSON, provider-specific handling

### Risk 3: Implementation Complexity

**Risk**: ZON encoding/decoding may be complex  
**Mitigation**: Start with core features, iterative development, comprehensive tests

---

## Next Steps

### Immediate

1. **Research & Design** (Research Agent):
   - Validate ZON format specification
   - Design Grain Style Zig implementation
   - Create detailed technical specification

2. **Coordination** (Flow Agent):
   - Discuss with Court Agent on module ownership
   - Discuss with Grainscript Agent on serializer integration
   - Coordinate with Research Agent on validation

### Short-term

3. **Implementation** (Court Agent or designated agent):
   - Phase 1: Core ZON module
   - Phase 2: Grainscript ZON serializer
   - Phase 3: Multi-provider LLM API

4. **Integration** (All agents):
   - Flow Agent: Metrics ZON export
   - Skate Agent: AI insights ZON input
   - Aurora Agent: AI provider ZON support

---

## References

- **ZON Format**: https://zonformat.org/
- **ZON GitHub**: https://github.com/ZON-Format/ZON
- **ZON Specification**: (See ZON documentation for full spec)
- **Grain Court**: `src/grain_court/compute.zig`
- **Grainscript**: `src/grainscript/`
- **Flow Agent Metrics**: `src/grain_flow/workflow_metrics.zig` (JSON export)

---

**Date**: 2025-12-20-210116-pst  
**Agent**: Grain Flow Agent  
**Status**: Proposal — Ready for Review and Coordination

This proposal outlines a comprehensive plan for integrating ZON format into Grain OS, enabling cost-effective LLM communication while maintaining Grainscript's unified format vision.
