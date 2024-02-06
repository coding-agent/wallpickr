const std = @import("std");
const Kf = @import("known-folders");
const Ini = @import("ini");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const Self = @This();
allocator: Allocator,
path: []const u8,

pub fn parse(allocator: Allocator) !Self {
    const config_dir = try Kf.open(allocator, .roaming_configuration, .{});
    const config_file = try config_dir.?.openFile("wallpickr/config.ini", .{});

    var parser = Ini.parse(allocator, config_file.reader());
    defer parser.deinit();
    var path = "";
    while (try parser.next()) |line| {
        switch (line) {
            .property => |prop| {
                if (std.mem.eql(u8, prop.key, "path")) {
                    path = @ptrCast(&prop.value);
                }
            },
            .enumeration => {
                @panic("Who told you to use enumerations?");
            },
            else => {},
        }
    }

    return Self{
        .allocator = allocator,
        .path = path,
    };
}
