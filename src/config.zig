const std = @import("std");
const Kf = @import("known-folders");
const Ini = @import("ini");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Self = @This();
allocator: Allocator,
path: ?[]const u8,
wallpapers: ?[][]const u8,

fn getWallpapers(path: []const u8) ![][]const u8 {
    var wp_list = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer wp_list.deinit();

    // TODO get the path from ini config file
    var wallpapers_dir = fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| {
        @panic(@errorName(err));
    };
    defer wallpapers_dir.close();

    var iterator = wallpapers_dir.iterate();
    while (try iterator.next()) |file| {
        switch (file.kind) {
            .file => {
                const file_absolute = try fs.path.joinZ(std.heap.c_allocator, &[_][]const u8{ path, file.name });
                try wp_list.append(file_absolute);
            },
            else => {},
        }
    }
    return wp_list.toOwnedSlice();
}

pub fn parse(allocator: Allocator) !Self {
    var self = Self{
        .allocator = allocator,
        .path = null,
        .wallpapers = null,
    };
    const config_dir = try Kf.open(allocator, .roaming_configuration, .{});
    const config_file = try config_dir.?.openFile("wallpickr/config.ini", .{});

    var parser = Ini.parse(allocator, config_file.reader());
    defer parser.deinit();
    while (try parser.next()) |line| {
        switch (line) {
            .property => |prop| {
                if (std.mem.eql(u8, prop.key, "path")) {
                    if (!fs.path.isAbsolute(prop.value)) @panic("path not absolute");
                    self.path = prop.value;
                }
            },
            .enumeration => {
                @panic("Who told you to use enumerations?");
            },
            else => {},
        }
    }

    self.wallpapers = try getWallpapers(self.path.?);

    return self;
}
