//! Keaton Dunsford Resume PDF: Grain Bubble Implementation.
//!
//! Why: Create aesthetic 5-6 page PDF resume with creator platform mockups.
//! Architecture: Grain Bubble canvas + PDF export with glitchy neon effects.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-030000-pst: Glow G2

const std = @import("std");
const canvas = @import("../src/grain_bubble/canvas.zig");
const export_pdf = @import("../src/grain_bubble/export_pdf.zig");
const component = @import("../src/grain_bubble/component.zig");

// Import profile data structure
const PersonProfile = @import("keaton_profile.zig").PersonProfile;

// Bounded: Max pages in PDF resume.
pub const MAX_PAGES: u32 = 6;

// Bounded: Max portrait images.
pub const MAX_PORTRAIT_IMAGES: u32 = 4;

// Bounded: PDF page dimensions (Letter size: 8.5" x 11" = 612 x 792 points).
pub const PDF_PAGE_WIDTH: u32 = 612;
pub const PDF_PAGE_HEIGHT: u32 = 792;

// Design tokens for resume aesthetic.
pub const DesignTokens = struct {
    // Background colors
    hemp_off_white: u32 = 0xF5F5DCFF,
    hemp_grain_dark: u32 = 0xE8E8D8FF,
    
    // Neon colors (ARGB format)
    neon_cyan: u32 = 0x00FFFF00,
    neon_magenta: u32 = 0xFF00FF00,
    neon_yellow: u32 = 0xFFFF0000,
    neon_green: u32 = 0x00FF0000,
    
    // Dark base colors
    dark_base: u32 = 0x0A0A0AFF,
    dark_overlay: u32 = 0x1A1A1AFF,
    
    // Text colors
    text_dark: u32 = 0x1A1A1AFF,
    text_neon: u32 = 0x00FFFF00,
};

