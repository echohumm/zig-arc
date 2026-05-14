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
            const allocator = if (comptime hasMethod(A, "allocator", fn(*A) std.mem.Allocator)) blk: {
                break :blk alloc.allocator();
                // this has the small flaw that if the allocator is especially odd, and uses *A or something else as its self arg, this won't work, but i'd rather avoid the copy pasting or writing a loop to check this for now
            } else if (comptime A == std.mem.Allocator)  blk: {
                break :blk alloc;
            } else {
                @compileError(std.fmt.comptimePrint(
                    "allocator type {s} is incompatible with Arc due to lacking the `allocator(Self) std.mem.Allocator` method and not being `std.mem.Allocator` itself.",
                    .{@typeName(A)},
                ));
            };
            const inner = try allocator.create(Inner);
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
            _ = self
        }
        
        pub fn clone(self: Self) !Self {
            // TODO
            _ = self;
        }
    };
}
