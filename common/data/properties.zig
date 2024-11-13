pub const LevelProperties = struct {
    s_name: []const u8,
    s_descriptor: []const u8,
    s_style: []const u8,
    b_flush: bool,
    b_fatal: bool,
};

pub const Properties = struct {
    a_levelProps: []const LevelProperties,
    m_specFuncs: struct {
        s_debug: []const u8,
        s_info: []const u8,
        s_warn: []const u8,
        s_error: []const u8,
        s_fatal: []const u8,
    },
    m_features: struct {
        b_time: bool,
        b_thread: bool,
        b_level: bool,
        b_file: bool,
    },
    m_queue: struct {
        b_enable: bool,
        u_size: u32,
        u_flushLimit: u32, // refers to the log level from which on flushing automatically occurs
    },
    u_verbosity: u32,
    u_fileVerbosity: u32,
};
