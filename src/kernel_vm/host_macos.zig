//! macOS Host Interface for Vantage VM
//! Why: Abstract macOS-specific operations for Vantage VM adaptation.
//! Grain Style: Explicit types (u32/u64 not usize), comprehensive assertions.

const std = @import("std");
const builtin = @import("builtin");
const Debug = @import("../kernel/debug.zig");

/// macOS version information.
/// Why: Track macOS version for adaptation and feature detection.
pub const MacOSVersion = struct {
    /// Major version (e.g., 26 for macOS Tahoe).
    major: u32,
    /// Minor version (e.g., 3 for macOS Tahoe 26.3).
    minor: u32,
    /// Patch version (e.g., 0 for macOS Tahoe 26.3.0).
    patch: u32,
    /// Whether this is a beta version.
    is_beta: bool,
    /// Beta version number (if is_beta is true).
    beta_number: u32,
    
    /// Format version string (e.g., "26.3.0" or "26.3.0-beta").
    /// Why: Human-readable version string for logging.
    pub fn format_string(self: *const MacOSVersion) [32]u8 {
        var buf: [32]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const writer = stream.writer();
        
        _ = std.fmt.bufPrint(&buf, "{d}.{d}.{d}", .{
            self.major,
            self.minor,
            self.patch,
        }) catch "0.0.0";
        
        if (self.is_beta) {
            _ = std.fmt.bufPrint(buf[std.mem.indexOf(u8, &buf, "\x00") orelse 0..], "-beta{d}", .{self.beta_number}) catch {};
        }
        
        return buf;
    }
    
    /// Compare versions (returns: -1 if self < other, 0 if equal, 1 if self > other).
    /// Why: Version comparison for feature detection.
    pub fn compare(self: *const MacOSVersion, other: *const MacOSVersion) i32 {
        if (self.major < other.major) return -1;
        if (self.major > other.major) return 1;
        if (self.minor < other.minor) return -1;
        if (self.minor > other.minor) return 1;
        if (self.patch < other.patch) return -1;
        if (self.patch > other.patch) return 1;
        if (self.is_beta and !other.is_beta) return -1;
        if (!self.is_beta and other.is_beta) return 1;
        if (self.is_beta and other.is_beta) {
            if (self.beta_number < other.beta_number) return -1;
            if (self.beta_number > other.beta_number) return 1;
        }
        return 0;
    }
};

/// macOS version detection result.
/// Why: Type-safe version detection result.
pub const MacOSVersionResult = union(enum) {
    /// Version detected successfully.
    success: MacOSVersion,
    /// Detection failed (not macOS or unsupported).
    failed: void,
};

/// Detect macOS version at runtime.
/// Why: Detect macOS version for adaptation and feature flags.
/// Contract: Must be called on macOS, returns version or failed.
/// Note: Uses sysctl to detect macOS version (requires macOS).
pub fn detect_macos_version() MacOSVersionResult {
    // Assert: Must be running on macOS.
    if (builtin.os.tag != .macos) {
        return .failed;
    }
    
    // Assert: Must be running on AArch64 (Apple Silicon).
    if (builtin.cpu.arch != .aarch64) {
        // Note: Intel Macs not supported for now.
        return .failed;
    }
    
    // Use sysctl to detect macOS version.
    // Note: sysctl kern.osproductversion returns version string like "26.3.0" or "26.3.0-beta1".
    // For now, use a stub that detects macOS Tahoe 26.3 Beta.
    // TODO: Implement actual sysctl call to detect version.
    // This is a placeholder that returns macOS Tahoe 26.3 Beta.
    const version = MacOSVersion{
        .major = 26,
        .minor = 3,
        .patch = 0,
        .is_beta = true,
        .beta_number = 1,
    };
    
    // Assert: Version must be reasonable (macOS versions start at 10.0).
    Debug.kassert(version.major >= 10, "Invalid macOS major version", .{});
    
    return .{ .success = version };
}

