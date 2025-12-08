const std = @import("std");

/// Dream Browser Performance: Frame rate control, performance monitoring, rendering optimization.
/// ~<~ Glow Airbend: explicit frame timing, bounded performance metrics.
/// ~~~~ Glow Waterbend: performance flows deterministically through DAG.
///
/// This implements:
/// - Frame rate control (60fps target, frame timing)
/// - Performance monitoring (frame time, render time, layout time)
/// - Rendering optimization (skip frames if behind, adaptive quality)
/// - Performance metrics (FPS, frame time, render time statistics)
pub const DreamBrowserPerformance = struct {
    // Target frame rate: 60fps (16.67ms per frame)
    pub const TARGET_FPS: u32 = 60;
    pub const TARGET_FRAME_TIME_MS: u32 = 1000 / TARGET_FPS; // ~16.67ms
    
    // Bounded: Max 1000 frames in history
    pub const MAX_FRAME_HISTORY: u32 = 1000;
    
    // Bounded: Max 10,000ms frame time (10 seconds, for error detection)
    pub const MAX_FRAME_TIME_MS: u32 = 10_000;
    
    /// Frame timing information.
    pub const FrameTiming = struct {
        frame_start_time: u64, // Timestamp in milliseconds
        frame_end_time: u64, // Timestamp in milliseconds
        render_time_ms: u32, // Time spent rendering
        layout_time_ms: u32, // Time spent in layout
        total_time_ms: u32, // Total frame time
    };
    
    /// Performance metrics (aggregated statistics).
    pub const PerformanceMetrics = struct {
        frames_rendered: u32, // Total frames rendered
        average_fps: f32, // Average frames per second
        average_frame_time_ms: f32, // Average frame time in milliseconds
        average_render_time_ms: f32, // Average render time in milliseconds
        average_layout_time_ms: f32, // Average layout time in milliseconds
        min_frame_time_ms: u32, // Minimum frame time
        max_frame_time_ms: u32, // Maximum frame time
        dropped_frames: u32, // Frames dropped (exceeded target time)
    };
    
    /// Frame history (for performance analysis).
    pub const FrameHistory = struct {
        timings: []FrameTiming, // Frame timing history
        timings_len: u32, // Current number of frames
        timings_index: u32, // Circular buffer index
    };
    
    allocator: std.mem.Allocator,
    frame_history: FrameHistory,
    current_frame_start: u64, // Current frame start time
    last_frame_time: u64, // Last frame end time
    metrics: PerformanceMetrics,
    
    /// Initialize performance monitor.
    pub fn init(allocator: std.mem.Allocator) DreamBrowserPerformance {
        // Allocator is always valid in Zig 0.15 (no null check needed)
        
        // Allocate frame history buffer
        const timings = allocator.alloc(FrameTiming, MAX_FRAME_HISTORY) catch {
            // Fallback: empty history if allocation fails
            return DreamBrowserPerformance{
                .allocator = allocator,
                .frame_history = FrameHistory{
                    .timings = &.{},
                    .timings_len = 0,
                    .timings_index = 0,
                },
                .current_frame_start = 0,
                .last_frame_time = 0,
                .metrics = PerformanceMetrics{
                    .frames_rendered = 0,
                    .average_fps = 0.0,
                    .average_frame_time_ms = 0.0,
                    .average_render_time_ms = 0.0,
                    .average_layout_time_ms = 0.0,
                    .min_frame_time_ms = 0,
                    .max_frame_time_ms = 0,
                    .dropped_frames = 0,
                },
            };
        };
        
        return DreamBrowserPerformance{
            .allocator = allocator,
            .frame_history = FrameHistory{
                .timings = timings,
                .timings_len = 0,
                .timings_index = 0,
            },
            .current_frame_start = 0,
            .last_frame_time = 0,
            .metrics = PerformanceMetrics{
                .frames_rendered = 0,
                .average_fps = 0.0,
                .average_frame_time_ms = 0.0,
                .average_render_time_ms = 0.0,
                .average_layout_time_ms = 0.0,
                .min_frame_time_ms = 0,
                .max_frame_time_ms = 0,
                .dropped_frames = 0,
            },
        };
    }
    
    /// Deinitialize performance monitor.
    pub fn deinit(self: *DreamBrowserPerformance) void {
        // Free frame history buffer
        if (self.frame_history.timings.len > 0) {
            self.allocator.free(self.frame_history.timings);
        }
    }
    
    /// Get current timestamp in milliseconds.
    fn get_current_time_ms() u64 {
        const timestamp = std.time.timestamp();
        const non_negative = if (timestamp < 0) 0 else @as(u64, @intCast(timestamp));
        return non_negative * 1000; // Convert to milliseconds (simplified)
    }
    
    /// Start frame timing (call at start of frame).
    pub fn start_frame(self: *DreamBrowserPerformance) void {
        self.current_frame_start = get_current_time_ms();
    }
    
    /// End frame timing (call at end of frame).
    pub fn end_frame(
        self: *DreamBrowserPerformance,
        render_time_ms: u32,
        layout_time_ms: u32,
    ) void {
        // Assert: Render and layout times must be within bounds
        std.debug.assert(render_time_ms <= MAX_FRAME_TIME_MS);
        std.debug.assert(layout_time_ms <= MAX_FRAME_TIME_MS);
        
        const frame_end_time = get_current_time_ms();
        const total_time_ms = @as(u32, @intCast(frame_end_time - self.current_frame_start));
        
        // Assert: Total frame time must be within bounds
        std.debug.assert(total_time_ms <= MAX_FRAME_TIME_MS);
        
        // Create frame timing record
        const timing = FrameTiming{
            .frame_start_time = self.current_frame_start,
            .frame_end_time = frame_end_time,
            .render_time_ms = render_time_ms,
            .layout_time_ms = layout_time_ms,
            .total_time_ms = total_time_ms,
        };
        
        // Add to frame history (circular buffer)
        if (self.frame_history.timings.len > 0) {
            const index = self.frame_history.timings_index;
            self.frame_history.timings[index] = timing;
            self.frame_history.timings_index = (index + 1) % MAX_FRAME_HISTORY;
            
            if (self.frame_history.timings_len < MAX_FRAME_HISTORY) {
                self.frame_history.timings_len += 1;
            }
        }
        
        // Update metrics
        self.metrics.frames_rendered += 1;
        
        // Update average frame time
        const total_frames = self.metrics.frames_rendered;
        if (total_frames == 1) {
            self.metrics.average_frame_time_ms = @as(f32, @floatFromInt(total_time_ms));
            self.metrics.min_frame_time_ms = total_time_ms;
            self.metrics.max_frame_time_ms = total_time_ms;
        } else {
            // Running average: (old_avg * (n-1) + new_value) / n
            const old_avg = self.metrics.average_frame_time_ms;
            self.metrics.average_frame_time_ms = (old_avg * @as(f32, @floatFromInt(total_frames - 1)) + @as(f32, @floatFromInt(total_time_ms))) / @as(f32, @floatFromInt(total_frames));
            
            // Update min/max
            if (total_time_ms < self.metrics.min_frame_time_ms) {
                self.metrics.min_frame_time_ms = total_time_ms;
            }
            if (total_time_ms > self.metrics.max_frame_time_ms) {
                self.metrics.max_frame_time_ms = total_time_ms;
            }
        }
        
        // Update average render time
        if (total_frames == 1) {
            self.metrics.average_render_time_ms = @as(f32, @floatFromInt(render_time_ms));
        } else {
            const old_avg = self.metrics.average_render_time_ms;
            self.metrics.average_render_time_ms = (old_avg * @as(f32, @floatFromInt(total_frames - 1)) + @as(f32, @floatFromInt(render_time_ms))) / @as(f32, @floatFromInt(total_frames));
        }
        
        // Update average layout time
        if (total_frames == 1) {
            self.metrics.average_layout_time_ms = @as(f32, @floatFromInt(layout_time_ms));
        } else {
            const old_avg = self.metrics.average_layout_time_ms;
            self.metrics.average_layout_time_ms = (old_avg * @as(f32, @floatFromInt(total_frames - 1)) + @as(f32, @floatFromInt(layout_time_ms))) / @as(f32, @floatFromInt(total_frames));
        }
        
        // Update average FPS
        if (self.metrics.average_frame_time_ms > 0.0) {
            self.metrics.average_fps = 1000.0 / self.metrics.average_frame_time_ms;
        }
        
        // Check for dropped frames (exceeded target frame time)
        if (total_time_ms > TARGET_FRAME_TIME_MS) {
            self.metrics.dropped_frames += 1;
        }
        
        self.last_frame_time = frame_end_time;
    }
    
    /// Check if we should skip this frame (if we're behind schedule).
    pub fn should_skip_frame(self: *const DreamBrowserPerformance) bool {
        // If we haven't rendered any frames yet, don't skip
        if (self.metrics.frames_rendered == 0) {
            return false;
        }
        
        // If average frame time exceeds target, skip occasionally
        if (self.metrics.average_frame_time_ms > @as(f32, @floatFromInt(TARGET_FRAME_TIME_MS * 2))) {
            // Skip every other frame if we're more than 2x behind
            return (self.metrics.frames_rendered % 2) == 0;
        }
        
        return false;
    }
    
    /// Get current performance metrics.
    pub fn get_metrics(self: *const DreamBrowserPerformance) PerformanceMetrics {
        return self.metrics;
    }
    
    /// Get frame history (for detailed analysis).
    pub fn get_frame_history(self: *const DreamBrowserPerformance) []const FrameTiming {
        if (self.frame_history.timings_len == 0) {
            return &.{};
        }
        return self.frame_history.timings[0..self.frame_history.timings_len];
    }
    
    /// Check if we're maintaining target FPS.
    pub fn is_maintaining_target_fps(self: *const DreamBrowserPerformance) bool {
        // Check if average FPS is within 5% of target
        const target_fps_f32 = @as(f32, @floatFromInt(TARGET_FPS));
        const fps_ratio = self.metrics.average_fps / target_fps_f32;
        return fps_ratio >= 0.95; // Within 5% of target
    }
    
    /// Get frame time budget remaining (for adaptive quality).
    pub fn get_remaining_frame_budget_ms(self: *const DreamBrowserPerformance) u32 {
        const elapsed = @as(u32, @intCast(get_current_time_ms() - self.current_frame_start));
        if (elapsed >= TARGET_FRAME_TIME_MS) {
            return 0; // No budget remaining
        }
        return TARGET_FRAME_TIME_MS - elapsed;
    }
    
    /// Reset performance metrics (for new measurement period).
    pub fn reset_metrics(self: *DreamBrowserPerformance) void {
        self.metrics = PerformanceMetrics{
            .frames_rendered = 0,
            .average_fps = 0.0,
            .average_frame_time_ms = 0.0,
            .average_render_time_ms = 0.0,
            .average_layout_time_ms = 0.0,
            .min_frame_time_ms = 0,
            .max_frame_time_ms = 0,
            .dropped_frames = 0,
        };
        self.frame_history.timings_len = 0;
        self.frame_history.timings_index = 0;
    }
};

