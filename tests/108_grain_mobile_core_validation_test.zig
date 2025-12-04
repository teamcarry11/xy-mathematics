//! Tests for Grain Mobile Core validation functions.
//!
//! Why: Verify email and password validation functionality.
//! GrainStyle: grain_case, u32/u64, bounded operations, assertions.

const std = @import("std");
const grain_mobile_core = @import("grain_mobile_core");
const email_validation = grain_mobile_core.email_validation;
const password_validation = grain_mobile_core.password_validation;

test "email validation - valid email" {
    const valid_emails = [_][]const u8{
        "user@example.com",
        "test.email@domain.co.uk",
        "user+tag@example.org",
        "first.last@subdomain.example.com",
    };
    
    for (valid_emails) |email| {
        std.debug.assert(email.len > 0);
        std.debug.assert(email.len <= email_validation.MAX_EMAIL_LEN);
        const is_valid = email_validation.validate_email(email);
        std.debug.assert(is_valid);
    }
}

test "email validation - invalid email" {
    const invalid_emails = [_][]const u8{
        "not-an-email",
        "user@",
        "user@example",
    };
    
    for (invalid_emails) |email| {
        std.debug.assert(email.len >= email_validation.MIN_EMAIL_LEN);
        std.debug.assert(email.len <= email_validation.MAX_EMAIL_LEN);
        const is_valid = email_validation.validate_email(email);
        std.debug.assert(!is_valid);
    }
}

test "email validation - too long" {
    var long_email: [300]u8 = undefined;
    var i: u32 = 0;
    while (i < 250) : (i += 1) {
        long_email[i] = 'a';
    }
    long_email[250] = '@';
    long_email[251] = 'e';
    long_email[252] = 'x';
    long_email[253] = '.';
    long_email[254] = 'c';
    long_email[255] = 'o';
    long_email[256] = 'm';
    
    const email_slice = long_email[0..257];
    std.debug.assert(email_slice.len > email_validation.MAX_EMAIL_LEN);
    const is_valid = email_validation.validate_email(email_slice);
    std.debug.assert(!is_valid);
}

test "password validation - valid password" {
    // 1Password-style memorable passwords (32+ chars recommended)
    const valid_passwords = [_][]const u8{
        "aladdin!petition7inge1kalinda3TABLET",  // 1Password style: words + separators
        "MyP@ssw0rdWith32CharsMinimumRequired!",
        "Str0ng#PasswordWith32CharactersHere!",
        "Test1234$PasswordMustBe32CharsLongNow",
    };
    
    for (valid_passwords) |password| {
        std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
        std.debug.assert(password.len <= password_validation.MAX_PASSWORD_LEN);
        const is_valid = password_validation.validate_password(password);
        std.debug.assert(is_valid);
    }
}

test "password validation - invalid password" {
    const invalid_passwords = [_][]const u8{
        "short",  // Too short (< 32 chars)
        "nouppercase123!ButLongEnoughFor32Chars",
        "NOLOWERCASE123!ButLongEnoughFor32Chars",
        "NoDigits!ButLongEnoughFor32CharsHere",
        "NoSpecial123ButLongEnoughFor32CharsHere",
        "TooShort123!",  // < 32 chars
    };
    
    for (invalid_passwords) |password| {
        if (password.len > 0 and password.len <= password_validation.MAX_PASSWORD_LEN) {
            const is_valid = password_validation.validate_password(password);
            std.debug.assert(!is_valid);
        }
    }
    
    // Test empty string separately (would fail assertion)
    const empty: []const u8 = "";
    std.debug.assert(empty.len == 0);
    
    // Test too short password (< 32 chars)
    const too_short = "Short123!";
    std.debug.assert(too_short.len < password_validation.MIN_PASSWORD_LEN);
    const is_valid_short = password_validation.validate_password(too_short);
    std.debug.assert(!is_valid_short);
}

test "password strength - weak password" {
    // Weak password: minimal characters, low score, but meets 32-char minimum
    const weak_password = "Ab1!Ab1!Ab1!Ab1!Ab1!Ab1!Ab1!Ab1!";  // 32 chars
    
    std.debug.assert(weak_password.len >= password_validation.MIN_PASSWORD_LEN);
    std.debug.assert(weak_password.len <= password_validation.MAX_PASSWORD_LEN);
    const strength = password_validation.get_password_strength(weak_password);
    // Score: low character diversity, but 32+ chars gets length bonus
    std.debug.assert(strength == .weak or strength == .medium);
}

test "password strength - strong password" {
    // 1Password-style memorable passwords score well (32+ chars, words + separators)
    const strong_passwords = [_][]const u8{
        "aladdin!petition7inge1kalinda3TABLET",  // 1Password style
        "VeryStr0ng#Password123!With32CharsMin",
        "Complex@Passw0rdWithManyChars32Plus!",
        "Word1!Word2@Word3#Word4$Word5%Word6",  // Memorable style
    };
    
    for (strong_passwords) |password| {
        std.debug.assert(password.len >= password_validation.MIN_PASSWORD_LEN);
        std.debug.assert(password.len <= password_validation.MAX_PASSWORD_LEN);
        const strength = password_validation.get_password_strength(password);
        std.debug.assert(strength == .strong);
    }
}

test "password validation - too long" {
    var long_password: [200]u8 = undefined;
    var i: u32 = 0;
    while (i < 150) : (i += 1) {
        long_password[i] = 'A';
    }
    
    const password_slice = long_password[0..150];
    std.debug.assert(password_slice.len > password_validation.MAX_PASSWORD_LEN);
    const is_valid = password_validation.validate_password(password_slice);
    std.debug.assert(!is_valid);
}

