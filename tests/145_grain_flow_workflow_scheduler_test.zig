//! Grain Flow Workflow Scheduler Tests
//!
//! Tests for workflow scheduling functionality.

const std = @import("std");
const grain_flow = @import("grain_flow");

test "workflow scheduler initialization" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    const scheduler = grain_flow.WorkflowScheduler.init(&engine);
    std.debug.assert(scheduler.schedules_len == 0);
    std.debug.assert(scheduler.next_schedule_id == 1);
}

test "schedule once workflow" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create a workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    std.debug.assert(workflow_id != null);

    // Schedule it for one-time execution.
    const schedule_id = scheduler.schedule_once(
        workflow_id.?,
        "test_schedule",
        1000000, // Future timestamp
    );
    std.debug.assert(schedule_id != null);
    std.debug.assert(scheduler.schedules_len == 1);
}

test "schedule interval workflow" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create a workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    std.debug.assert(workflow_id != null);

    // Schedule it for interval execution.
    const schedule_id = scheduler.schedule_interval(
        workflow_id.?,
        "interval_schedule",
        60000, // 1 minute interval
        1000000, // First execution
    );
    std.debug.assert(schedule_id != null);
    std.debug.assert(scheduler.schedules_len == 1);

    // Verify schedule properties.
    const schedule = scheduler.get_schedule(schedule_id.?);
    std.debug.assert(schedule != null);
    std.debug.assert(schedule.?.schedule_type == grain_flow.ScheduleType.interval);
    std.debug.assert(schedule.?.interval_ms == 60000);
}

test "schedule recurring workflow" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create a workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    std.debug.assert(workflow_id != null);

    // Schedule it for recurring execution.
    const schedule_id = scheduler.schedule_recurring(
        workflow_id.?,
        "recurring_schedule",
        "0 * * * *", // Every hour
        1000000, // Next execution
    );
    std.debug.assert(schedule_id != null);
    std.debug.assert(scheduler.schedules_len == 1);

    // Verify schedule properties.
    const schedule = scheduler.get_schedule(schedule_id.?);
    std.debug.assert(schedule != null);
    std.debug.assert(schedule.?.schedule_type == grain_flow.ScheduleType.recurring);
}

test "check and execute due workflows" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create a workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    std.debug.assert(workflow_id != null);

    // Schedule it for immediate execution (past timestamp).
    const schedule_id = scheduler.schedule_once(
        workflow_id.?,
        "immediate_schedule",
        1000, // Past timestamp
    );
    std.debug.assert(schedule_id != null);

    // Check and execute (should execute).
    const executed = scheduler.check_and_execute(2000);
    std.debug.assert(executed == 1);

    // Verify schedule was disabled (one-time).
    const schedule = scheduler.get_schedule(schedule_id.?);
    std.debug.assert(schedule != null);
    std.debug.assert(!schedule.?.enabled);
    std.debug.assert(schedule.?.execution_count == 1);
}

test "enable and disable schedule" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create and schedule workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    const schedule_id = scheduler.schedule_once(
        workflow_id.?,
        "test_schedule",
        1000000,
    );
    std.debug.assert(schedule_id != null);

    // Disable schedule.
    const disabled = scheduler.disable_schedule(schedule_id.?);
    std.debug.assert(disabled);
    std.debug.assert(scheduler.get_enabled_count() == 0);

    // Enable schedule.
    const enabled = scheduler.enable_schedule(schedule_id.?);
    std.debug.assert(enabled);
    std.debug.assert(scheduler.get_enabled_count() == 1);
}

test "remove schedule" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create and schedule workflow.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    const schedule_id = scheduler.schedule_once(
        workflow_id.?,
        "test_schedule",
        1000000,
    );
    std.debug.assert(schedule_id != null);
    std.debug.assert(scheduler.schedules_len == 1);

    // Remove schedule.
    const removed = scheduler.remove_schedule(schedule_id.?);
    std.debug.assert(removed);
    std.debug.assert(scheduler.schedules_len == 0);
}

test "interval schedule next execution" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create and schedule workflow with interval.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    const schedule_id = scheduler.schedule_interval(
        workflow_id.?,
        "interval_schedule",
        60000, // 1 minute
        1000000, // First execution
    );
    std.debug.assert(schedule_id != null);

    // Execute at first execution time.
    const executed = scheduler.check_and_execute(1000000);
    std.debug.assert(executed == 1);

    // Verify next execution was calculated.
    const schedule = scheduler.get_schedule(schedule_id.?);
    std.debug.assert(schedule != null);
    std.debug.assert(schedule.?.next_execution == 1000000 + 60000);
    std.debug.assert(schedule.?.execution_count == 1);
}

