//! Tests for Dream Browser Renderer.
//!
//! Why: Verify renderer functionality (layout, rendering, display types).
//! Architecture: Comprehensive test coverage for renderer operations.
//! GrainStyle: grain_case, u32/u64, bounded allocations, assertions.
//!
//! 2025-12-19-191728-pst: Grain Aurora Agent

const std = @import("std");
const testing = std.testing;
const DreamBrowserRenderer = @import("dream_browser_renderer").DreamBrowserRenderer;
const DreamBrowserParser = @import("dream_browser_parser").DreamBrowserParser;
const GrainBuffer = @import("grain_buffer.zig").GrainBuffer;

test "renderer initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    // Assert: Renderer initialized correctly
    std.debug.assert(renderer.allocator == allocator);
}

test "renderer get display type block" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Content</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const display = renderer.getDisplayType(&node);

    // Assert: Block element has block display type
    std.debug.assert(display == .block);
}

test "renderer get display type inline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<span>Content</span>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const display = renderer.getDisplayType(&node);

    // Assert: Inline element has inline display type
    std.debug.assert(display == .inline_element);
}

test "renderer get display type paragraph" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<p>Paragraph</p>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const display = renderer.getDisplayType(&node);

    // Assert: Paragraph has block display type
    std.debug.assert(display == .block);
}

test "renderer layout simple block" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Hello</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const boxes = try renderer.layout(&node, 800, 600);
    defer allocator.free(boxes);

    // Assert: Layout boxes created
    std.debug.assert(boxes.len > 0);
    std.debug.assert(boxes[0].width > 0);
    std.debug.assert(boxes[0].display == .block);
}

test "renderer layout simple inline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<span>Text</span>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const boxes = try renderer.layout(&node, 800, 600);
    defer allocator.free(boxes);

    // Assert: Layout boxes created
    std.debug.assert(boxes.len > 0);
    std.debug.assert(boxes[0].display == .inline_element);
}

test "renderer layout nested elements" {
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const boxes = try renderer.layout(&node, 800, 600);
    defer allocator.free(boxes);

    // Assert: Layout boxes created for nested structure
    std.debug.assert(boxes.len > 0);
}

test "renderer layout viewport bounds" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Content</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    // Test with maximum viewport dimensions
    const boxes = try renderer.layout(
        &node,
        DreamBrowserRenderer.MAX_DIMENSION,
        DreamBrowserRenderer.MAX_DIMENSION,
    );
    defer allocator.free(boxes);

    // Assert: Layout handles maximum dimensions
    std.debug.assert(boxes.len > 0);
}

test "renderer render to aurora simple" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Hello</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const css_rules = &.{};
    const aurora_node = try renderer.renderToAurora(&node, css_rules);

    // Assert: Aurora node created
    std.debug.assert(aurora_node == .column);
}

test "renderer render to aurora with css" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Content</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const aurora_node = try renderer.renderToAurora(&node, rules);

    // Assert: Aurora node created with CSS
    std.debug.assert(aurora_node == .column);
}

test "renderer create readonly spans" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Content</div>";
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

    var buffer = try GrainBuffer.init(allocator, "test content");
    defer buffer.deinit();

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const readonly_spans = try renderer.createReadonlySpans(&node, &buffer);
    defer allocator.free(readonly_spans);

    // Assert: Readonly spans created
    _ = readonly_spans; // May be empty, but function should succeed
}

test "renderer create editable spans" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Content</div>";
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

    var buffer = try GrainBuffer.init(allocator, "test content");
    defer buffer.deinit();

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    // Assert: Editable spans created (function should succeed)
    try renderer.createEditableSpans(&node, &buffer);
}

test "renderer render page complete" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>Hello World</div>";
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

    const css_rules = &.{};

    var buffer = try GrainBuffer.init(allocator, "initial content");
    defer buffer.deinit();

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const result = try renderer.renderPage(&node, css_rules, &buffer);
    defer allocator.free(result.readonly_spans);

    // Assert: Render result created
    std.debug.assert(result.aurora_node == .column);
}

test "renderer layout multiple blocks" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<div>First</div><div>Second</div>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const boxes = try renderer.layout(&node, 800, 600);
    defer allocator.free(boxes);

    // Assert: Multiple layout boxes created
    std.debug.assert(boxes.len > 0);
}

test "renderer get display type heading" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<h1>Heading</h1>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const display = renderer.getDisplayType(&node);

    // Assert: Heading has block display type
    std.debug.assert(display == .block);
}

test "renderer get display type list" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = DreamBrowserParser.init(allocator);
    defer parser.deinit();

    const html = "<ul><li>Item</li></ul>";
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

    var renderer = DreamBrowserRenderer.init(allocator);
    defer renderer.deinit();

    const display = renderer.getDisplayType(&node);

    // Assert: List has block display type
    std.debug.assert(display == .block);
}

