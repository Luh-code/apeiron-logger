const std = @import("std");

pub const Color = enum(i32) {
    BLACK = 30,
    RED = 31,
    GREEN = 32,
    YELLOW = 33,
    BLUE = 34,
    MAGENTA = 35,
    CYAN = 36,
    WHITE = 37,
    DEFAULT = 39,
    RESET = 0,
    ALXTERM_BRIGHT = 60, // add this value to the other colors if you want alxterm bright colors
};
pub const TextMode = enum(i32) {
    RESET = 0,
    BOLD = 1,
    DIM = 2,
    ITALIC = 3,
    UNDERLINE = 4,
    BLINKING = 5,
    INVERSE = 7,
    HIDDEN = 8,
    STRIKETHROUGH = 9,
};

pub fn makeESC(comptime fg: i32, comptime bg: i32, comptime mode: TextMode) []const u8 {
    return std.fmt.comptimePrint("\x1B[{d};{d};{d}m", .{
        @intFromEnum(mode),
        fg,
        bg+10
    });
}

pub const RGBColor = struct {
    r: u8,
    g: u8,
    b: u8,
};
fn makePartialESCTrueColor(comptime part: i32, comptime col: RGBColor) []const u8 {
    return std.fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{
        part,
        col.r,
        col.g,
        col.b,
    });
}
pub fn makeESCTrueColor(comptime fg: RGBColor, comptime bg: RGBColor, comptime mode: TextMode) []const u8 {
    return std.fmt.comptimePrint("\x1B[{d}m{s}{s}", .{
        @intFromEnum(mode),
        comptime makePartialESCTrueColor(38, fg),
        comptime makePartialESCTrueColor(48, bg),
    });
}
