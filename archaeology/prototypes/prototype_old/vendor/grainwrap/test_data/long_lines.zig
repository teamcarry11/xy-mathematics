// test file with lines that exceed 73 characters
// this file intentionally violates grain_style constraints

const std = @import("std");
const very_long_module_name_that_exceeds_seventy_three_characters = @import("std");

pub fn main() !void {
    const extremely_long_variable_name_that_goes_way_over_the_limit_and_should_be_wrapped = "this is a very long string that also exceeds the 73 character limit and needs to be wrapped properly";
    const another_long_variable = std.mem.eql(u8, "this is a test string", "this is another test string that is even longer and should definitely be wrapped");
    
    // this is a very long comment that exceeds seventy three characters and should be wrapped to fit grain_style constraints
    const result = try std.fmt.allocPrint(std.heap.page_allocator, "format string with many parameters: {s} {d} {s} {d} {s}", .{ "param1", 42, "param2", 99, "param3" });
    
    const function_call_with_many_parameters = try some_function_with_very_long_name_that_takes_many_parameters(allocator, param1, param2, param3, param4, param5, param6);
    
    if (very_long_condition_that_exceeds_seventy_three_characters and another_long_condition_that_also_exceeds_the_limit) {
        try do_something();
    }
    
    const nested_function_call = try outer_function(inner_function(another_inner_function(deeply_nested_parameter, another_deeply_nested_parameter)));
}

fn very_long_function_name_that_exceeds_seventy_three_characters_and_should_be_wrapped(allocator: std.mem.Allocator, param1: []const u8, param2: u32, param3: bool) !void {
    _ = allocator;
    _ = param1;
    _ = param2;
    _ = param3;
}

