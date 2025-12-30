# JG Project Analysis Framework Plan

**Date**: 2025-12-29-160113-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Planning Phase — Framework Design  
**Timeline**: Months 6-12 (Implementation: Months 6-12)

---

## Overview

This document outlines the analysis framework for Research Agent's JG Project responsibilities (Months 6-12). The framework defines data structures, analysis modules, and integration points for economic, housing, environmental, and social analysis.

**Design Document**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`  
**Coordination Plan**: `docs/agent-communications/core_agent_coordination_plan_2025-12-29-152539-pst.md`

---

## Phase 1: Economic Analysis (Months 6-8)

### Analysis Modules

#### 1. Unemployment Reduction Tracking

**Data Sources**:
- Grain JG Task Tracker: Worker task assignments, time logging
- Grainbank: Worker account creation, wage payments
- Silo: Worker profile data (`jg_worker:*`)

**Metrics**:
- Total workers employed (active JG workers)
- Unemployment reduction rate (before/after JG program)
- Worker retention rate (workers staying in program)
- Transition to private sector employment rate

**Analysis Functions**:
- `track_unemployment_reduction(period_start: u64, period_end: u64) -> UnemploymentMetrics`
- `calculate_unemployment_rate(region_id: ?u32) -> f64`
- `analyze_worker_retention(worker_id: u32) -> RetentionAnalysis`
- `track_transition_to_private_sector(worker_id: u32) -> TransitionMetrics`

**Data Structures**:
```zig
pub const UnemploymentMetrics = struct {
    period_start: u64,
    period_end: u64,
    total_workers: u32,
    new_workers: u32,
    retained_workers: u32,
    transitioned_workers: u32,
    unemployment_rate_before: f64,
    unemployment_rate_after: f64,
    reduction_percentage: f64,
};

pub const RetentionAnalysis = struct {
    worker_id: u32,
    months_in_program: u32,
    tasks_completed: u32,
    total_hours: u64,
    retention_score: f64,
};
```

#### 2. Wage Growth Analysis

**Data Sources**:
- Grainbank: Wage payments, wage rate history
- Grain JG Task Tracker: Skills premium tracking, certification records

**Metrics**:
- Average wage growth for bottom quartile workers
- Skills premium impact on wages
- Regional wage adjustments
- Wage growth over time (monthly/quarterly)

**Analysis Functions**:
- `analyze_wage_growth(worker_id: u32, period_months: u32) -> WageGrowthMetrics`
- `calculate_bottom_quartile_wage_growth(period_start: u64, period_end: u64) -> f64`
- `analyze_skills_premium_impact(worker_id: u32) -> SkillsPremiumAnalysis`
- `track_regional_wage_adjustments(region_id: u32) -> RegionalWageMetrics`

**Data Structures**:
```zig
pub const WageGrowthMetrics = struct {
    worker_id: u32,
    period_start: u64,
    period_end: u64,
    starting_wage: u64,
    ending_wage: u64,
    wage_growth_percentage: f64,
    skills_premium_earned: u64,
    total_wage_increase: u64,
};

pub const SkillsPremiumAnalysis = struct {
    worker_id: u32,
    certifications: []Certification,
    premium_earned: u64,
    premium_percentage: f64,
};
```

#### 3. Poverty Reduction Analysis

**Data Sources**:
- Grainbank: Housing accounts, rent-to-own equity, income data
- Grain JG Project Manager: Housing unit allocations

**Metrics**:
- Poverty rate reduction (before/after JG program)
- Housing affordability improvements
- Rent-to-income ratio improvements
- Equity building through rent-to-own

**Analysis Functions**:
- `analyze_poverty_reduction(region_id: ?u32, period_start: u64, period_end: u64) -> PovertyMetrics`
- `calculate_affordability_improvement(resident_id: u32) -> AffordabilityMetrics`
- `track_equity_building(resident_id: u32) -> EquityMetrics`
- `analyze_rent_to_income_ratio(resident_id: u32) -> RentToIncomeRatio`

**Data Structures**:
```zig
pub const PovertyMetrics = struct {
    region_id: ?u32,
    period_start: u64,
    period_end: u64,
    poverty_rate_before: f64,
    poverty_rate_after: f64,
    reduction_percentage: f64,
    households_lifted_out_of_poverty: u32,
};

