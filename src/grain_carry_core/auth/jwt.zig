// JWT (JSON Web Token) handling for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Basic JWT parsing and validation (HS256 algorithm)
// Note: Full JWT implementation would require JSON parsing library

const std = @import("std");
const errors = @import("../utils/errors.zig");
const hash = @import("../crypto/hash.zig");

pub const MAX_JWT_LEN: u32 = 2048;
pub const JWT_HEADER: []const u8 = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

pub const JwtClaims = struct {
    user_id: [64]u8,
    user_id_len: u32,
    exp: u64,  // Expiration timestamp
    iat: u64,  // Issued at timestamp
};

// Base64URL encoding (simplified, for JWT)
fn base64url_encode(input: []const u8, output: []u8) u32 {
    std.debug.assert(input.len > 0);
    std.debug.assert(output.len >= (input.len * 4 / 3 + 4));
    
    const base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    var i: u32 = 0;
    var out_idx: u32 = 0;
    
    while (i < input.len) {
        const byte1 = input[i];
        i += 1;
        
        if (i < input.len) {
            const byte2 = input[i];
            i += 1;
            
            if (i < input.len) {
                const byte3 = input[i];
                i += 1;
                
                const b1 = (byte1 >> 2) & 0x3F;
                const b2 = ((byte1 & 0x03) << 4) | ((byte2 >> 4) & 0x0F);
                const b3 = ((byte2 & 0x0F) << 2) | ((byte3 >> 6) & 0x03);
                const b4 = byte3 & 0x3F;
                
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b3)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b4)];
                out_idx += 1;
            } else {
                const b1 = (byte1 >> 2) & 0x3F;
                const b2 = ((byte1 & 0x03) << 4) | ((byte2 >> 4) & 0x0F);
                const b3 = (byte2 & 0x0F) << 2;
                
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b3)];
                out_idx += 1;
                if (out_idx < output.len) output[out_idx] = '=';
                out_idx += 1;
            }
        } else {
            const b1 = (byte1 >> 2) & 0x3F;
            const b2 = (byte1 & 0x03) << 4;
            
            if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b1)];
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = base64_chars[@intCast(b2)];
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = '=';
            out_idx += 1;
            if (out_idx < output.len) output[out_idx] = '=';
            out_idx += 1;
        }
    }
    
    std.debug.assert(out_idx <= output.len);
    
    return out_idx;
}

// Base64URL decoding (simplified, for JWT)
fn base64url_decode(input: []const u8, output: []u8) u32 {
    std.debug.assert(input.len > 0);
    std.debug.assert(output.len >= (input.len * 3 / 4));
    
    var out_idx: u32 = 0;
    var i: u32 = 0;
    
    while (i < input.len) {
        if (input[i] == '=') {
            break;
        }
        
        const char1 = base64url_char_to_value(input[i]);
        i += 1;
        if (i >= input.len) break;
        
        const char2 = base64url_char_to_value(input[i]);
        i += 1;
        
        if (out_idx < output.len) {
            output[out_idx] = (@as(u8, @intCast(char1)) << 2) | (@as(u8, @intCast(char2 >> 4)) & 0x03);
            out_idx += 1;
        }
        
        if (i >= input.len or input[i] == '=') break;
        const char3 = base64url_char_to_value(input[i]);
        i += 1;
        
        if (out_idx < output.len) {
            output[out_idx] = (@as(u8, @intCast(char2 & 0x0F)) << 4) | (@as(u8, @intCast(char3 >> 2)) & 0x0F);
            out_idx += 1;
        }
        
        if (i >= input.len or input[i] == '=') break;
        const char4 = base64url_char_to_value(input[i]);
        i += 1;
        
        if (out_idx < output.len) {
            output[out_idx] = (@as(u8, @intCast(char3 & 0x03)) << 6) | @as(u8, @intCast(char4));
            out_idx += 1;
        }
    }
    
    std.debug.assert(out_idx <= output.len);
    
    return out_idx;
}

