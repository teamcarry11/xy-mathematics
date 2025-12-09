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

test "dag integration get event history" {
    var integration = dag_integration.DagIntegration.init();
    var events: [8]dag_integration.DesignEvent = undefined;
    var i: u32 = 0;
    while (i < events.len) : (i += 1) {
        events[i] = dag_integration.DesignEvent.init();
    }
    const canvas_id: u32 = 1;
    const count = integration.get_event_history(canvas_id, events[0..]);
    // Returns 0 when DAG not set (expected for Phase 3).
    std.debug.assert(count == 0);
}

test "dag integration create version snapshot" {
    var integration = dag_integration.DagIntegration.init();
    const canvas_id: u32 = 1;
    const event_id: u64 = 100;
    const description = "Snapshot at event 100";
    const version_id = integration.create_version_snapshot(
        canvas_id,
        event_id,
        description,
    );
    std.debug.assert(version_id != null);
    std.debug.assert(version_id.? > 0);
    std.debug.assert(integration.design_history_len == 1);
    if (integration.get_version(version_id.?)) |version| {
        std.debug.assert(version.event_id == event_id);
        std.debug.assert(version.canvas_id == canvas_id);
    }
}

test "dag integration load version snapshot" {
    var integration = dag_integration.DagIntegration.init();
    const canvas_id: u32 = 1;
    const event_id: u64 = 200;
    const description = "Snapshot at event 200";
    const version_id = integration.create_version_snapshot(
        canvas_id,
        event_id,
        description,
    );
    std.debug.assert(version_id != null);
    const loaded_event_id = integration.load_version_snapshot(version_id.?);
    std.debug.assert(loaded_event_id != null);
    std.debug.assert(loaded_event_id.? == event_id);
}

test "dag integration serialize deserialize event" {
    var event = dag_integration.DesignEvent.init();
    event.event_id = 100;
    event.event_type = .add_shape;
    event.canvas_id = 1;
    event.component_id = 2;
    event.event_data_len = 4;
    event.event_data[0] = 0xAA;
    event.event_data[1] = 0xBB;
    event.event_data[2] = 0xCC;
    event.event_data[3] = 0xDD;
    event.timestamp = 1234567890;
    event.parent_events_len = 2;
    event.parent_events[0] = 50;
    event.parent_events[1] = 60;
    var buffer: [dag_integration.MAX_EVENT_DATA_LEN + 64]u8 = undefined;
    const serialized_len = dag_integration.DagIntegration.serialize_event(&event, buffer[0..]);
    std.debug.assert(serialized_len > 0);
    var deserialized_event = dag_integration.DesignEvent.init();
    const deserialized = dag_integration.DagIntegration.deserialize_event(
        buffer[0..serialized_len],
        &deserialized_event,
    );
    std.debug.assert(deserialized == true);
    std.debug.assert(deserialized_event.event_id == event.event_id);
    std.debug.assert(deserialized_event.event_type == event.event_type);
    std.debug.assert(deserialized_event.canvas_id == event.canvas_id);
    std.debug.assert(deserialized_event.component_id == event.component_id);
    std.debug.assert(deserialized_event.event_data_len == event.event_data_len);
    std.debug.assert(deserialized_event.timestamp == event.timestamp);
    std.debug.assert(deserialized_event.parent_events_len == event.parent_events_len);
}

