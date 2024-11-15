const std = @import("std");

// struct for the file logger. Handles fileIO
pub fn FileHandler() type {
    return struct {
        // double buffer for continuous execution when logging to file.
        buffer_a: std.ArrayList(u8),
        buffer_b: std.ArrayList(u8),
        // when true, buffer_a is active, otherwise buffer_b
        active_buffer: bool = true,

        // batch size for automatic flushing
        threshold: usize = 1024,

        io_thread: ?std.Thread = null,
        mutex: std.Thread.Mutex,
        condvar: std.Thread.Condition,

        should_flush: bool = false,
        file_name: []const u8,

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, file_name: []const u8) !*FileHandler() {
            var fh = try allocator.create(FileHandler());
            fh.buffer_a = std.ArrayList(u8).init(allocator);
            fh.buffer_b = std.ArrayList(u8).init(allocator);
            fh.io_thread = try std.Thread.spawn(.{}, &FileHandler().logToFile, .{fh});
            fh.mutex = .{};
            fh.condvar = .{};
            fh.file_name = file_name;
            fh.allocator = allocator;
            return fh;
        }

        pub fn deinit(self: *FileHandler()) void {
            self.allocator.free(self.buffer_a);
            self.allocator.free(self.buffer_b);
            defer self.allocator.deinit();
        }

        // Add log line to active buffer
        pub fn log(self: *FileHandler(), message: []const u8) !void {
            const buffer = if (self.active_buffer) &self.buffer_a else &self.buffer_b;
            try buffer.appendSlice(message);

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
            //var file = try std.fs.cwd().openFile(self.file_name, .{ .mode = std.fs.File.OpenMode.read_write });

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
                try file.writeAll(buffer_to_write.items);
                buffer_to_write.clearAndFree();

                // Reset flush flag
                self.should_flush = false;
            }
        }
    };
}
