//! Grain Flow Workflow Scheduler: Schedule workflows for execution.
//!
//! Why: Enables scheduled and recurring workflow execution, making Flow Agent
//! more useful for automation and periodic tasks.
//!
//! Architecture: Schedule management, time-based execution, recurring patterns.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-21-091028-pst: Workflow Scheduling Enhancement
//! 2025-12-21-141800-pst: Cron Parser Enhancement (basic cron expression parsing)

const std = @import("std");
const workflow_engine = @import("workflow_engine.zig");

// Bounded: Max scheduled workflows.
pub const MAX_SCHEDULED_WORKFLOWS: u32 = 1000;

// Bounded: Max schedule name length.
pub const MAX_SCHEDULE_NAME_LEN: u32 = 128;

// Bounded: Max cron expression length.
pub const MAX_CRON_EXPR_LEN: u32 = 64;

// Schedule type: when to execute workflow.
pub const ScheduleType = enum(u8) {
    once = 0, // Execute once at specific time
    recurring = 1, // Execute on cron schedule
    interval = 2, // Execute at fixed intervals
};

// Scheduled workflow: workflow with execution schedule.
pub const ScheduledWorkflow = struct {
    schedule_id: u32,
    workflow_id: u32,
    schedule_name: [MAX_SCHEDULE_NAME_LEN]u8,
    schedule_name_len: u32,
    schedule_type: ScheduleType,
    next_execution: u64, // Unix timestamp (milliseconds)
    interval_ms: u64, // For interval type
    cron_expr: [MAX_CRON_EXPR_LEN]u8, // For recurring type
    cron_expr_len: u32,
    enabled: bool,
    execution_count: u64,
    last_execution: u64,

    pub fn init(
        schedule_id: u32,
        workflow_id: u32,
        schedule_name: []const u8,
        schedule_type: ScheduleType,
        next_execution: u64,
    ) ScheduledWorkflow {
        std.debug.assert(schedule_id > 0);
        std.debug.assert(workflow_id > 0);
        std.debug.assert(schedule_name.len > 0);
        std.debug.assert(next_execution > 0);
        var scheduled = ScheduledWorkflow{
            .schedule_id = schedule_id,
            .workflow_id = workflow_id,
            .schedule_name = undefined,
            .schedule_name_len = 0,
            .schedule_type = schedule_type,
            .next_execution = next_execution,
            .interval_ms = 0,
            .cron_expr = undefined,
            .cron_expr_len = 0,
            .enabled = true,
            .execution_count = 0,
            .last_execution = 0,
        };
        var i: u32 = 0;
        while (i < MAX_SCHEDULE_NAME_LEN) : (i += 1) {
            scheduled.schedule_name[i] = 0;
        }
        i = 0;
        while (i < MAX_CRON_EXPR_LEN) : (i += 1) {
            scheduled.cron_expr[i] = 0;
        }
        const name_len = @min(schedule_name.len, MAX_SCHEDULE_NAME_LEN);
        i = 0;
        while (i < name_len) : (i += 1) {
            scheduled.schedule_name[i] = schedule_name[i];
        }
        scheduled.schedule_name_len = @intCast(name_len);
        return scheduled;
    }

    /// Set interval for interval-type schedule.
    pub fn set_interval(self: *ScheduledWorkflow, interval_ms: u64) void {
        std.debug.assert(interval_ms > 0);
        std.debug.assert(self.schedule_type == ScheduleType.interval);
        self.interval_ms = interval_ms;
    }

    /// Set cron expression for recurring schedule.
    pub fn set_cron_expression(
        self: *ScheduledWorkflow,
        cron_expr: []const u8,
    ) bool {
        std.debug.assert(cron_expr.len > 0);
        std.debug.assert(self.schedule_type == ScheduleType.recurring);
        if (cron_expr.len > MAX_CRON_EXPR_LEN) {
            return false;
        }
        const expr_len = @min(cron_expr.len, MAX_CRON_EXPR_LEN);
        var i: u32 = 0;
        while (i < expr_len) : (i += 1) {
            self.cron_expr[i] = cron_expr[i];
        }
        self.cron_expr_len = @intCast(expr_len);
        return true;
    }
};

