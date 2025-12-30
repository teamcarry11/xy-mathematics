# JG Project Workflow Orchestration Plan

**Date**: 2025-12-30-015221-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Planning Document — Workflow Orchestration Patterns for JG Project  
**JG Project Design**: `docs/zyx/grainbank_mmt_job_guarantee_housing_program_2025-12-28-232324-pst.md`

---

## Executive Summary

This document outlines Flow Agent's workflow orchestration plan for the Grainbank MMT Job Guarantee (JG) Housing Program. Flow Agent is responsible for orchestrating task workflows, supply chain workflows, and democratic process workflows (Months 4-10).

**Flow Agent Responsibilities**:
- **Phase 1** (Months 4-6): Task Workflow Orchestration
- **Phase 2** (Months 7-8): Supply Chain Workflow Orchestration
- **Phase 3** (Months 9-10): Democratic Process Workflows

**Current Status**: Planning phase — Reviewing JG project design document, mapping workflow requirements to Flow Agent capabilities, designing workflow orchestration patterns.

---

## JG Project Overview

**Program Vision**: Build beautiful, affordable, sustainable housing using fastest-growing renewable materials (hemp, bamboo, timber, rammed earth) through a federal Job Guarantee program that creates jobs, builds communities, and restores traditional urbanism principles.

**Core JG Modules**:
1. **Grain JG Project Manager** (`grain_jg_project`): Project lifecycle management
2. **Grain JG Task Tracker** (`grain_jg_task`): Task assignment and completion tracking
3. **Grain JG Inventory Manager** (`grain_jg_inventory`): Material tracking from cultivation to construction
4. **Grain JG Supply Chain** (`grain_jg_supply_chain`): Transportation and logistics tracking
5. **Grain JG 3D Architect** (`grain_jg_architect`): 3D architectural planning and visualization

**Integration Points for Flow Agent**:
- **Core Agent**: JG Project Manager, JG Task Tracker, JG Supply Chain, JG Inventory Manager
- **Silo Agent**: Task data storage (`jg_task:*`), supply chain data storage (`jg_supply_chain:*`), worker profile data storage (`jg_worker:*`)
- **Grainbank**: Time logging triggers wage payments, material purchase payments
- **Court Agent**: LLM-assisted route optimization (Months 7-9)
- **Workspace Agent**: Desktop dashboards for democratic processes (Months 3-8)

---

## Phase 1: Task Workflow Orchestration (Months 4-6)

### Workflow Type 1: Task Dependency Workflows

**Purpose**: Manage task sequencing, dependencies, critical path analysis, and parallel task coordination.

**JG Project Requirements**:
- Tasks have dependencies (`JgTask.dependencies` array)
- Tasks have status (`TaskStatus`: pending, assigned, in_progress, completed, verified, failed)
- Tasks have priority (`TaskPriority`: low, medium, high, critical)
- Tasks belong to projects (`JgTask.project_id`)

**Flow Agent Capabilities**:
- ✅ DAG-based workflow engine (`workflow_engine.zig`)
- ✅ Workflow nodes with dependencies (`WorkflowNode`, `WorkflowEdge`)
- ✅ Edge types: `dependency`, `data_flow`, `conditional`
- ✅ Topological sort execution (iterative, no recursion)
- ✅ Workflow state management

**Workflow Pattern Design**:
```
Task Dependency Workflow:
  Node 1: Check Task Dependencies (Core Agent: JG Task Tracker)
    └─> Edge (dependency): All dependencies completed?
  Node 2: Assign Task to Worker (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Worker assignment data
  Node 3: Execute Task (Worker)
    └─> Edge (dependency): Task execution complete
  Node 4: Quality Verification (Core Agent: JG Task Tracker)
    └─> Edge (conditional): Quality score >= threshold?
  Node 5: Mark Task Complete (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Completion data
  Node 6: Trigger Dependent Tasks (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Dependency resolution
```

**Implementation Approach**:
1. Create workflow template: `create_jg_task_dependency_workflow()`
2. Map `JgTask.dependencies` to `WorkflowEdge` dependencies
3. Use `WorkflowEngine.execute_workflow()` for task sequencing
4. Publish events on task status changes (`task_assigned`, `task_completed`, `task_failed`)
5. Handle blocked tasks (dependencies not met)

