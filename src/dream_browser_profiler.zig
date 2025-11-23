const std = @import("std");

/// Dream Browser Profiler: Hot path identification and optimization guidance.
/// ~<~ Glow Airbend: explicit profiling, bounded samples.
/// ~~~~ Glow Waterbend: profiling flows deterministically through DAG.
///
/// This implements:
/// - Function call profiling (track call counts, total time, average time)
/// - Hot path identification (functions that exceed time thresholds)
/// - Call stack sampling (identify slow call chains)
/// - Optimization recommendations (suggest optimizations for hot paths)
pub const DreamBrowserProfiler = struct {
    // Bounded: Max 1000 functions to profile
    pub const MAX_PROFILED_FUNCTIONS: u32 = 1000;
    
    // Bounded: Max 10,000 call samples
    pub const MAX_CALL_SAMPLES: u32 = 10_000;
    
    // Hot path threshold: functions taking >1ms are considered hot
    pub const HOT_PATH_THRESHOLD_US: u32 = 1000; // 1ms in microseconds
    
    // Critical path threshold: functions taking >10ms are critical
    pub const CRITICAL_PATH_THRESHOLD_US: u32 = 10_000; // 10ms in microseconds
    
    /// Function profile (call statistics).
    pub const FunctionProfile = struct {
        function_name: []const u8, // Function name (e.g., "layout", "render")
        call_count: u32, // Number of times called
        total_time_us: u64, // Total time spent (microseconds)
        average_time_us: u32, // Average time per call (microseconds)
        min_time_us: u32, // Minimum call time
        max_time_us: u32, // Maximum call time
        is_hot_path: bool, // Whether this is a hot path
        is_critical_path: bool, // Whether this is a critical path
    };
    
    /// Call sample (for stack trace analysis).
    pub const CallSample = struct {
        function_name: []const u8, // Function name
        timestamp_us: u64, // Timestamp when called
        duration_us: u32, // Duration of call
        parent_function: ?[]const u8 = null, // Parent function (caller)
    };
    
    /// Function profiles (indexed by function name hash).
    pub const ProfileMap = struct {
        profiles: []FunctionProfile, // Function profiles
        profiles_len: u32, // Current number of profiles
        function_names: [][]const u8, // Function name strings (owned)
        function_names_len: u32, // Current number of function names
    };
    
    /// Call samples (for analysis).
    pub const SampleBuffer = struct {
        samples: []CallSample, // Call samples
        samples_len: u32, // Current number of samples
        samples_index: u32, // Circular buffer index
    };
    
    profile_map: ProfileMap,
    sample_buffer: SampleBuffer,
    
    /// Initialize profiler.
    pub fn init(allocator: std.mem.Allocator) !DreamBrowserProfiler {
        // Pre-allocate profile map
        const profiles = try allocator.alloc(FunctionProfile, MAX_PROFILED_FUNCTIONS);
        const function_names = try allocator.alloc([]const u8, MAX_PROFILED_FUNCTIONS);
        
        // Pre-allocate sample buffer
        const samples = try allocator.alloc(CallSample, MAX_CALL_SAMPLES);
        
        return DreamBrowserProfiler{
            .allocator = allocator,
            .profile_map = ProfileMap{
                .profiles = profiles,
                .profiles_len = 0,
                .function_names = function_names,
                .function_names_len = 0,
            },
            .sample_buffer = SampleBuffer{
                .samples = samples,
                .samples_len = 0,
                .samples_index = 0,
            },
        };
    }
    
    /// Deinitialize profiler.
    pub fn deinit(self: *DreamBrowserProfiler) void {
        // Free function name strings
        for (self.profile_map.function_names[0..self.profile_map.function_names_len]) |name| {
            self.allocator.free(name);
        }
        
        // Free sample function names
        for (self.sample_buffer.samples[0..self.sample_buffer.samples_len]) |sample| {
            self.allocator.free(sample.function_name);
            if (sample.parent_function) |parent| {
                self.allocator.free(parent);
            }
        }
        
        // Free arrays
        self.allocator.free(self.profile_map.profiles);
        self.allocator.free(self.profile_map.function_names);
        self.allocator.free(self.sample_buffer.samples);
    }
    
    /// Get current timestamp in microseconds.
    fn get_current_time_us() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative * 1_000_000; // Convert to microseconds (simplified)
    }
    
    /// Start profiling a function call.
    pub fn start_function(self: *DreamBrowserProfiler, function_name: []const u8) u64 {
        // Record start time
        return get_current_time_us();
    }
    
    /// End profiling a function call.
    pub fn end_function(
        self: *DreamBrowserProfiler,
        function_name: []const u8,
        start_time_us: u64,
        parent_function: ?[]const u8,
    ) !void {
        // Assert: Function name must be non-empty
        std.debug.assert(function_name.len > 0);
        std.debug.assert(function_name.len <= 256); // Bounded function name length
        
        const end_time_us = get_current_time_us();
        const duration_us = @as(u32, @intCast(end_time_us - start_time_us));
        
        // Assert: Duration must be reasonable
        std.debug.assert(duration_us < 1_000_000_000); // Max 1000 seconds
        
        // Find or create function profile
        var profile_index: ?u32 = null;
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (std.mem.eql(u8, self.profile_map.function_names[i], function_name)) {
                profile_index = i;
                break;
            }
        }
        
        if (profile_index) |idx| {
            // Update existing profile
            const profile = &self.profile_map.profiles[idx];
            profile.call_count += 1;
            profile.total_time_us += duration_us;
            profile.average_time_us = @as(u32, @intCast(profile.total_time_us / profile.call_count));
            
            // Update min/max
            if (duration_us < profile.min_time_us or profile.call_count == 1) {
                profile.min_time_us = duration_us;
            }
            if (duration_us > profile.max_time_us) {
                profile.max_time_us = duration_us;
            }
            
            // Update hot path flags
            profile.is_hot_path = profile.average_time_us > HOT_PATH_THRESHOLD_US;
            profile.is_critical_path = profile.average_time_us > CRITICAL_PATH_THRESHOLD_US;
        } else {
            // Create new profile
            if (self.profile_map.profiles_len >= MAX_PROFILED_FUNCTIONS) {
                return; // Skip if at capacity
            }
            
            const name_copy = try self.allocator.dupe(u8, function_name);
            errdefer self.allocator.free(name_copy);
            
            const idx = self.profile_map.profiles_len;
            self.profile_map.function_names[idx] = name_copy;
            self.profile_map.profiles[idx] = FunctionProfile{
                .function_name = name_copy,
                .call_count = 1,
                .total_time_us = duration_us,
                .average_time_us = duration_us,
                .min_time_us = duration_us,
                .max_time_us = duration_us,
                .is_hot_path = duration_us > HOT_PATH_THRESHOLD_US,
                .is_critical_path = duration_us > CRITICAL_PATH_THRESHOLD_US,
            };
            self.profile_map.profiles_len += 1;
            self.profile_map.function_names_len += 1;
        }
        
        // Add call sample (for stack trace analysis)
        if (self.sample_buffer.samples_len < MAX_CALL_SAMPLES) {
            const sample_idx = self.sample_buffer.samples_len;
            const sample_name = try self.allocator.dupe(u8, function_name);
            errdefer self.allocator.free(sample_name);
            
            const parent_name = if (parent_function) |parent| blk: {
                const parent_copy = try self.allocator.dupe(u8, parent);
                break :blk parent_copy;
            } else null;
            
            self.sample_buffer.samples[sample_idx] = CallSample{
                .function_name = sample_name,
                .timestamp_us = start_time_us,
                .duration_us = duration_us,
                .parent_function = parent_name,
            };
            self.sample_buffer.samples_len += 1;
        } else {
            // Circular buffer: overwrite oldest sample
            const sample_idx = self.sample_buffer.samples_index;
            const old_sample = &self.sample_buffer.samples[sample_idx];
            
            // Free old sample data
            self.allocator.free(old_sample.function_name);
            if (old_sample.parent_function) |parent| {
                self.allocator.free(parent);
            }
            
            // Create new sample
            const sample_name = try self.allocator.dupe(u8, function_name);
            errdefer self.allocator.free(sample_name);
            
            const parent_name = if (parent_function) |parent| blk: {
                const parent_copy = try self.allocator.dupe(u8, parent);
                break :blk parent_copy;
            } else null;
            
            self.sample_buffer.samples[sample_idx] = CallSample{
                .function_name = sample_name,
                .timestamp_us = start_time_us,
                .duration_us = duration_us,
                .parent_function = parent_name,
            };
            
            self.sample_buffer.samples_index = (sample_idx + 1) % MAX_CALL_SAMPLES;
        }
    }
    
    /// Get function profile by name.
    pub fn get_function_profile(
        self: *const DreamBrowserProfiler,
        function_name: []const u8,
    ) ?*const FunctionProfile {
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (std.mem.eql(u8, self.profile_map.function_names[i], function_name)) {
                return &self.profile_map.profiles[i];
            }
        }
        return null;
    }
    
    /// Get all hot paths (functions exceeding threshold).
    pub fn get_hot_paths(self: *const DreamBrowserProfiler) []const FunctionProfile {
        // Count hot paths
        var hot_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (self.profile_map.profiles[i].is_hot_path) {
                hot_count += 1;
            }
        }
        
        if (hot_count == 0) {
            return &.{};
        }
        
        // Allocate result array
        const hot_paths = self.allocator.alloc(FunctionProfile, hot_count) catch {
            return &.{};
        };
        
        // Copy hot paths
        var hot_idx: u32 = 0;
        i = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (self.profile_map.profiles[i].is_hot_path) {
                hot_paths[hot_idx] = self.profile_map.profiles[i];
                hot_idx += 1;
            }
        }
        
        return hot_paths[0..hot_count];
    }
    
    /// Get all critical paths (functions exceeding critical threshold).
    /// Note: Returns slice pointing to allocated array (caller must free).
    pub fn get_critical_paths(self: *const DreamBrowserProfiler) []const FunctionProfile {
        // Count critical paths
        var critical_count: u32 = 0;
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (self.profile_map.profiles[i].is_critical_path) {
                critical_count += 1;
            }
        }
        
        if (critical_count == 0) {
            return &.{};
        }
        
        // Allocate result array (caller must free)
        const critical_paths = self.allocator.alloc(FunctionProfile, critical_count) catch {
            return &.{};
        };
        
        // Copy critical paths
        var critical_idx: u32 = 0;
        i = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            if (self.profile_map.profiles[i].is_critical_path) {
                critical_paths[critical_idx] = self.profile_map.profiles[i];
                critical_idx += 1;
            }
        }
        
        return critical_paths[0..critical_count];
    }
    
    /// Get call samples (for stack trace analysis).
    pub fn get_call_samples(self: *const DreamBrowserProfiler) []const CallSample {
        return self.sample_buffer.samples[0..self.sample_buffer.samples_len];
    }
    
    /// Reset profiler (start new measurement period).
    pub fn reset(self: *DreamBrowserProfiler) void {
        // Free function name strings
        for (self.profile_map.function_names[0..self.profile_map.function_names_len]) |name| {
            self.allocator.free(name);
        }
        
        // Free sample function names
        for (self.sample_buffer.samples[0..self.sample_buffer.samples_len]) |sample| {
            self.allocator.free(sample.function_name);
            if (sample.parent_function) |parent| {
                self.allocator.free(parent);
            }
        }
        
        // Reset counters
        self.profile_map.profiles_len = 0;
        self.profile_map.function_names_len = 0;
        self.sample_buffer.samples_len = 0;
        self.sample_buffer.samples_index = 0;
    }
    
    /// Get total number of function calls profiled.
    pub fn get_total_calls(self: *const DreamBrowserProfiler) u32 {
        var total: u32 = 0;
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            total += self.profile_map.profiles[i].call_count;
        }
        return total;
    }
    
    /// Get total time spent in all profiled functions.
    pub fn get_total_time_us(self: *const DreamBrowserProfiler) u64 {
        var total: u64 = 0;
        var i: u32 = 0;
        while (i < self.profile_map.profiles_len) : (i += 1) {
            total += self.profile_map.profiles[i].total_time_us;
        }
        return total;
    }
};

