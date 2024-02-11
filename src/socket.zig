const std = @import("std");
const Allocator = std.mem.Allocator;

const Monitor = struct {
    name: []const u8,
    focused: bool,
};

fn getActiveMonitor(alloc: Allocator, signature: ?[]const u8) ![]const u8 {
    if (signature) |sign| {
        const socket_path = try std.fs.path.join(alloc, &.{ "/tmp", "hypr", sign, ".socket.sock" });
        const hl_stream = try std.net.connectUnixSocket(socket_path);
        defer hl_stream.close();

        try hl_stream.writeAll("[[BATCH]][-j]/monitors;");
        var json_reader = std.json.reader(alloc, hl_stream.reader());

        const monitors: []Monitor = try std.json.innerParse([]Monitor, alloc, &json_reader, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_if_needed,
            .max_value_len = std.json.default_max_value_len,
        });
        for (monitors) |monitor| {
            if (monitor.focused) {
                return monitor.name;
            }
        }
        unreachable;
    } else {
        //TODO get the active monitor from wayland instead
        return "eDP-1";
    }
}

pub fn setWallpaperToCurrentMonitor(alloc: Allocator, path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const buf = try arena.allocator().alloc(u8, 100);

    const instance_signature = std.os.getenv("HYPRLAND_INSTANCE_SIGNATURE");
    const active_monitor = try getActiveMonitor(arena.allocator(), instance_signature);

    const hyprpaper_socket_path =
        if (instance_signature) |sign|
        try std.fs.path.join(alloc, &.{ "/tmp", "hypr", sign, ".hyprpaper.sock" })
    else
        try std.fs.path.join(alloc, &.{ "/tmp", "hypr", ".hyprpaper.sock" });

    _ = preload: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();

        const msg = try std.mem.concat(arena.allocator(), u8, &[_][]const u8{ "preload ", path });

        _ = try stream.writer().write(msg);
        break :preload try stream.read(buf);
    };
    std.debug.print("{s}\n", .{buf});

    _ = wallpaper: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();

        const msg = try std.mem.concat(arena.allocator(), u8, &[_][]const u8{
            "wallpaper ",
            active_monitor,
            ",contain:",
            path,
        });
        _ = try stream.writer().write(msg);
        break :wallpaper try stream.read(buf);
    };
    std.debug.print("{s}\n", .{buf});

    _ = unload: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();
        const msg = "unload all";

        _ = try stream.writer().write(msg);
        break :unload try stream.read(buf);
    };
    std.debug.print("{s}\n", .{buf});
}
