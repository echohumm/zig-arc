const std = @import("std");

/// check if `T` has method `name` with either signature in `sigs`
fn hasAnyMethod(comptime T: type, comptime name: []const u8, comptime sigs: [2]type) bool {
    switch (@typeInfo(T)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {},
        else => {
            return false;
        },
    }
    if (!@hasDecl(T, name)) return false;
    inline for (sigs) |Sig| {
        if (@TypeOf(@field(T, name)) == Sig) return true;
    }
    return false;
}

/// attempts to deconstruct `val` of type `T` there is a `deinit` method, fails otherwise.
///
/// takes a pointer to avoid bringing very large `T` onto the stack.
fn maybeDeinit(comptime T: type, val: *T) void {
    if (comptime hasAnyMethod(T, "deinit", .{ fn (*T) void, fn (T) void })) {
        val.deinit();
    }
}

/// create monomorphized shared Inner type for Arc and Weak
fn InnerTy(comptime T: type) type {
    return struct { strong: std.atomic.Value(usize), weak: std.atomic.Value(usize), alloc: std.mem.Allocator, data: T };
}

pub fn Arc(comptime T: type) type {
    return struct {
        pub const WeakRef = Weak(T);
        const Self = @This();
        const Inner = InnerTy(T);

        inner: *Inner,

        // TODO: currently fails with very large `T`, seemingly due to the issue of bringing them onto this function's
        //  stack
        pub fn init(data: T, alloc: std.mem.Allocator) std.mem.Allocator.Error!Self {
            const inner = try alloc.create(Inner);
            inner.* = .{
                .strong = std.atomic.Value(usize).init(1),
                .weak = std.atomic.Value(usize).init(1),
                .alloc = alloc,
                .data = data,
            };
            return Self{ .inner = inner };
        }

        pub fn deinit(self: Self) void {
            // assuming fetchSub returns previous value, not new
            if (self.inner.strong.fetchSub(1, .release) != 1) {
                return;
            }
            // assuming this works in theory for zig like it does rust rather than a full fence
            _ = self.inner.strong.load(.acquire);

            // deconstruct the data if it requires deconstruction
            maybeDeinit(T, &self.inner.data);

            // Weak deinit handles deallocation
            (Weak(T){ .inner = self.inner }).deinit();
        }

        pub fn clone(self: Self) Self {
            if (self.inner.strong.fetchAdd(1, .monotonic) > std.math.maxInt(isize)) {
                std.process.abort();
            }

            // just copy `self`
            return self;
        }

        pub fn downgrade(self: Self) WeakRef {
            if (self.inner.weak.fetchAdd(1, .monotonic) > std.math.maxInt(isize)) {
                std.process.abort();
            }

            return WeakRef{ .inner = self.inner };
        }

        pub fn get(self: Self) *const T {
            return &self.inner.data;
        }

        pub fn getMut(self: Self) ?*T {
            // todo: idk if this impl is right
            if (self.inner.strong.load(.acquire) != 1) {
                return null;
            }

            return &self.inner.data;
        }

        pub fn strongCount(self: Self) usize {
            return self.inner.strong.load(.monotonic);
        }

        pub fn weakCount(self: Self) usize {
            // we exist, so presumably the implicit weak ref does too; we do a -1 to account for it.
            return self.inner.weak.load(.monotonic) - 1;
        }
    };
}

// no comptime A for now, may be necessary later
pub fn Weak(comptime T: type) type {
    return struct {
        pub const StrongRef = Arc(T);
        const Self = @This();
        const Inner = InnerTy(T);

        inner: *Inner,

        pub fn deinit(self: Self) void {
            if (self.inner.weak.fetchSub(1, .release) != 1) {
                return;
            }
            _ = self.inner.weak.load(.acquire);

            const a = self.inner.alloc;
            a.destroy(self.inner);
        }

        pub fn clone(self: Self) Self {
            if (self.inner.weak.fetchAdd(1, .monotonic) > std.math.maxInt(isize)) {
                std.process.abort();
            }

            return self;
        }
    };
}
