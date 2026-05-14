const std = @import("std");

/// check if `T` has method `name` with signature `Sig`
fn hasMethod(comptime T: type, comptime name: []const u8, comptime Sig: type) bool {
    if (!@hasDecl(T, name)) return false;
    return @TypeOf(@field(T, name)) == Sig;
}

/// check if `T` has method `name` with either signature in `sigs`
fn hasAnyMethod(comptime T: type, comptime name: []const u8, comptime sigs: [2]type) bool {
    switch (@typeInfo(@TypeOf(T))) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {},
        else => { return false; }
    }
    if (!@hasDecl(T, name)) return false;
    inline for (sigs) |Sig| {
        if (@FieldType(T, name) == Sig) return true;
    }
    return false;
}

/// attempts to destruct `val` of type `T`
fn tryDeinit(comptime T: type, val: T) void {
    if (comptime hasAnyMethod(T, "deinit", .{ fn (*T) void, fn (T) void })) {
        val.deinit();
    }
}

/// create monomorphized shared Inner type for Arc and Weak
fn Inner(comptime T: type, comptime A: type) type {
    return struct { strong: std.atomic.Value(usize), weak: std.atomic.Value(usize), alloc: A, data: T };
}

pub fn Arc(comptime T: type, comptime A: type) type {
    return struct {
        const Self = @This();
        // TODO: better name for shorthand
        const Data = Inner(T, A);

        inner: *Data,

        pub fn init(data: T, alloc: A) !Self {
            var a = alloc;
            const inner: *Data = if (comptime hasMethod(A, "allocator", fn (*A) std.mem.Allocator)) blk: {
                break :blk try a.allocator().create(Data);
            } else if (comptime A == std.mem.Allocator) blk: {
                break :blk try a.create(Data);
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
            return Self{ .inner = inner };
        }

        pub fn deinit(self: Self) void {
            @compileError("unimplemented");
        }

        pub fn clone(self: Self) !Self {
            // TODO
            _ = self;
        }
    };
}
