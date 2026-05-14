const std = @import("std");
const arc = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    var val = try arc.Arc(u32, std.mem.Allocator).init(0, gpa.allocator());
}
