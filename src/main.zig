const std = @import("std");
const ffi = @import("ffi.zig");
const gui = @import("gui.zig");
const Arena = std.heap.ArenaAllocator;
const c = ffi.c;

pub fn main() !u8 {
    var arena = Arena.init(std.heap.c_allocator);
    defer arena.deinit();

    var state: gui.State = .{
        .arena = arena.allocator(),
    };
    const app = c.gtk_application_new(null, c.G_APPLICATION_FLAGS_NONE);
    defer c.g_object_unref(app);

    gui.init(app, &state);

    const status = c.g_application_run(@ptrCast(app), 0, null);
    return @intCast(status);
}
