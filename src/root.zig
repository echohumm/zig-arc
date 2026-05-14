const std = @import("std");

fn hasMethod(comptime T: type, comptime name: []const u8, comptime Sig: type) bool {
    if (!@hasDecl(T, name)) return false;
    return @TypeOf(@field(T, name)) == Sig;
}

pub fn Arc(comptime T: type, comptime A: type) type {
    return struct {
        const Self = @This();

        const Inner = struct {
            strong: std.atomic.Value(usize),
            weak: std.atomic.Value(usize),
            alloc: A,
            data: T
        };
        inner: *Inner,

        pub fn init(data: T, alloc: A) !Self {
            var a = alloc;
            const inner: *Inner = if (comptime hasMethod(A, "allocator", fn(*A) std.mem.Allocator)) blk: {
                break :blk try a.allocator().create(Inner);
            } else if (comptime A == std.mem.Allocator) blk: {
                break :blk try a.create(Inner);
            } else {
                @compileError(std.fmt.comptimePrint(
                    "type {s} is incompatible with Arc",
                    .{@typeName(A)},
                ));
            };
            inner.* = .{
                .strong = std.atomic.Value(usize).init(1),
                .weak = std.atomic.Value(usize).init(1),
                .alloc = alloc,
                .data = data,
            };
            return Self { .inner = inner };
        }

        pub fn deinit(self: Self) !void {
            // TODO
            _ = self;
        }

        pub fn clone(self: Self) !Self {
            // TODO
            _ = self;
        }
    };
}