pub const AffordabilityMetrics = struct {
    resident_id: u32,
    monthly_income: u64,
    monthly_rent: u64,
    rent_to_income_ratio: f64,
    affordability_score: f64,
};
```

#### 4. Local Economic Multiplier Analysis

**Data Sources**:
- Grain JG Project Manager: Project spending, material purchases
- Grainbank: Cooperative payments, local business transactions
- Grain JG Supply Chain: Local material sourcing

**Metrics**:
- Local spending multiplier (dollars spent locally per JG dollar)
- Cooperative business formation rate
- Local supplier network growth
- Regional economic impact

**Analysis Functions**:
- `calculate_economic_multiplier(region_id: u32, period_start: u64, period_end: u64) -> EconomicMultiplierMetrics`
- `track_cooperative_formation(region_id: u32) -> CooperativeFormationMetrics`
- `analyze_local_supplier_network(region_id: u32) -> SupplierNetworkMetrics`
- `estimate_regional_impact(region_id: u32) -> RegionalImpactMetrics`

**Data Structures**:
```zig
pub const EconomicMultiplierMetrics = struct {
    region_id: u32,
    period_start: u64,
    period_end: u64,
    jg_dollars_spent: u64,
    local_dollars_generated: u64,
    multiplier_ratio: f64,
    local_businesses_created: u32,
    jobs_created_indirectly: u32,
};

pub const CooperativeFormationMetrics = struct {
    region_id: u32,
    cooperatives_formed: u32,
    total_workers_in_cooperatives: u32,
    cooperative_revenue: u64,
    profit_distribution: u64,
};
```

---

## Phase 2: Housing Indicators Analysis (Months 9-10)

### Analysis Modules

#### 1. Units Produced Per Year Analysis

**Data Sources**:
- Grain JG Project Manager: Project completion data, unit completion tracking
- Grain JG Task Tracker: Construction task completion

**Metrics**:
- Total units produced per year
- Units by size category (500-800 sq ft, 800-1000 sq ft, 1000-1200 sq ft)
- Construction time per unit
- Production rate trends

**Analysis Functions**:
- `calculate_units_produced(period_start: u64, period_end: u64) -> UnitsProducedMetrics`
- `analyze_units_by_size(period_start: u64, period_end: u64) -> UnitsBySizeMetrics`
- `calculate_construction_time_per_unit(project_id: u32) -> ConstructionTimeMetrics`
- `track_production_rate_trends(period_months: u32) -> ProductionRateTrends`

**Data Structures**:
```zig
pub const UnitsProducedMetrics = struct {
    period_start: u64,
    period_end: u64,
    total_units: u32,
    units_by_size: UnitsBySize,
    average_construction_time_days: u32,
    production_rate_units_per_month: f64,
};

pub const UnitsBySize = struct {
    small_units_500_800: u32,
    medium_units_800_1000: u32,
    large_units_1000_1200: u32,
};
```

#### 2. Affordability Analysis

**Data Sources**:
- Grainbank: Rent payments, income data, rent-to-own equity
- Grain JG Project Manager: Unit pricing, rent calculations

**Metrics**:
- Rent-to-income ratios
- Affordability by income quartile
- Rent-to-own equity accumulation
- Housing cost burden reduction

**Analysis Functions**:
- `analyze_affordability(region_id: ?u32) -> AffordabilityAnalysis`
- `calculate_rent_to_income_ratios(resident_ids: []u32) -> []RentToIncomeRatio`
- `track_equity_accumulation(resident_id: u32) -> EquityAccumulationMetrics`
- `analyze_housing_cost_burden(region_id: u32) -> CostBurdenMetrics`

**Data Structures**:
```zig
pub const AffordabilityAnalysis = struct {
    region_id: ?u32,
    average_rent_to_income_ratio: f64,
    affordable_units_count: u32,
    affordability_by_quartile: [4]f64,
    median_rent: u64,
    median_income: u64,
};