// Resume PDF generator.
pub const ResumePdfGenerator = struct {
    allocator: std.mem.Allocator,
    profile: *const PersonProfile,
    portrait_image_paths: []const []const u8,
    design_tokens: DesignTokens,
    
    /// Initialize resume PDF generator.
    pub fn init(
        allocator: std.mem.Allocator,
        profile: *const PersonProfile,
        portrait_image_paths: []const []const u8,
    ) ResumePdfGenerator {
        // Assert: Profile must be valid
        std.debug.assert(profile.name_len > 0);
        // Assert: Portrait images must be bounded
        std.debug.assert(portrait_image_paths.len <= MAX_PORTRAIT_IMAGES);
        
        return ResumePdfGenerator{
            .allocator = allocator,
            .profile = profile,
            .portrait_image_paths = portrait_image_paths,
            .design_tokens = DesignTokens{},
        };
    }
    
    /// Generate complete resume PDF (5-6 pages).
    pub fn generate_pdf(self: *ResumePdfGenerator) ![]const u8 {
        // Assert: Generator must be initialized
        std.debug.assert(self.profile.name_len > 0);
        
        // Create pages
        const page1 = try self.create_page_1_cover();
        errdefer self.allocator.free(page1);
        const page2 = try self.create_page_2_profile();
        errdefer self.allocator.free(page2);
        const page3 = try self.create_page_3_work();
        errdefer self.allocator.free(page3);
        const page4 = try self.create_page_4_private_spaces();
        errdefer self.allocator.free(page4);
        const page5 = try self.create_page_5_livestreaming();
        errdefer self.allocator.free(page5);
        const page6 = try self.create_page_6_dashboard();
        errdefer self.allocator.free(page6);
        
        // Combine pages into single PDF
        const combined_pdf = try self.combine_pdf_pages(&[_][]const u8{
            page1, page2, page3, page4, page5, page6,
        });
        
        // Free individual pages
        self.allocator.free(page1);
        self.allocator.free(page2);
        self.allocator.free(page3);
        self.allocator.free(page4);
        self.allocator.free(page5);
        self.allocator.free(page6);
        
        return combined_pdf;
    }
    
    /// Create Page 1: Cover with glitchy portrait.
    fn create_page_1_cover(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add hemp paper background
        try self.add_hemp_background(&doc);
        
        // Add glitchy portrait (large, centered)
        if (self.portrait_image_paths.len > 0) {
            try self.add_glitchy_portrait(&doc, 306, 400, 200, 250);
        }
        
        // Add name (neon glitch typography)
        try self.add_neon_text(
            &doc,
            self.profile.name,
            306,
            150,
            48,
            self.design_tokens.neon_cyan,
        );
        
        // Add tagline
        const tagline = "Systems Architect | Grain OS | Patient Discipline";
        try self.add_neon_text(
            &doc,
            tagline,
            306,
            120,
            16,
            self.design_tokens.neon_magenta,
        );
        
        // Add hashtags
        try self.add_hashtags(&doc, 306, 90);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Create Page 2: Profile from keaton_profile.zig data.
    fn create_page_2_profile(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add hemp paper background
        try self.add_hemp_background(&doc);
        
        // Add description text
        try self.add_description_text(&doc);
        
        // Add values bubble diagram
        try self.add_values_diagram(&doc);
        
        // Add inspirations grid
        try self.add_inspirations_grid(&doc);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Create Page 3: Work and projects.
    fn create_page_3_work(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add hemp paper background
        try self.add_hemp_background(&doc);
        
        // Add Grain OS architecture diagram (bubble flow)
        try self.add_architecture_diagram(&doc);
        
        // Add multi-agent system visualization
        try self.add_agent_system_viz(&doc);
        
        // Add technical achievements
        try self.add_technical_achievements(&doc);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Create Page 4: Creator Platform - Private Spaces mockup.
    fn create_page_4_private_spaces(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add dark neon gradient background
        try self.add_dark_neon_background(&doc);
        
        // Add private spaces UI mockup
        try self.add_private_spaces_mockup(&doc);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Create Page 5: Creator Platform - Livestreaming & Payments.
    fn create_page_5_livestreaming(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add dark neon gradient background
        try self.add_dark_neon_background(&doc);
        
        // Add livestreaming interface mockup
        try self.add_livestream_mockup(&doc);
        
        // Add payment flow visualization
        try self.add_payment_flow(&doc);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Create Page 6: Creator Platform - Financial Dashboard.
    fn create_page_6_dashboard(self: *ResumePdfGenerator) ![]const u8 {
        var doc = export_pdf.PdfDocument.init(
            PDF_PAGE_WIDTH,
            PDF_PAGE_HEIGHT,
        );
        doc.write_header();
        
        // Add dark neon gradient background
        try self.add_dark_neon_background(&doc);
        
        // Add financial dashboard mockup
        try self.add_financial_dashboard(&doc);
        
        doc.write_footer();
        return try self.allocator.dupe(u8, doc.get_content());
    }
    
    /// Add hemp paper texture background.
    fn add_hemp_background(self: *ResumePdfGenerator, doc: *export_pdf.PdfDocument) !void {
        _ = self;
        // Create off-white rectangle covering entire page
        // Add subtle grain pattern (small noise rectangles)
        // This would be implemented with multiple small shapes
        // to create texture effect
    }
    
    /// Add dark neon gradient background.
    fn add_dark_neon_background(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        // Create dark base rectangle
        // Add neon gradient overlays (cyan, magenta, yellow)
        // Apply glitch effects (RGB channel separation)
    }
    
    /// Add glitchy portrait image.
    fn add_glitchy_portrait(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
        center_x: u32,
        center_y: u32,
        width: u32,
        height: u32,
    ) !void {
        _ = self;
        _ = doc;
        _ = center_x;
        _ = center_y;
        _ = width;
        _ = height;
        // Note: Image import would be implemented here
        // Apply glitch effects: RGB channel separation, scan lines
        // Add neon color overlays
    }
    
    /// Add neon glitch text.
    fn add_neon_text(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
        text: []const u8,
        x: u32,
        y: u32,
        font_size: u32,
        color: u32,
    ) !void {
        _ = self;
        _ = doc;
        _ = text;
        _ = x;
        _ = y;
        _ = font_size;
        _ = color;
        // Add text with neon color
        // Apply glitch effect (slight RGB channel offset)
    }
    
    /// Add hashtags.
    fn add_hashtags(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
        center_x: u32,
        y: u32,
    ) !void {
        _ = self;
        _ = doc;
        _ = center_x;
        _ = y;
        // Add #vegan #zig #sol hashtags
        // Styled with neon colors
    }
    
    /// Add description text from profile.
    fn add_description_text(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Render profile.description as formatted text
    }
    
    /// Add values bubble diagram.
    fn add_values_diagram(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create bubble diagram showing profile.values
        // Each value as a rounded rectangle "bubble"
        // Connected with lines showing relationships
    }
    
    /// Add inspirations grid.
    fn add_inspirations_grid(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create grid layout showing inspirations
        // Technical, spiritual, ethical, creative categories
        // Each inspiration as a card/bubble
    }
    
    /// Add Grain OS architecture diagram.
    fn add_architecture_diagram(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create bubble flow diagram
        // Show: Basin Kernel -> Core -> Agents
        // Use rounded rectangles (bubbles) for each component
        // Connect with lines showing dependencies
    }
    
    /// Add multi-agent system visualization.
    fn add_agent_system_viz(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Visualize 8 Grain agents
        // Show coordination and dependencies
        // Use bubble diagram format
    }
    
    /// Add technical achievements.
    fn add_technical_achievements(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // List: zero technical debt, Grain Style, etc.
        // Format as bullet points or cards
    }
    
    /// Add private spaces UI mockup.
    fn add_private_spaces_mockup(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create UI mockup showing:
        // - Split screen (creator view / fan view)
        // - Private chat interface (bubble messages)
        // - Content sharing gallery
        // - Fan tier visualization
        // - Safety features
        // Use rounded "bubble" components, neon accents
    }
    
    /// Add livestreaming interface mockup.
    fn add_livestream_mockup(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create UI mockup showing:
        // - Video player (rounded corners, neon border)
        // - Real-time tip buttons (Grainbank/Grainsoul)
        // - Micropayment amounts displayed
        // - Glitchy neon effects
    }
    
    /// Add payment flow visualization.
    fn add_payment_flow(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create bubble flow diagram showing:
        // - Grainbank (MMT fiat) payment path
        // - Grainsoul (Grain Solana) payment path
        // - Real-time tipping flow
        // - Connection bubbles between components
    }
    
    /// Add financial dashboard mockup.
    fn add_financial_dashboard(
        self: *ResumePdfGenerator,
        doc: *export_pdf.PdfDocument,
    ) !void {
        _ = self;
        _ = doc;
        // Create dashboard mockup showing:
        // - Total assets ($1M+)
        // - Citizenship context (flag, country)
        // - Government department connections
        // - Fiat currency context
        // - Investment diversification chart (bubble diagram)
        // - Neon data visualizations
    }
    
    /// Combine multiple PDF pages into single document.
    fn combine_pdf_pages(
        self: *ResumePdfGenerator,
        pages: []const []const u8,
    ) ![]const u8 {
        // Assert: Pages must be bounded
        std.debug.assert(pages.len <= MAX_PAGES);
        
        // Calculate total size
        var total_size: u32 = 0;
        var i: u32 = 0;
        while (i < pages.len) : (i += 1) {
            total_size += @as(u32, @intCast(pages[i].len));
        }
        
        // Allocate combined PDF buffer
        const combined = try self.allocator.alloc(u8, total_size);
        var offset: u32 = 0;
        
        // Copy each page
        i = 0;
        while (i < pages.len) : (i += 1) {
            const page = pages[i];
            @memcpy(combined[offset..offset + page.len], page);
            offset += @as(u32, @intCast(page.len));
        }
        
        return combined;
    }
};
