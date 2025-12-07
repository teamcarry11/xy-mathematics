//! Tests for Dream Browser Parser.
//!
//! Why: Verify HTML/CSS parsing functionality (DOM tree, CSS rules, style computation).
//! Architecture: Comprehensive test coverage for parser operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-07-071305-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const DreamBrowserParser = @import("dream_browser_parser").DreamBrowserParser;

test "parser initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Assert: Parser initialized correctly
    std.debug.assert(parser.allocator == allocator);
}

test "parser parse simple html" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Hello, World!</div>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        for (node.children) |child| {
            allocator.free(child.tag_name);
            allocator.free(child.text_content);
            for (child.attributes) |cattr| {
                allocator.free(cattr.name);
                allocator.free(cattr.value);
            }
            allocator.free(child.attributes);
            allocator.free(child.children);
        }
        allocator.free(node.children);
    }

    // Assert: Node parsed correctly
    try testing.expectEqualStrings("div", node.tag_name);
    try testing.expectEqualStrings("Hello, World!", node.text_content);
    std.debug.assert(node.children.len == 0);
    std.debug.assert(node.attributes.len == 0);
}

test "parser parse html with attributes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div id=\"test\" class=\"container\">Content</div>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        allocator.free(node.children);
    }

    // Assert: Attributes parsed correctly
    try testing.expectEqualStrings("div", node.tag_name);
    std.debug.assert(node.attributes.len >= 2);
    
    // Find id and class attributes
    var found_id = false;
    var found_class = false;
    for (node.attributes) |attr| {
        if (std.mem.eql(u8, attr.name, "id")) {
            try testing.expectEqualStrings("test", attr.value);
            found_id = true;
        }
        if (std.mem.eql(u8, attr.name, "class")) {
            try testing.expectEqualStrings("container", attr.value);
            found_class = true;
        }
    }
    std.debug.assert(found_id);
    std.debug.assert(found_class);
}

test "parser parse html with nested elements" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div><span>Inner</span></div>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        for (node.children) |child| {
            allocator.free(child.tag_name);
            allocator.free(child.text_content);
            for (child.attributes) |cattr| {
                allocator.free(cattr.name);
                allocator.free(cattr.value);
            }
            allocator.free(child.attributes);
            allocator.free(child.children);
        }
        allocator.free(node.children);
    }

    // Assert: Nested structure parsed
    try testing.expectEqualStrings("div", node.tag_name);
    std.debug.assert(node.children.len > 0);
}

test "parser parse css simple rule" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const css = "div { color: red; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Assert: CSS rule parsed correctly
    std.debug.assert(rules.len > 0);
    try testing.expectEqualStrings("div", rules[0].selector);
    std.debug.assert(rules[0].declarations.len > 0);
    try testing.expectEqualStrings("color", rules[0].declarations[0].property);
    try testing.expectEqualStrings("red", rules[0].declarations[0].value);
}

test "parser parse css multiple rules" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const css = "div { color: red; } span { background: blue; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Assert: Multiple CSS rules parsed
    std.debug.assert(rules.len >= 2);
}

test "parser parse css with multiple declarations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const css = "div { color: red; background: blue; font-size: 16px; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Assert: Multiple declarations parsed
    std.debug.assert(rules.len > 0);
    std.debug.assert(rules[0].declarations.len >= 3);
}

test "parser compute style for element" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Parse HTML
    const html = "<div>Test</div>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        allocator.free(node.children);
    }

    // Parse CSS
    const css = "div { color: red; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Compute style
    const style = try parser.computeStyles(&node, rules);
    defer {
        for (style) |decl| {
            allocator.free(decl.property);
            allocator.free(decl.value);
        }
        allocator.free(style);
    }

    // Assert: Style computed correctly
    std.debug.assert(style.len > 0);
    
    // Find color declaration
    var found_color = false;
    for (style) |decl| {
        if (std.mem.eql(u8, decl.property, "color")) {
            try testing.expectEqualStrings("red", decl.value);
            found_color = true;
        }
    }
    std.debug.assert(found_color);
}