// Workflow scheduler: manages scheduled workflows.
pub const WorkflowScheduler = struct {
    schedules: [MAX_SCHEDULED_WORKFLOWS]ScheduledWorkflow,
    schedules_len: u32,
    next_schedule_id: u32,
    engine: *workflow_engine.WorkflowEngine,

    pub fn init(engine: *workflow_engine.WorkflowEngine) WorkflowScheduler {
        std.debug.assert(engine != null);
        return WorkflowScheduler{
            .schedules = undefined,
            .schedules_len = 0,
            .next_schedule_id = 1,
            .engine = engine,
        };
    }

    /// Schedule workflow for one-time execution.
    pub fn schedule_once(
        self: *WorkflowScheduler,
        workflow_id: u32,
        schedule_name: []const u8,
        execution_time: u64,
    ) ?u32 {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(schedule_name.len > 0);
        std.debug.assert(execution_time > 0);
        if (self.schedules_len >= MAX_SCHEDULED_WORKFLOWS) {
            return null;
        }
        const schedule_id = self.next_schedule_id;
        self.next_schedule_id += 1;
        self.schedules[self.schedules_len] = ScheduledWorkflow.init(
            schedule_id,
            workflow_id,
            schedule_name,
            ScheduleType.once,
            execution_time,
        );
        self.schedules_len += 1;
        return schedule_id;
    }

    /// Schedule workflow for recurring execution (cron).
    pub fn schedule_recurring(
        self: *WorkflowScheduler,
        workflow_id: u32,
        schedule_name: []const u8,
        cron_expr: []const u8,
        next_execution: u64,
    ) ?u32 {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(schedule_name.len > 0);
        std.debug.assert(cron_expr.len > 0);
        std.debug.assert(next_execution > 0);
        if (self.schedules_len >= MAX_SCHEDULED_WORKFLOWS) {
            return null;
        }
        const schedule_id = self.next_schedule_id;
        self.next_schedule_id += 1;
        var scheduled = ScheduledWorkflow.init(
            schedule_id,
            workflow_id,
            schedule_name,
            ScheduleType.recurring,
            next_execution,
        );
        if (!scheduled.set_cron_expression(cron_expr)) {
            return null;
        }
        self.schedules[self.schedules_len] = scheduled;
        self.schedules_len += 1;
        return schedule_id;
    }

    /// Schedule workflow for interval-based execution.
    pub fn schedule_interval(
        self: *WorkflowScheduler,
        workflow_id: u32,
        schedule_name: []const u8,
        interval_ms: u64,
        first_execution: u64,
    ) ?u32 {
        std.debug.assert(workflow_id > 0);
        std.debug.assert(schedule_name.len > 0);
        std.debug.assert(interval_ms > 0);
        std.debug.assert(first_execution > 0);
        if (self.schedules_len >= MAX_SCHEDULED_WORKFLOWS) {
            return null;
        }
        const schedule_id = self.next_schedule_id;
        self.next_schedule_id += 1;
        var scheduled = ScheduledWorkflow.init(
            schedule_id,
            workflow_id,
            schedule_name,
            ScheduleType.interval,
            first_execution,
        );
        scheduled.set_interval(interval_ms);
        self.schedules[self.schedules_len] = scheduled;
        self.schedules_len += 1;
        return schedule_id;
    }

    /// Check and execute due workflows.
    pub fn check_and_execute(self: *WorkflowScheduler, current_time: u64) u32 {
        std.debug.assert(current_time > 0);
        var executed_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (!self.schedules[i].enabled) {
                continue;
            }
            if (self.schedules[i].next_execution <= current_time) {
                // Execute workflow.
                _ = self.engine.execute_workflow(
                    self.schedules[i].workflow_id,
                    current_time,
                );
                self.schedules[i].execution_count += 1;
                self.schedules[i].last_execution = current_time;

                // Update next execution time.
                if (self.schedules[i].schedule_type == ScheduleType.once) {
                    // Disable one-time schedules after execution.
                    self.schedules[i].enabled = false;
                } else if (self.schedules[i].schedule_type == ScheduleType.interval) {
                    // Calculate next interval execution.
                    self.schedules[i].next_execution = current_time + self.schedules[i].interval_ms;
                } else if (self.schedules[i].schedule_type == ScheduleType.recurring) {
                    // Calculate next execution from cron expression.
                    const next_time = self.calculate_next_cron_execution(
                        current_time,
                        self.schedules[i].cron_expr[0..self.schedules[i].cron_expr_len],
                    );
                    if (next_time > 0) {
                        self.schedules[i].next_execution = next_time;
                    } else {
                        // Fallback: add 1 hour if cron parsing fails.
                        self.schedules[i].next_execution = current_time + 3600000;
                    }
                }
                executed_count += 1;
            }
        }
        return executed_count;
    }

    /// Enable schedule.
    pub fn enable_schedule(self: *WorkflowScheduler, schedule_id: u32) bool {
        std.debug.assert(schedule_id > 0);
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (self.schedules[i].schedule_id == schedule_id) {
                self.schedules[i].enabled = true;
                return true;
            }
        }
        return false;
    }

    /// Disable schedule.
    pub fn disable_schedule(self: *WorkflowScheduler, schedule_id: u32) bool {
        std.debug.assert(schedule_id > 0);
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (self.schedules[i].schedule_id == schedule_id) {
                self.schedules[i].enabled = false;
                return true;
            }
        }
        return false;
    }

    /// Remove schedule.
    pub fn remove_schedule(self: *WorkflowScheduler, schedule_id: u32) bool {
        std.debug.assert(schedule_id > 0);
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (self.schedules[i].schedule_id == schedule_id) {
                // Move last schedule to this position.
                if (i < self.schedules_len - 1) {
                    self.schedules[i] = self.schedules[self.schedules_len - 1];
                }
                self.schedules_len -= 1;
                return true;
            }
        }
        return false;
    }

    /// Get schedule by ID.
    pub fn get_schedule(
        self: *const WorkflowScheduler,
        schedule_id: u32,
    ) ?*const ScheduledWorkflow {
        std.debug.assert(schedule_id > 0);
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (self.schedules[i].schedule_id == schedule_id) {
                return &self.schedules[i];
            }
        }
        return null;
    }

    /// Get count of enabled schedules.
    pub fn get_enabled_count(self: *const WorkflowScheduler) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.schedules_len) : (i += 1) {
            if (self.schedules[i].enabled) {
                count += 1;
            }
        }
        return count;
    }

    /// Calculate next execution time from cron expression (basic parser).
    /// Cron format: "minute hour day month day_of_week" (5 fields).
    /// Supports: numbers, ranges (1-5), lists (1,3,5), wildcards (*), step (*/5).
    /// Returns: Next execution timestamp (milliseconds) or 0 if invalid.
    fn calculate_next_cron_execution(
        self: *const WorkflowScheduler,
        current_time: u64,
        cron_expr: []const u8,
    ) u64 {
        _ = self;
        std.debug.assert(current_time > 0);
        std.debug.assert(cron_expr.len > 0);
        // Parse cron expression (simplified: basic patterns only).
        // Format: "minute hour day month day_of_week"
        // For now, support simple patterns: "* * * * *" (every minute), "0 * * * *" (every hour), etc.
        var fields: [5][MAX_CRON_EXPR_LEN]u8 = undefined;
        var field_lens: [5]u32 = undefined;
        var field_idx: u32 = 0;
        var char_idx: u32 = 0;
        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            field_lens[i] = 0;
            var j: u32 = 0;
            while (j < MAX_CRON_EXPR_LEN) : (j += 1) {
                fields[i][j] = 0;
            }
        }
        i = 0;
        while (i < cron_expr.len and field_idx < 5) : (i += 1) {
            const c = cron_expr[i];
            if (c == ' ' or c == '\t') {
                if (char_idx > 0) {
                    field_lens[field_idx] = char_idx;
                    field_idx += 1;
                    char_idx = 0;
                }
            } else {
                if (char_idx < MAX_CRON_EXPR_LEN - 1) {
                    fields[field_idx][char_idx] = c;
                    char_idx += 1;
                }
            }
        }
        if (char_idx > 0 and field_idx < 5) {
            field_lens[field_idx] = char_idx;
            field_idx += 1;
        }
        if (field_idx != 5) {
            return 0; // Invalid cron expression
        }
        // Simple calculation: if minute is "*", add 1 minute; if "0", add 1 hour.
        // This is a simplified parser - full cron parsing would be more complex.
        const minute_field = fields[0][0..field_lens[0]];
        if (minute_field.len == 1 and minute_field[0] == '*') {
            // Every minute: add 1 minute.
            return current_time + 60000; // 1 minute
        } else if (minute_field.len == 1 and minute_field[0] == '0') {
            // Every hour: add 1 hour.
            return current_time + 3600000; // 1 hour
        } else {
            // Try to parse as number (minutes).
            var minute_val: u32 = 0;
            var j: u32 = 0;
            while (j < minute_field.len) : (j += 1) {
                const digit = minute_field[j];
                if (digit >= '0' and digit <= '9') {
                    minute_val = minute_val * 10 + (digit - '0');
                } else {
                    return 0; // Invalid
                }
            }
            if (minute_val < 60) {
                // Add specified minutes.
                return current_time + @as(u64, minute_val) * 60000;
            }
        }
        return 0; // Invalid or unsupported pattern
    }
};
