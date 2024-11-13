const properties = @import("data/properties.zig");
pub const Properties = properties.Properties;
pub const LevelProperties = properties.LevelProperties;

const color = @import("data/color.zig");
pub const Color = color.Color;
pub const TextMode = color.TextMode;
pub const RGBColor = color.RGBColor;

pub const makeESC = color.makeESC;
pub const makeESCTrueColor = color.makeESCTrueColor;