**Event Bus Integration**:
- `task_dependency_ready` event: Triggered when all dependencies complete
- `task_blocked` event: Triggered when dependencies not met
- `task_critical_path_updated` event: Triggered when critical path changes

---

### Workflow Type 2: Worker Assignment Workflows

**Purpose**: Match workers to tasks based on skills, balance workloads, form teams, and resolve assignment conflicts.

**JG Project Requirements**:
- Tasks have skill requirements (`JgTask.skill_requirements` array)
- Workers have skills (from `jg_worker:*` storage)
- Tasks have priority and estimated hours
- Workers have current workload

**Flow Agent Capabilities**:
- ✅ Workflow engine for multi-step assignment process
- ✅ Event bus for worker availability notifications
- ✅ Agent coordinator for worker registry (if workers are agents)

**Workflow Pattern Design**:
```
Worker Assignment Workflow:
  Node 1: Identify Task Requirements (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Skill requirements, priority, estimated hours
  Node 2: Query Available Workers (Silo Agent: jg_worker:* storage)
    └─> Edge (data_flow): Worker profiles with skills
  Node 3: Match Skills (Flow Agent: Matching logic)
    └─> Edge (conditional): Skills match?
  Node 4: Check Workload Balance (Flow Agent: Workload calculation)
    └─> Edge (conditional): Workload acceptable?
  Node 5: Assign Task to Worker (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Assignment confirmation
  Node 6: Update Worker Workload (Silo Agent: jg_worker:* storage)
    └─> Edge (data_flow): Workload update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_worker_assignment_workflow()`
2. Implement skill matching logic (compare `JgTask.skill_requirements` with worker skills)
3. Implement workload balancing (sum of `JgTask.estimated_hours` for each worker)
4. Handle assignment conflicts (multiple tasks for same worker)
5. Publish events on assignment changes (`worker_assigned`, `worker_unavailable`, `assignment_conflict`)

**Event Bus Integration**:
- `worker_available` event: Triggered when worker becomes available
- `worker_assigned` event: Triggered when task assigned to worker
- `assignment_conflict` event: Triggered when conflict detected
- `workload_imbalanced` event: Triggered when workload distribution needs rebalancing

---

### Workflow Type 3: Quality Assurance Workflows

**Purpose**: Schedule inspections, manage quality check dependencies, create rework tasks, and handle approval workflows.

**JG Project Requirements**:
- Tasks have quality scores (`JgTask.quality_score: ?u8`)
- Tasks have status transitions (completed → verified)
- Quality checks may require rework
- Inspections scheduled based on project phase

**Flow Agent Capabilities**:
- ✅ Workflow engine for multi-step quality processes
- ✅ Conditional edges for quality thresholds
- ✅ Workflow templates for reusable patterns

**Workflow Pattern Design**:
```
Quality Assurance Workflow:
  Node 1: Task Completion Trigger (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Task completion data
  Node 2: Schedule Inspection (Core Agent: JG Project Manager)
    └─> Edge (dependency): Inspection scheduled
  Node 3: Perform Inspection (Inspector)
    └─> Edge (data_flow): Inspection results
  Node 4: Evaluate Quality Score (Flow Agent: Quality evaluation)
    └─> Edge (conditional): Quality score >= threshold?
  Node 5a: Approve Task (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Task verified
  Node 5b: Create Rework Task (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Rework task created
  Node 6: Update Project Quality Metrics (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Quality metrics update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_quality_assurance_workflow()`
2. Implement quality threshold evaluation (compare `JgTask.quality_score` with threshold)
3. Handle rework task creation (create new task linked to original)
4. Schedule inspections based on project phase
5. Publish events on quality changes (`quality_check_scheduled`, `quality_approved`, `quality_failed`, `rework_required`)

**Event Bus Integration**:
- `quality_check_scheduled` event: Triggered when inspection scheduled
- `quality_approved` event: Triggered when quality meets threshold
- `quality_failed` event: Triggered when quality below threshold
- `rework_required` event: Triggered when rework task created

---

### Workflow Type 4: Time Logging Workflows

**Purpose**: Validate time entries, trigger wage calculations, detect overtime, and track benefits eligibility.

**JG Project Requirements**:
- Tasks have estimated hours (`JgTask.estimated_hours: u32`)
- Tasks have actual hours (`JgTask.actual_hours: ?u32`)
- Time logging triggers wage payments (via Grainbank)
- Overtime detection (hours > 40/week)
- Benefits eligibility tracking

