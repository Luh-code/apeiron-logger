const std = @import("std");
const fmt = std.fmt;

const common = @import("common");
pub const Properties = common.Properties;
pub const LevelProperties = common.LevelProperties;

//const color = @import("data/color.zig");
pub const Color = common.Color;
pub const TextMode = common.TextMode;
pub const makeStyle = common.makeESC;
pub const RGBColor = common.RGBColor;
pub const makeRGB = common.makeESCTrueColor;

const format = @import("format.zig");
pub const add_time = format.add_time;
pub const name_thread = format.name_thread;
pub const add_thread = format.add_thread;
pub const add_source = format.add_source;
pub const add_level = format.add_level;
pub const add_scope = format.add_scope;

const scopes = @import("data/scopes.zig");
pub const Scope = scopes.Scope;

const logErrors = @import("errors.zig");
const LogError = logErrors.LogError;

const user_config = @import("user_config");
pub const props = user_config.props;

const file = @import("file.zig");
const FileHandler = file.FileHandler;
var fileHandler: ?*FileHandler() = null;
var s_filePath: []const u8 = "";
var b_initialized = false;

const stdout = std.io.getStdOut();
var bufferedWriter = std.io.bufferedWriter(stdout.writer());
const writer = bufferedWriter.writer();

pub fn init(path: []const u8) LogError!void {
    if (b_initialized) {
        return LogError.AlreadyInitializedError;
    }
    b_initialized = true;
    errdefer b_initialized = false;

    // Create log file and set up logging
    s_filePath = path;
    var fileHandlerAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    fileHandler = FileHandler().init(fileHandlerAllocator.allocator(), s_filePath) catch |err| {
        std.debug.print("{}", .{err});
        return;
    };
}

const LevelInfo = struct { m_props: *const LevelProperties, u_level: u32 };

fn getLogLevel(comptime level_name: []const u8) LevelInfo {
    for (props.a_levelProps, 0..) |prop, i| {
        if (std.mem.eql(u8, prop.s_name, level_name)) {
            return LevelInfo{ .m_props = &prop, .u_level = i };
        }
    }

    @compileError(LogError.UnknownLogLevelError);
}

var logbuf: [1000]u8 = undefined;

pub fn log(comptime level_name: []const u8, comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelProps: LevelInfo = comptime getLogLevel(level_name);

    // TODO: Queue functionality

    // If this has performance problems try using a GPA and FBA instead of a page_allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var list = std.ArrayList(u8).init(allocator);

    const feats = props.m_features;
    if (feats.b_time) {
        add_time(&list);
    }
    if (feats.b_thread) {
        add_thread(&list);
    }

    // TODO: uncomment when add_source uses @frame when implemented

    //if (feats.b_file) {
    //    add_source(&list);
    //}
    if (feats.b_level) {
        add_level(&list, levelProps.m_props, levelProps.u_level);
    }

    if (s) |v| {
        add_scope(&list, v);
    }

    const fmttedMsg = fmt.bufPrint(&logbuf, message, wildcards) catch |err| blk: {
        if (err == error.OutOfMemory) {
            std.debug.print("api error: message length exceeded defined maximum", .{});
        } else {
            std.debug.print("error: {}", .{err});
        }

        break :blk message;
    };

    fileHandler.?.log(fmttedMsg) catch |err| {
        std.debug.print("{}", err);
    };

    const logColor = levelProps.m_props.s_style;
    const defaultColor = comptime makeStyle(@intFromEnum(Color.DEFAULT), @intFromEnum(Color.DEFAULT), TextMode.RESET);
    writer.print("{s}{s} {s}{s}{s}\n", .{ logColor, list.items, if (s) |_| "" else "| ", fmttedMsg, defaultColor }) catch |err| {
        std.debug.print("error: {}", .{err});
    };

    if (levelProps.m_props.b_flush) flush();
    if (levelProps.m_props.b_fatal) {
        std.debug.print("Fatality occured, stopping process...\n", .{});
        fatal(@truncate(levelProps.u_level));
    }
}

fn flush() void {
    bufferedWriter.flush() catch |err| {
        std.debug.print("An error occured while flushing: {}", .{err});
    };
}

fn fatal(code: u8) void {
    std.process.exit(code);
}

pub fn ldebug(comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelName = props.m_specFuncs.s_debug;
    log(levelName, message, s, wildcards);
}
pub fn linfo(comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelName = props.m_specFuncs.s_info;
    log(levelName, message, s, wildcards);
}
pub fn lwarn(comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelName = props.m_specFuncs.s_warn;
    log(levelName, message, s, wildcards);
}
pub fn lerror(comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelName = props.m_specFuncs.s_error;
    log(levelName, message, s, wildcards);
}
pub fn lfatal(comptime message: []const u8, comptime s: ?*const Scope, wildcards: anytype) void {
    const levelName = props.m_specFuncs.s_fatal;
    log(levelName, message, s, wildcards);
}
