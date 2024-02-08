const std = @import("std");
const Allocator = std.mem.Allocator;

const Monitor = struct {
    name: []const u8,
    focused: bool,
};

pub fn setWallpaperToCurrentMonitor(alloc: Allocator, path: []const u8) !void {
    var json_arena = std.heap.ArenaAllocator.init(alloc);
    defer json_arena.deinit();
    const instance_signature = std.os.getenv("HYPRLAND_INSTANCE_SIGNATURE") orelse
        return error.MissingInstanceSignature;
    const socket_path = try std.fs.path.join(alloc, &.{ "/tmp", "hypr", instance_signature, ".socket.sock" });

    const monitors: []Monitor = communication: {
        const stream = try std.net.connectUnixSocket(socket_path);
        defer stream.close();

        try stream.writeAll("[[BATCH]][-j]/monitors;");
        var json_reader = std.json.reader(json_arena.allocator(), stream.reader());

        break :communication try std.json.innerParse([]Monitor, json_arena.allocator(), &json_reader, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_if_needed,
            .max_value_len = std.json.default_max_value_len,
        });
    };

    const stream = try std.net.connectUnixSocket(socket_path);
    defer stream.close();

    var buf_writer = std.io.bufferedWriter(stream.writer());
    const writer = buf_writer.writer();

    for (monitors) |monitor| {
        if (monitor.focused) {
            try writer.writeAll("[[BATCH]]");
            try writer.print("/hyprpaper preload {s}", .{path});
            try writer.print("/hyprpaper wallpaper {s},contain:{s}", .{ monitor.name, path });
            try writer.print("/hyprpaper unload all", .{});
            break;
        } else {
            unreachable;
        }
    }

    try buf_writer.flush();
}
