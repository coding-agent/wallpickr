const std = @import("std");
const ffi = @import("ffi.zig");
const Config = @import("config.zig");
const socket = @import("wallpaper.zig");
const fs = std.fs;
const c = ffi.c;

const WidgetData = struct { win: *c.GtkWindow, path: *[]const u8 };

fn connectSignal(instance: c.gpointer, detailed_signal: [*c]const c.gchar, c_handler: c.GCallback, data: c.gpointer) void {
    _ = c.g_signal_connect_data(@ptrCast(instance), detailed_signal, c_handler, data, null, 0);
}

pub const State = struct {
    arena: std.mem.Allocator,
};

fn activate(app: *c.GtkApplication, state: *State) callconv(.C) void {
    const window = c.gtk_application_window_new(app);
    c.gtk_window_set_title(@ptrCast(window), "wallpickr");
    c.gtk_window_set_modal(@ptrCast(window), 1);
    c.gtk_window_set_resizable(@ptrCast(window), 0);
    c.gtk_window_set_default_size(@ptrCast(window), 900, 100);

    const config = Config.parse(std.heap.c_allocator) catch |err| @panic(@errorName(err));

    const grid = c.gtk_grid_new();
    const wallpapers_list = config.wallpapers;

    for (wallpapers_list.?, 0..) |*wp, i| {
        const texture = c.gdk_pixbuf_new_from_file(wp.ptr, null);
        const image = c.gtk_image_new_from_pixbuf(texture);
        const button = c.gtk_button_new();
        c.gtk_button_set_child(@ptrCast(button), @ptrCast(image));
        c.gtk_widget_set_size_request(@ptrCast(button), 300, 300);
        c.gtk_grid_attach(@ptrCast(grid), @ptrCast(button), @as(c_int, @intCast(i)), 0, 1, 1);
        const eck = c.gtk_event_controller_key_new();
        c.gtk_widget_add_controller(button, eck);
        const data = state.arena.create(WidgetData) catch @panic("foo");
        data.* = .{
            .win = @ptrCast(window),
            .path = wp,
        };
        connectSignal(
            eck,
            "key-pressed",
            @ptrCast(&handleClicked),
            @ptrCast(data),
        );
    }

    const adjustement = c.gtk_adjustment_new(0, 0, 0, 1, 1, 200);
    const scrolled_window = c.gtk_scrolled_window_new();
    const vport = c.gtk_viewport_new(adjustement, null);
    c.gtk_scrolled_window_set_policy(@ptrCast(scrolled_window), c.GTK_POLICY_ALWAYS, c.GTK_POLICY_NEVER);
    c.gtk_viewport_set_child(@ptrCast(vport), @ptrCast(grid));
    c.gtk_scrolled_window_set_kinetic_scrolling(@ptrCast(scrolled_window), 1);
    c.gtk_scrolled_window_set_child(@ptrCast(scrolled_window), @ptrCast(vport));
    c.gtk_window_set_child(@ptrCast(window), @ptrCast(scrolled_window));

    const eck = c.gtk_event_controller_key_new();
    c.gtk_widget_add_controller(window, eck);
    connectSignal(eck, "key-pressed", @ptrCast(&handleEscapeKeypress), @ptrCast(window));

    // show window
    c.gtk_widget_show(@ptrCast(window));
}

pub fn init(app: *c.GtkApplication, state: *State) void {
    const handler: c.GCallback = @ptrCast(&activate);
    connectSignal(app, "activate", handler, state);
}

fn handleEscapeKeypress(
    eck: *c.GtkEventControllerKey,
    keyval: c.guint,
    keycode: c.guint,
    state: c.GdkModifierType,
    win: *c.GtkWindow,
) callconv(.C) c.gboolean {
    _ = eck;
    _ = keycode;
    _ = state;

    switch (keyval) {
        c.GDK_KEY_Escape => {
            c.gtk_window_close(win);
            return 1;
        },
        else => return 0,
    }
}

fn handleClicked(
    eck: *c.GtkEventControllerKey,
    keyval: c.guint,
    keycode: c.guint,
    state: c.GdkModifierType,
    data: *WidgetData,
) callconv(.C) c.gboolean {
    _ = eck;
    _ = keycode;
    _ = state;

    if (keyval == c.GDK_KEY_Return) {
        const ally = std.heap.c_allocator;
        c.gtk_window_close(data.win);
        socket.setWallpaperToCurrentMonitor(ally, data.path.*) catch |err| @panic(@errorName(err));
        return 1;
    }
    return 0;
}