**Flow Agent Capabilities**:
- ✅ Workflow engine for time validation processes
- ✅ Event bus for time entry notifications
- ✅ Workflow state for time tracking

**Workflow Pattern Design**:
```
Time Logging Workflow:
  Node 1: Time Entry Submitted (Worker)
    └─> Edge (data_flow): Time entry data (task_id, hours, date)
  Node 2: Validate Time Entry (Flow Agent: Validation logic)
    └─> Edge (conditional): Time entry valid?
  Node 3: Check Overtime (Flow Agent: Overtime calculation)
    └─> Edge (conditional): Hours > 40/week?
  Node 4: Calculate Wage (Grainbank: Wage calculation)
    └─> Edge (data_flow): Wage amount, overtime premium
  Node 5: Credit Worker Account (Grainbank: Account crediting)
    └─> Edge (data_flow): Payment confirmation
  Node 6: Update Task Hours (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Actual hours update
  Node 7: Update Benefits Eligibility (Core Agent: Benefits tracking)
    └─> Edge (data_flow): Benefits status update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_time_logging_workflow()`
2. Implement time entry validation (check task_id, hours, date, worker_id)
3. Implement overtime detection (sum hours per week, check > 40)
4. Trigger Grainbank wage calculation (via event or API call)
5. Update task actual hours
6. Publish events on time logging (`time_entry_submitted`, `time_entry_validated`, `wage_calculated`, `overtime_detected`)

**Event Bus Integration**:
- `time_entry_submitted` event: Triggered when worker submits time entry
- `time_entry_validated` event: Triggered when time entry passes validation
- `time_entry_invalid` event: Triggered when time entry fails validation
- `wage_calculated` event: Triggered when wage calculation complete
- `overtime_detected` event: Triggered when overtime hours detected

---

## Phase 2: Supply Chain Workflow Orchestration (Months 7-8)

### Workflow Type 1: Transportation Workflows

**Purpose**: Plan routes, assign vehicles, schedule deliveries, and track carbon footprint.

**JG Project Requirements**:
- Supply chain routes (`SupplyChainRoute` structure)
- Transport modes (truck, rail, barge, electric_vehicle, local_delivery)
- Route optimization (source → destination, material type, quantity)
- Carbon footprint calculation (`carbon_footprint_kg: u64`)

**Flow Agent Capabilities**:
- ✅ Workflow engine for multi-step transportation processes
- ✅ Event bus for route updates
- ✅ Integration with Court Agent for LLM-assisted route optimization (Months 7-9)

**Workflow Pattern Design**:
```
Transportation Workflow:
  Node 1: Material Request Received (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Material request (type, quantity, destination)
  Node 2: Identify Source Location (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Source location, available quantity
  Node 3: Optimize Route (Court Agent: LLM route optimization)
    └─> Edge (data_flow): Optimized route, estimated duration, carbon footprint
  Node 4: Assign Vehicle (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Vehicle assignment
  Node 5: Schedule Departure (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Scheduled departure time
  Node 6: Track Transportation (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Real-time location updates
  Node 7: Confirm Delivery (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Delivery confirmation, actual duration, actual carbon footprint
  Node 8: Update Inventory (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Inventory update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_transportation_workflow()`
2. Integrate with Court Agent LLM route optimization (Months 7-9)
3. Handle vehicle assignment logic
4. Track transportation progress (via events)
5. Calculate actual carbon footprint
6. Publish events on transportation changes (`route_optimized`, `vehicle_assigned`, `departure_scheduled`, `delivery_confirmed`)

**Event Bus Integration**:
- `material_request_received` event: Triggered when material request created
- `route_optimized` event: Triggered when route optimization complete
- `vehicle_assigned` event: Triggered when vehicle assigned to route
- `transportation_started` event: Triggered when vehicle departs
- `transportation_progress` event: Triggered on location updates
- `delivery_confirmed` event: Triggered when delivery complete

---

### Workflow Type 2: Material Delivery Workflows

**Purpose**: Process material requests, confirm deliveries, perform quality inspections on arrival, and trigger inventory updates.

**JG Project Requirements**:
- Material requests from tasks (`JgTask` → material requirements)
- Delivery confirmation (`SupplyChainRoute.actual_arrival`)
- Quality inspection on arrival (material quality certification)
- Inventory updates (`InventoryItem` quantity updates)