fn base64url_char_to_value(c: u8) u32 {
    if (c >= 'A' and c <= 'Z') {
        return @as(u32, c - 'A');
    } else if (c >= 'a' and c <= 'z') {
        return @as(u32, c - 'a' + 26);
    } else if (c >= '0' and c <= '9') {
        return @as(u32, c - '0' + 52);
    } else if (c == '-') {
        return 62;
    } else if (c == '_') {
        return 63;
    } else {
        return 0;
    }
}

// Create JWT token (simplified - uses fixed header)
pub fn create_jwt(
    claims: *const JwtClaims,
    secret: []const u8,
    token_out: []u8,
) u32 {
    std.debug.assert(claims.user_id_len > 0);
    std.debug.assert(secret.len > 0);
    std.debug.assert(token_out.len >= MAX_JWT_LEN);
    
    // Encode header
    var header_encoded: [256]u8 = undefined;
    const header_encoded_len = base64url_encode(JWT_HEADER, &header_encoded);
    
    // Encode claims (simplified - just user_id and timestamps)
    // Format: {"user_id":"...","exp":123,"iat":456}
    var claims_json: [512]u8 = undefined;
    var claims_json_len: u32 = 0;
    
    // Start JSON object
    claims_json[claims_json_len] = '{';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "user_id");
    claims_json_len += 7;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], claims.user_id[0..claims.user_id_len]);
    claims_json_len += claims.user_id_len;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    
    // Add exp
    claims_json[claims_json_len] = ',';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "exp");
    claims_json_len += 3;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    // Convert exp to string (simplified - assume max 20 digits)
    var exp_str: [20]u8 = undefined;
    var exp_remaining = claims.exp;
    var exp_str_len: u32 = 0;
    if (exp_remaining == 0) {
        exp_str[0] = '0';
        exp_str_len = 1;
    } else {
        var exp_idx: u32 = 19;
        while (exp_remaining > 0) {
            exp_str[exp_idx] = '0' + @as(u8, @intCast(exp_remaining % 10));
            exp_remaining /= 10;
            exp_idx -= 1;
        }
        exp_str_len = 20 - exp_idx - 1;
        std.mem.copyForwards(u8, claims_json[claims_json_len..], exp_str[exp_idx + 1..20]);
        claims_json_len += exp_str_len;
    }
    
    // Add iat
    claims_json[claims_json_len] = ',';
    claims_json_len += 1;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    std.mem.copyForwards(u8, claims_json[claims_json_len..], "iat");
    claims_json_len += 3;
    claims_json[claims_json_len] = '"';
    claims_json_len += 1;
    claims_json[claims_json_len] = ':';
    claims_json_len += 1;
    // Convert iat to string
    var iat_remaining = claims.iat;
    var iat_str: [20]u8 = undefined;
    var iat_str_len: u32 = 0;
    if (iat_remaining == 0) {
        iat_str[0] = '0';
        iat_str_len = 1;
    } else {
        var iat_idx: u32 = 19;
        while (iat_remaining > 0) {
            iat_str[iat_idx] = '0' + @as(u8, @intCast(iat_remaining % 10));
            iat_remaining /= 10;
            iat_idx -= 1;
        }
        iat_str_len = 20 - iat_idx - 1;
        std.mem.copyForwards(u8, claims_json[claims_json_len..], iat_str[iat_idx + 1..20]);
        claims_json_len += iat_str_len;
    }
    
    // End JSON object
    claims_json[claims_json_len] = '}';
    claims_json_len += 1;
    
    var claims_encoded: [256]u8 = undefined;
    const claims_encoded_len = base64url_encode(claims_json[0..claims_json_len], &claims_encoded);
    
    // Create signature: HMAC-SHA256(header.payload, secret)
    var message: [512]u8 = undefined;
    std.mem.copyForwards(u8, message[0..header_encoded_len], header_encoded[0..header_encoded_len]);
    message[header_encoded_len] = '.';
    std.mem.copyForwards(u8, message[header_encoded_len + 1..header_encoded_len + 1 + claims_encoded_len], claims_encoded[0..claims_encoded_len]);
    const message_len = header_encoded_len + 1 + claims_encoded_len;
    
    // HMAC-SHA256
    var signature: [32]u8 = undefined;
    hmac_sha256(secret, message[0..message_len], &signature);
    
    var signature_encoded: [64]u8 = undefined;
    const signature_encoded_len = base64url_encode(&signature, &signature_encoded);
    
    // Combine: header.payload.signature
    var token_len: u32 = 0;
    std.mem.copyForwards(u8, token_out[token_len..], header_encoded[0..header_encoded_len]);
    token_len += header_encoded_len;
    token_out[token_len] = '.';
    token_len += 1;
    std.mem.copyForwards(u8, token_out[token_len..], claims_encoded[0..claims_encoded_len]);
    token_len += claims_encoded_len;
    token_out[token_len] = '.';
    token_len += 1;
    std.mem.copyForwards(u8, token_out[token_len..], signature_encoded[0..signature_encoded_len]);
    token_len += signature_encoded_len;
    
    std.debug.assert(token_len <= token_out.len);
    
    return token_len;
}

