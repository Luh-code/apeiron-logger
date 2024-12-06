const std = @import("std");
const Build = std.Build;

const GenerationError = error{
    ExpectedKeyNotFound,
    InvalidValueException,
    KeyNotAvailable,
    InvalidFunctionName,
    ValueNotFound,
    InternalError,
    ModuleGenerationError,
};

fn generateStructAttr(code: *std.ArrayList(u8), json: std.json.Value, key: []const u8, attr: []const u8, pre: []const u8) !void {
    try code.appendSlice(pre);
    try code.appendSlice(".");
    try code.appendSlice(attr);
    try code.appendSlice(" = \"");
    if (json.object.get(key)) |k| {
        try code.appendSlice(k.string);
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }
    try code.appendSlice("\",\n");
}

fn addColorsTogether(code: *std.ArrayList(u8), arr: []std.json.Value) !void {
    for (arr, 0..) |v, i| {
        if (i > 0) {
            try code.appendSlice(" + ");
        }
        try code.appendSlice("@intFromEnum(Color.");
        try code.appendSlice(v.string);
        try code.appendSlice(")");
    }
}

fn addRGBTogether(code: *std.ArrayList(u8), arr: []std.json.Value) !void {
    try code.appendSlice(".{");
    for (arr, 0..) |v, i| {
        if (i > 0) {
            try code.appendSlice(", ");
        }
        try code.appendSlice(v.string);
    }
    try code.appendSlice("}");
}

fn addFuncBinding(code: *std.ArrayList(u8), name: []const u8, func: std.json.Value) !void {
    if (func.object.get("level")) |level| {
        try code.appendSlice("\t\t.s_");
        try code.appendSlice(name);
        try code.appendSlice(" = \"");
        try code.appendSlice(level.string);
        try code.appendSlice("\",\n");
    } else {
        return GenerationError.ValueNotFound;
    }
}

fn addFeature(code: *std.ArrayList(u8), feature: []const u8, json: std.json.Value) !void {
    if (json.object.get(feature)) |feat| {
        try code.appendSlice("\t\t.b_");
        try code.appendSlice(feature);
        try code.appendSlice(" = ");
        try code.appendSlice(if (feat.bool) "true" else "false");
        try code.appendSlice(",\n");
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }
}

fn generateConfig(allocator: std.mem.Allocator, json: std.json.Value) ![]const u8 {
    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    try code.appendSlice("// Generated Code\n");
    try code.appendSlice("// DO NOT MODIFY MANUALLY - CHANGE config.json!\n\n");

    try code.appendSlice("const common = @import(\"common\");\n");
    try code.appendSlice("const Properites = common.Properties;\n");
    try code.appendSlice("const LevelProperties = common.LevelProperties;\n");
    try code.appendSlice("const makeStyle = common.makeESC;\n");
    try code.appendSlice("const makeRGB = common.makeESCTrueColor;\n");
    try code.appendSlice("const Color = common.Color;\n");
    try code.appendSlice("const TextMode = common.TextMode;\n\n");

    try code.appendSlice("pub const props = Properites {\n");
    try code.appendSlice("\t.a_levelProps = &[_]LevelProperties{\n");
    if (json.object.get("levelProps")) |props| {
        for (props.object.keys()) |propName| {
            const prop = if (props.object.get(propName)) |p| p else {
                return GenerationError.KeyNotAvailable;
            };
            try code.appendSlice("\t\t.{\n");
            try code.appendSlice("\t\t\t.s_name = \"");
            try code.appendSlice(propName);
            try code.appendSlice("\",\n");
            try generateStructAttr(&code, prop, "desc", "s_descriptor", "\t\t\t");
            if (prop.object.get("style")) |style| {
                try code.appendSlice("\t\t\t.s_style = ");
                const fg = if (style.object.get("fg")) |fgv| fgv.array.items else {
                    return GenerationError.ExpectedKeyNotFound;
                };
                const bg = if (style.object.get("bg")) |bgv| bgv.array.items else {
                    return GenerationError.ExpectedKeyNotFound;
                };
                const textMode = if (style.object.get("mode")) |mode| mode.string else {
                    return GenerationError.ExpectedKeyNotFound;
                };
                if (style.object.get("type")) |styleType| {
                    const stype = styleType.string;
                    if (std.mem.eql(u8, stype, "ascii")) {
                        if (fg.len < 1 or bg.len < 1) {
                            return GenerationError.InvalidValueException;
                        }
                        try code.appendSlice("makeStyle(");
                        try addColorsTogether(&code, fg);
                        try code.appendSlice(", ");
                        try addColorsTogether(&code, bg);
                        try code.appendSlice(", TextMode.");
                        try code.appendSlice(textMode);
                        try code.appendSlice("),\n");
                    } else if (std.mem.eql(u8, stype, "rgb")) {
                        if (fg.len != 3 or bg.len != 3) {
                            return GenerationError.InvalidValueException;
                        }
                        try code.appendSlice("makeRGB(");
                        try addRGBTogether(&code, fg);
                        try code.appendSlice(", ");
                        try addRGBTogether(&code, bg);
                        try code.appendSlice(", ");
                        try code.appendSlice(textMode);
                        try code.appendSlice("),\n");
                    } else {
                        return GenerationError.InvalidValueException;
                    }
                } else {
                    return GenerationError.ExpectedKeyNotFound;
                }
            } else {
                return GenerationError.ExpectedKeyNotFound;
            }
            if (prop.object.get("flush")) |flush| {
                try code.appendSlice("\t\t\t.b_flush = ");
                try code.appendSlice(if (flush.bool) "true" else "false");
                try code.appendSlice(",\n");
            } else {
                return GenerationError.ExpectedKeyNotFound;
            }
            if (prop.object.get("fatal")) |fatal| {
                try code.appendSlice("\t\t\t.b_fatal = ");
                try code.appendSlice(if (fatal.bool) "true" else "false");
                try code.appendSlice(",\n");
            } else {
                return GenerationError.ExpectedKeyNotFound;
            }
            try code.appendSlice("\t\t},\n");
        }
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }

    try code.appendSlice("\t},\n");
    try code.appendSlice("\t.m_specFuncs = .{\n");

    if (json.object.get("funcs")) |funcs| {
        const FuncNames = enum { debug, info, warn, err, fatal };

        var debugSet: bool = false;
        var infoSet: bool = false;
        var warnSet: bool = false;
        var errSet: bool = false;
        var fatalSet: bool = false;

        for (funcs.object.keys()) |funcKey| {
            const func = funcs.object.get(funcKey) orelse
                return GenerationError.InternalError;
            const funcRep = std.meta.stringToEnum(FuncNames, funcKey) orelse
                return GenerationError.InvalidFunctionName;
            switch (funcRep) {
                .debug => {
                    debugSet = true;
                    try addFuncBinding(&code, "debug", func);
                },
                .info => {
                    infoSet = true;
                    try addFuncBinding(&code, "info", func);
                },
                .warn => {
                    warnSet = true;
                    try addFuncBinding(&code, "warn", func);
                },
                .err => {
                    errSet = true;
                    try addFuncBinding(&code, "error", func);
                },
                .fatal => {
                    fatalSet = true;
                    try addFuncBinding(&code, "fatal", func);
                },
            }
        }

        if (!debugSet or !infoSet or !warnSet or !errSet or !fatalSet) {
            std.debug.print("\"funcs\" should contain: \"debug\", \"info\", \"warn\", \"err\", \"fatal\"\n", .{});
            return GenerationError.ExpectedKeyNotFound;
        }
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }

    try code.appendSlice("\t},\n");
    try code.appendSlice("\t.m_features = .{\n");

    if (json.object.get("features")) |features| {
        try addFeature(&code, "time", features);
        try addFeature(&code, "thread", features);
        try addFeature(&code, "level", features);
        try addFeature(&code, "file", features);
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }

    try code.appendSlice("\t},\n");
    const tempQueue =
        \\      .m_queue = .{
        \\          .b_enable = true,
        \\          .u_size = 100,
        \\          .u_flushLimit = 3,
        \\      },  
        \\
    ;
    try code.appendSlice(tempQueue);

    if (json.object.get("verbosity")) |verbosity| {
        try code.appendSlice("\t.u_verbosity = ");
        const vStr = try std.fmt.allocPrint(allocator, "{d}", .{verbosity.integer});
        try code.appendSlice(vStr);
        try code.appendSlice(",\n");
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }
    if (json.object.get("fileVerbosity")) |verbosity| {
        try code.appendSlice("\t.u_fileVerbosity = ");
        const vStr = try std.fmt.allocPrint(allocator, "{d}", .{verbosity.integer});
        try code.appendSlice(vStr);
        try code.appendSlice(",\n");
    } else {
        return GenerationError.ExpectedKeyNotFound;
    }

    try code.appendSlice("};\n");

    return code.toOwnedSlice();
}

