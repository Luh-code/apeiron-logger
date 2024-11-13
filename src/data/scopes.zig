const std = @import("std");

pub const Scope = struct {
    name: []const u8,
    major: ?*Scope,
};
pub fn format_scope(comptime s: *const Scope, arena: *std.heap.ArenaAllocator) []u8 {
    const allocator = arena.allocator();

    var stack = std.ArrayList([]const u8).init(allocator);
    defer stack.deinit();

    var t: ?*const Scope = s;
    while (t) |v| {
        stack.append(v.name) catch |err| {
            std.debug.print("error: {}", .{err});
        };
        t = v.major;
    }

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    for (stack.items) |item| {
        list.writer().print("{s}/", .{item}) catch |err| {
            std.debug.print("error: {}", .{err});
        };
    }

    const slice: []u8 = list.toOwnedSlice() catch |err| {
        std.debug.print("error: {}", .{err});
        @panic("Failed to get owned slice");
    };
    return slice;
}