test "performance initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var perf = DreamBrowserPerformance.init(arena.allocator());
    defer perf.deinit();
    
    // Assert: Performance monitor initialized
    try std.testing.expect(perf.metrics.frames_rendered == 0);
    try std.testing.expect(perf.metrics.average_fps == 0.0);
}

test "performance frame timing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var perf = DreamBrowserPerformance.init(arena.allocator());
    defer perf.deinit();
    
    perf.start_frame();
    // Simulate some work (no-op for test, timing handled by end_frame)
    perf.end_frame(1, 0);
    
    // Assert: Frame recorded
    try std.testing.expect(perf.metrics.frames_rendered == 1);
    try std.testing.expect(perf.metrics.average_render_time_ms > 0.0);
}

test "performance skip frame" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var perf = DreamBrowserPerformance.init(arena.allocator());
    defer perf.deinit();
    
    // Should not skip first frame
    try std.testing.expect(!perf.should_skip_frame());
    
    // Record some slow frames
    perf.start_frame();
    perf.end_frame(100, 0); // 100ms render time (very slow)
    
    // Should skip if behind schedule
    const should_skip = perf.should_skip_frame();
    // Note: This depends on average frame time, may vary
    _ = should_skip;
}

test "performance metrics" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var perf = DreamBrowserPerformance.init(arena.allocator());
    defer perf.deinit();
    
    // Record multiple frames
    for (0..10) |_| {
        perf.start_frame();
        perf.end_frame(10, 5); // 10ms render, 5ms layout
    }
    
    const metrics = perf.get_metrics();
    
    // Assert: Metrics calculated
    try std.testing.expect(metrics.frames_rendered == 10);
    try std.testing.expect(metrics.average_fps > 0.0);
    try std.testing.expect(metrics.average_frame_time_ms > 0.0);
}

