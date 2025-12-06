const std = @import("std");
const root = @import("root");

test "connection manager init" {
    const conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    std.debug.assert(conn_mgr.connections_len == 0);
    std.debug.assert(conn_mgr.next_connection_id == 1);
}

test "add connection" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    if (conn_mgr.add_connection()) |idx| {
        std.debug.assert(idx == 0);
        std.debug.assert(conn_mgr.connections_len == 1);
        if (conn_mgr.get_connection(idx)) |conn| {
            std.debug.assert(conn.active);
            std.debug.assert(conn.connection_id == 1);
            std.debug.assert(conn.state == root.grain_core.connection_manager.ConnectionState.idle);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "remove connection" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    if (conn_mgr.add_connection()) |idx| {
        const removed = conn_mgr.remove_connection(idx);
        std.debug.assert(removed);
        std.debug.assert(conn_mgr.connections_len == 0);
        if (conn_mgr.get_connection(idx)) |_conn| {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "connection keep alive" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    if (conn_mgr.add_connection()) |idx| {
        if (conn_mgr.get_connection(idx)) |conn| {
            conn.set_keep_alive(true);
            std.debug.assert(conn.keep_alive);
            std.debug.assert(conn.state == root.grain_core.connection_manager.ConnectionState.keep_alive);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "connection timeout" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    conn_mgr.update_time(1000);
    if (conn_mgr.add_connection()) |idx| {
        if (conn_mgr.get_connection(idx)) |conn| {
            conn.update_activity(1000);
            conn_mgr.update_time(1000 + root.grain_core.connection_manager.DEFAULT_REQUEST_TIMEOUT + 1);
            const timed_out = conn.is_timed_out(conn_mgr.current_time);
            std.debug.assert(timed_out);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "cleanup timeouts" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    conn_mgr.update_time(1000);
    if (conn_mgr.add_connection()) |idx| {
        if (conn_mgr.get_connection(idx)) |conn| {
            conn.update_activity(1000);
            conn_mgr.update_time(1000 + root.grain_core.connection_manager.DEFAULT_REQUEST_TIMEOUT + 1);
            const cleaned = conn_mgr.cleanup_timeouts();
            std.debug.assert(cleaned == 1);
            std.debug.assert(conn_mgr.connections_len == 0);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "connection request count" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    if (conn_mgr.add_connection()) |idx| {
        if (conn_mgr.get_connection(idx)) |conn| {
            std.debug.assert(conn.request_count == 0);
            conn.increment_request_count();
            std.debug.assert(conn.request_count == 1);
            conn.increment_request_count();
            std.debug.assert(conn.request_count == 2);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "max connections" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    var i: u32 = 0;
    while (i < root.grain_core.connection_manager.MAX_CONNECTIONS) : (i += 1) {
        if (conn_mgr.add_connection()) |_idx| {
            _ = _idx;
        } else {
            std.debug.assert(false);
        }
    }
    std.debug.assert(conn_mgr.connections_len == root.grain_core.connection_manager.MAX_CONNECTIONS);
    if (conn_mgr.add_connection()) |_idx| {
        std.debug.assert(false);
    }
}

test "active connection count" {
    var conn_mgr = root.grain_core.connection_manager.ConnectionManager.init();
    _ = conn_mgr.add_connection();
    _ = conn_mgr.add_connection();
    _ = conn_mgr.add_connection();
    std.debug.assert(conn_mgr.get_active_connection_count() == 3);
    if (conn_mgr.get_connection(0)) |conn| {
        conn.close();
    }
    std.debug.assert(conn_mgr.get_active_connection_count() == 3);
    _ = conn_mgr.remove_connection(0);
    std.debug.assert(conn_mgr.get_active_connection_count() == 2);
}

