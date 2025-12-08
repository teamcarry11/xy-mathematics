//! Language Detector: Detects programming language from file extension and shebang.
//!
//! Why: Enable language-specific syntax highlighting in Grain Skate editor.
//! Architecture: Extension-based and shebang-based detection.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-141818-pst: Active implementation

const std = @import("std");

// Bounded: Max filename length (explicit limit, in bytes)
// 2025-12-03-141818-pst: Active constant
pub const MAX_FILENAME_LEN: u32 = 512;

// Bounded: Max shebang line length (explicit limit, in bytes)
// 2025-12-03-141818-pst: Active constant
pub const MAX_SHEBANG_LEN: u32 = 256;

// Programming language enumeration.
// 2025-12-03-141818-pst: Active enum
pub const Language = enum(u8) {
    unknown, // Unknown language (no highlighting)
    zig, // Zig
    rust, // Rust
    c, // C
    cpp, // C++
    python, // Python
    javascript, // JavaScript
    typescript, // TypeScript
    go, // Go
    java, // Java
    markdown, // Markdown
    json, // JSON
    yaml, // YAML
    shell, // Shell script
    html, // HTML
    css, // CSS
};

// Language detector state.
// 2025-12-03-141818-pst: Active struct
pub const LanguageDetector = struct {
    /// Detect language from filename (extension-based).
    // 2025-12-03-141818-pst: Active function
    pub fn detect_from_filename(filename: []const u8) Language {
        // Assert: Filename must be bounded
        std.debug.assert(filename.len <= MAX_FILENAME_LEN);
        // Find last dot (extension separator)
        var dot_idx: ?u32 = null;
        var i: u32 = 0;
        while (i < filename.len) : (i += 1) {
            if (filename[i] == '.') {
                dot_idx = i;
            }
        }
        if (dot_idx) |idx| {
            if (idx + 1 < filename.len) {
                const ext = filename[idx + 1..];
                return detect_from_extension(ext);
            }
        }
        return .unknown;
    }

    /// Detect language from file extension.
    // 2025-12-03-141818-pst: Active function
    fn detect_from_extension(ext: []const u8) Language {
        // Normalize extension to lowercase for comparison
        if (ext.len == 0) {
            return .unknown;
        }
        // Common extensions (case-insensitive comparison)
        if (std.mem.eql(u8, ext, "zig") or std.mem.eql(u8, ext, "ZIG")) {
            return .zig;
        }
        if (std.mem.eql(u8, ext, "rs") or std.mem.eql(u8, ext, "RS")) {
            return .rust;
        }
        if (std.mem.eql(u8, ext, "c") or std.mem.eql(u8, ext, "C")) {
            return .c;
        }
        if (std.mem.eql(u8, ext, "cpp") or std.mem.eql(u8, ext, "CPP") or std.mem.eql(u8, ext, "cc") or std.mem.eql(u8, ext, "CC") or std.mem.eql(u8, ext, "cxx") or std.mem.eql(u8, ext, "CXX")) {
            return .cpp;
        }
        if (std.mem.eql(u8, ext, "py") or std.mem.eql(u8, ext, "PY")) {
            return .python;
        }
        if (std.mem.eql(u8, ext, "js") or std.mem.eql(u8, ext, "JS")) {
            return .javascript;
        }
        if (std.mem.eql(u8, ext, "ts") or std.mem.eql(u8, ext, "TS")) {
            return .typescript;
        }
        if (std.mem.eql(u8, ext, "go") or std.mem.eql(u8, ext, "GO")) {
            return .go;
        }
        if (std.mem.eql(u8, ext, "java") or std.mem.eql(u8, ext, "JAVA")) {
            return .java;
        }
        if (std.mem.eql(u8, ext, "md") or std.mem.eql(u8, ext, "MD") or std.mem.eql(u8, ext, "markdown") or std.mem.eql(u8, ext, "MARKDOWN")) {
            return .markdown;
        }
        if (std.mem.eql(u8, ext, "json") or std.mem.eql(u8, ext, "JSON")) {
            return .json;
        }
        if (std.mem.eql(u8, ext, "yaml") or std.mem.eql(u8, ext, "YAML") or std.mem.eql(u8, ext, "yml") or std.mem.eql(u8, ext, "YML")) {
            return .yaml;
        }
        if (std.mem.eql(u8, ext, "sh") or std.mem.eql(u8, ext, "SH") or std.mem.eql(u8, ext, "bash") or std.mem.eql(u8, ext, "BASH")) {
            return .shell;
        }
        if (std.mem.eql(u8, ext, "html") or std.mem.eql(u8, ext, "HTML") or std.mem.eql(u8, ext, "htm") or std.mem.eql(u8, ext, "HTM")) {
            return .html;
        }
        if (std.mem.eql(u8, ext, "css") or std.mem.eql(u8, ext, "CSS")) {
            return .css;
        }
        return .unknown;
    }

    /// Detect language from shebang line (first line of file).
    // 2025-12-03-141818-pst: Active function
    pub fn detect_from_shebang(content: []const u8) Language {
        // Assert: Content must be bounded
        std.debug.assert(content.len <= MAX_SHEBANG_LEN);
        // Check for shebang (#!)
        if (content.len < 2) {
            return .unknown;
        }
        if (content[0] != '#' or content[1] != '!') {
            return .unknown;
        }
        // Find end of first line
        var line_end: u32 = 2;
        while (line_end < content.len and content[line_end] != '\n') : (line_end += 1) {}
        const shebang_line = content[0..line_end];
        // Check for common interpreters
        if (std.mem.indexOf(u8, shebang_line, "python") != null or std.mem.indexOf(u8, shebang_line, "python3") != null) {
            return .python;
        }
        if (std.mem.indexOf(u8, shebang_line, "node") != null) {
            return .javascript;
        }
        if (std.mem.indexOf(u8, shebang_line, "sh") != null or std.mem.indexOf(u8, shebang_line, "bash") != null) {
            return .shell;
        }
        if (std.mem.indexOf(u8, shebang_line, "zig") != null) {
            return .zig;
        }
        return .unknown;
    }

    /// Detect language from filename and content (combined detection).
    // 2025-12-03-141818-pst: Active function
    pub fn detect(filename: []const u8, content: []const u8) Language {
        // Try filename first (more reliable)
        const lang_from_filename = detect_from_filename(filename);
        if (lang_from_filename != .unknown) {
            return lang_from_filename;
        }
        // Fall back to shebang if filename detection failed
        if (content.len > 0) {
            const lang_from_shebang = detect_from_shebang(content);
            if (lang_from_shebang != .unknown) {
                return lang_from_shebang;
            }
        }
        return .unknown;
    }
};

