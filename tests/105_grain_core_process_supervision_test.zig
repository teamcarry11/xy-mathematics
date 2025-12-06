//! Tests for Grain OS process supervision system.
//!
//! Why: Verify process supervision functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_core = @import("grain_core");
const Compositor = grain_core.compositor.Compositor;
const ProcessSupervisor = grain_core.process_supervision.ProcessSupervisor;
const SupervisionPolicy = grain_core.process_supervision.SupervisionPolicy;
const SupervisionState = grain_core.process_supervision.SupervisionState;

test "process supervisor initialization" {
    const supervisor = ProcessSupervisor.init();
    std.debug.assert(supervisor.supervised_len == 0);
    std.debug.assert(supervisor.next_supervision_id == 1);
}

test "add supervised process" {
    var supervisor = ProcessSupervisor.init();
    const supervision_id_opt = supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    std.debug.assert(supervision_id_opt != null);
    if (supervision_id_opt) |supervision_id| {
        std.debug.assert(supervision_id == 1);
        std.debug.assert(supervisor.get_supervised_count() == 1);
    }
}

test "find supervised process by process id" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.process_id == 1);
        std.debug.assert(supervised.policy == SupervisionPolicy.always);
    }
}

test "find supervised process by supervision id" {
    var supervisor = ProcessSupervisor.init();
    if (supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000)) |supervision_id| {
        if (supervisor.find_by_supervision_id(supervision_id)) |supervised| {
            std.debug.assert(supervised.supervision_id == supervision_id);
        }
    }
}

test "update process state" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    const result = supervisor.update_process_state(1, SupervisionState.running);
    std.debug.assert(result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.state == SupervisionState.running);
    }
}

test "record process exit always restart" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    const result = supervisor.record_process_exit(1, 0, 2000);
    std.debug.assert(result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.state == SupervisionState.starting);
        std.debug.assert(supervised.restart_count == 1);
    }
}

test "record process exit never restart" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.never, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    const result = supervisor.record_process_exit(1, 0, 2000);
    std.debug.assert(!result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.state == SupervisionState.stopped);
    }
}

test "record process exit on failure restart" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.on_failure, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    const result = supervisor.record_process_exit(1, 1, 2000);
    std.debug.assert(result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.state == SupervisionState.starting);
    }
}

test "record process exit on failure no restart" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.on_failure, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    const result = supervisor.record_process_exit(1, 0, 2000);
    std.debug.assert(!result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.state == SupervisionState.stopped);
    }
}

test "max restarts limit" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.always, 2, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    _ = supervisor.record_process_exit(1, 1, 2000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    _ = supervisor.record_process_exit(1, 1, 3000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    const result = supervisor.record_process_exit(1, 1, 4000);
    std.debug.assert(!result);
    if (supervisor.find_by_process_id(1)) |supervised| {
        std.debug.assert(supervised.restart_count == 2);
        std.debug.assert(supervised.state == SupervisionState.stopped);
    }
}

test "remove supervised process" {
    var supervisor = ProcessSupervisor.init();
    if (supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000)) |supervision_id| {
        const result = supervisor.remove_supervised_process(supervision_id);
        std.debug.assert(result);
        std.debug.assert(supervisor.get_supervised_count() == 0);
    }
}

test "get running count" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    _ = supervisor.add_supervised_process(2, SupervisionPolicy.always, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    _ = supervisor.update_process_state(2, SupervisionState.running);
    const count = supervisor.get_running_count();
    std.debug.assert(count == 2);
}

test "get crashed count" {
    var supervisor = ProcessSupervisor.init();
    _ = supervisor.add_supervised_process(1, SupervisionPolicy.never, 0, 1000);
    _ = supervisor.update_process_state(1, SupervisionState.running);
    _ = supervisor.record_process_exit(1, 1, 2000);
    const count = supervisor.get_crashed_count();
    std.debug.assert(count == 0); // Should be stopped, not crashed.
}

test "compositor add supervised process" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const supervision_id_opt = comp.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    std.debug.assert(supervision_id_opt != null);
}

test "compositor record supervised process exit" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.add_supervised_process(1, SupervisionPolicy.always, 0, 1000);
    _ = comp.update_supervised_process_state(1, SupervisionState.running);
    const result = comp.record_supervised_process_exit(1, 0, 2000);
    std.debug.assert(result);
}

test "supervision policies" {
    std.debug.assert(@intFromEnum(SupervisionPolicy.always) == 0);
    std.debug.assert(@intFromEnum(SupervisionPolicy.never) == 1);
    std.debug.assert(@intFromEnum(SupervisionPolicy.on_failure) == 2);
    std.debug.assert(@intFromEnum(SupervisionPolicy.on_success) == 3);
}

test "supervision states" {
    std.debug.assert(@intFromEnum(SupervisionState.idle) == 0);
    std.debug.assert(@intFromEnum(SupervisionState.starting) == 1);
    std.debug.assert(@intFromEnum(SupervisionState.running) == 2);
    std.debug.assert(@intFromEnum(SupervisionState.crashed) == 3);
    std.debug.assert(@intFromEnum(SupervisionState.stopping) == 4);
    std.debug.assert(@intFromEnum(SupervisionState.stopped) == 5);
}

test "process supervision constants" {
    std.debug.assert(grain_core.process_supervision.MAX_SUPERVISED_PROCESSES == 64);
    std.debug.assert(grain_core.process_supervision.MAX_POLICY_NAME_LEN == 64);
}

