# JG Project LLM Integration Planning

**Date**: 2025-12-29-153000-pst  
**Agent**: Grain Court Agent (11th Agent)  
**Status**: Planning Phase (Months 1-3 of JG Project Timeline)  
**Design Document**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`

---

## Overview

This document outlines the preliminary planning for Court Agent's LLM integration responsibilities in the JG Project. Court Agent will provide LLM-assisted planning services across three phases: Design Optimization (Months 4-6), Supply Chain Optimization (Months 7-9), and Policy Analysis (Months 10-12).

---

## Phase 1: Design Optimization (Months 4-6)

### LLM Use Cases

**1. Design Optimization Suggestions**
- Analyze architectural designs for traditional urbanism principles
- Suggest improvements for walkability, human scale, mixed-use
- Recommend design adjustments for energy efficiency
- Provide design alternatives based on material availability

**2. Material Quantity Takeoff Assistance**
- Calculate material requirements from architectural designs
- Estimate quantities for hemp, bamboo, timber, rammed earth, stone, clay
- Provide material cost estimates
- Suggest material substitutions based on regional availability

**3. Energy Efficiency Analysis Recommendations**
- Analyze passive thermal mass design
- Calculate energy efficiency scores
- Recommend improvements for heating/cooling efficiency
- Suggest renewable energy integration opportunities

**4. Traditional Urbanism Design Guidance**
- Provide guidance on walled town design principles
- Suggest canal and water feature placement
- Recommend public space and green space allocation
- Guide mixed-use building placement and density

### Integration Points

**Core Agent Modules**:
- `grain_jg_architect` — Architectural design data structures
- `ArchitecturalDesign` struct — Design information
- `MaterialRequirement` struct — Material quantities
- `SiteLayout` struct — Site planning data

**Workspace Agent**:
- Desktop dashboard integration for design suggestions
- 3D visualization integration for design alternatives
- Real-time design optimization feedback

**Court Agent APIs**:
- Multi-provider LLM API for design analysis
- ZON format for efficient data transfer (35-70% token reduction)
- Token efficiency tools for cost-effective analysis
- Cost tracking for design optimization cost analysis

### API Contract Design (Preliminary)

**Note**: These API contracts will be finalized in coordination with Core Agent when `grain_jg_architect` module is implemented.

```zig
// Bounded: Max design suggestions per optimization.
pub const MAX_DESIGN_SUGGESTIONS: u32 = 20;

// Bounded: Max material types.
pub const MAX_MATERIAL_TYPES: u32 = 20;

// Design optimization request.
pub const DesignOptimizationRequest = struct {
    design: *const ArchitecturalDesign, // From grain_jg_architect
    site_layout: *const SiteLayout, // From grain_jg_architect
    regional_material_availability: []const MaterialAvailability,
    optimization_goals: OptimizationGoals,
    timeout_ms: ?u32, // Default: 60000 (60 seconds)
};

// Optimization goals.
pub const OptimizationGoals = struct {
    minimize_cost: bool,
    maximize_energy_efficiency: bool,
    maximize_traditional_urbanism: bool,
    maximize_walkability: bool,
    use_regional_materials: bool,
};

// Design optimization result.
pub const DesignOptimizationResult = struct {
    suggestions: [MAX_DESIGN_SUGGESTIONS]DesignSuggestion,
    suggestions_len: u32,
    material_quantity_takeoff: MaterialQuantityTakeoff,
    energy_efficiency_analysis: EnergyEfficiencyAnalysis,
    traditional_urbanism_score: u8, // 0-100
    walkability_score: u8, // 0-100
    estimated_cost_savings: f64,
    estimated_total_cost: u64,
};

// Design suggestion.
pub const DesignSuggestion = struct {
    suggestion_type: DesignSuggestionType,
    description: [256]u8,
    description_len: u32,
    priority: SuggestionPriority,
    estimated_impact: f64, // Cost savings or efficiency gain
};

// Design suggestion type.
pub const DesignSuggestionType = enum(u8) {
    material_substitution,
    layout_improvement,
    energy_efficiency,
    traditional_urbanism,
    walkability,
    cost_optimization,
};

// Material quantity takeoff.
pub const MaterialQuantityTakeoff = struct {
    material_requirements: [MAX_MATERIAL_TYPES]MaterialRequirement,
    material_requirements_len: u32,
    total_estimated_cost: u64,
    regional_availability: [MAX_MATERIAL_TYPES]bool,
    alternative_materials: [MAX_MATERIAL_TYPES]MaterialAlternative,
    alternative_materials_len: u32,
};

