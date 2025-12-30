# JG Project Knowledge Graph Structure: Preliminary Design

**Date**: 2025-12-29-170000-pst  
**Agent**: Grain Skate Agent  
**Status**: Preliminary Design — Planning Phase  
**Reference**: [`docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-29-041147-pst.md`](../zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-29-041147-pst.md)

---

## Overview

This document outlines the preliminary knowledge graph structure for the JG (Job Guarantee) Project. Skate Agent is responsible for building knowledge graphs to support:
- Material properties and relationships
- Worker skill networks
- Project relationship mapping

**Implementation Timeline**: Months 5-7 (Phase 8)

---

## 1. Material Knowledge Graph

### Node Types

**Material Nodes**:
- `material:hemp_raw` - Raw hemp material
- `material:hemp_processed` - Processed hemp
- `material:hempcrete_block` - Hempcrete construction blocks
- `material:bamboo_raw` - Raw bamboo
- `material:bamboo_processed` - Processed bamboo
- `material:laminated_bamboo_lumber` - LBL construction material
- `material:timber_raw` - Raw timber
- `material:timber_processed` - Processed timber
- `material:mass_timber_clt` - Cross-laminated timber
- `material:rammed_earth` - Rammed earth construction
- `material:compressed_earth_block` - CEB blocks
- `material:clay_raw` - Raw clay
- `material:brick_fired` - Fired bricks
- `material:stone_raw` - Raw stone
- `material:stone_cut` - Cut stone
- `material:lime_stucco` - Lime stucco finish
- `material:natural_plaster` - Natural plaster finish

**Property Nodes**:
- `property:structural_grade` - Structural load-bearing capability
- `property:fire_rated` - Fire resistance rating
- `property:moisture_resistant` - Moisture resistance
- `property:thermal_mass` - Thermal mass properties
- `property:insulation_value` - R-value insulation
- `property:carbon_negative` - Carbon sequestration capability
- `property:renewable` - Renewable resource status
- `property:fair_trade` - Fair trade certification
- `property:organic` - Organic certification

**Certification Nodes**:
- `certification:organic` - Organic certification standard
- `certification:fair_trade` - Fair trade certification
- `certification:sustainable_forestry` - Sustainable forestry certification
- `certification:structural_grade` - Structural engineering certification
- `certification:fire_rated` - Fire safety certification
- `certification:moisture_resistant` - Moisture resistance certification

**Processing Technique Nodes**:
- `technique:hempcrete_mixing` - Hempcrete mixing process
- `technique:lbl_lamination` - Laminated bamboo lumber process
- `technique:ceb_compression` - Compressed earth block process
- `technique:brick_firing` - Brick firing process
- `technique:stone_cutting` - Stone cutting process

**Regional Source Nodes**:
- `region:california` - California regional source
- `region:oregon` - Oregon regional source
- `region:washington` - Washington regional source
- `region:arizona` - Arizona regional source
- `region:new_mexico` - New Mexico regional source

### Edge Types

**Material Relationships**:
- `raw_to_processed` - Raw material → processed material
- `processed_to_construction` - Processed material → construction use
- `material_has_property` - Material → property relationship
- `material_has_certification` - Material → certification relationship
- `material_processed_by` - Material → processing technique
- `material_sourced_from` - Material → regional source

**Property Relationships**:
- `property_measured_in` - Property → measurement unit
- `property_value_range` - Property → value range (min, max)

**Certification Relationships**:
- `certification_issued_by` - Certification → issuing authority
- `certification_valid_for` - Certification → material type

**Regional Relationships**:
- `region_has_availability` - Region → material availability
- `region_has_cost` - Region → material cost per unit

### Example Queries

**Find materials by property**:
```
Query: Find all materials with fire_rated property
Graph: material:* → material_has_property → property:fire_rated
```

**Find processing techniques for material**:
```
Query: Find processing techniques for hemp
Graph: material:hemp_raw → material_processed_by → technique:*
```

**Find regional availability**:
```
Query: Find hemp availability in California
Graph: region:california → region_has_availability → material:hemp_raw
```

---

## 2. Worker Skill Network

### Node Types

**Worker Nodes**:
- `worker:{worker_id}` - Individual worker profile
  - Attributes: name, worker_id, certifications, experience_years

**Skill Nodes**:
- `skill:carpentry` - Carpentry skills
- `skill:masonry` - Masonry skills
- `skill:plumbing` - Plumbing skills
- `skill:electrical` - Electrical skills
- `skill:roofing` - Roofing skills
- `skill:foundation` - Foundation construction
- `skill:framing` - Structural framing
- `skill:finishing` - Interior finishing
- `skill:hempcrete_construction` - Hempcrete construction techniques
- `skill:bamboo_construction` - Bamboo construction techniques
- `skill:rammed_earth` - Rammed earth construction
- `skill:project_management` - Project management
- `skill:quality_inspection` - Quality inspection

**Certification Nodes**:
- `certification:osha_10` - OSHA 10-hour safety certification
- `certification:osha_30` - OSHA 30-hour safety certification
- `certification:journeyman_carpenter` - Journeyman carpenter certification
- `certification:master_carpenter` - Master carpenter certification
- `certification:licensed_plumber` - Licensed plumber certification
- `certification:licensed_electrician` - Licensed electrician certification

**Project Phase Nodes**:
- `phase:planning` - Project planning phase
- `phase:site_preparation` - Site preparation phase
- `phase:foundation` - Foundation phase
- `phase:framing` - Framing phase
- `phase:enclosure` - Enclosure phase
- `phase:systems_installation` - Systems installation phase
- `phase:finishing` - Finishing phase
- `phase:inspection` - Inspection phase