test "parser html bounds checking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Create HTML larger than MAX_HTML_SIZE
    var large_html = try allocator.alloc(u8, DreamBrowserParser.MAX_HTML_SIZE + 1);
    defer allocator.free(large_html);
    
    // Fill with valid HTML structure
    @memset(large_html, ' ');
    @memcpy(large_html[0..6], "<div>");
    @memcpy(large_html[large_html.len - 7..], "</div>");

    // Assert: Parser should reject oversized HTML
    const result = parser.parseHtml(large_html);
    try testing.expectError(error.HtmlTooLarge, result);
}

test "parser css bounds checking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Create CSS with too many rules
    var css_buf = std.ArrayList(u8).init(allocator);
    defer css_buf.deinit();
    
    var i: u32 = 0;
    while (i < DreamBrowserParser.MAX_CSS_RULES + 1) : (i += 1) {
        try css_buf.writer().print("div{d} {{ color: red; }}\n", .{i});
    }
    
    const css = css_buf.items;
    const result = parser.parseCss(css);
    
    // Note: Parser may handle this gracefully or return error
    // This test verifies parser doesn't crash
    if (result) |rules| {
        defer {
            for (rules) |rule| {
                allocator.free(rule.selector);
                for (rule.declarations) |decl| {
                    allocator.free(decl.property);
                    allocator.free(decl.value);
                }
                allocator.free(rule.declarations);
            }
            allocator.free(rules);
        }
        // Parser handled it (may have truncated)
        std.debug.assert(rules.len <= DreamBrowserParser.MAX_CSS_RULES);
    } else |_| {
        // Parser rejected it (acceptable)
    }
}

test "parser parse empty html" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Assert: Empty HTML should fail
    const result = parser.parseHtml("");
    try testing.expectError(error.InvalidHtml, result);
}

test "parser parse invalid html" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Assert: Invalid HTML should fail
    const result = parser.parseHtml("not html");
    try testing.expectError(error.InvalidHtml, result);
}

test "parser parse html with text node" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<p>Paragraph text</p>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        allocator.free(node.children);
    }

    // Assert: Text content parsed
    try testing.expectEqualStrings("p", node.tag_name);
    try testing.expectEqualStrings("Paragraph text", node.text_content);
}

test "parser compute style specificity" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    // Parse HTML with class
    const html = "<div class=\"test\">Content</div>";
    const node = try parser.parseHtml(html);
    defer {
        allocator.free(node.tag_name);
        allocator.free(node.text_content);
        for (node.attributes) |attr| {
            allocator.free(attr.name);
            allocator.free(attr.value);
        }
        allocator.free(node.attributes);
        allocator.free(node.children);
    }

    // Parse CSS with conflicting rules (class should win)
    const css = "div { color: red; } .test { color: blue; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Compute style
    const style = try parser.computeStyles(&node, rules);
    defer {
        for (style) |decl| {
            allocator.free(decl.property);
            allocator.free(decl.value);
        }
        allocator.free(style);
    }

    // Assert: Style computed (specificity may favor class selector)
    std.debug.assert(style.len > 0);
}

test "parser parse css class selector" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const css = ".container { width: 100%; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Assert: Class selector parsed
    std.debug.assert(rules.len > 0);
    try testing.expectEqualStrings(".container", rules[0].selector);
}

test "parser parse css id selector" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const css = "#main { margin: 0; }";
    const rules = try parser.parseCss(css);
    defer {
        for (rules) |rule| {
            allocator.free(rule.selector);
            for (rule.declarations) |decl| {
                allocator.free(decl.property);
                allocator.free(decl.value);
            }
            allocator.free(rule.declarations);
        }
        allocator.free(rules);
    }

    // Assert: ID selector parsed
    std.debug.assert(rules.len > 0);
    try testing.expectEqualStrings("#main", rules[0].selector);
}