// Energy efficiency analysis.
pub const EnergyEfficiencyAnalysis = struct {
    passive_thermal_mass_score: u8, // 0-100
    heating_efficiency_score: u8, // 0-100
    cooling_efficiency_score: u8, // 0-100
    renewable_energy_potential: u8, // 0-100
    recommendations: [MAX_DESIGN_SUGGESTIONS]DesignSuggestion,
    recommendations_len: u32,
};
```

**LLM Integration Function**:
```zig
// Optimize architectural design using LLM.
pub fn optimize_design(
    request: *const DesignOptimizationRequest,
    allocator: std.mem.Allocator,
    provider_pool: *ProviderPool,
) !DesignOptimizationResult {
    // 1. Encode design data to ZON format (35-70% token reduction)
    // 2. Send LLM request with design optimization prompt
    // 3. Parse LLM response (ZON or JSON)
    // 4. Convert to DesignOptimizationResult
    // 5. Track cost using CostTracker
}
```

---

## Phase 2: Supply Chain Optimization (Months 7-9)

### LLM Use Cases

**1. Supply Chain Route Optimization**
- Optimize transportation routes for material delivery
- Minimize transportation costs and carbon footprint
- Consider regional processing facility locations
- Account for material cultivation site locations

**2. Transportation Scheduling Recommendations**
- Schedule material transport to minimize delays
- Coordinate multiple material types and sources
- Optimize for construction phase timing
- Account for seasonal material availability

**3. Processing Facility Capacity Optimization**
- Analyze processing facility capacity utilization
- Recommend capacity expansion or new facility locations
- Optimize material processing workflows
- Suggest processing facility improvements

**4. Carbon Footprint Calculation Assistance**
- Calculate carbon footprint for supply chain routes
- Compare carbon impact of different material sources
- Recommend low-carbon transportation options
- Track carbon sequestration from renewable materials

### Integration Points

**Core Agent Modules**:
- `grain_jg_supply_chain` — Supply chain data structures
- `TransportationRoute` struct — Route information
- `ProcessingFacility` struct — Facility capacity data
- `MaterialTransport` struct — Transport scheduling

**Flow Agent**:
- Workflow orchestration for transportation workflows
- Material delivery workflow coordination
- Processing facility workflow integration
- Carbon tracking workflow integration

**Court Agent APIs**:
- Cost tracking for supply chain cost analysis
- Provider recommendation for cost-optimized LLM selection
- Token efficiency tools for efficient analysis
- Multi-provider LLM API for route optimization

### API Contract Design (Preliminary)

**Note**: These API contracts will be finalized in coordination with Core Agent when `grain_jg_supply_chain` module is implemented.

```zig
// Bounded: Max routes per optimization.
pub const MAX_ROUTES: u32 = 100;

// Bounded: Max facilities.
pub const MAX_FACILITIES: u32 = 50;

// Supply chain optimization request.
pub const SupplyChainOptimizationRequest = struct {
    material_requirements: []const MaterialRequirement, // From grain_jg_inventory
    cultivation_sites: []const CultivationSite,
    processing_facilities: []const ProcessingFacility, // From grain_jg_supply_chain
    construction_sites: []const ConstructionSite,
    optimization_goals: SupplyChainOptimizationGoals,
    timeout_ms: ?u32, // Default: 60000 (60 seconds)
};

// Supply chain optimization goals.
pub const SupplyChainOptimizationGoals = struct {
    minimize_cost: bool,
    minimize_carbon_footprint: bool,
    minimize_transport_time: bool,
    maximize_facility_utilization: bool,
    prioritize_regional_sources: bool,
};

// Supply chain optimization result.
pub const SupplyChainOptimizationResult = struct {
    optimized_routes: [MAX_ROUTES]SupplyChainRoute, // From grain_jg_supply_chain
    optimized_routes_len: u32,
    transportation_schedule: TransportationSchedule,
    facility_capacity_recommendations: [MAX_FACILITIES]FacilityRecommendation,
    facility_capacity_recommendations_len: u32,
    carbon_footprint_analysis: CarbonFootprintAnalysis,
    estimated_cost_savings: f64,
    estimated_total_cost: u64,
};

// Transportation schedule.
pub const TransportationSchedule = struct {
    scheduled_transports: [MAX_ROUTES]ScheduledTransport,
    scheduled_transports_len: u32,
    total_transport_time_hours: u32,
    total_carbon_footprint_kg: u64,
};

// Facility recommendation.
pub const FacilityRecommendation = struct {
    facility_id: u32,
    recommendation_type: FacilityRecommendationType,
    current_utilization: u64,
    recommended_capacity: u64,
    estimated_cost: u64,
    priority: RecommendationPriority,
};