pub const EquityAccumulationMetrics = struct {
    resident_id: u32,
    total_rent_paid: u64,
    equity_accumulated: u64,
    equity_percentage: f64,
    months_to_full_ownership: u32,
};
```

#### 3. Quality Measures Analysis

**Data Sources**:
- Grain JG 3D Architect: Energy efficiency data, building specifications
- Grain JG Task Tracker: Quality inspection records
- Grain JG Inventory: Material quality certifications

**Metrics**:
- Energy efficiency ratings
- Building durability scores
- Material quality certifications
- Quality inspection pass rates

**Analysis Functions**:
- `analyze_energy_efficiency(project_id: u32) -> EnergyEfficiencyMetrics`
- `calculate_durability_scores(project_id: u32) -> DurabilityMetrics`
- `track_quality_certifications(project_id: u32) -> QualityCertificationMetrics`
- `analyze_inspection_pass_rates(period_start: u64, period_end: u64) -> InspectionMetrics`

**Data Structures**:
```zig
pub const EnergyEfficiencyMetrics = struct {
    project_id: u32,
    energy_rating: f64,
    passive_solar_score: f64,
    thermal_mass_score: f64,
    renewable_energy_percentage: f64,
    estimated_annual_energy_cost: u64,
};

pub const DurabilityMetrics = struct {
    project_id: u32,
    material_quality_score: f64,
    structural_integrity_score: f64,
    expected_lifespan_years: u32,
    maintenance_requirements: MaintenanceRequirements,
};
```

#### 4. Resident Satisfaction Analysis

**Data Sources**:
- Workspace Agent: Survey data, resident feedback
- Silo: Community data, length of residency
- Grain JG Project Manager: Unit allocation data

**Metrics**:
- Resident satisfaction scores
- Length of residency (community stability)
- Complaint resolution rates
- Community engagement levels

**Analysis Functions**:
- `analyze_resident_satisfaction(period_start: u64, period_end: u64) -> SatisfactionMetrics`
- `calculate_residency_length(region_id: ?u32) -> ResidencyLengthMetrics`
- `track_complaint_resolution(period_start: u64, period_end: u64) -> ComplaintResolutionMetrics`
- `analyze_community_engagement(region_id: u32) -> CommunityEngagementMetrics`

**Data Structures**:
```zig
pub const SatisfactionMetrics = struct {
    period_start: u64,
    period_end: u64,
    average_satisfaction_score: f64,
    satisfaction_by_category: SatisfactionByCategory,
    response_rate: f64,
    total_responses: u32,
};

pub const SatisfactionByCategory = struct {
    housing_quality: f64,
    community: f64,
    affordability: f64,
    location: f64,
    services: f64,
};
```

---

## Phase 3: Environmental & Social Analysis (Months 11-12)

### Analysis Modules

#### 1. Carbon Sequestration Analysis

**Data Sources**:
- Grain JG Inventory: Material tracking (hemp, timber, bamboo)
- Grain JG 3D Architect: Building material specifications
- Grain JG Supply Chain: Transportation carbon footprint

**Metrics**:
- Carbon sequestered per unit (hemp, timber, bamboo)
- Total carbon sequestration per project
- Carbon footprint reduction vs. conventional construction
- Net carbon impact (sequestration minus emissions)

**Analysis Functions**:
- `calculate_carbon_sequestration(project_id: u32) -> CarbonSequestrationMetrics`
- `analyze_material_carbon_impact(material_type: MaterialType, quantity: u64) -> MaterialCarbonMetrics`
- `track_transportation_carbon(route_id: u32) -> TransportationCarbonMetrics`
- `calculate_net_carbon_impact(project_id: u32) -> NetCarbonImpactMetrics`

**Data Structures**:
```zig
pub const CarbonSequestrationMetrics = struct {
    project_id: u32,
    total_carbon_sequestered_kg: u64,
    carbon_by_material: MaterialCarbonBreakdown,
    sequestration_rate_per_unit: f64,
    net_carbon_impact_kg: i64,
};

