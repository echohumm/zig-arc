const std = @import("std");
const arc = @import("root.zig");

const has_deinit = struct {
    const Self = @This();

    pub fn deinit(self: Self) void {
        _ = self;
        std.debug.print("deconstructed\n", .{});
    }
};

pub fn main() !void {
    var a = std.heap.DebugAllocator(.{ .verbose_log = true }){};
    defer { std.debug.print("deinit res: {}\n", .{ a.deinit() }); }
    var val = try arc.Arc(has_deinit).init(.{}, a.allocator());
    defer val.deinit();
}