// Carbon footprint analysis.
pub const CarbonFootprintAnalysis = struct {
    total_carbon_footprint_kg: u64,
    carbon_per_route: [MAX_ROUTES]u64,
    carbon_per_route_len: u32,
    low_carbon_alternatives: [MAX_ROUTES]LowCarbonAlternative,
    low_carbon_alternatives_len: u32,
    estimated_carbon_savings_kg: u64,
};
```

**LLM Integration Function**:
```zig
// Optimize supply chain routes using LLM.
pub fn optimize_supply_chain(
    request: *const SupplyChainOptimizationRequest,
    allocator: std.mem.Allocator,
    provider_pool: *ProviderPool,
) !SupplyChainOptimizationResult {
    // 1. Encode supply chain data to ZON format
    // 2. Send LLM request with route optimization prompt
    // 3. Parse LLM response (ZON or JSON)
    // 4. Convert to SupplyChainOptimizationResult
    // 5. Track cost using CostTracker
}
```

---

## Phase 3: Policy Analysis (Months 10-12)

### LLM Use Cases

**1. Inflation Analysis and Recommendations**
- Analyze inflation impact on material costs
- Recommend wage adjustments based on inflation
- Track inflation trends in construction materials
- Suggest policy responses to inflation

**2. Policy Analysis and Recommendations**
- Analyze JG program policy effectiveness
- Recommend policy adjustments for program improvement
- Compare policy alternatives
- Provide policy impact analysis

**3. Regional Wage Adjustment Analysis**
- Analyze regional cost-of-living differences
- Recommend regional wage adjustments
- Track wage adjustment effectiveness
- Suggest wage adjustment policy improvements

**4. Benefits Administration Optimization**
- Analyze benefits administration efficiency
- Recommend benefits policy improvements
- Optimize benefits cost allocation
- Suggest benefits administration workflow improvements

### Integration Points

**Core Agent Modules**:
- `grainbank` MMT integration — Wage and payment data
- `WorkerAccount` struct — Worker wage information
- `RegionalWageAdjustment` struct — Regional wage data
- `BenefitsAdministration` struct — Benefits data

**Research Agent**:
- Economic analysis collaboration
- Policy impact analysis support
- Data analysis and optimization
- Research methodology support

**Court Agent APIs**:
- Token efficiency tools for cost-effective policy analysis
- Cost reporting for policy impact analysis
- Multi-provider LLM API for policy analysis
- Provider recommendation for analysis cost optimization

### API Contract Design (Preliminary)

**Note**: These API contracts will be finalized in coordination with Core Agent when `grainbank` MMT integration is implemented.

```zig
// Bounded: Max policy recommendations.
pub const MAX_POLICY_RECOMMENDATIONS: u32 = 50;

// Policy analysis request.
pub const PolicyAnalysisRequest = struct {
    policy_type: PolicyType,
    analysis_period: TimePeriod,
    regional_wage_data: []const RegionalWageData, // From grainbank
    worker_account_data: []const WorkerAccountSummary, // From grainbank
    material_cost_data: []const MaterialCostData,
    policy_alternatives: []const PolicyAlternative,
    timeout_ms: ?u32, // Default: 60000 (60 seconds)
};

// Policy type.
pub const PolicyType = enum(u8) {
    inflation_analysis,
    wage_adjustment,
    benefits_administration,
    material_cost_policy,
    regional_policy,
    program_effectiveness,
};

// Policy analysis result.
pub const PolicyAnalysisResult = struct {
    inflation_analysis: InflationAnalysis,
    policy_recommendations: [MAX_POLICY_RECOMMENDATIONS]PolicyRecommendation,
    policy_recommendations_len: u32,
    regional_wage_adjustment_analysis: RegionalWageAdjustmentAnalysis,
    benefits_administration_recommendations: [MAX_POLICY_RECOMMENDATIONS]BenefitsRecommendation,
    benefits_administration_recommendations_len: u32,
    estimated_policy_impact: PolicyImpact,
    estimated_cost_impact: f64,
};

// Inflation analysis.
pub const InflationAnalysis = struct {
    current_inflation_rate: f64,
    material_cost_inflation: f64,
    wage_inflation: f64,
    projected_inflation_rate: f64,
    recommendations: [MAX_POLICY_RECOMMENDATIONS]PolicyRecommendation,
    recommendations_len: u32,
};

