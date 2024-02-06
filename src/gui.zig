const std = @import("std");
const ffi = @import("ffi.zig");
const Config = @import("config.zig");
const fs = std.fs;
const c = ffi.c;

fn connectSignal(instance: c.gpointer, detailed_signal: [*c]const c.gchar, c_handler: c.GCallback, data: c.gpointer) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), detailed_signal, c_handler, data, null, 0);
}

fn getWallpapers() ![][]const u8 {
    var wp_list = std.ArrayList([]const u8).init(std.heap.c_allocator);
    defer wp_list.deinit();

    // TODO get the path from ini config file
    const wp_path = "/home/coding-agent/dev/wallpapers/";
    var wallpapers_dir = fs.openDirAbsolute(wp_path, .{ .iterate = true }) catch |err| {
        @panic(@errorName(err));
    };
    defer wallpapers_dir.close();

    var iterator = wallpapers_dir.iterate();
    while (try iterator.next()) |file| {
        switch (file.kind) {
            .file => {
                const file_absolute = try fs.path.joinZ(std.heap.c_allocator, &[_][]const u8{ wp_path, file.name });
                try wp_list.append(file_absolute);
            },
            else => {},
        }
    }
    return wp_list.toOwnedSlice();
}

fn activate(app: *c.GtkApplication) callconv(.C) void {
    // setup the window
    const window = c.gtk_application_window_new(app);
    c.gtk_window_set_title(@ptrCast(window), "Chibino");
    c.gtk_window_set_modal(@ptrCast(window), 1);
    c.gtk_window_set_resizable(@ptrCast(window), 0);
    c.gtk_window_set_default_size(@ptrCast(window), 600, 100);
    const main_box = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 2);
    c.gtk_window_set_child(@ptrCast(window), main_box);

    // body
    const grid = c.gtk_grid_new();
    const wallpapers_list = getWallpapers() catch @panic("foo");
    for (wallpapers_list, 0..) |wp, i| {
        const texture = c.gdk_pixbuf_new_from_file(@ptrCast(wp), null);
        const image = c.gtk_image_new_from_pixbuf(@ptrCast(texture));
        c.gtk_widget_set_size_request(@ptrCast(image), 400, 375);
        c.gtk_grid_attach(@ptrCast(grid), @ptrCast(image), @as(c_int, @intCast(i)), 0, 1, 1);
    }

    const adjustement = c.gtk_adjustment_new(0, 0, 0, 1, 1, 200);
    const scrolled_window = c.gtk_scrolled_window_new();
    const vport = c.gtk_viewport_new(adjustement, null);
    c.gtk_scrolled_window_set_policy(@ptrCast(scrolled_window), c.GTK_POLICY_ALWAYS, c.GTK_POLICY_NEVER);
    c.gtk_viewport_set_child(@ptrCast(vport), @ptrCast(grid));
    c.gtk_scrolled_window_set_child(@ptrCast(scrolled_window), @ptrCast(vport));
    c.gtk_box_append(@ptrCast(main_box), @ptrCast(scrolled_window));

    // Exit on ESC key press
    const eck = c.gtk_event_controller_key_new();
    c.gtk_widget_add_controller(window, eck);

    // Signals
    connectSignal(eck, "key-pressed", @ptrCast(&handleEscapeKeypress), @ptrCast(window));

    // show window
    c.gtk_widget_show(@ptrCast(window));
}

pub fn init(app: *c.GtkApplication, config: Config) void {
    _ = config; // autofix
    const handler: c.GCallback = @ptrCast(&activate);
    connectSignal(app, "activate", handler, null);
}

fn handleEscapeKeypress(
    eck: *c.GtkEventControllerKey,
    keyval: c.guint,
    keycode: c.guint,
    state: c.GdkModifierType,
    win: *c.GtkWindow,
) c.gboolean {
    _ = eck;
    _ = keycode;
    _ = state;

    if (keyval == c.GDK_KEY_Escape) {
        c.gtk_window_close(win);
        return 1;
    } else {
        return 0;
    }
}
