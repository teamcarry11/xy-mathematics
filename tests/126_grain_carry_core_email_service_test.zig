//! Tests for Grain Carry Core Email Service.
//!
//! Why: Verify email service functionality for OTP delivery.
//! Architecture: Comprehensive test coverage for email service.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-06-232641-pst: Grain Carry Agent

const std = @import("std");
const testing = std.testing;
const grain_carry_core = @import("grain_carry_core");
const email = grain_carry_core.email.service;

test "email service initialization" {
    const service = email.EmailService.init();
    
    std.debug.assert(service.email_count == 0);
    std.debug.assert(!service.config.enabled);
}

test "email service configuration" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = true;
    config.smtp_port = 587;
    
    service.configure(config);
    
    std.debug.assert(service.config.enabled);
    std.debug.assert(service.config.smtp_port == 587);
}

test "email service send otp email disabled" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = false;
    service.configure(config);
    
    const recipient = "test@example.com";
    const otp_code = "123456";
    const result = service.send_otp_email(recipient, otp_code);
    
    try testing.expect(result == email.EmailResult.service_unavailable);
}

test "email service send otp email enabled" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = true;
    service.configure(config);
    
    const recipient = "test@example.com";
    const otp_code = "123456";
    const result = service.send_otp_email(recipient, otp_code);
    
    try testing.expect(result == email.EmailResult.success);
    try testing.expect(service.email_count == 1);
}

test "email service send otp email invalid recipient" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = true;
    service.configure(config);
    
    const recipient = "";
    const otp_code = "123456";
    const result = service.send_otp_email(recipient, otp_code);
    
    try testing.expect(result == email.EmailResult.invalid_recipient);
}

test "email service send otp email invalid code" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = true;
    service.configure(config);
    
    const recipient = "test@example.com";
    const otp_code = "";
    const result = service.send_otp_email(recipient, otp_code);
    
    try testing.expect(result == email.EmailResult.invalid_body);
}

test "email service multiple emails" {
    var service = email.EmailService.init();
    var config = email.EmailConfig.init();
    config.enabled = true;
    service.configure(config);
    
    const recipient = "test@example.com";
    const otp_code = "123456";
    _ = service.send_otp_email(recipient, otp_code);
    _ = service.send_otp_email(recipient, otp_code);
    _ = service.send_otp_email(recipient, otp_code);
    
    try testing.expect(service.email_count == 3);
}

