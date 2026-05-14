const std = @import("std");
const arc = @import("root.zig");

pub fn main() !void {
    var val = try arc.Arc(u32, std.heap.DebugAllocator(.{})).init(0, std.heap.DebugAllocator(.{}){});
    defer val.deinit();
}