### Edge Types

**Worker Relationships**:
- `worker_has_skill` - Worker → skill (with proficiency level: beginner, intermediate, advanced, expert)
- `worker_has_certification` - Worker → certification (with expiration date)
- `worker_worked_on` - Worker → project (with role, hours, dates)
- `worker_trained_in` - Worker → skill (training pathway)

**Skill Relationships**:
- `skill_requires_skill` - Skill → prerequisite skill
- `skill_related_to` - Skill → related skill
- `skill_used_in_phase` - Skill → project phase
- `skill_required_for_material` - Skill → material type

**Certification Relationships**:
- `certification_requires_skill` - Certification → required skill
- `certification_expires_on` - Certification → expiration date

### Example Queries

**Find workers for project phase**:
```
Query: Find workers with carpentry skills for framing phase
Graph: worker:* → worker_has_skill → skill:carpentry → skill_used_in_phase → phase:framing
```

**Find skill gaps for project**:
```
Query: Find missing skills for hempcrete construction project
Graph: project:{project_id} → project_requires_skill → skill:* (compare with worker:* → worker_has_skill)
```

**Find training pathways**:
```
Query: Find training pathway from beginner to expert carpentry
Graph: skill:carpentry → skill_requires_skill → skill:* (traverse prerequisite chain)
```

---

## 3. Project Relationship Mapping

### Node Types

**Project Nodes**:
- `project:{project_id}` - Individual housing project
  - Attributes: project_name, site_location, phase, units_planned, start_date, target_completion_date

**Task Nodes**:
- `task:{task_id}` - Individual construction task
  - Attributes: task_name, task_type, priority, status, assigned_worker_id

**Material Usage Nodes**:
- `material_usage:{usage_id}` - Material usage in project
  - Attributes: material_type, quantity, unit, cost_per_unit, usage_date

**Worker Assignment Nodes**:
- `assignment:{assignment_id}` - Worker assignment to project/task
  - Attributes: worker_id, project_id, task_id, role, hours_worked, wage_rate

### Edge Types

**Project Relationships**:
- `project_uses_material` - Project → material usage
- `project_has_task` - Project → task
- `project_assigned_worker` - Project → worker assignment
- `project_depends_on` - Project → prerequisite project (for multi-site coordination)
- `project_in_phase` - Project → project phase

**Task Relationships**:
- `task_requires_material` - Task → material usage
- `task_assigned_worker` - Task → worker assignment
- `task_depends_on` - Task → prerequisite task
- `task_in_phase` - Task → project phase

**Material Usage Relationships**:
- `material_usage_from_inventory` - Material usage → inventory item
- `material_usage_for_task` - Material usage → task

**Worker Assignment Relationships**:
- `assignment_to_project` - Worker assignment → project
- `assignment_to_task` - Worker assignment → task
- `assignment_uses_skill` - Worker assignment → required skill

### Example Queries

**Find project dependencies**:
```
Query: Find all prerequisite projects for project X
Graph: project:{project_id} → project_depends_on → project:*
```

**Find resource conflicts**:
```
Query: Find projects competing for same workers/materials
Graph: project:* → project_assigned_worker → worker:{worker_id} (find overlapping assignments)
```

**Find material requirements**:
```
Query: Find all materials needed for project X
Graph: project:{project_id} → project_has_task → task:* → task_requires_material → material_usage:*
```

---

## Implementation Notes

### Data Storage (Silo Agent)

**Storage Keys**:
- `jg_material:{material_id}` - Material data
- `jg_worker:{worker_id}` - Worker data
- `jg_project:{project_id}` - Project data
- `jg_task:{task_id}` - Task data
- `jg_certification:{certification_id}` - Certification data

### Graph Modules (Skate Agent)

**Module Structure**:
- `src/grain_skate/jg_material_graph.zig` - Material knowledge graph
- `src/grain_skate/jg_worker_skill_graph.zig` - Worker skill network
- `src/grain_skate/jg_project_graph.zig` - Project relationship mapping

### Integration Points

**Silo Agent**: Data storage for all graph nodes and edges
**Grainbank**: Material cost tracking, worker wage calculations
**Grain JG Project Manager**: Project lifecycle tracking
**Grain JG Task Tracker**: Task-to-project relationships
**Grain JG Inventory Manager**: Material inventory tracking
**Court Agent**: LLM-powered material recommendations, skill matching
**Flow Agent**: Workflow orchestration for project dependencies

### Coordination Needed

**Core Agent**:
- Data access patterns for knowledge graph operations
- Grainbank MMT integration coordination

**Silo Agent**:
- Storage schemas for knowledge graph data
- Material knowledge storage schema
- Worker skill network storage schema
- Project relationship storage schema

**Court Agent**:
- LLM-powered insights for knowledge graph data
- Material selection recommendations
- Skill matching recommendations

**Flow Agent**:
- Workflow orchestration integration
- Project dependencies → workflow mapping

---

## Next Steps

1. **Review with Core Agent**: Coordinate on data access patterns and Grainbank integration
2. **Review with Silo Agent**: Coordinate on storage schemas
3. **Design Graph API**: Design query APIs for each graph type
4. **Prototype Material Graph**: Create prototype material knowledge graph with sample data
5. **Begin Implementation**: Start Month 5 implementation (material knowledge graph foundation)

---

**Last Updated**: 2025-12-29-170000-pst  
**Agent**: Grain Skate Agent
