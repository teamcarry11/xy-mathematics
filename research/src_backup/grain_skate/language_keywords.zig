//! Language Keywords: Language-specific keyword sets for syntax highlighting.
//!
//! Why: Enable language-specific syntax highlighting in Grain Skate editor.
//! Architecture: Keyword sets per language, efficient lookup.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-03-141818-pst: Active implementation

const std = @import("std");
const Language = @import("language_detector.zig").Language;

// Bounded: Max keywords per language (explicit limit)
// 2025-12-03-141818-pst: Active constant
pub const MAX_KEYWORDS_PER_LANG: u32 = 256;

// Language keywords module.
// 2025-12-03-141818-pst: Active struct
pub const LanguageKeywords = struct {
    /// Check if word is a keyword for given language.
    // 2025-12-03-141818-pst: Active function
    pub fn is_keyword(lang: Language, word: []const u8) bool {
        return switch (lang) {
            .zig => is_zig_keyword(word),
            .rust => is_rust_keyword(word),
            .c, .cpp => is_c_keyword(word),
            .python => is_python_keyword(word),
            .javascript, .typescript => is_javascript_keyword(word),
            .go => is_go_keyword(word),
            .java => is_java_keyword(word),
            .shell => is_shell_keyword(word),
            .html => is_html_keyword(word),
            .css => is_css_keyword(word),
            else => false, // Unknown language or no keywords
        };
    }

    /// Check if word is a Zig keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_zig_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "if", "else", "while", "for", "fn", "var", "const", "return", "break", "continue", "pub", "priv", "struct", "enum", "union", "error", "try", "catch", "defer", "switch", "case", "default", "true", "false", "null", "undefined", "void", "bool", "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64", "usize", "isize", "comptime", "inline", "noinline", "export", "extern", "packed", "align", "test", "async", "await", "suspend", "resume", "anytype", "anyframe", "allowzero", "volatile", "linksection", "callconv", "nakedcc", "stdcallcc", "asm", "usingnamespace" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a Rust keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_rust_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while", "async", "await", "dyn", "abstract", "become", "box", "do", "final", "macro", "override", "priv", "try", "typeof", "unsized", "virtual", "yield" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a C/C++ keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_c_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "int", "long", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "asm", "bool", "catch", "class", "const_cast", "delete", "dynamic_cast", "explicit", "false", "friend", "inline", "mutable", "namespace", "new", "operator", "private", "protected", "public", "reinterpret_cast", "static_cast", "template", "this", "throw", "true", "try", "typeid", "typename", "using", "virtual", "wchar_t" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a Python keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_python_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "and", "as", "assert", "break", "class", "continue", "def", "del", "elif", "else", "except", "exec", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "not", "or", "pass", "print", "raise", "return", "try", "while", "with", "yield", "False", "None", "True", "async", "await", "nonlocal" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a JavaScript/TypeScript keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_javascript_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "abstract", "arguments", "await", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue", "debugger", "default", "delete", "do", "double", "else", "enum", "eval", "export", "extends", "false", "final", "finally", "float", "for", "function", "goto", "if", "implements", "import", "in", "instanceof", "int", "interface", "let", "long", "native", "new", "null", "package", "private", "protected", "public", "return", "short", "static", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "true", "try", "typeof", "var", "void", "volatile", "while", "with", "yield", "async", "await", "from", "of", "as", "type", "namespace", "declare", "module", "interface", "enum", "const", "readonly", "keyof", "infer", "extends", "implements" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a Go keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_go_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var", "true", "false", "nil", "iota" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a Java keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_java_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void", "volatile", "while", "true", "false", "null" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a shell keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_shell_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "if", "then", "else", "elif", "fi", "case", "esac", "for", "select", "while", "until", "do", "done", "in", "function", "time", "!", "[", "]", "alias", "bg", "bind", "break", "builtin", "caller", "cd", "command", "compgen", "complete", "compopt", "continue", "declare", "dirs", "disown", "echo", "enable", "eval", "exec", "exit", "export", "false", "fc", "fg", "getopts", "hash", "help", "history", "jobs", "kill", "let", "local", "logout", "mapfile", "popd", "printf", "pushd", "pwd", "read", "readarray", "readonly", "return", "set", "shift", "shopt", "source", "suspend", "test", "times", "trap", "true", "type", "typeset", "ulimit", "umask", "unalias", "unset", "wait" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is an HTML keyword (tag name).
    // 2025-12-03-141818-pst: Active function
    fn is_html_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "html", "head", "body", "title", "meta", "link", "script", "style", "div", "span", "p", "a", "img", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "table", "tr", "td", "th", "form", "input", "button", "textarea", "select", "option", "br", "hr", "strong", "em", "b", "i", "u", "code", "pre", "blockquote", "article", "section", "nav", "header", "footer", "aside", "main" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Check if word is a CSS keyword.
    // 2025-12-03-141818-pst: Active function
    fn is_css_keyword(word: []const u8) bool {
        const keywords = [_][]const u8{ "align-content", "align-items", "align-self", "all", "animation", "animation-delay", "animation-direction", "animation-duration", "animation-fill-mode", "animation-iteration-count", "animation-name", "animation-play-state", "animation-timing-function", "backface-visibility", "background", "background-attachment", "background-blend-mode", "background-clip", "background-color", "background-image", "background-origin", "background-position", "background-repeat", "background-size", "border", "border-bottom", "border-bottom-color", "border-bottom-left-radius", "border-bottom-right-radius", "border-bottom-style", "border-bottom-width", "border-collapse", "border-color", "border-image", "border-image-outset", "border-image-repeat", "border-image-slice", "border-image-source", "border-image-width", "border-left", "border-left-color", "border-left-style", "border-left-width", "border-radius", "border-right", "border-right-color", "border-right-style", "border-right-width", "border-spacing", "border-style", "border-top", "border-top-color", "border-top-left-radius", "border-top-right-radius", "border-top-style", "border-top-width", "border-width", "bottom", "box-decoration-break", "box-shadow", "box-sizing", "break-after", "break-before", "break-inside", "caption-side", "caret-color", "clear", "clip", "color", "column-count", "column-fill", "column-gap", "column-rule", "column-rule-color", "column-rule-style", "column-rule-width", "column-span", "column-width", "columns", "content", "counter-increment", "counter-reset", "cursor", "direction", "display", "empty-cells", "filter", "flex", "flex-basis", "flex-direction", "flex-flow", "flex-grow", "flex-shrink", "flex-wrap", "float", "font", "font-family", "font-kerning", "font-size", "font-stretch", "font-style", "font-variant", "font-weight", "grid", "grid-area", "grid-auto-columns", "grid-auto-flow", "grid-auto-rows", "grid-column", "grid-column-end", "grid-column-gap", "grid-column-start", "grid-gap", "grid-row", "grid-row-end", "grid-row-gap", "grid-row-start", "grid-template", "grid-template-areas", "grid-template-columns", "grid-template-rows", "hanging-punctuation", "height", "hyphens", "isolation", "justify-content", "left", "letter-spacing", "line-height", "list-style", "list-style-image", "list-style-position", "list-style-type", "margin", "margin-bottom", "margin-left", "margin-right", "margin-top", "max-height", "max-width", "min-height", "min-width", "mix-blend-mode", "object-fit", "object-position", "opacity", "order", "outline", "outline-color", "outline-offset", "outline-style", "outline-width", "overflow", "overflow-x", "overflow-y", "padding", "padding-bottom", "padding-left", "padding-right", "padding-top", "page-break-after", "page-break-before", "page-break-inside", "perspective", "perspective-origin", "pointer-events", "position", "quotes", "resize", "right", "scroll-behavior", "tab-size", "table-layout", "text-align", "text-align-last", "text-decoration", "text-decoration-color", "text-decoration-line", "text-decoration-style", "text-indent", "text-justify", "text-overflow", "text-shadow", "text-transform", "top", "transform", "transform-origin", "transform-style", "transition", "transition-delay", "transition-duration", "transition-property", "transition-timing-function", "unicode-bidi", "user-select", "vertical-align", "visibility", "white-space", "width", "word-break", "word-spacing", "word-wrap", "z-index" };
        for (keywords) |keyword| {
            if (word.len == keyword.len and std.mem.eql(u8, word, keyword)) {
                return true;
            }
        }
        return false;
    }
};