// HMAC-SHA256 for JWT signatures
fn hmac_sha256(key: []const u8, message: []const u8, output: []u8) void {
    std.debug.assert(key.len > 0);
    std.debug.assert(message.len > 0);
    std.debug.assert(output.len >= 32);
    
    const block_size: u32 = 64;
    var ipad_key: [block_size]u8 = undefined;
    var opad_key: [block_size]u8 = undefined;
    
    if (key.len > block_size) {
        var key_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(key, &key_hash, .{});
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..32], &key_hash);
    } else {
        std.mem.set(u8, &ipad_key, 0);
        std.mem.copyForwards(u8, ipad_key[0..key.len], key);
    }
    
    var i: u32 = 0;
    while (i < block_size) : (i += 1) {
        opad_key[i] = ipad_key[i];
        ipad_key[i] ^= 0x36;
        opad_key[i] ^= 0x5C;
    }
    
    var inner_hash: [32]u8 = undefined;
    var inner_input: [block_size + 256]u8 = undefined;
    std.mem.copyForwards(u8, inner_input[0..block_size], &ipad_key);
    if (message.len <= 256) {
        std.mem.copyForwards(u8, inner_input[block_size..block_size + message.len], message);
        std.crypto.hash.sha2.Sha256.hash(inner_input[0..block_size + message.len], &inner_hash, .{});
    } else {
        std.crypto.hash.sha2.Sha256.hash(message, &inner_hash, .{});
    }
    
    var outer_input: [block_size + 32]u8 = undefined;
    std.mem.copyForwards(u8, outer_input[0..block_size], &opad_key);
    std.mem.copyForwards(u8, outer_input[block_size..block_size + 32], &inner_hash);
    std.crypto.hash.sha2.Sha256.hash(outer_input[0..block_size + 32], output[0..32], .{});
    
    std.debug.assert(output.len >= 32);
}

