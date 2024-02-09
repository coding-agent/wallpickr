const std = @import("std");
const Allocator = std.mem.Allocator;

const Monitor = struct {
    name: []const u8,
    focused: bool,
};

pub fn setWallpaperToCurrentMonitor(alloc: Allocator, path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const instance_signature = std.os.getenv("HYPRLAND_INSTANCE_SIGNATURE") orelse
        return error.MissingInstanceSignature;
    const socket_path = try std.fs.path.join(alloc, &.{ "/tmp", "hypr", instance_signature, ".socket.sock" });

    const monitors: []Monitor = communication: {
        const hl_stream = try std.net.connectUnixSocket(socket_path);
        defer hl_stream.close();

        try hl_stream.writeAll("[[BATCH]][-j]/monitors;");
        var json_reader = std.json.reader(arena.allocator(), hl_stream.reader());

        break :communication try std.json.innerParse([]Monitor, arena.allocator(), &json_reader, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_if_needed,
            .max_value_len = std.json.default_max_value_len,
        });
    };

    const hyprpaper_socket_path = try std.fs.path.join(alloc, &.{ "/tmp", "hypr", instance_signature, ".hyprpaper.sock" });

    const preload_response = preload: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();

        const msg = try std.mem.concat(arena.allocator(), u8, &[_][]const u8{ "preload ", path });

        break :preload try stream.writer().write(msg);
    };
    _ = preload_response;

    const wallpaper_response = wallpaper: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();
        var focused_monitor: ?Monitor = null;

        for (monitors) |monitor| {
            if (monitor.focused) {
                focused_monitor = monitor;
                break;
            } else {
                unreachable;
            }
        }

        const msg = try std.mem.concat(arena.allocator(), u8, &[_][]const u8{
            "wallpaper ",
            focused_monitor.?.name,
            ",contain:",
            path,
        });
        break :wallpaper try stream.writer().write(msg);
    };
    _ = wallpaper_response;

    const unload_response = preload: {
        const stream = try std.net.connectUnixSocket(hyprpaper_socket_path);
        defer stream.close();

        const msg = "unload all";

        break :preload try stream.writer().write(msg);
    };
    _ = unload_response;
}
