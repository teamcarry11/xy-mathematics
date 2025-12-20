//! Grain Mobile Core Handler Adapters: Grain OS API Server integration.
//!
//! Why: Adapt mobile handlers to Grain OS API Server RouteHandler signature.
//! Architecture: Handler adapters, request parsing, response building.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-05-104028-pst: Grain Mobile Agent

const std = @import("std");
const grain_core_api = @import("../../grain_core/api_server.zig");
const grain_core_auth = @import("../../grain_core/auth_service.zig");
const grain_core_json = @import("../../grain_core/json_helpers.zig");
const models = @import("models.zig");
const responses = @import("responses.zig");
const validation = @import("validation.zig");
const endpoints = @import("endpoints.zig");
const handlers = @import("handlers.zig");
const auth_integration = @import("auth_integration.zig");
const auth_service_integration = @import("auth_service_integration.zig");
const email_service = @import("../email/service.zig");
const oauth = @import("../auth/oauth.zig");

// Global API server instance (set during initialization).
var global_api_server: ?*grain_core_api.ApiServer = null;

// Set API server instance.
pub fn set_api_server(server: *grain_core_api.ApiServer) void {
    global_api_server = server;
    std.debug.assert(global_api_server != null);
}

// Get API server instance.
fn get_api_server() ?*grain_core_api.ApiServer {
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

// Global email service instance (set during initialization).
var global_email_service: ?*email_service.EmailService = null;

// Set email service instance.
pub fn set_email_service(service: *email_service.EmailService) void {
    global_email_service = service;
    std.debug.assert(global_email_service != null);
}

// Get email service instance.
fn get_email_service() ?*email_service.EmailService {
    return global_email_service;
}

// Handler adapter: Register endpoint.
pub fn handle_register_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
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
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const password_len = server.parse_json_string_from_request(
        request,
        "password",
        &password_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const username_len = server.parse_json_string_from_request(
        request,
        "username",
        &username_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
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
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    
    // Hash password using auth service
    var password_hash: [grain_core_auth.HASH_OUTPUT_LEN]u8 = undefined;
    auth_integration.hash_password(password, &password_hash);
    
    // TODO: Store user in database (when database available)
    // For now, just hash the password and generate tokens
    
    // Generate user_id from email (temporary until database available)
    var user_id: [grain_core_auth.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = if (email_len <= grain_core_auth.MAX_USER_ID_LEN) email_len else grain_core_auth.MAX_USER_ID_LEN;
    std.mem.copyForwards(u8, &user_id, email[0..user_id_len]);
    
    // Generate tokens
    const current_time: u64 = @intCast(std.time.timestamp());
    var access_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    var refresh_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const access_token_len = auth_integration.generate_access_token(
        user_id[0..user_id_len],
        current_time,
        &access_token,
    );
    const refresh_token_len = auth_integration.generate_refresh_token(
        user_id[0..user_id_len],
        current_time,
        &refresh_token,
    );
    
    if (access_token_len == 0 or refresh_token_len == 0) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    
    // Build auth response
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token(access_token[0..access_token_len]);
    _ = auth_resp.set_refresh_token(refresh_token[0..refresh_token_len]);
    _ = auth_resp.set_user_id(user_id[0..user_id_len]);
    auth_resp.expires_in = grain_core_auth.ACCESS_TOKEN_EXPIRY;
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Login endpoint.
pub fn handle_login_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var password_buf: [models.MAX_PASSWORD_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const password_len = server.parse_json_string_from_request(
        request,
        "password",
        &password_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    const password = password_buf[0..password_len];
    var login_req = models.LoginRequest.init(email, password);
    std.debug.assert(login_req.email_len == email_len);
    std.debug.assert(login_req.password_len == password_len);
    if (!validation.validate_login_request(&login_req)) {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    
    // TODO: Verify credentials against database (when database available)
    // For now, generate tokens for any valid email/password format
    
    // Generate user_id from email (temporary until database available)
    var user_id: [grain_core_auth.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = if (email_len <= grain_core_auth.MAX_USER_ID_LEN) email_len else grain_core_auth.MAX_USER_ID_LEN;
    std.mem.copyForwards(u8, &user_id, email[0..user_id_len]);
    
    // Generate tokens
    const current_time: u64 = @intCast(std.time.timestamp());
    var access_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    var refresh_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const access_token_len = auth_integration.generate_access_token(
        user_id[0..user_id_len],
        current_time,
        &access_token,
    );
    const refresh_token_len = auth_integration.generate_refresh_token(
        user_id[0..user_id_len],
        current_time,
        &refresh_token,
    );
    
    if (access_token_len == 0 or refresh_token_len == 0) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    
    // Build auth response
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token(access_token[0..access_token_len]);
    _ = auth_resp.set_refresh_token(refresh_token[0..refresh_token_len]);
    _ = auth_resp.set_user_id(user_id[0..user_id_len]);
    auth_resp.expires_in = grain_core_auth.ACCESS_TOKEN_EXPIRY;
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Logout endpoint.
pub fn handle_logout_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    // Extract and revoke JWT token
    var token_buf: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_integration.extract_jwt_token_from_request(request, &token_buf);
    
    if (token_len > 0) {
        const service = auth_integration.get_auth_service();
        if (service) |auth_service| {
            _ = auth_service.revoke_token(token_buf[0..token_len]);
        }
    }
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Logged out", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Refresh token endpoint.
pub fn handle_refresh_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    // Extract refresh token from request
    var token_buf: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const token_len = auth_integration.extract_jwt_token_from_request(request, &token_buf);
    
    if (token_len == 0) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    
    // Validate refresh token
    const current_time: u64 = @intCast(std.time.timestamp());
    var claims = grain_core_auth.JwtClaims{
        .user_id = undefined,
        .user_id_len = 0,
        .exp = 0,
        .iat = 0,
        .token_type = grain_core_auth.TokenType.refresh,
    };
    
    if (!auth_integration.validate_jwt_token(token_buf[0..token_len], current_time, &claims)) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    
    // Generate new access token
    var access_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const access_token_len = auth_integration.generate_access_token(
        claims.user_id[0..claims.user_id_len],
        current_time,
        &access_token,
    );
    
    if (access_token_len == 0) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    
    // Build auth response
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token(access_token[0..access_token_len]);
    _ = auth_resp.set_user_id(claims.user_id[0..claims.user_id_len]);
    auth_resp.expires_in = grain_core_auth.ACCESS_TOKEN_EXPIRY;
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: OTP send endpoint.
pub fn handle_otp_send_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    var otp_req = models.OtpSendRequest.init(email);
    std.debug.assert(otp_req.email_len == email_len);
    if (!validation.validate_otp_send_request(&otp_req)) {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    
    // Generate OTP using auth service
    const current_time: u64 = @intCast(std.time.timestamp());
    var otp = grain_core_auth.Otp{
        .code = undefined,
        .code_len = 0,
        .email = undefined,
        .email_len = 0,
        .created_at = 0,
        .expires_at = 0,
        .is_used = false,
    };
    
    if (!auth_service_integration.generate_email_otp(email, current_time, &otp)) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    
    // Send OTP email using email service
    const email_svc = get_email_service();
    if (email_svc) |svc| {
        const otp_code = otp.code[0..otp.code_len];
        const email_result = svc.send_otp_email(email, otp_code);
        if (email_result != email_service.EmailResult.success) {
            response.status = grain_core_api.HttpStatus.internal_server_error;
            return;
        }
    }
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("OTP sent", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: OTP verify endpoint.
pub fn handle_otp_verify_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    var email_buf: [models.MAX_EMAIL_LEN]u8 = undefined;
    var code_buf: [models.MAX_OTP_CODE_LEN]u8 = undefined;
    const email_len = server.parse_json_string_from_request(
        request,
        "email",
        &email_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const code_len = server.parse_json_string_from_request(
        request,
        "code",
        &code_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const email = email_buf[0..email_len];
    const code = code_buf[0..code_len];
    var otp_req = models.OtpVerifyRequest.init(email, code);
    std.debug.assert(otp_req.email_len == email_len);
    std.debug.assert(otp_req.code_len == code_len);
    if (!validation.validate_otp_verify_request(&otp_req)) {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    
    // Validate OTP code
    const current_time: u64 = @intCast(std.time.timestamp());
    if (!auth_service_integration.validate_email_otp(email, code, current_time)) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    
    // Generate user_id from email (temporary until database available)
    var user_id: [grain_core_auth.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = if (email_len <= grain_core_auth.MAX_USER_ID_LEN) email_len else grain_core_auth.MAX_USER_ID_LEN;
    std.mem.copyForwards(u8, &user_id, email[0..user_id_len]);
    
    // Generate tokens
    var access_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    var refresh_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const access_token_len = auth_integration.generate_access_token(
        user_id[0..user_id_len],
        current_time,
        &access_token,
    );
    const refresh_token_len = auth_integration.generate_refresh_token(
        user_id[0..user_id_len],
        current_time,
        &refresh_token,
    );
    
    if (access_token_len == 0 or refresh_token_len == 0) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    
    // Build auth response
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token(access_token[0..access_token_len]);
    _ = auth_resp.set_refresh_token(refresh_token[0..refresh_token_len]);
    _ = auth_resp.set_user_id(user_id[0..user_id_len]);
    auth_resp.expires_in = grain_core_auth.ACCESS_TOKEN_EXPIRY;
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: 2FA enable endpoint.
pub fn handle_2fa_enable_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const result = handlers.handle_2fa_enable(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("2FA enabled", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: 2FA verify endpoint.
pub fn handle_2fa_verify_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const context = get_handler_context() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    var code_buf: [models.MAX_TOTP_CODE_LEN]u8 = undefined;
    const code_len = server.parse_json_string_from_request(
        request,
        "code",
        &code_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const code = code_buf[0..code_len];
    var totp_req = models.TotpVerifyRequest.init(code);
    std.debug.assert(totp_req.code_len == code_len);
    if (!validation.validate_totp_verify_request(&totp_req)) {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    const result = handlers.handle_2fa_verify(context);
    if (result != handlers.HandlerResult.success) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("2FA verified", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Users profile endpoint.
pub fn handle_users_profile_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    // Validate JWT token
    const current_time: u64 = @intCast(std.time.timestamp());
    var claims = grain_core_auth.JwtClaims{
        .user_id = undefined,
        .user_id_len = 0,
        .exp = 0,
        .iat = 0,
        .token_type = grain_core_auth.TokenType.access,
    };
    
    if (!auth_service_integration.extract_and_validate_token(request, current_time, &claims)) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    
    // TODO: Fetch user profile from database (when database available)
    // For now, return success with user_id from token
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Profile retrieved", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Handler adapter: Users settings endpoint.
pub fn handle_users_settings_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    
    // Validate JWT token
    const current_time: u64 = @intCast(std.time.timestamp());
    var claims = grain_core_auth.JwtClaims{
        .user_id = undefined,
        .user_id_len = 0,
        .exp = 0,
        .iat = 0,
        .token_type = grain_core_auth.TokenType.access,
    };
    
    if (!auth_service_integration.extract_and_validate_token(request, current_time, &claims)) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    
    // TODO: Fetch user settings from database (when database available)
    // For now, return success with user_id from token
    
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_success_response("Settings retrieved", "", &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

// Global OAuth manager instance (set during initialization).
var global_oauth_manager: ?*oauth.OAuthManager = null;

// Set OAuth manager instance.
pub fn set_oauth_manager(manager: *oauth.OAuthManager) void {
    global_oauth_manager = manager;
    std.debug.assert(global_oauth_manager != null);
}

// Get OAuth manager instance.
fn get_oauth_manager() ?*oauth.OAuthManager {
    return global_oauth_manager;
}

// Handler adapter: OAuth callback endpoint.
pub fn handle_oauth_callback_adapter(
    request: *grain_core_api.HttpRequest,
    response: *grain_core_api.HttpResponse,
) void {
    std.debug.assert(request != null);
    std.debug.assert(response != null);
    const server = get_api_server() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    const oauth_mgr = get_oauth_manager() orelse {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    };
    var provider_buf: [32]u8 = undefined;
    var callback_url_buf: [2048]u8 = undefined;
    const provider_len = server.parse_query_string_from_request(
        request,
        "provider",
        &provider_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const callback_url_len = server.parse_query_string_from_request(
        request,
        "callback_url",
        &callback_url_buf,
    ) orelse {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    };
    const provider_str = provider_buf[0..provider_len];
    const callback_url = callback_url_buf[0..callback_url_len];
    var provider: oauth.OAuthProvider = undefined;
    if (std.mem.eql(u8, provider_str, "google")) {
        provider = oauth.OAuthProvider.google;
    } else if (std.mem.eql(u8, provider_str, "facebook")) {
        provider = oauth.OAuthProvider.facebook;
    } else if (std.mem.eql(u8, provider_str, "github")) {
        provider = oauth.OAuthProvider.github;
    } else if (std.mem.eql(u8, provider_str, "apple")) {
        provider = oauth.OAuthProvider.apple;
    } else {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    var code_buf: [oauth.MAX_AUTH_CODE_LEN]u8 = undefined;
    var state_buf: [oauth.MAX_STATE_LEN]u8 = undefined;
    const parse_result = oauth.parse_oauth_callback(callback_url, &code_buf, &state_buf);
    if (!parse_result.success) {
        response.status = grain_core_api.HttpStatus.bad_request;
        return;
    }
    const code = code_buf[0..parse_result.code_len];
    var token_response = oauth.OAuthTokenResponse.init();
    if (!oauth_mgr.exchange_code_for_tokens(provider, code, state_buf[0..parse_result.state_len], &token_response)) {
        response.status = grain_core_api.HttpStatus.unauthorized;
        return;
    }
    const current_time: u64 = @intCast(std.time.timestamp());
    var user_id: [grain_core_auth.MAX_USER_ID_LEN]u8 = undefined;
    const user_id_len = @min(token_response.access_token_len, grain_core_auth.MAX_USER_ID_LEN);
    std.mem.copyForwards(u8, &user_id, token_response.access_token[0..user_id_len]);
    var access_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    var refresh_token: [grain_core_auth.MAX_JWT_LEN]u8 = undefined;
    const access_token_len = auth_integration.generate_access_token(
        user_id[0..user_id_len],
        current_time,
        &access_token,
    );
    const refresh_token_len = auth_integration.generate_refresh_token(
        user_id[0..user_id_len],
        current_time,
        &refresh_token,
    );
    if (access_token_len == 0 or refresh_token_len == 0) {
        response.status = grain_core_api.HttpStatus.internal_server_error;
        return;
    }
    var auth_resp = models.AuthResponse.init();
    auth_resp.success = true;
    _ = auth_resp.set_token(access_token[0..access_token_len]);
    _ = auth_resp.set_refresh_token(refresh_token[0..refresh_token_len]);
    _ = auth_resp.set_user_id(user_id[0..user_id_len]);
    auth_resp.expires_in = grain_core_auth.ACCESS_TOKEN_EXPIRY;
    var json_buf: [responses.MAX_JSON_RESPONSE_LEN]u8 = undefined;
    const json_len = responses.build_auth_response(&auth_resp, &json_buf);
    response.status = grain_core_api.HttpStatus.ok;
    _ = response.add_header("Content-Type", "application/json");
    std.mem.copyForwards(u8, response.body[0..json_len], json_buf[0..json_len]);
    response.body_len = @intCast(json_len);
}

