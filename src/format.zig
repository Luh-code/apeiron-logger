const std = @import("std");
const fmt = @import("fmt");
const ctime = @cImport(@cInclude("time.h"));
const csystime = @cImport(@cInclude("sys/time.h"));

const logErrors = @import("errors.zig");
const LogError = logErrors.LogError;

const threadsData = @import("data/threads.zig");
var threadNames: threadsData.ThreadMap = threadsData.ThreadMap.init(std.heap.page_allocator);

const scopesData = @import("data/scopes.zig");
const Scope = scopesData.Scope;
const format_scope = scopesData.format_scope;

const common = @import("common");
const LevelProperties = common.LevelProperties;

fn internal_error(err: anytype) void {
    std.debug.print("internal error: {}/n", .{err});
}

pub fn add_time(message: *std.ArrayList(u8)) void {
    var time_now: csystime.timeval = undefined;
    _ = csystime.gettimeofday(&time_now, null);
    const ms: u32 = @intCast(@divFloor(time_now.tv_usec, 1000));

    var t_str_buf: [9]u8 = undefined; // len of 8 + eod
    var d_str_buf: [9]u8 = undefined;
    const t = ctime.time(null);
    const lt = ctime.localtime(&t);
    const t_format = "%H:%M:%S";
    const d_format = "%d.%m.%y";
    _ = ctime.strftime(&t_str_buf, t_str_buf.len, t_format, lt);
    _ = ctime.strftime(&d_str_buf, d_str_buf.len, d_format, lt);

    message.writer().print(
        "| {s:8}.{d:0>4}-{s:8} ",
        .{ t_str_buf[0..8], ms, d_str_buf[0..8] },
    ) catch |err| {
        internal_error(err);
    };
}

pub fn name_thread(comptime name: []const u8) void {
    const threadID = std.Thread.getCurrentId();
    threadNames.put(threadID, name) catch |err| {
        internal_error(err);
    };
}

pub fn add_thread(message: *std.ArrayList(u8)) void {
    const threadID = std.Thread.getCurrentId();
    const named = threadNames.containsID(threadID) catch |err| {
        internal_error(err);
    };

    const threadName = if (!named) "N/A" else threadNames.getName(threadID) catch |err| blk: {
        internal_error(err);
        break :blk "err";
    };

    message.writer().print("| {s:>10}({d}) ", .{ threadName, threadID }) catch |err| {
        internal_error(err);
    };
}

pub fn add_source(message: *std.ArrayList(u8), source: std.builtin.SourceLocation) void {
    var ll_str_buf: [100]u8 = undefined;
    _ = std.fmt.bufPrint(&ll_str_buf, "{d}:{d}", .{ source.line, source.column }) catch |err| {
        internal_error(err);
    };

    message.writer().print("| {s:>10}:{s: >9} ", .{ source.file, ll_str_buf }) catch |err| {
        internal_error(err);
    };
}

pub fn add_level(message: *std.ArrayList(u8), level: *const LevelProperties, level_int: u32) void {
    message.writer().print("| {s: >11}:{d:<2}", .{ level.s_descriptor, level_int }) catch |err| {
        internal_error(err);
    };
}

pub fn add_scope(message: *std.ArrayList(u8), comptime scope: *const Scope) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const s_text: []u8 = format_scope(scope, &arena);
    message.writer().print(" | [{s}]", .{s_text}) catch |err| {
        internal_error(err);
    };
}
