//! Grain Bubble DAG Integration Tests.
//!
//! Why: Test DAG integration for design graph storage.
//! Architecture: Unit tests for DAG integration.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-054259-pst: Grain Bubble Agent

const std = @import("std");
const testing = std.testing;
const dag_integration = @import("grain_bubble").dag_integration;

test "dag integration init" {
    const integration = dag_integration.DagIntegration.init();
    std.debug.assert(integration.dag == null);
    std.debug.assert(integration.design_history_len == 0);
    std.debug.assert(integration.next_version_id == 1);
    std.debug.assert(integration.next_event_id == 1);
}

test "dag integration set dag" {
    var integration = dag_integration.DagIntegration.init();
    // Note: In real implementation, would create actual DagCore instance.
    // For Phase 3, testing interface structure.
    std.debug.assert(integration.dag == null);
}

test "dag integration record event" {
    var integration = dag_integration.DagIntegration.init();
    var event = dag_integration.DesignEvent.init();
    event.event_id = 1;
    event.event_type = .add_shape;
    const result = integration.record_event(&event);
    // Returns false when DAG not set (expected for Phase 3).
    std.debug.assert(result == false);
}

test "dag integration create version" {
    var integration = dag_integration.DagIntegration.init();
    const canvas_id: u32 = 1;
    const description = "Initial design";
    const version_id = integration.create_version(canvas_id, description);
    std.debug.assert(version_id != null);
    std.debug.assert(version_id.? > 0);
    std.debug.assert(integration.design_history_len == 1);
}

test "dag integration get version" {
    var integration = dag_integration.DagIntegration.init();
    const canvas_id: u32 = 1;
    const description = "Initial design";
    const version_id = integration.create_version(canvas_id, description);
    std.debug.assert(version_id != null);
    if (integration.get_version(version_id.?)) |version| {
        std.debug.assert(version.version_id == version_id.?);
        std.debug.assert(version.canvas_id == canvas_id);
    }
}

test "dag integration multiple versions" {
    var integration = dag_integration.DagIntegration.init();
    const version1 = integration.create_version(1, "Version 1");
    const version2 = integration.create_version(1, "Version 2");
    const version3 = integration.create_version(1, "Version 3");
    std.debug.assert(version1 != null);
    std.debug.assert(version2 != null);
    std.debug.assert(version3 != null);
    std.debug.assert(integration.design_history_len == 3);
    std.debug.assert(version1.? != version2.?);
    std.debug.assert(version2.? != version3.?);
}

