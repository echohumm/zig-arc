const std = @import("std");
const arc = @import("root.zig");

const N = 2048;

const has_deinit = struct {
    const Self = @This();
    big: [N]u32768 = [_]u32768{0} ** N,

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

    var io = std.Io.Threaded.init(std.mem.Allocator.failing, .{});
    defer io.deinit();

    try std.Io.sleep(io.io(), std.Io.Duration.fromMilliseconds(10000), std.Io.Clock.awake);
}
