// Spacing scales for Grain Mobile Core
// Grain Style compliant: explicit types, bounded allocations, assertions
//
// Defines spacing scales (padding, margins, gaps)
// Sizes in dp (Android) / points (iOS)

const std = @import("std");

pub const SpacingScale = struct {
    xs: u32,
    sm: u32,
    md: u32,
    lg: u32,
    xl: u32,
    xxl: u32,

    pub fn init() SpacingScale {
        return SpacingScale{
            .xs = 4,
            .sm = 8,
            .md = 16,
            .lg = 24,
            .xl = 32,
            .xxl = 48,
        };
    }

    pub fn get(self: *const SpacingScale, size: SpacingSize) u32 {
        std.debug.assert(@intFromEnum(size) < 6);
        
        return switch (size) {
            .xs => self.xs,
            .sm => self.sm,
            .md => self.md,
            .lg => self.lg,
            .xl => self.xl,
            .xxl => self.xxl,
        };
    }
};

pub const SpacingSize = enum(u8) {
    xs,
    sm,
    md,
    lg,
    xl,
    xxl,
};