pub fn generate_config_module(b: *std.Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, path: []const u8) !*Build.Module {
    const file_contents = std.fs.cwd().readFileAlloc(b.allocator, path, 1024 * 1024) catch |err| {
        std.debug.print("error: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };
    defer b.allocator.free(file_contents);

    const parsed = std.json.parseFromSlice(std.json.Value, b.allocator, file_contents, .{}) catch |err| {
        std.debug.print("error whilst parsing json: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };
    defer parsed.deinit();

    const root = parsed.value;

    const generated_code = generateConfig(b.allocator, root) catch |err| {
        std.debug.print("error whilst generating code: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };

    //std.debug.print("{s}\n", .{generated_code});
    const gen_file_path_abs: []u8 = b.cache_root.join(b.allocator, &[_][]const u8{"user_config.zig"}) catch |err| {
        std.debug.print("error whilst trying to create file path for generated code: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };
    const gen_file_path = ".zig-cache/user_config.zig";

    var generated_file = std.fs.createFileAbsolute(gen_file_path_abs, .{}) catch |err| {
        std.debug.print("error whilst trying to create file for generated code: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };

    _ = generated_file.write(generated_code) catch |err| {
        std.debug.print("error whilst trying to write generated code: {}\n", .{err});
        return GenerationError.ModuleGenerationError;
    };

    const config = b.addModule("user_config", .{
        .root_source_file = b.path(gen_file_path),
        .target = target,
        .optimize = optimize,
    });

    return config;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const common = b.addModule("commond", .{
        .root_source_file = b.path("common/common.zig"),
        .target = target,
        .optimize = optimize,
    });

    const log = b.addModule("apeiron-logger", .{
        .root_source_file = b.path("src/log.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("src/demo/demo.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (b.option([]const u8, "config", "JSON configuration")) |config_json_path| {
        const config = generate_config_module(b, target, optimize, config_json_path) catch |err| {
            std.debug.print("error: {}\n", .{err});
            return;
        };
        log.addImport("user_config", config);
        config.addImport("common", common);
    } else {
        std.debug.print("No configuration defined\n", .{});
    }

    log.addImport("common", common);

    exe.root_module.addImport("log", log);
    exe.linkLibC();

    if (b.option(bool, "enable-demo", "install the demo too") orelse false) {
        b.installArtifact(exe);
    }
}
