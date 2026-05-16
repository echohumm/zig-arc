const std = @import("std");

// TODO: clean whole maybeDeinit subsystem up; all of these functions and the Arc.deinit fn. there's a bit of
//  copy-n-paste and passing between of variables/types.

// i can has methods?
/// returns `true` if `T` is a type which can have methods
fn canHasMethods(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"enum", .@"union", .@"opaque" => true,
        else => false,
    };
}

/// attempts to deconstruct `val` of type `T` there is a `deinit` method, nop otherwise.
///
/// takes a pointer to avoid bringing very large `T` onto the stack.
fn maybeDeinit(comptime T: type, comptime TDeinit: type, val: *T) TDeinit {
    if (comptime !canHasMethods(T) or !@hasDecl(T, "deinit")) return;

    const sig = @TypeOf(@field(T, "deinit"));
    // we allow both deinits which take *T and T
    if (comptime sig == fn(T) TDeinit or sig == fn(*T) TDeinit) {
        return val.deinit();
    } else {
        // implicit void return works here but i think this is cleaner
        return;
    }
}

/// create monomorphized shared Inner type for Arc and Weak
fn InnerTy(comptime T: type) type {
    return struct { strong: std.atomic.Value(usize), weak: std.atomic.Value(usize), alloc: std.mem.Allocator, data: T };
}

pub fn Arc(comptime T: type) type {
    return struct {
        const TDeinit = blk: {
            // if `T` can't have methods or doesn't have a `deinit` member, default to void.
            if (!canHasMethods(T) or !@hasDecl(T, "deinit")) break :blk void;

            const info = @typeInfo(@TypeOf(T.deinit));
            // if `deinit` isn't a function, default
            if (info != .@"fn") break :blk void;

            if (@typeInfo(@TypeOf(T.deinit)).@"fn".return_type) |r| break :blk r else break :blk void;
        };

        pub const WeakRef = Weak(T);
        const Self = @This();
        const Inner = InnerTy(T);

        inner: *Inner,

        // TODO: currently fails with very large `T` (somewhere between 838608 and 16777216),
        //  seemingly due to the issue of bringing them onto this function's stack?
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

        // TODO: this currently returns ?void if T.deinit doesn't exist or returns void. it should only be an optional
        //  if TDeinit return type isn't void (?TDeinit or void, never ?void).
        pub fn deinit(self: Self) ?TDeinit {
            // assuming fetchSub returns previous value, not new
            if (self.inner.strong.fetchSub(1, .release) != 1) {
                return null;
            }
            // assuming this works in theory for zig like it does rust rather than a full fence
            _ = self.inner.strong.load(.acquire);

            // deconstruct the data if it requires deconstruction
            const ret = maybeDeinit(T, TDeinit, &self.inner.data);

            // Weak deinit handles deallocation
            (Weak(T){ .inner = self.inner }).deinit();

            return ret;
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
