const std = @import("std");
const ffi = @import("ffi.zig");
const gui = @import("gui.zig");
const Config = @import("config.zig");
const c = ffi.c;

pub fn main() !u8 {
    const app = c.gtk_application_new(null, c.G_APPLICATION_FLAGS_NONE);
    defer c.g_object_unref(app);

    const config = Config.parse(std.heap.c_allocator) catch |err| {
        if (std.mem.eql(u8, "FileNotFound", @errorName(err))) {
            @panic("missing the config file");
        }
        return 1;
    };
    gui.init(app, config);

    const status = c.g_application_run(@ptrCast(app), 0, null);
    return @intCast(status);
}
