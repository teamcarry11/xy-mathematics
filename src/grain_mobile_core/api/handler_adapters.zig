//! Grain Mobile Core Handler Adapters: Grain OS API Server integration.
//!
//! Why: Adapt mobile handlers to Grain OS API Server RouteHandler signature.
//! Architecture: Handler adapters, request parsing, response building.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-05-104028-pst: Grain Mobile Agent

const std = @import("std");
const grain_os_api = @import("../../grain_os/api_server.zig");
const grain_os_json = @import("../../grain_os/json_helpers.zig");
const models = @import("models.zig");
const responses = @import("responses.zig");
const validation = @import("validation.zig");
const endpoints = @import("endpoints.zig");
const handlers = @import("handlers.zig");

// Global API server instance (set during initialization).
var global_api_server: ?*grain_os_api.ApiServer = null;

// Set API server instance.
pub fn set_api_server(server: *grain_os_api.ApiServer) void {
    global_api_server = server;
    std.debug.assert(global_api_server != null);
}

// Get API server instance.
fn get_api_server() ?*grain_os_api.ApiServer {
    return global_api_server;
}

// Handler context (global, set during initialization).
var global_handler_context: ?*handlers.HandlerContext = null;

// Set handler context.
pub fn set_handler_context(context: *handlers.HandlerContext) void {
    global_handler_context = context;
    std.debug.assert(global_handler_context != null);
}

// Get handler context.
fn get_handler_context() ?*handlers.HandlerContext {
    return global_handler_context;
}

// Handler adapter: Register endpoint.
pub fn handle_register_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var password_buf: [models.MAX_PASSWORD_LEN]u8 = undefined;
    var username_buf: [models.MAX_USERNAME_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const password_len = server.parse_json_string_from_request(
        request,
        "password",
        &password_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const username_len = server.parse_json_string_from_request(
        request,
        "username",
        &username_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    const password = password_buf[0..password_len];
    const username = username_buf[0..username_len];
    var register_req = models.RegisterRequest.init(email, password, username);
    std.debug.assert(register_req.email_len == email_len);
    std.debug.assert(register_req.password_len == password_len);
    std.debug.assert(register_req.username_len == username_len);
    if (!validation.validate_register_request(&register_req)) {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_register(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    }
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Login endpoint.
pub fn handle_login_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var password_buf: [models.MAX_PASSWORD_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const password_len = server.parse_json_string_from_request(
        request,
        "password",
        &password_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    const password = password_buf[0..password_len];
    var login_req = models.LoginRequest.init(email, password);
    std.debug.assert(login_req.email_len == email_len);
    std.debug.assert(login_req.password_len == password_len);
    if (!validation.validate_login_request(&login_req)) {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_login(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.unauthorized;
        return;
    }
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Logout endpoint.
pub fn handle_logout_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_logout(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Logged out", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Refresh token endpoint.
pub fn handle_refresh_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_refresh(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.unauthorized;
        return;
    }
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: OTP send endpoint.
pub fn handle_otp_send_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    var otp_req = models.OtpSendRequest.init(email);
    std.debug.assert(otp_req.email_len == email_len);
    if (!validation.validate_otp_send_request(&otp_req)) {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_otp_send(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("OTP sent", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: OTP verify endpoint.
pub fn handle_otp_verify_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var code_buf: [models.MAX_OTP_CODE_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const code_len = server.parse_json_string_from_request(
        request,
        "code",
        &code_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    const code = code_buf[0..code_len];
    var otp_req = models.OtpVerifyRequest.init(email, code);
    std.debug.assert(otp_req.email_len == email_len);
    std.debug.assert(otp_req.code_len == code_len);
    if (!validation.validate_otp_verify_request(&otp_req)) {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_otp_verify(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.unauthorized;
        return;
    }
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: 2FA enable endpoint.
pub fn handle_2fa_enable_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_2fa_enable(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("2FA enabled", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: 2FA verify endpoint.
pub fn handle_2fa_verify_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    var code_buf: [models.MAX_TOTP_CODE_LEN]u8 = undefined;
    const code_len = server.parse_json_string_from_request(
        request,
        "code",
        &code_buf,
    ) orelse {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    };
    const code = code_buf[0..code_len];
    var totp_req = models.TotpVerifyRequest.init(code);
    std.debug.assert(totp_req.code_len == code_len);
    if (!validation.validate_totp_verify_request(&totp_req)) {
        response.status = grain_os_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_2fa_verify(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.unauthorized;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("2FA verified", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Users profile endpoint.
pub fn handle_users_profile_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_users_profile(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.not_found;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Profile retrieved", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Users settings endpoint.
pub fn handle_users_settings_adapter(
    request: *grain_os_api.HttpRequest,
    response: *grain_os_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_os_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_users_settings(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_os_api.HttpStatus.not_found;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Settings retrieved", "", &json_buf);
    response.status = grain_os_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

