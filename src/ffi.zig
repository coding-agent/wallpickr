const std = @import("std");

pub const c = @cImport({
    @cInclude("gtk/gtk.h");
});
