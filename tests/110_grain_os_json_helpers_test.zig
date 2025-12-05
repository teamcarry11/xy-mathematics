const std = @import("std");
const root = @import("root");

test "find json key" {
    const json = "{\"email\":\"user@example.com\",\"password\":\"secret123\"}";
    const json_helpers = root.grain_os.json_helpers;
    if (json_helpers.find_json_key(json, "email")) |result| {
        std.debug.assert(result.success);
        std.debug.assert(result.value_start < json.len);
        std.debug.assert(result.value_len > 0);
    } else {
        std.debug.assert(false);
    }
}

test "extract json string value" {
    const json = "{\"email\":\"user@example.com\"}";
    const json_helpers = root.grain_os.json_helpers;
    if (json_helpers.find_json_key(json, "email")) |result| {
        var result_mut = result;
        var output: [256]u8 = undefined;
        if (json_helpers.extract_json_string_value(json, &result_mut, &output)) |len| {
            std.debug.assert(len > 0);
            const value = output[0..len];
            std.debug.assert(std.mem.eql(u8, value, "user@example.com"));
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "extract json number value" {
    const json = "{\"count\":42}";
    const json_helpers = root.grain_os.json_helpers;
    if (json_helpers.find_json_key(json, "count")) |result| {
        var result_mut = result;
        if (json_helpers.extract_json_number_value(json, &result_mut)) |num| {
            std.debug.assert(num == 42);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "extract json bool value" {
    const json = "{\"success\":true}";
    const json_helpers = root.grain_os.json_helpers;
    if (json_helpers.find_json_key(json, "success")) |result| {
        var result_mut = result;
        if (json_helpers.extract_json_bool_value(json, &result_mut)) |val| {
            std.debug.assert(val == true);
        } else {
            std.debug.assert(false);
        }
    } else {
        std.debug.assert(false);
    }
}

test "write json string" {
    var output: [256]u8 = undefined;
    var pos: u32 = 0;
    const json_helpers = root.grain_os.json_helpers;
    const written = json_helpers.write_json_string(&output, &pos, "test");
    std.debug.assert(written);
    std.debug.assert(pos > 0);
    const result = output[0..pos];
    std.debug.assert(std.mem.eql(u8, result, "\"test\""));
}

test "write json number" {
    var output: [256]u8 = undefined;
    var pos: u32 = 0;
    const json_helpers = root.grain_os.json_helpers;
    const written = json_helpers.write_json_number(&output, &pos, 42);
    std.debug.assert(written);
    std.debug.assert(pos > 0);
}

test "write json bool" {
    var output: [256]u8 = undefined;
    var pos: u32 = 0;
    const json_helpers = root.grain_os.json_helpers;
    const written = json_helpers.write_json_bool(&output, &pos, true);
    std.debug.assert(written);
    std.debug.assert(pos == 4);
    const result = output[0..pos];
    std.debug.assert(std.mem.eql(u8, result, "true"));
}

test "api server parse json string from request" {
    var server = root.grain_os.api_server.ApiServer.init(8080);
    var req = root.grain_os.api_server.HttpRequest.init();
    const body = "{\"email\":\"user@example.com\"}";
    var i: u32 = 0;
    while (i < body.len) : (i += 1) {
        req.body[i] = body[i];
    }
    req.body_len = @intCast(body.len);
    var output: [256]u8 = undefined;
    if (server.parse_json_string_from_request(&req, "email", &output)) |len| {
        std.debug.assert(len > 0);
        const value = output[0..len];
        std.debug.assert(std.mem.eql(u8, value, "user@example.com"));
    } else {
        std.debug.assert(false);
    }
}

test "api server write json string to response" {
    var server = root.grain_os.api_server.ApiServer.init(8080);
    var res = root.grain_os.api_server.HttpResponse.init();
    const written = server.write_json_string_to_response(&res, "status", "success");
    std.debug.assert(written);
    std.debug.assert(res.body_len > 0);
    const finalized = server.finalize_json_response(&res);
    std.debug.assert(finalized);
    const body = res.body[0..res.body_len];
    std.debug.assert(std.mem.startsWith(u8, body, "{\"status\":\"success\"}"));
}