// Regional wage adjustment analysis.
pub const RegionalWageAdjustmentAnalysis = struct {
    regional_adjustments: [MAX_REGIONS]RegionalWageAdjustment,
    regional_adjustments_len: u32,
    cost_of_living_analysis: [MAX_REGIONS]CostOfLivingAnalysis,
    cost_of_living_analysis_len: u32,
    recommended_adjustments: [MAX_REGIONS]RecommendedWageAdjustment,
    recommended_adjustments_len: u32,
};

// Benefits administration recommendation.
pub const BenefitsRecommendation = struct {
    benefit_type: BenefitType,
    recommendation: [256]u8,
    recommendation_len: u32,
    estimated_cost_impact: f64,
    priority: RecommendationPriority,
};
```

**LLM Integration Function**:
```zig
// Analyze policy using LLM.
pub fn analyze_policy(
    request: *const PolicyAnalysisRequest,
    allocator: std.mem.Allocator,
    provider_pool: *ProviderPool,
) !PolicyAnalysisResult {
    // 1. Encode policy data to ZON format
    // 2. Send LLM request with policy analysis prompt
    // 3. Parse LLM response (ZON or JSON)
    // 4. Convert to PolicyAnalysisResult
    // 5. Track cost using CostTracker
}
```

---

## Implementation Plan

### Months 1-3: Planning and API Contract Design

**Tasks**:
- [x] Review JG project design document
- [x] Design preliminary LLM API contracts for all three phases
- [x] Design data structures for LLM requests/responses
- [x] Plan integration with Core Agent modules
- [x] Plan integration with Workspace/Flow/Research Agents
- [ ] Coordinate with Core Agent on API contract design (when Core Agent is ready)
- [ ] Finalize API contracts based on Core Agent module implementations

**Deliverables**:
- ✅ API contract design documents (preliminary)
- ✅ Data structure definitions (preliminary)
- ✅ Integration plan documents
- ⏳ Finalized API contracts (pending Core Agent coordination)

### Months 4-6: Design Optimization Implementation

**Tasks**:
- [ ] Implement `jg_design_optimization.zig` module
- [ ] Implement design optimization LLM functions
- [ ] Integrate with `grain_jg_architect` module
- [ ] Test with real design scenarios
- [ ] Coordinate with Workspace Agent on dashboard integration
- [ ] Add comprehensive tests

### Months 7-9: Supply Chain Optimization Implementation

**Tasks**:
- [ ] Implement `jg_supply_chain_optimization.zig` module
- [ ] Implement supply chain optimization LLM functions
- [ ] Integrate with `grain_jg_supply_chain` module
- [ ] Test with real supply chain scenarios
- [ ] Coordinate with Flow Agent on workflow integration
- [ ] Add comprehensive tests

### Months 10-12: Policy Analysis Implementation

**Tasks**:
- [ ] Implement `jg_policy_analysis.zig` module
- [ ] Implement policy analysis LLM functions
- [ ] Integrate with `grainbank` MMT integration
- [ ] Test with real policy scenarios
- [ ] Coordinate with Research Agent on analysis collaboration
- [ ] Add comprehensive tests

---

## Technical Considerations

### LLM Provider Selection

**For Design Optimization**:
- Use `recommend_cheapest_provider()` for cost-optimized selection
- Consider model capabilities for design analysis (GPT-4o, Claude 3.5 Sonnet recommended)
- Use ZON format for efficient data transfer (35-70% token reduction)
- Track costs using `CostTracker` for design optimization cost analysis

**For Supply Chain Optimization**:
- Use `compare_provider_costs()` for cost-effective provider selection
- Consider model capabilities for route optimization (GPT-4o recommended)
- Use cost tracking for supply chain cost analysis
- Use provider cost comparison for cost-effective analysis

**For Policy Analysis**:
- Use token efficiency tools for cost-effective analysis
- Consider model capabilities for policy analysis (Claude 3.5 Sonnet recommended for analysis)
- Use cost reporting for policy impact analysis
- Use `generate_cost_report()` for policy analysis cost tracking

### Data Format

**Input Data**:
- Use ZON format for efficient data transfer (35-70% token reduction)
- Convert from Core Agent module data structures to ZON using `auto_encode_request_to_zon()`
- Use automatic ZON encoding with JSON fallback (handles provider compatibility automatically)
- Encode design data, supply chain data, and policy data to ZON format

**Output Data**:
- Parse LLM responses (ZON or JSON) using `handle_provider_output()`
- Convert to Core Agent module data structures
- Use provider-specific output handling (automatic ZON/JSON detection)

**Example Integration Pattern**:
```zig
// 1. Prepare request data
var request = LlmRequest{ /* ... */ };
var design_data = [_]struct { key: []const u8, value: ZonValue }{ /* ... */ };

