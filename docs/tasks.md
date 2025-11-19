# Task Ledger 📋

> "A list of tasks, represented as a Zig structure."

## Tasks

```zig
const std = @import("std");

pub const Task = struct {
    id: u64,
    title: []const u8,
    status: Status,
};

pub const Status = enum {
    todo,
    in_progress,
    done,
};

pub const TASKS = [_]Task{
    .{ .id = 0, .title = "Search for 'Glow G2' in docs", .status = .done },
    .{ .id = 1, .title = "Identify relevant documentation", .status = .done },
    .{ .id = 2, .title = "Load up the Glow G2 voice", .status = .done },
    .{ .id = 3, .title = "Add extra tags to Glow G2", .status = .done },
    .{ .id = 4, .title = "Create mathematics.md notebook", .status = .done },
    .{ .id = 5, .title = "Archive docs to docs/zyx", .status = .done },
    .{ .id = 6, .title = "Move test_tahoe_simple.md to docs/zyx", .status = .done },
    .{ .id = 7, .title = "Find grainmirror and graintime modules", .status = .done },
    .{ .id = 8, .title = "Formulate grainmirror strategy for graintime", .status = .done },
    .{ .id = 9, .title = "Implement grainmirror strategy", .status = .done },
    .{ .id = 10, .title = "Locate teamshine05/graintime", .status = .done },
    .{ .id = 11, .title = "Calculate new graintime", .status = .done },
};

pub const TASK_COUNT = TASKS.len;
pub const latest = TASKS[TASKS.len - 1];
```
