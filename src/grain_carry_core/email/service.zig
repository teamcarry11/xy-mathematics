//! Grain Carry Core Email Service: Email sending for OTP delivery.
//!
//! Why: Provide email sending functionality for OTP codes and notifications.
//! Architecture: Email service with OTP email templates, extensible for SMTP.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions, max 70 lines.
//!
//! 2025-12-06-232641-pst: Grain Carry Agent

const std = @import("std");

// Bounded: Max email subject length.
pub const MAX_EMAIL_SUBJECT_LEN: u32 = 256;

// Bounded: Max email body length.
pub const MAX_EMAIL_BODY_LEN: u32 = 4096;

// Bounded: Max email recipient length.
pub const MAX_EMAIL_RECIPIENT_LEN: u32 = 256;

// Bounded: Max OTP code length.
pub const MAX_OTP_CODE_LEN: u32 = 10;

// Email sending result.
pub const EmailResult = enum(u8) {
    success,
    invalid_recipient,
    invalid_subject,
    invalid_body,
    service_unavailable,
    send_failed,
};

// Email service configuration.
pub const EmailConfig = struct {
    smtp_host: [256]u8,
    smtp_host_len: u32,
    smtp_port: u16,
    smtp_username: [256]u8,
    smtp_username_len: u32,
    smtp_password: [256]u8,
    smtp_password_len: u32,
    from_email: [256]u8,
    from_email_len: u32,
    enabled: bool,

    pub fn init() EmailConfig {
        var config = EmailConfig{
            .smtp_host = undefined,
            .smtp_host_len = 0,
            .smtp_port = 587,
            .smtp_username = undefined,
            .smtp_username_len = 0,
            .smtp_password = undefined,
            .smtp_password_len = 0,
            .from_email = undefined,
            .from_email_len = 0,
            .enabled = false,
        };
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            config.smtp_host[i] = 0;
            config.smtp_username[i] = 0;
            config.smtp_password[i] = 0;
            config.from_email[i] = 0;
        }
        std.debug.assert(config.smtp_port > 0);
        std.debug.assert(config.smtp_port <= 65535);
        std.debug.assert(!config.enabled);
        return config;
    }
};

// Email service.
pub const EmailService = struct {
    config: EmailConfig,
    email_count: u32,

    pub fn init() EmailService {
        var service = EmailService{
            .config = EmailConfig.init(),
            .email_count = 0,
        };
        std.debug.assert(service.email_count == 0);
        return service;
    }

    // Configure email service.
    pub fn configure(self: *EmailService, config: EmailConfig) void {
        std.debug.assert(self != null);
        self.config = config;
        std.debug.assert(self.config.smtp_port > 0);
        std.debug.assert(self.config.smtp_port <= 65535);
    }

    // Send OTP email.
    pub fn send_otp_email(
        self: *EmailService,
        recipient: []const u8,
        otp_code: []const u8,
    ) EmailResult {
        std.debug.assert(self != null);
        std.debug.assert(recipient.len > 0);
        std.debug.assert(recipient.len <= MAX_EMAIL_RECIPIENT_LEN);
        std.debug.assert(otp_code.len > 0);
        std.debug.assert(otp_code.len <= MAX_OTP_CODE_LEN);
        if (recipient.len == 0 or recipient.len > MAX_EMAIL_RECIPIENT_LEN) {
            return EmailResult.invalid_recipient;
        }
        if (otp_code.len == 0 or otp_code.len > MAX_OTP_CODE_LEN) {
            return EmailResult.invalid_body;
        }
        if (!self.config.enabled) {
            return EmailResult.service_unavailable;
        }
        var subject_buf: [MAX_EMAIL_SUBJECT_LEN]u8 = undefined;
        const subject_len = build_otp_subject(&subject_buf);
        var body_buf: [MAX_EMAIL_BODY_LEN]u8 = undefined;
        const body_len = build_otp_body(otp_code, &body_buf);
        const result = self.send_email(recipient, subject_buf[0..subject_len], body_buf[0..body_len]);
        if (result == EmailResult.success) {
            self.email_count += 1;
        }
        std.debug.assert(self.email_count <= 10000);
        return result;
    }

    // Send email (internal, extensible for SMTP).
    fn send_email(
        self: *EmailService,
        recipient: []const u8,
        subject: []const u8,
        body: []const u8,
    ) EmailResult {
        std.debug.assert(self != null);
        std.debug.assert(recipient.len > 0);
        std.debug.assert(subject.len > 0);
        std.debug.assert(body.len > 0);
        if (recipient.len > MAX_EMAIL_RECIPIENT_LEN) {
            return EmailResult.invalid_recipient;
        }
        if (subject.len > MAX_EMAIL_SUBJECT_LEN) {
            return EmailResult.invalid_subject;
        }
        if (body.len > MAX_EMAIL_BODY_LEN) {
            return EmailResult.invalid_body;
        }
        if (!self.config.enabled) {
            return EmailResult.service_unavailable;
        }
        std.debug.assert(recipient.len <= MAX_EMAIL_RECIPIENT_LEN);
        std.debug.assert(subject.len <= MAX_EMAIL_SUBJECT_LEN);
        std.debug.assert(body.len <= MAX_EMAIL_BODY_LEN);
        return EmailResult.success;
    }
};

// Build OTP email subject.
fn build_otp_subject(subject_buf: []u8) u32 {
    std.debug.assert(subject_buf.len >= MAX_EMAIL_SUBJECT_LEN);
    const subject = "Your OTP Code";
    const subject_len = @min(subject.len, subject_buf.len);
    std.mem.copyForwards(u8, subject_buf[0..subject_len], subject);
    std.debug.assert(subject_len > 0);
    std.debug.assert(subject_len <= MAX_EMAIL_SUBJECT_LEN);
    return @intCast(subject_len);
}

// Build OTP email body.
fn build_otp_body(otp_code: []const u8, body_buf: []u8) u32 {
    std.debug.assert(otp_code.len > 0);
    std.debug.assert(otp_code.len <= MAX_OTP_CODE_LEN);
    std.debug.assert(body_buf.len >= MAX_EMAIL_BODY_LEN);
    const prefix = "Your OTP code is: ";
    var body_len: u32 = 0;
    const prefix_len = @min(prefix.len, body_buf.len);
    std.mem.copyForwards(u8, body_buf[body_len..], prefix);
    body_len += @intCast(prefix_len);
    const code_len = @min(otp_code.len, body_buf.len - body_len);
    std.mem.copyForwards(u8, body_buf[body_len..], otp_code[0..code_len]);
    body_len += @intCast(code_len);
    const suffix = "\n\nThis code will expire in 5 minutes.";
    const suffix_len = @min(suffix.len, body_buf.len - body_len);
    std.mem.copyForwards(u8, body_buf[body_len..], suffix);
    body_len += @intCast(suffix_len);
    std.debug.assert(body_len > 0);
    std.debug.assert(body_len <= MAX_EMAIL_BODY_LEN);
    return body_len;
}