// 2. Auto-encode to ZON (with JSON fallback)
try auto_encode_request_to_zon(&request, &design_data, allocator);

// 3. Send request with fallback
const response = try provider_pool.send_request_with_fallback(&request, allocator);

// 4. Handle output (ZON or JSON)
const parsed_data = try handle_provider_output(&response, allocator);

// 5. Track cost
_ = track_response_cost(&cost_tracker, &response, "gpt-4o");
```

### Error Handling

**Error Types**:
- Use `LlmProviderError` enum for structured errors
- Use `LlmErrorContext.init()` for detailed error information
- Use `is_llm_error_retryable()` for retryability classification

**Retry Logic**:
- Implement exponential backoff for retryable errors
- Handle rate limiting with `check_rate_limit_response()` and `parse_retry_after_header()`
- Use timeout handling (60s default, configurable via `timeout_ms` in `LlmRequest`)

**Error Handling Pattern**:
```zig
const response = provider_pool.send_request_with_fallback(&request, allocator) catch |err| {
    if (is_llm_error_retryable(err)) {
        // Implement exponential backoff retry
        // Check Retry-After header if rate limited
    }
    const ctx = LlmErrorContext.init(err, "jg_design_optimization", null, null, "Design optimization failed");
    return err;
};
```

### Cost Optimization

**Cost Tracking**:
- Use `CostTracker` to track all JG project LLM costs
- Use `generate_cost_report()` for cost analysis
- Use `compare_provider_costs()` to select cost-effective providers
- Use `recommend_cheapest_provider()` for automatic cost optimization

**Token Efficiency**:
- Use ZON format for 35-70% token reduction
- Use `calculate_token_savings_percent()` to measure efficiency
- Use `calculate_token_efficiency()` to track efficiency metrics

---

## Coordination Requirements

### Core Agent

**API Contracts**:
- `grain_jg_architect` module API contracts (Months 4-6)
- `grain_jg_supply_chain` module API contracts (Months 7-9)
- `grainbank` MMT integration API contracts (Months 10-12)

**Timeline Coordination**:
- Coordinate on implementation timeline
- Coordinate on API contract design timeline
- Coordinate on integration testing timeline

### Workspace Agent

**Desktop Dashboard Integration** (Months 4-6):
- Design optimization suggestions display
- Real-time design optimization feedback
- 3D visualization integration

### Flow Agent

**Workflow Orchestration Integration** (Months 7-9):
- Transportation workflow integration
- Material delivery workflow integration
- Processing facility workflow integration
- Carbon tracking workflow integration

### Research Agent

**Analysis Collaboration** (Months 10-12):
- Policy impact analysis support
- Economic analysis collaboration
- Data analysis and optimization
- Research methodology support

---

## Next Steps

**1. Continue Planning Refinement** (IMMEDIATE, Independent Work)
- ✅ Review JG project design document — COMPLETE
- ✅ Design preliminary API contracts — COMPLETE
- ✅ Design data structures — COMPLETE
- ✅ Plan technical implementation approach — COMPLETE
- ⏳ Refine implementation details as needed
- ⏳ Document integration patterns and examples

**2. Coordinate with Core Agent** (When Core Agent is Ready)
- Review API contract design requirements
- Coordinate on data structure definitions (when `grain_jg_architect`, `grain_jg_supply_chain`, `grainbank` modules are implemented)
- Plan integration timeline
- Finalize API contracts based on actual module implementations

**3. Begin Implementation** (Months 4-6)
- Start with Design Optimization phase
- Implement `jg_design_optimization.zig` module
- Integrate with `grain_jg_architect` module
- Test with real design scenarios
- Coordinate with Workspace Agent on dashboard integration

## Current Status

**Planning Phase**: ✅ **SUBSTANTIALLY COMPLETE**
- ✅ JG project design document reviewed
- ✅ LLM use cases identified for all three phases
- ✅ Preliminary API contracts designed
- ✅ Data structures defined (based on JG project design document)
- ✅ Technical implementation approach documented
- ✅ Integration points identified
- ⏳ Waiting on Core Agent coordination for API contract finalization

**Ready for Implementation**: ⏳ **WAITING ON CORE AGENT**
- ⏳ Core Agent JG module implementation (Months 1-6)
- ⏳ API contract coordination (when Core Agent is ready)
- ⏳ Integration testing planning (when modules are available)

---

**Date**: 2025-12-29-153000-pst  
**Agent**: Grain Court Agent (11th Agent)  
**Status**: Planning Phase — API Contract Design Pending
