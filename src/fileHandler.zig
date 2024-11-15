const std = @import("std");
const fmt = @import("fmt");
const ctime = @cImport(@cInclude("time.h"));
const csystime = @cImport(@cInclude("sys/time.h"));

pub fn generate_log_file_name(allocator: std.mem.Allocator, directory: []const u8) ![]const u8 {
    var time_now: csystime.timeval = undefined;
    _ = csystime.gettimeofday(&time_now, null);
    const ms: u32 = @intCast(@divFloor(time_now.tv_usec, 1000));

    var t_str_buf: [9]u8 = undefined; // len of 8 + eod
    var d_str_buf: [9]u8 = undefined;
    const t = ctime.time(null);
    const lt = ctime.localtime(&t);
    const t_format = "%H-%M-%S";
    const d_format = "%d_%m_%y";
    _ = ctime.strftime(&t_str_buf, t_str_buf.len, t_format, lt);
    _ = ctime.strftime(&d_str_buf, d_str_buf.len, d_format, lt);

    var name = std.ArrayList(u8).init(allocator);
    _ = directory;
    //try name.appendSlice(directory);
    //if (name.items.len == 0) try name.appendSlice(".");
    //const lastChar = name.items[name.items.len - 1];
    //if (lastChar != '/' and lastChar != '\\') {
    //    try name.appendSlice("/");
    //}

    try name.writer().print(
        "{s:8}-{d:0>4}-{s:8}.log",
        .{ t_str_buf[0..8], ms, d_str_buf[0..8] },
    );

    return name.toOwnedSlice();
}

// struct for the file logger. Handles fileIO
pub fn FileHandler() type {
    return struct {
        // double buffer for continuous execution when logging to file.
        buffer_a: std.ArrayList(u8),
        buffer_b: std.ArrayList(u8),
        // when true, buffer_a is active, otherwise buffer_b
        active_buffer: bool = true,

        // batch size for automatic flushing
        threshold: usize = 2048,

        io_thread: ?std.Thread = null,
        mutex: std.Thread.Mutex,
        condvar: std.Thread.Condition,

        should_flush: bool = false,
        should_close: bool = false,
        file_name: []const u8,

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, file_name: []const u8) !*FileHandler() {
            var fh = try allocator.create(FileHandler());
            fh.buffer_a = std.ArrayList(u8).init(allocator);
            fh.buffer_b = std.ArrayList(u8).init(allocator);
            fh.io_thread = try std.Thread.spawn(.{}, FileHandler().logToFile, .{fh});
            fh.mutex = .{};
            fh.condvar = .{};
            fh.file_name = file_name;
            fh.allocator = allocator;
            return fh;
        }

        pub fn deinit(self: *FileHandler()) !void {
            self.mutex.lock();
            self.should_close = true;
            self.should_flush = true;
            self.condvar.signal();
            self.mutex.unlock();
            //try self.swapBuffersAndSignal();

            if (self.io_thread) |t| {
                t.join();
            }
        }

        // Add log line to active buffer
        pub fn log(self: *FileHandler(), message: []const u8) !void {
            const buffer = if (self.active_buffer) &self.buffer_a else &self.buffer_b;
            try buffer.appendSlice(try self.allocator.dupe(u8, message));
            try buffer.appendSlice("\n");

            // If buffer size reaches threshold, signal flushing and swap buffers
            if (buffer.items.len >= self.threshold and !self.should_flush) {
                try self.swapBuffersAndSignal();
            }
        }

        pub fn swapBuffersAndSignal(self: *FileHandler()) !void {
            // Lock mutex to sync IO thread
            self.mutex.lock();
            defer self.mutex.unlock();

            // Swap buffers
            self.active_buffer = !self.active_buffer;
            self.should_flush = true;

            // Wake IO Thread
            self.condvar.signal();
        }

        pub fn logToFile(self: *FileHandler()) !void {
            var file = try std.fs.cwd().createFile(self.file_name, .{});

            while (true) {
                // Lock mutex before checking condition
                self.mutex.lock();
                while (!self.should_flush) {
                    // Put thread into dormant state until notified
                    self.condvar.wait(&self.mutex);
                }
                defer self.mutex.unlock();

                // Write inactive buffer to file

                const buffer_to_write = if (self.active_buffer) &self.buffer_a else &self.buffer_b;
                file.writeAll(buffer_to_write.items) catch |err| {
                    std.debug.print("error: {}", .{err});
                };
                buffer_to_write.clearAndFree();

                // Reset flush flag
                self.should_flush = false;

                if (self.should_close) {
                    file.close();
                    break;
                }
            }
        }
    };
}