/// macOS feature flags.
/// Why: Track macOS capabilities for adaptation.
pub const MacOSFeatureFlags = struct {
    /// Whether JIT compilation is supported.
    jit_supported: bool,
    /// Whether code signing is required for JIT.
    jit_code_signing_required: bool,
    /// Whether performance counters are available.
    performance_counters_available: bool,
    /// Whether profiling tools integration is available.
    profiling_tools_available: bool,
    /// Whether memory protection APIs are available.
    memory_protection_available: bool,
    
    /// Initialize feature flags from macOS version.
    /// Why: Set feature flags based on detected macOS version.
    /// Contract: version must be valid macOS version.
    pub fn init_from_version(version: *const MacOSVersion) MacOSFeatureFlags {
        // Assert: Version must be valid.
        Debug.kassert(version.major >= 10, "Invalid macOS major version", .{});
        
        // macOS Tahoe 26.3 Beta feature flags.
        // Note: These are placeholders - actual feature detection will be implemented.
        return MacOSFeatureFlags{
            .jit_supported = true,
            .jit_code_signing_required = false, // Placeholder
            .performance_counters_available = true,
            .profiling_tools_available = true,
            .memory_protection_available = true,
        };
    }
};

/// macOS host interface.
/// Why: Abstract macOS-specific operations for Vantage VM.
pub const MacOSHost = struct {
    /// Detected macOS version.
    version: MacOSVersion,
    /// Feature flags for this macOS version.
    feature_flags: MacOSFeatureFlags,
    /// Whether host is initialized.
    initialized: bool,
    
    /// Initialize macOS host interface.
    /// Why: Set up macOS host interface with version detection.
    /// Contract: Must be called on macOS, returns host or failed.
    pub fn init() MacOSHostResult {
        // Detect macOS version.
        const version_result = detect_macos_version();
        
        switch (version_result) {
            .success => |version| {
                // Initialize feature flags from version.
                const feature_flags = MacOSFeatureFlags.init_from_version(&version);
                
                return .{ .success = MacOSHost{
                    .version = version,
                    .feature_flags = feature_flags,
                    .initialized = true,
                } };
            },
            .failed => {
                return .failed;
            },
        }
    }
    
    /// Get macOS version string.
    /// Why: Human-readable version string for logging.
    pub fn get_version_string(self: *const MacOSHost) [32]u8 {
        // Assert: Host must be initialized.
        Debug.kassert(self.initialized, "macOS host not initialized", .{});
        
        return self.version.format_string();
    }
    
    /// Check if feature is available.
    /// Why: Query feature availability for adaptation.
    pub fn has_feature(self: *const MacOSHost, feature: MacOSFeature) bool {
        // Assert: Host must be initialized.
        Debug.kassert(self.initialized, "macOS host not initialized", .{});
        
        return switch (feature) {
            .jit => self.feature_flags.jit_supported,
            .jit_code_signing => self.feature_flags.jit_code_signing_required,
            .performance_counters => self.feature_flags.performance_counters_available,
            .profiling_tools => self.feature_flags.profiling_tools_available,
            .memory_protection => self.feature_flags.memory_protection_available,
        };
    }
};

/// macOS feature enumeration.
/// Why: Type-safe feature queries.
pub const MacOSFeature = enum(u32) {
    /// JIT compilation support.
    jit = 0,
    /// JIT code signing requirement.
    jit_code_signing = 1,
    /// Performance counters availability.
    performance_counters = 2,
    /// Profiling tools integration availability.
    profiling_tools = 3,
    /// Memory protection APIs availability.
    memory_protection = 4,
};

/// macOS host initialization result.
/// Why: Type-safe host initialization result.
pub const MacOSHostResult = union(enum) {
    /// Host initialized successfully.
    success: MacOSHost,
    /// Initialization failed (not macOS or unsupported).
    failed: void,
};

/// Global macOS host instance.
/// Why: Single macOS host instance for VM use.
var global_macos_host: ?MacOSHost = null;

/// Set global macOS host instance.
/// Why: Initialize macOS host for VM use.
/// Contract: host must be initialized.
pub fn set_macos_host(host: MacOSHost) void {
    // Assert: Host must be initialized.
    Debug.kassert(host.initialized, "macOS host not initialized", .{});
    
    global_macos_host = host;
}

/// Get global macOS host instance.
/// Why: Access macOS host from VM code.
/// Contract: Host must be set before use.
pub fn get_macos_host() ?*const MacOSHost {
    return if (global_macos_host) |*host| host else null;
}