**Flow Agent Capabilities**:
- ✅ Workflow engine for delivery processes
- ✅ Event bus for delivery notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Material Delivery Workflow:
  Node 1: Material Request Created (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Material request (task_id, material_type, quantity)
  Node 2: Check Inventory Availability (Core Agent: JG Inventory Manager)
    └─> Edge (conditional): Inventory available?
  Node 3: Create Supply Chain Route (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Route created
  Node 4: Execute Transportation (Transportation Workflow)
    └─> Edge (dependency): Transportation complete
  Node 5: Perform Quality Inspection (Core Agent: JG Inventory Manager)
    └─> Edge (conditional): Quality meets requirements?
  Node 6: Confirm Delivery (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Delivery confirmation
  Node 7: Update Inventory (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Inventory quantity update
  Node 8: Notify Task (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Material available notification
```

**Implementation Approach**:
1. Create workflow template: `create_jg_material_delivery_workflow()`
2. Integrate with Transportation Workflow (dependency)
3. Handle quality inspection logic
4. Update inventory quantities
5. Notify tasks when materials available
6. Publish events on delivery changes (`material_request_created`, `inventory_checked`, `delivery_confirmed`, `quality_inspection_passed`)

**Event Bus Integration**:
- `material_request_created` event: Triggered when task requires materials
- `inventory_available` event: Triggered when inventory sufficient
- `inventory_low` event: Triggered when inventory below reorder point
- `delivery_confirmed` event: Triggered when delivery complete
- `quality_inspection_passed` event: Triggered when quality meets requirements
- `quality_inspection_failed` event: Triggered when quality below requirements

---

### Workflow Type 3: Processing Facility Workflows

**Purpose**: Assign processing tasks, manage capacity, implement quality control checkpoints, and track output.

**JG Project Requirements**:
- Processing tasks (cultivation → processing → construction materials)
- Processing facility capacity management
- Quality control checkpoints
- Output tracking (processed materials)

**Flow Agent Capabilities**:
- ✅ Workflow engine for processing workflows
- ✅ Event bus for capacity notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Processing Facility Workflow:
  Node 1: Raw Material Arrived (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Raw material data (type, quantity, batch_id)
  Node 2: Check Facility Capacity (Core Agent: JG Supply Chain)
    └─> Edge (conditional): Capacity available?
  Node 3: Assign Processing Task (Core Agent: JG Task Tracker)
    └─> Edge (data_flow): Processing task assigned
  Node 4: Perform Processing (Worker)
    └─> Edge (dependency): Processing complete
  Node 5: Quality Control Checkpoint (Core Agent: JG Inventory Manager)
    └─> Edge (conditional): Quality meets standards?
  Node 6: Track Output (Core Agent: JG Inventory Manager)
    └─> Edge (data_flow): Processed material output
  Node 7: Update Facility Capacity (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Capacity update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_processing_facility_workflow()`
2. Implement capacity management logic
3. Handle quality control checkpoints
4. Track processed material output
5. Update facility capacity
6. Publish events on processing changes (`raw_material_arrived`, `processing_task_assigned`, `processing_complete`, `quality_checkpoint_passed`)

**Event Bus Integration**:
- `raw_material_arrived` event: Triggered when raw material arrives at facility
- `facility_capacity_checked` event: Triggered when capacity checked
- `processing_task_assigned` event: Triggered when processing task assigned
- `processing_complete` event: Triggered when processing finished
- `quality_checkpoint_passed` event: Triggered when quality meets standards
- `output_tracked` event: Triggered when processed material output recorded

---

### Workflow Type 4: Carbon Tracking Workflows

**Purpose**: Trigger carbon calculations, track sequestration, manage carbon credit workflows, and generate environmental reports.

**JG Project Requirements**:
- Carbon footprint calculation (`SupplyChainRoute.carbon_footprint_kg`)
- Carbon sequestration tracking (from renewable materials)
- Carbon credit workflows
- Environmental reporting

**Flow Agent Capabilities**:
- ✅ Workflow engine for carbon tracking workflows
- ✅ Event bus for carbon calculation triggers
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Carbon Tracking Workflow:
  Node 1: Activity Trigger (Various: Transportation, Processing, Construction)
    └─> Edge (data_flow): Activity data (type, material, quantity, distance)
  Node 2: Calculate Carbon Footprint (Flow Agent: Carbon calculation)
    └─> Edge (data_flow): Carbon footprint (kg CO2)
  Node 3: Calculate Sequestration (Flow Agent: Sequestration calculation)
    └─> Edge (data_flow): Carbon sequestered (kg CO2)
  Node 4: Net Carbon Calculation (Flow Agent: Net carbon)
    └─> Edge (data_flow): Net carbon (footprint - sequestration)
  Node 5: Update Carbon Credits (Core Agent: JG Supply Chain)
    └─> Edge (data_flow): Carbon credit balance
  Node 6: Generate Environmental Report (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Environmental metrics
```

**Implementation Approach**:
1. Create workflow template: `create_jg_carbon_tracking_workflow()`
2. Implement carbon footprint calculation (transportation, processing, construction)
3. Implement carbon sequestration calculation (renewable materials)
4. Calculate net carbon (footprint - sequestration)
5. Update carbon credit balances
6. Generate environmental reports
7. Publish events on carbon changes (`carbon_calculated`, `sequestration_calculated`, `carbon_credit_updated`, `environmental_report_generated`)

**Event Bus Integration**:
- `carbon_calculation_triggered` event: Triggered when activity requires carbon calculation
- `carbon_footprint_calculated` event: Triggered when carbon footprint calculated
- `sequestration_calculated` event: Triggered when sequestration calculated
- `net_carbon_calculated` event: Triggered when net carbon calculated
- `carbon_credit_updated` event: Triggered when carbon credit balance updated
- `environmental_report_generated` event: Triggered when environmental report created

---

## Phase 3: Democratic Process Workflows (Months 9-10)

### Workflow Type 1: Worker Election Workflows

**Purpose**: Schedule elections, manage candidate nominations, coordinate voting processes, and tabulate results.

**JG Project Requirements**:
- Worker elections (for leadership positions, committees)
- Candidate nomination process
- Voting coordination
- Results tabulation and announcement

**Flow Agent Capabilities**:
- ✅ Workflow engine for election processes
- ✅ Event bus for election notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Worker Election Workflow:
  Node 1: Election Scheduled (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Election data (position, date, eligible voters)
  Node 2: Candidate Nomination Period (Core Agent: JG Project Manager)
    └─> Edge (dependency): Nomination period complete
  Node 3: Validate Candidates (Flow Agent: Candidate validation)
    └─> Edge (conditional): Candidates valid?
  Node 4: Voting Period (Core Agent: JG Project Manager)
    └─> Edge (dependency): Voting period complete
  Node 5: Tabulate Results (Flow Agent: Vote counting)
    └─> Edge (data_flow): Election results
  Node 6: Announce Results (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Results announcement
  Node 7: Update Leadership Positions (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Leadership update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_worker_election_workflow()`
2. Implement candidate nomination validation
3. Implement voting period coordination
4. Implement vote tabulation (secure, verifiable)
5. Announce results
6. Update leadership positions
7. Publish events on election changes (`election_scheduled`, `candidate_nominated`, `voting_started`, `voting_complete`, `results_announced`)

**Event Bus Integration**:
- `election_scheduled` event: Triggered when election scheduled
- `candidate_nominated` event: Triggered when candidate nominated
- `voting_started` event: Triggered when voting period begins
- `vote_cast` event: Triggered when worker casts vote
- `voting_complete` event: Triggered when voting period ends
- `results_announced` event: Triggered when results announced

---

### Workflow Type 2: Town Hall Coordination Workflows

**Purpose**: Schedule meetings, manage agendas, track discussion topics, and record decisions.

**JG Project Requirements**:
- Town hall meetings (regular community meetings)
- Agenda management
- Discussion topic tracking
- Decision recording

**Flow Agent Capabilities**:
- ✅ Workflow engine for meeting coordination
- ✅ Event bus for meeting notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Town Hall Coordination Workflow:
  Node 1: Meeting Scheduled (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Meeting data (date, time, location, agenda)
  Node 2: Agenda Items Added (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Agenda items
  Node 3: Notify Participants (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Meeting notifications
  Node 4: Meeting Conducted (Participants)
    └─> Edge (dependency): Meeting complete
  Node 5: Record Discussion Topics (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Discussion topics
  Node 6: Record Decisions (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Decisions made
  Node 7: Distribute Minutes (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Meeting minutes
```

**Implementation Approach**:
1. Create workflow template: `create_jg_town_hall_coordination_workflow()`
2. Implement agenda management
3. Implement participant notification
4. Record discussion topics and decisions
5. Generate and distribute meeting minutes
6. Publish events on meeting changes (`meeting_scheduled`, `agenda_updated`, `meeting_started`, `meeting_complete`, `decisions_recorded`)

**Event Bus Integration**:
- `meeting_scheduled` event: Triggered when town hall scheduled
- `agenda_updated` event: Triggered when agenda items added
- `meeting_started` event: Triggered when meeting begins
- `discussion_topic_added` event: Triggered when discussion topic raised
- `decision_made` event: Triggered when decision recorded
- `meeting_complete` event: Triggered when meeting ends
- `minutes_distributed` event: Triggered when minutes distributed

---

### Workflow Type 3: Grievance and Mediation Workflows

**Purpose**: Handle grievance submissions, schedule mediations, track resolutions, and manage appeal processes.

**JG Project Requirements**:
- Grievance submission process
- Mediation scheduling
- Resolution tracking
- Appeal processes

**Flow Agent Capabilities**:
- ✅ Workflow engine for grievance processes
- ✅ Event bus for grievance notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Grievance and Mediation Workflow:
  Node 1: Grievance Submitted (Worker)
    └─> Edge (data_flow): Grievance data (worker_id, issue, details)
  Node 2: Validate Grievance (Flow Agent: Grievance validation)
    └─> Edge (conditional): Grievance valid?
  Node 3: Schedule Mediation (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Mediation scheduled
  Node 4: Conduct Mediation (Mediator, Parties)
    └─> Edge (dependency): Mediation complete
  Node 5: Record Resolution (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Resolution data
  Node 6: Track Resolution Implementation (Core Agent: JG Project Manager)
    └─> Edge (dependency): Resolution implemented
  Node 7: Handle Appeal (if needed) (Core Agent: JG Project Manager)
    └─> Edge (conditional): Appeal filed?
```

**Implementation Approach**:
1. Create workflow template: `create_jg_grievance_mediation_workflow()`
2. Implement grievance validation
3. Implement mediation scheduling
4. Track resolution implementation
5. Handle appeal processes
6. Publish events on grievance changes (`grievance_submitted`, `grievance_validated`, `mediation_scheduled`, `mediation_complete`, `resolution_recorded`, `appeal_filed`)

**Event Bus Integration**:
- `grievance_submitted` event: Triggered when grievance submitted
- `grievance_validated` event: Triggered when grievance passes validation
- `mediation_scheduled` event: Triggered when mediation scheduled
- `mediation_started` event: Triggered when mediation begins
- `mediation_complete` event: Triggered when mediation finished
- `resolution_recorded` event: Triggered when resolution recorded
- `appeal_filed` event: Triggered when appeal filed

---

### Workflow Type 4: Career Ladder Workflows

**Purpose**: Track skill certifications, manage promotion eligibility, coordinate training programs, and track career progression.

**JG Project Requirements**:
- Skill certification tracking
- Promotion eligibility
- Training program coordination
- Career progression tracking

**Flow Agent Capabilities**:
- ✅ Workflow engine for career progression processes
- ✅ Event bus for certification notifications
- ✅ Integration with Core Agent JG modules

**Workflow Pattern Design**:
```
Career Ladder Workflow:
  Node 1: Skill Certification Request (Worker)
    └─> Edge (data_flow): Certification request (worker_id, skill_type)
  Node 2: Validate Certification Requirements (Flow Agent: Requirements check)
    └─> Edge (conditional): Requirements met?
  Node 3: Schedule Certification Test (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Test scheduled
  Node 4: Conduct Certification Test (Tester)
    └─> Edge (dependency): Test complete
  Node 5: Record Certification (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Certification recorded
  Node 6: Check Promotion Eligibility (Flow Agent: Eligibility check)
    └─> Edge (conditional): Promotion eligible?
  Node 7: Update Career Progression (Core Agent: JG Project Manager)
    └─> Edge (data_flow): Career progression update
```

**Implementation Approach**:
1. Create workflow template: `create_jg_career_ladder_workflow()`
2. Implement certification requirement validation
3. Implement promotion eligibility checking
4. Coordinate training programs
5. Track career progression
6. Publish events on career changes (`certification_requested`, `certification_test_scheduled`, `certification_earned`, `promotion_eligible`, `career_progression_updated`)

**Event Bus Integration**:
- `certification_requested` event: Triggered when worker requests certification
- `certification_test_scheduled` event: Triggered when test scheduled
- `certification_earned` event: Triggered when certification earned
- `promotion_eligible` event: Triggered when worker becomes promotion eligible
- `training_program_scheduled` event: Triggered when training scheduled
- `career_progression_updated` event: Triggered when career progression changes

---

## Flow Agent Capabilities Mapping

### Existing Capabilities

**Workflow Engine** (`workflow_engine.zig`):
- ✅ DAG-based workflow execution
- ✅ Workflow nodes with dependencies
- ✅ Edge types: `dependency`, `data_flow`, `conditional`
- ✅ Topological sort execution (iterative)
- ✅ Workflow state management
- ✅ Workflow status tracking

**Event Bus** (`event_bus.zig`):
- ✅ Event publishing and subscription
- ✅ Event filtering by type, source, destination
- ✅ Bounded event queue
- ✅ Async pattern event types (HTTP, WebSocket, File I/O)

**Workflow Templates** (`workflow_templates.zig`):
- ✅ Pre-built workflow templates
- ✅ Template builders for common patterns
- ✅ Integration examples

**Agent Coordinator** (`agent_coordinator.zig`):
- ✅ Agent registry
- ✅ Agent health monitoring
- ✅ Agent-to-agent RPC

**Workflow Scheduler** (`workflow_scheduler.zig`):
- ✅ One-time, interval, and recurring schedules
- ✅ Cron parser with step value support
- ✅ Schedule management

**Workflow Visualizer** (`workflow_visualizer.zig`):
- ✅ Hierarchical layout
- ✅ DAG visualization

### Capabilities Needed for JG Project

**New Workflow Templates** (to be created):
- `create_jg_task_dependency_workflow()`
- `create_jg_worker_assignment_workflow()`
- `create_jg_quality_assurance_workflow()`
- `create_jg_time_logging_workflow()`
- `create_jg_transportation_workflow()`
- `create_jg_material_delivery_workflow()`
- `create_jg_processing_facility_workflow()`
- `create_jg_carbon_tracking_workflow()`
- `create_jg_worker_election_workflow()`
- `create_jg_town_hall_coordination_workflow()`
- `create_jg_grievance_mediation_workflow()`
- `create_jg_career_ladder_workflow()`

**New Event Types** (to be added):
- Task events: `task_dependency_ready`, `task_blocked`, `task_critical_path_updated`, `task_assigned`, `task_completed`, `task_failed`
- Worker events: `worker_available`, `worker_assigned`, `assignment_conflict`, `workload_imbalanced`
- Quality events: `quality_check_scheduled`, `quality_approved`, `quality_failed`, `rework_required`
- Time events: `time_entry_submitted`, `time_entry_validated`, `time_entry_invalid`, `wage_calculated`, `overtime_detected`
- Transportation events: `material_request_received`, `route_optimized`, `vehicle_assigned`, `transportation_started`, `delivery_confirmed`
- Material events: `material_request_created`, `inventory_available`, `inventory_low`, `quality_inspection_passed`
- Processing events: `raw_material_arrived`, `processing_task_assigned`, `processing_complete`, `quality_checkpoint_passed`
- Carbon events: `carbon_calculation_triggered`, `carbon_footprint_calculated`, `sequestration_calculated`, `carbon_credit_updated`
- Election events: `election_scheduled`, `candidate_nominated`, `voting_started`, `vote_cast`, `results_announced`
- Meeting events: `meeting_scheduled`, `agenda_updated`, `meeting_started`, `decision_made`, `meeting_complete`
- Grievance events: `grievance_submitted`, `grievance_validated`, `mediation_scheduled`, `mediation_complete`, `resolution_recorded`
- Career events: `certification_requested`, `certification_earned`, `promotion_eligible`, `career_progression_updated`

**New Helper Functions** (to be created):
- Skill matching logic
- Workload balancing calculation
- Quality threshold evaluation
- Time entry validation
- Overtime detection
- Carbon footprint calculation
- Carbon sequestration calculation
- Vote tabulation
- Certification requirement validation
- Promotion eligibility checking

---

## Integration Points

### Core Agent Integration

**JG Project Manager** (`grain_jg_project`):
- Project lifecycle management
- Project phase tracking
- Quality metrics aggregation
- Leadership position management
- Meeting coordination

**JG Task Tracker** (`grain_jg_task`):
- Task creation and assignment
- Task status updates
- Task dependency management
- Quality score updates
- Time logging

**JG Supply Chain** (`grain_jg_supply_chain`):
- Route creation and optimization
- Vehicle assignment
- Transportation tracking
- Carbon footprint tracking
- Facility capacity management

**JG Inventory Manager** (`grain_jg_inventory`):
- Inventory level checks
- Material quality certification
- Inventory updates
- Batch tracking

**API Contracts** (to be coordinated):
- Task dependency query API
- Worker assignment API
- Quality check scheduling API
- Time entry submission API
- Route optimization API
- Material request API
- Election coordination API
- Meeting coordination API
- Grievance submission API
- Certification tracking API

### Silo Agent Integration

**Storage Keys**:
- `jg_task:*` — Task data storage
- `jg_supply_chain:*` — Supply chain data storage
- `jg_worker:*` — Worker profile data storage
- `jg_project:*` — Project data storage (for reference)

**Storage Operations**:
- Query tasks by dependencies
- Query workers by skills
- Query worker workload
- Update task status
- Update worker assignments
- Update inventory levels

### Grainbank Integration

**Wage Payment Triggers**:
- Time logging workflows trigger wage calculations
- Overtime detection triggers premium payments
- Benefits eligibility triggers benefit payments

**Payment Processing**:
- Worker account crediting (via events or API)
- Material purchase payments to cooperatives
- Benefits administration payments

### Court Agent Integration (Months 7-9)

**LLM-Assisted Route Optimization**:
- Route optimization requests
- Optimization recommendations
- Carbon footprint calculation assistance

### Workspace Agent Integration (Months 3-8)

**Desktop Dashboards**:
- Workflow visualization
- Democratic process dashboards
- Election results display
- Meeting agenda and minutes display

---

## Implementation Timeline

### Phase 1: Task Workflow Orchestration (Months 4-6)

**Month 4**:
- Review Core Agent JG module API contracts
- Design workflow templates for task workflows
- Implement task dependency workflow template
- Implement worker assignment workflow template

**Month 5**:
- Implement quality assurance workflow template
- Implement time logging workflow template
- Add JG project event types to Event Bus
- Create helper functions (skill matching, workload balancing, etc.)

**Month 6**:
- Integration testing with Core Agent JG modules
- End-to-end testing of task workflows
- Documentation and examples

### Phase 2: Supply Chain Workflow Orchestration (Months 7-8)

**Month 7**:
- Design workflow templates for supply chain workflows
- Implement transportation workflow template
- Implement material delivery workflow template
- Integrate with Court Agent LLM route optimization

**Month 8**:
- Implement processing facility workflow template
- Implement carbon tracking workflow template
- Integration testing with Core Agent JG modules
- End-to-end testing of supply chain workflows

### Phase 3: Democratic Process Workflows (Months 9-10)

**Month 9**:
- Design workflow templates for democratic process workflows
- Implement worker election workflow template
- Implement town hall coordination workflow template

**Month 10**:
- Implement grievance and mediation workflow template
- Implement career ladder workflow template
- Integration testing with Core Agent JG modules
- End-to-end testing of democratic process workflows
- Complete documentation

---

## Next Steps

1. ⏳ **Continue Planning** (current):
   - Review Core Agent JG module API contracts (when available, Months 1-6)
   - Refine workflow template designs
   - Plan helper function implementations

2. ⏳ **Coordinate with Core Agent** (Months 3-4):
   - Review API contracts for JG modules
   - Coordinate on event bus integration
   - Plan workflow trigger points

3. ⏳ **Begin Implementation** (Months 4-6):
   - Implement Phase 1 workflow templates
   - Add JG project event types
   - Create helper functions
   - Integration testing

---

**Date**: 2025-12-30-015221-pst  
**Agent**: Grain Flow Agent (9th Agent)  
**Status**: Planning Document Complete — Ready for Implementation (Months 4-10)
