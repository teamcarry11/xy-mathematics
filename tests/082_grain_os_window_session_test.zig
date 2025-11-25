//! Tests for Grain OS window session management system.
//!
//! Why: Verify window session save and restore functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_os = @import("grain_os");
const Compositor = grain_os.compositor.Compositor;
const SessionManager = grain_os.window_session.SessionManager;

test "session manager initialization" {
    const manager = SessionManager.init();
    std.debug.assert(manager.sessions_len == 0);
    std.debug.assert(manager.next_session_id == 1);
}

test "create session" {
    var manager = SessionManager.init();
    const session_id_opt = manager.create_session("test_session");
    std.debug.assert(session_id_opt != null);
    if (session_id_opt) |session_id| {
        std.debug.assert(session_id == 1);
        std.debug.assert(manager.sessions_len == 1);
    }
}

test "find session by ID" {
    var manager = SessionManager.init();
    if (manager.create_session("test_session")) |session_id| {
        const session_opt = manager.find_session(session_id);
        std.debug.assert(session_opt != null);
        if (session_opt) |session| {
            std.debug.assert(session.session_id == session_id);
        }
    }
}

test "find session by name" {
    var manager = SessionManager.init();
    _ = manager.create_session("test_session");
    const session_opt = manager.find_session_by_name("test_session");
    std.debug.assert(session_opt != null);
    if (session_opt) |session| {
        std.debug.assert(session.session_id == 1);
    }
}

test "delete session" {
    var manager = SessionManager.init();
    if (manager.create_session("test_session")) |session_id| {
        const result = manager.delete_session(session_id);
        std.debug.assert(result);
        std.debug.assert(manager.sessions_len == 0);
    }
}

test "get session count" {
    var manager = SessionManager.init();
    std.debug.assert(manager.get_session_count() == 0);
    _ = manager.create_session("session1");
    std.debug.assert(manager.get_session_count() == 1);
    _ = manager.create_session("session2");
    std.debug.assert(manager.get_session_count() == 2);
}

test "clear all sessions" {
    var manager = SessionManager.init();
    _ = manager.create_session("session1");
    _ = manager.create_session("session2");
    manager.clear_all();
    std.debug.assert(manager.get_session_count() == 0);
}

test "compositor create session" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const session_id_opt = comp.create_window_session("test_session");
    std.debug.assert(session_id_opt != null);
}

test "compositor restore session" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    const window_id = try comp.create_window(800, 600);
    std.debug.assert(window_id > 0);
    if (comp.create_window_session("test_session")) |session_id| {
        const result = comp.restore_window_session(session_id);
        std.debug.assert(result);
    }
}

test "compositor find session by name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    _ = comp.create_window_session("test_session");
    const session_id_opt = comp.find_session_by_name("test_session");
    std.debug.assert(session_id_opt != null);
}

test "compositor get session count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = Compositor.init(allocator);
    std.debug.assert(comp.get_session_count() == 0);
    _ = comp.create_window_session("session1");
    std.debug.assert(comp.get_session_count() == 1);
}

test "window session constants" {
    std.debug.assert(grain_os.window_session.MAX_SESSIONS == 32);
    std.debug.assert(grain_os.window_session.MAX_SESSION_NAME_LEN == 64);
}

