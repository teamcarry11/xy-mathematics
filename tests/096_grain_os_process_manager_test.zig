//! Tests for Grain OS process management system.
//!
//! Why: Verify process management functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const ProcessManager = grain_os.process_manager.ProcessManager;
const ProcessState = grain_os.process_manager.ProcessState;
const ProcessPriority = grain_os.process_manager.ProcessPriority;

test "process manager initialization" {
    const manager = ProcessManager.init();
    std.debug.assert(manager.processes_len == 0);
    std.debug.assert(manager.next_process_id == 1);
}

test "add process" {
    var manager = ProcessManager.init();
    const process_id_opt = manager.add_process(0, "test_process", "/bin/test", 1000);
    std.debug.assert(process_id_opt != null);
    if (process_id_opt) |process_id| {
        std.debug.assert(process_id == 1);
        std.debug.assert(manager.get_process_count() == 1);
    }
}

test "find process by ID" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const proc_opt = manager.find_process(process_id);
        std.debug.assert(proc_opt != null);
        if (proc_opt) |proc| {
            std.debug.assert(proc.process_id == process_id);
            std.debug.assert(proc.state == ProcessState.running);
        }
    }
}

test "set process state" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.set_process_state(process_id, ProcessState.sleeping);
        std.debug.assert(result);
        if (manager.find_process(process_id)) |proc| {
            std.debug.assert(proc.state == ProcessState.sleeping);
        }
    }
}

test "set process priority" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.set_process_priority(process_id, ProcessPriority.high);
        std.debug.assert(result);
        if (manager.find_process(process_id)) |proc| {
            std.debug.assert(proc.priority == ProcessPriority.high);
        }
    }
}

test "update process CPU usage" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.update_process_cpu_usage(process_id, 25.5);
        std.debug.assert(result);
        if (manager.find_process(process_id)) |proc| {
            std.debug.assert(proc.cpu_usage == 25.5);
        }
    }
}

test "update process memory usage" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.update_process_memory_usage(process_id, 4096);
        std.debug.assert(result);
        if (manager.find_process(process_id)) |proc| {
            std.debug.assert(proc.memory_usage == 4096);
        }
    }
}

test "remove process" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = manager.remove_process(process_id);
        std.debug.assert(result);
        std.debug.assert(manager.get_process_count() == 0);
    }
}

test "get running process count" {
    var manager = ProcessManager.init();
    if (manager.add_process(0, "test_process1", "/bin/test1", 1000)) |process_id_1| {
        if (manager.add_process(0, "test_process2", "/bin/test2", 2000)) |process_id_2| {
            _ = manager.set_process_state(process_id_2, ProcessState.sleeping);
            std.debug.assert(manager.get_running_process_count() == 1);
        }
    }
}

test "compositor add process" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const process_id_opt = comp.add_process(0, "test_process", "/bin/test", 1000);
    std.debug.assert(process_id_opt != null);
}

test "compositor set process state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = comp.set_process_state(process_id, ProcessState.stopped);
        std.debug.assert(result);
    }
}

test "compositor update process CPU usage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_process(0, "test_process", "/bin/test", 1000)) |process_id| {
        const result = comp.update_process_cpu_usage(process_id, 30.0);
        std.debug.assert(result);
    }
}

test "compositor get process count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_process_count() == 0);
    _ = comp.add_process(0, "test_process", "/bin/test", 1000);
    std.debug.assert(comp.get_process_count() == 1);
}

test "compositor get running process count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    if (comp.add_process(0, "test_process1", "/bin/test1", 1000)) |process_id_1| {
        if (comp.add_process(0, "test_process2", "/bin/test2", 2000)) |process_id_2| {
            _ = comp.set_process_state(process_id_2, ProcessState.sleeping);
            std.debug.assert(comp.get_running_process_count() == 1);
        }
    }
}

test "process states" {
    std.debug.assert(@intFromEnum(ProcessState.unknown) == 0);
    std.debug.assert(@intFromEnum(ProcessState.running) == 1);
    std.debug.assert(@intFromEnum(ProcessState.sleeping) == 2);
    std.debug.assert(@intFromEnum(ProcessState.stopped) == 3);
}

test "process priorities" {
    std.debug.assert(@intFromEnum(ProcessPriority.low) == 0);
    std.debug.assert(@intFromEnum(ProcessPriority.normal) == 1);
    std.debug.assert(@intFromEnum(ProcessPriority.high) == 2);
    std.debug.assert(@intFromEnum(ProcessPriority.realtime) == 3);
}

test "process manager constants" {
    std.debug.assert(grain_os.process_manager.MAX_PROCESSES == 256);
    std.debug.assert(grain_os.process_manager.MAX_PROCESS_NAME_LEN == 128);
    std.debug.assert(grain_os.process_manager.MAX_CMD_LINE_LEN == 512);
}

