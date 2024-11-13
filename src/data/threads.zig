const std = @import("std");
const logErrors = @import("../errors.zig");
const LogError = logErrors.LogError;

pub const ThreadMap = struct {
    forward: std.AutoHashMap(u32, []const u8),
    backward: std.StringHashMap(u32),

    pub fn init(allocator: std.mem.Allocator) ThreadMap {
        return .{
            .forward = std.AutoHashMap(u32, []const u8).init(allocator),
            .backward = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn put(self: *ThreadMap, id: u32, comptime name: []const u8) !void {
        try self.forward.put(id, name);
        try self.backward.put(name, id);
    }

    pub fn removeFromID(self: *ThreadMap, id: u32) !void {
        const name = try self.forward.remove(id); 
        try self.backward.remove(name) catch {
            try self.forward.put(id, name);
            return LogError.ThreadMapDesyncError;
        };
    }

    pub fn removeFromName(self: *ThreadMap, comptime name: []const u8) !void {
        const id = try self.backward.remove(name); 
        try self.forward.remove(name) catch {
            try self.backward.put(id, name);
            return LogError.ThreadMapDesyncError;
        };
    }

    pub fn getName(self: *ThreadMap, id: u32) ![]const u8 {
        const res = self.forward.get(id);
        return if (res) |value| value else LogError.ThreadNotNamedError;
    }

    pub fn getID(self: *ThreadMap, comptime name: []const u8) !u32 {
        const res = self.backward.get(name);
        return if (res) |value| value else LogError.ThreadNotNamedError;
    }

    pub fn containsID(self: *ThreadMap, id: u32) !bool {
        return self.forward.contains(id);
    }

    pub fn containsName(self: *ThreadMap, comptime name: []const u8) !bool {
        return comptime self.backward.contains(name);
    }
};
