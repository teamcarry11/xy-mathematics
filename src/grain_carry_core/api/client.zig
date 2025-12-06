// API client for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Provides HTTP client functionality for mobile apps
// Ready for integration when Grain OS Agent completes API Server (Phase 59)

const std = @import("std");
const errors = @import("../utils/errors.zig");

pub const MAX_URL_LEN: u32 = 2048;
pub const MAX_HEADER_NAME_LEN: u32 = 256;
pub const MAX_HEADER_VALUE_LEN: u32 = 1024;
pub const MAX_HEADERS: u32 = 32;
pub const MAX_BODY_LEN: u32 = 1048576; // 1 MB

pub const HttpMethod = enum(u8) {
    get,
    post,
    put,
    delete,
    patch,
};

pub const HttpStatus = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    conflict = 409,
    internal_server_error = 500,
    service_unavailable = 503,
};

pub const Header = struct {
    name: [MAX_HEADER_NAME_LEN]u8,
    name_len: u32,
    value: [MAX_HEADER_VALUE_LEN]u8,
    value_len: u32,

    pub fn init(name: []const u8, value: []const u8) Header {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_HEADER_NAME_LEN);
        std.debug.assert(value.len <= MAX_HEADER_VALUE_LEN);
        
        var header: Header = undefined;
        std.mem.copyForwards(u8, &header.name, name);
        header.name_len = @intCast(name.len);
        std.mem.copyForwards(u8, &header.value, value);
        header.value_len = @intCast(value.len);
        
        std.debug.assert(header.name_len > 0);
        std.debug.assert(header.name_len <= MAX_HEADER_NAME_LEN);
        
        return header;
    }
};

pub const Request = struct {
    method: HttpMethod,
    url: [MAX_URL_LEN]u8,
    url_len: u32,
    headers: [MAX_HEADERS]Header,
    headers_len: u32,
    body: [MAX_BODY_LEN]u8,
    body_len: u32,

    pub fn init(method: HttpMethod, url: []const u8) Request {
        std.debug.assert(url.len > 0);
        std.debug.assert(url.len <= MAX_URL_LEN);
        
        var req: Request = undefined;
        req.method = method;
        std.mem.copyForwards(u8, &req.url, url);
        req.url_len = @intCast(url.len);
        req.headers_len = 0;
        req.body_len = 0;
        
        std.debug.assert(req.url_len > 0);
        std.debug.assert(req.url_len <= MAX_URL_LEN);
        
        return req;
    }

    pub fn add_header(self: *Request, name: []const u8, value: []const u8) bool {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_HEADER_NAME_LEN);
        std.debug.assert(value.len <= MAX_HEADER_VALUE_LEN);
        
        if (self.headers_len >= MAX_HEADERS) {
            return false;
        }
        
        self.headers[self.headers_len] = Header.init(name, value);
        self.headers_len += 1;
        
        std.debug.assert(self.headers_len <= MAX_HEADERS);
        
        return true;
    }

    pub fn set_body(self: *Request, body: []const u8) bool {
        std.debug.assert(body.len <= MAX_BODY_LEN);
        
        if (body.len > MAX_BODY_LEN) {
            return false;
        }
        
        std.mem.copyForwards(u8, &self.body, body);
        self.body_len = @intCast(body.len);
        
        std.debug.assert(self.body_len <= MAX_BODY_LEN);
        
        return true;
    }
};

pub const Response = struct {
    status: HttpStatus,
    headers: [MAX_HEADERS]Header,
    headers_len: u32,
    body: [MAX_BODY_LEN]u8,
    body_len: u32,

    pub fn init() Response {
        return Response{
            .status = .ok,
            .headers_len = 0,
            .body_len = 0,
        };
    }

    pub fn get_header(self: *const Response, name: []const u8) ?[]const u8 {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_HEADER_NAME_LEN);
        
        var i: u32 = 0;
        while (i < self.headers_len) : (i += 1) {
            const header_name = self.headers[i].name[0..self.headers[i].name_len];
            if (std.mem.eql(u8, header_name, name)) {
                const header_value = self.headers[i].value[0..self.headers[i].value_len];
                return header_value;
            }
        }
        
        return null;
    }
};

pub const ApiClient = struct {
    base_url: [MAX_URL_LEN]u8,
    base_url_len: u32,
    default_headers: [MAX_HEADERS]Header,
    default_headers_len: u32,

    pub fn init(base_url: []const u8) ApiClient {
        std.debug.assert(base_url.len > 0);
        std.debug.assert(base_url.len <= MAX_URL_LEN);
        
        var client: ApiClient = undefined;
        std.mem.copyForwards(u8, &client.base_url, base_url);
        client.base_url_len = @intCast(base_url.len);
        client.default_headers_len = 0;
        
        std.debug.assert(client.base_url_len > 0);
        std.debug.assert(client.base_url_len <= MAX_URL_LEN);
        
        return client;
    }

    pub fn add_default_header(self: *ApiClient, name: []const u8, value: []const u8) bool {
        std.debug.assert(name.len > 0);
        std.debug.assert(name.len <= MAX_HEADER_NAME_LEN);
        std.debug.assert(value.len <= MAX_HEADER_VALUE_LEN);
        
        if (self.default_headers_len >= MAX_HEADERS) {
            return false;
        }
        
        self.default_headers[self.default_headers_len] = Header.init(name, value);
        self.default_headers_len += 1;
        
        std.debug.assert(self.default_headers_len <= MAX_HEADERS);
        
        return true;
    }

    pub fn build_url(self: *const ApiClient, path: []const u8, url_out: []u8) u32 {
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= MAX_URL_LEN);
        std.debug.assert(url_out.len >= MAX_URL_LEN);
        
        const base = self.base_url[0..self.base_url_len];
        var url_len: u32 = 0;
        
        std.mem.copyForwards(u8, url_out[url_len..], base);
        url_len += self.base_url_len;
        
        if (path[0] != '/') {
            url_out[url_len] = '/';
            url_len += 1;
        }
        
        std.mem.copyForwards(u8, url_out[url_len..], path);
        url_len += @intCast(path.len);
        
        std.debug.assert(url_len <= MAX_URL_LEN);
        std.debug.assert(url_len <= url_out.len);
        
        return url_len;
    }

    pub fn create_request(
        self: *const ApiClient,
        method: HttpMethod,
        path: []const u8,
    ) Request {
        std.debug.assert(path.len > 0);
        std.debug.assert(path.len <= MAX_URL_LEN);
        
        var url: [MAX_URL_LEN]u8 = undefined;
        const url_len = self.build_url(path, &url);
        
        var req = Request.init(method, url[0..url_len]);
        
        var i: u32 = 0;
        while (i < self.default_headers_len) : (i += 1) {
            const header_name = self.default_headers[i].name[0..self.default_headers[i].name_len];
            const header_value = self.default_headers[i].value[0..self.default_headers[i].value_len];
            _ = req.add_header(header_name, header_value);
        }
        
        std.debug.assert(req.url_len > 0);
        
        return req;
    }
};