pub const MaterialCarbonBreakdown = struct {
    hemp_carbon_kg: u64,
    timber_carbon_kg: u64,
    bamboo_carbon_kg: u64,
    total_kg: u64,
};
```

#### 2. Embodied Energy Analysis

**Data Sources**:
- Grain JG 3D Architect: Building material specifications, energy analysis
- Grain JG Inventory: Material processing energy data
- Grain JG Supply Chain: Transportation energy data

**Metrics**:
- Embodied energy per unit
- Energy efficiency vs. conventional construction
- Renewable energy percentage
- Lifecycle energy analysis

**Analysis Functions**:
- `calculate_embodied_energy(project_id: u32) -> EmbodiedEnergyMetrics`
- `analyze_energy_efficiency(project_id: u32) -> EnergyEfficiencyAnalysis`
- `track_renewable_energy_percentage(project_id: u32) -> RenewableEnergyMetrics`
- `calculate_lifecycle_energy(project_id: u32) -> LifecycleEnergyMetrics`

**Data Structures**:
```zig
pub const EmbodiedEnergyMetrics = struct {
    project_id: u32,
    total_embodied_energy_mj: u64,
    energy_by_material: MaterialEnergyBreakdown,
    energy_per_sqft: f64,
    energy_efficiency_score: f64,
};

pub const MaterialEnergyBreakdown = struct {
    hemp_energy_mj: u64,
    timber_energy_mj: u64,
    bamboo_energy_mj: u64,
    processing_energy_mj: u64,
    transportation_energy_mj: u64,
    total_mj: u64,
};
```

#### 3. Health Outcomes Analysis

**Data Sources**:
- Grainbank: Benefits administration, healthcare utilization
- Silo: Community health data
- Grain JG 3D Architect: Building health features (natural ventilation, etc.)

**Metrics**:
- Healthcare utilization rates
- Health outcome improvements
- Building health features impact
- Community health indicators

**Analysis Functions**:
- `analyze_health_outcomes(region_id: ?u32, period_start: u64, period_end: u64) -> HealthOutcomesMetrics`
- `track_healthcare_utilization(worker_id: u32) -> HealthcareUtilizationMetrics`
- `analyze_building_health_impact(project_id: u32) -> BuildingHealthMetrics`
- `calculate_community_health_indicators(region_id: u32) -> CommunityHealthMetrics`

**Data Structures**:
```zig
pub const HealthOutcomesMetrics = struct {
    region_id: ?u32,
    period_start: u64,
    period_end: u64,
    healthcare_utilization_rate: f64,
    health_outcome_improvements: HealthImprovements,
    building_health_score: f64,
    community_health_score: f64,
};

pub const HealthImprovements = struct {
    respiratory_health: f64,
    mental_health: f64,
    physical_health: f64,
    overall_improvement: f64,
};
```

#### 4. Civic Engagement Analysis

**Data Sources**:
- Flow Agent: Democratic process workflows, town hall coordination
- Silo: Community data, civic participation records
- Grain JG Task Tracker: Community engagement tasks

**Metrics**:
- Civic participation rates
- Democratic process participation
- Community engagement levels
- Volunteer hours and contributions

**Analysis Functions**:
- `analyze_civic_engagement(region_id: u32, period_start: u64, period_end: u64) -> CivicEngagementMetrics`
- `track_democratic_participation(region_id: u32) -> DemocraticParticipationMetrics`
- `calculate_community_engagement(region_id: u32) -> CommunityEngagementMetrics`
- `analyze_volunteer_contributions(region_id: u32) -> VolunteerMetrics`

**Data Structures**:
```zig
pub const CivicEngagementMetrics = struct {
    region_id: u32,
    period_start: u64,
    period_end: u64,
    civic_participation_rate: f64,
    democratic_process_participation: u32,
    community_engagement_score: f64,
    volunteer_hours: u64,
    community_events_attended: u32,
};