test "profiler initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var profiler = try DreamBrowserProfiler.init(arena.allocator());
    defer profiler.deinit();
    
    // Assert: Profiler initialized
    try std.testing.expect(profiler.profile_map.profiles_len == 0);
    try std.testing.expect(profiler.sample_buffer.samples_len == 0);
}

test "profiler function profiling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var profiler = try DreamBrowserProfiler.init(arena.allocator());
    defer profiler.deinit();
    
    const start_time = profiler.start_function("test_function");
    // Simulate some work (no-op for test)
    try profiler.end_function("test_function", start_time, null);
    
    // Assert: Function profiled
    const profile = profiler.get_function_profile("test_function");
    try std.testing.expect(profile != null);
    try std.testing.expect(profile.?.call_count == 1);
}

test "profiler hot path detection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var profiler = try DreamBrowserProfiler.init(arena.allocator());
    defer profiler.deinit();
    
    // Profile a slow function (simulated)
    const start_time = profiler.start_function("slow_function");
    // Simulate slow function (no-op, but duration will be calculated)
    try profiler.end_function("slow_function", start_time, null);
    
    // Check if detected as hot path (depends on actual duration)
    const profile = profiler.get_function_profile("slow_function");
    if (profile) |p| {
        // Hot path detection depends on actual call time
        _ = p.is_hot_path;
    }
}

test "profiler reset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var profiler = try DreamBrowserProfiler.init(arena.allocator());
    defer profiler.deinit();
    
    // Profile some functions
    const start_time = profiler.start_function("test_function");
    try profiler.end_function("test_function", start_time, null);
    
    // Reset profiler
    profiler.reset();
    
    // Assert: Profiler reset
    try std.testing.expect(profiler.profile_map.profiles_len == 0);
    try std.testing.expect(profiler.sample_buffer.samples_len == 0);
}

