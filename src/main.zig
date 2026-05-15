const std = @import("std");
const builtin = @import("builtin");
const arc = @import("root.zig");

const N = 2048;

const has_no_deinit = struct {
    fn dummy(v: usize) usize {
        return v -% 1;
    }
};

const has_deinit = struct {
    const Self = @This();
    big: [N]u32768 = [_]u32768{0} ** N,

    pub fn deinit(self: Self) void {
        _ = self;
        std.debug.print("deconstructed\n", .{});
    }
};

const has_complex_deinit = struct {
    const Self = @This();
    big: [N]u32768 = [_]u32768{0} ** N,

    pub fn deinit(self: Self) usize {
        _ = self;
        std.debug.print("deconstructed\n", .{});
        return std.math.maxInt(usize) / 2 / 10 * 13;
    }
};

// these basic ideas will be tests someday when i start exploring the test system
pub fn main(init: std.process.Init) !void {
    var a = std.heap.DebugAllocator(.{ .verbose_log = true }){};
    defer { std.debug.print("alloc deinit res: {}\n", .{ a.deinit() }); }

    var no_deinit = try arc.Arc(has_no_deinit).init(.{}, a.allocator());
    defer { std.debug.print("type deinit res: {any}\n\n", .{no_deinit.deinit()}); }

    // primitives cant have methods at all, which has caused problems before
    var no_methods = try arc.Arc(u32).init(42, a.allocator());
    defer { std.debug.print("type deinit res: {any}\n\n", .{no_methods.deinit()}); }

    var simple_deinit = try arc.Arc(has_deinit).init(.{}, a.allocator());
    defer { std.debug.print("type deinit res: {any}\n\n", .{simple_deinit.deinit()}); }

    var complex_deinit = try arc.Arc(has_complex_deinit).init(.{}, a.allocator());
    defer { std.debug.print("type deinit res: {any}\n\n", .{complex_deinit.deinit()}); }

    try std.Io.sleep(init.io, std.Io.Duration.fromMilliseconds(10000), std.Io.Clock.awake);
}