pub const DemocraticParticipationMetrics = struct {
    region_id: u32,
    town_hall_attendance: u32,
    worker_elections_participation: u32,
    grievance_process_participation: u32,
    career_ladder_participation: u32,
};
```

---

## Data Access Requirements

### Core Agent Integration

**Required APIs**:
- JG project module data access (`jg_project:*`, `jg_task:*`, `jg_inventory:*`, `jg_supply_chain:*`, `jg_architect:*`)
- Grainbank data access (wage payments, housing accounts, cooperative accounts)
- Worker and resident data access (`jg_worker:*`, `jg_housing:*`)

**Data Access Patterns**:
- Query by time period (period_start, period_end)
- Query by region (region_id)
- Query by project (project_id)
- Query by worker/resident (worker_id, resident_id)
- Aggregate queries (sum, average, count)

### Silo Agent Integration

**Required Storage**:
- Analysis results storage (`jg_research:*` keys)
- Historical data caching
- Aggregated metrics storage

### Workspace Agent Integration

**Required Data**:
- Survey data for resident satisfaction analysis
- Dashboard data for visualization

### Flow Agent Integration

**Required Data**:
- Democratic process workflow data
- Civic engagement workflow data

---

## Implementation Plan

### Module Structure

```
src/grain_research/jg_analysis/
├── economic_analysis.zig          # Phase 1: Economic analysis modules
│   ├── unemployment_tracking.zig
│   ├── wage_growth_analysis.zig
│   ├── poverty_reduction.zig
│   └── economic_multiplier.zig
├── housing_indicators.zig          # Phase 2: Housing indicators analysis
│   ├── units_produced.zig
│   ├── affordability_analysis.zig
│   ├── quality_measures.zig
│   └── resident_satisfaction.zig
└── environmental_social.zig        # Phase 3: Environmental & social analysis
    ├── carbon_sequestration.zig
    ├── embodied_energy.zig
    ├── health_outcomes.zig
    └── civic_engagement.zig
```

### Grain Style Requirements

- Function names: `grain_case` (e.g., `track_unemployment_reduction`, `analyze_wage_growth`)
- Types: Explicit `u32`/`u64` instead of `usize`/`isize`
- Bounded allocations: `MAX_METRICS_COUNT`, `MAX_WORKERS_PER_QUERY`, etc.
- Assertions: Comprehensive assertions for all preconditions
- Line limits: Max 103 characters per line (`grainwrap-100`)
- Function limits: Max 70 lines per function (`grain validate-70`)
- Compiler warnings: All warnings enabled

### Testing Requirements

- Unit tests for each analysis function
- Integration tests with Core Agent JG modules
- Data validation tests
- Performance tests for large datasets

---

## Timeline

**Months 6-8**: Phase 1 — Economic Analysis Implementation
- Month 6: Unemployment reduction tracking, wage growth analysis
- Month 7: Poverty reduction analysis
- Month 8: Local economic multiplier analysis

**Months 9-10**: Phase 2 — Housing Indicators Analysis Implementation
- Month 9: Units produced, affordability analysis
- Month 10: Quality measures, resident satisfaction analysis

**Months 11-12**: Phase 3 — Environmental & Social Analysis Implementation
- Month 11: Carbon sequestration, embodied energy analysis
- Month 12: Health outcomes, civic engagement analysis

---

## Dependencies

**Required from Other Agents**:
- **Core Agent**: JG project modules and data access APIs (Months 1-6) ⏳
- **Silo Agent**: Storage schemas for JG project data (Months 1-3) ⏳
- **Workspace Agent**: Desktop dashboards for data visualization (Months 3-8) ⏳
- **Flow Agent**: Workflow orchestration for data collection (Months 4-10) ⏳

**Research Agent Provides**:
- Economic analysis and reporting
- Housing indicators analysis
- Environmental and social impact analysis
- Optimization recommendations

---

**Date**: 2025-12-29-160113-pst  
**Agent**: Grain Research Agent (10th Agent)  
**Status**: Planning Phase — Framework Design Complete ✅