test "recurring schedule cron parser" {
    var event_bus = grain_flow.EventBus.init();
    var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
    var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
    var scheduler = grain_flow.WorkflowScheduler.init(&engine);

    // Create and schedule workflow with recurring cron.
    const workflow_id = engine.create_workflow("test_workflow", 10000);
    const schedule_id = scheduler.schedule_recurring(
        workflow_id.?,
        "recurring_schedule",
        "0 * * * *", // Every hour
        1000000, // First execution
    );
    std.debug.assert(schedule_id != null);

    // Execute at first execution time.
    const executed = scheduler.check_and_execute(1000000);
    std.debug.assert(executed == 1);

    // Verify next execution was calculated (should be 1 hour later).
    const schedule = scheduler.get_schedule(schedule_id.?);
    std.debug.assert(schedule != null);
    std.debug.assert(schedule.?.next_execution == 1000000 + 3600000); // 1 hour
    std.debug.assert(schedule.?.execution_count == 1);
}

    test "recurring schedule cron parser every minute" {
        var event_bus = grain_flow.EventBus.init();
        var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
        var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
        var scheduler = grain_flow.WorkflowScheduler.init(&engine);

        // Create and schedule workflow with recurring cron (every minute).
        const workflow_id = engine.create_workflow("test_workflow", 10000);
        const schedule_id = scheduler.schedule_recurring(
            workflow_id.?,
            "recurring_schedule",
            "* * * * *", // Every minute
            1000000, // First execution
        );
        std.debug.assert(schedule_id != null);

        // Execute at first execution time.
        const executed = scheduler.check_and_execute(1000000);
        std.debug.assert(executed == 1);

        // Verify next execution was calculated (should be 1 minute later).
        const schedule = scheduler.get_schedule(schedule_id.?);
        std.debug.assert(schedule != null);
        std.debug.assert(schedule.?.next_execution == 1000000 + 60000); // 1 minute
        std.debug.assert(schedule.?.execution_count == 1);
    }

    test "recurring schedule cron parser step value" {
        var event_bus = grain_flow.EventBus.init();
        var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
        var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
        var scheduler = grain_flow.WorkflowScheduler.init(&engine);

        // Create and schedule workflow with recurring cron (every 5 minutes).
        const workflow_id = engine.create_workflow("test_workflow", 10000);
        const schedule_id = scheduler.schedule_recurring(
            workflow_id.?,
            "recurring_schedule",
            "*/5 * * * *", // Every 5 minutes
            1000000, // First execution
        );
        std.debug.assert(schedule_id != null);

        // Execute at first execution time.
        const executed = scheduler.check_and_execute(1000000);
        std.debug.assert(executed == 1);

        // Verify next execution was calculated (should be 5 minutes later).
        const schedule = scheduler.get_schedule(schedule_id.?);
        std.debug.assert(schedule != null);
        std.debug.assert(schedule.?.next_execution == 1000000 + 5 * 60000); // 5 minutes
        std.debug.assert(schedule.?.execution_count == 1);
    }

    test "recurring schedule cron parser step value every 10 minutes" {
        var event_bus = grain_flow.EventBus.init();
        var coordinator = grain_flow.AgentCoordinator.init(&event_bus);
        var engine = grain_flow.WorkflowEngine.init(&event_bus, &coordinator);
        var scheduler = grain_flow.WorkflowScheduler.init(&engine);

        // Create and schedule workflow with recurring cron (every 10 minutes).
        const workflow_id = engine.create_workflow("test_workflow", 10000);
        const schedule_id = scheduler.schedule_recurring(
            workflow_id.?,
            "recurring_schedule",
            "*/10 * * * *", // Every 10 minutes
            1000000, // First execution
        );
        std.debug.assert(schedule_id != null);

        // Execute at first execution time.
        const executed = scheduler.check_and_execute(1000000);
        std.debug.assert(executed == 1);

        // Verify next execution was calculated (should be 10 minutes later).
        const schedule = scheduler.get_schedule(schedule_id.?);
        std.debug.assert(schedule != null);
        std.debug.assert(schedule.?.next_execution == 1000000 + 10 * 60000); // 10 minutes
        std.debug.assert(schedule.?.execution_count == 1);
    }