// Validate JWT token
pub fn validate_jwt(
    token: []const u8,
    secret: []const u8,
    current_time: u64,
    claims_out: *JwtClaims,
) bool {
    std.debug.assert(token.len > 0);
    std.debug.assert(token.len <= MAX_JWT_LEN);
    std.debug.assert(secret.len > 0);
    std.debug.assert(current_time > 0);
    std.debug.assert(claims_out != null);
    
    // Split token into parts
    var parts: [3][]const u8 = undefined;
    var part_count: u32 = 0;
    var start: u32 = 0;
    var i: u32 = 0;
    while (i < token.len and part_count < 3) : (i += 1) {
        if (token[i] == '.') {
            parts[part_count] = token[start..i];
            part_count += 1;
            start = i + 1;
        }
    }
    if (part_count < 2) {
        return false;
    }
    parts[part_count] = token[start..];
    part_count += 1;
    
    if (part_count != 3) {
        return false;
    }
    
    // Verify signature
    var message: [1024]u8 = undefined;
    std.mem.copyForwards(u8, message[0..parts[0].len], parts[0]);
    message[parts[0].len] = '.';
    std.mem.copyForwards(u8, message[parts[0].len + 1..parts[0].len + 1 + parts[1].len], parts[1]);
    const message_len = parts[0].len + 1 + parts[1].len;
    
    var computed_sig: [32]u8 = undefined;
    hmac_sha256(secret, message[0..message_len], &computed_sig);
    
    var computed_sig_encoded: [64]u8 = undefined;
    const computed_sig_len = base64url_encode(&computed_sig, &computed_sig_encoded);
    
    // Compare signatures (simplified - should use constant-time comparison)
    if (computed_sig_len != parts[2].len) {
        return false;
    }
    if (!std.mem.eql(u8, computed_sig_encoded[0..computed_sig_len], parts[2])) {
        return false;
    }
    
    // Decode and parse claims (simplified)
    var claims_decoded: [256]u8 = undefined;
    const claims_decoded_len = base64url_decode(parts[1], &claims_decoded);
    
    // Simple parsing: find "exp" and "user_id" (simplified JSON parsing)
    var exp_found: bool = false;
    var exp_value: u64 = 0;
    var user_id_start: ?u32 = null;
    var user_id_end: ?u32 = null;
    
    i = 0;
    while (i < claims_decoded_len) : (i += 1) {
        if (i + 4 < claims_decoded_len and std.mem.eql(u8, claims_decoded[i..i + 5], "\"exp\"")) {
            i += 5;
            while (i < claims_decoded_len and (claims_decoded[i] == ' ' or claims_decoded[i] == ':')) : (i += 1) {}
            var exp_str_start = i;
            while (i < claims_decoded_len and claims_decoded[i] >= '0' and claims_decoded[i] <= '9') : (i += 1) {}
            const exp_str = claims_decoded[exp_str_start..i];
            // Parse integer manually (Grain Style: avoid fmt functions)
            exp_value = 0;
            var exp_j: u32 = 0;
            while (exp_j < exp_str.len) : (exp_j += 1) {
                if (exp_str[exp_j] >= '0' and exp_str[exp_j] <= '9') {
                    exp_value = exp_value * 10 + @as(u64, exp_str[exp_j] - '0');
                }
            }
            exp_found = true;
        }
        if (i + 7 < claims_decoded_len and std.mem.eql(u8, claims_decoded[i..i + 8], "\"user_id\"")) {
            i += 8;
            while (i < claims_decoded_len and claims_decoded[i] != '"') : (i += 1) {}
            i += 1;
            user_id_start = i;
            while (i < claims_decoded_len and claims_decoded[i] != '"') : (i += 1) {}
            user_id_end = i;
        }
    }
    
    if (!exp_found) {
        return false;
    }
    
    if (current_time > exp_value) {
        return false;
    }
    
    if (user_id_start != null and user_id_end != null) {
        const user_id_len = user_id_end.? - user_id_start.?;
        if (user_id_len > 0 and user_id_len <= 64) {
            std.mem.copyForwards(u8, &claims_out.user_id, claims_decoded[user_id_start.?..user_id_end.?]);
            claims_out.user_id_len = @intCast(user_id_len);
        }
    }
    
    claims_out.exp = exp_value;
    claims_out.iat = 0;  // Not parsed in simplified version
    
    std.debug.assert(claims_out.user_id_len > 0);
    std.debug.assert(claims_out.exp > 0);
    
    return true;
}

