# Wallpickr

A very simple wallpaper picker for hyprpaper.
Compatible with Hyprland and River

## Configuration

First you must have a config file named `wallpickr/config.ini` in any of the known-folders, refer to [known-folders](https://github.com/ziglibs/known-folders)

```ini
# config.ini

path=/home/user/path/to/wallpapers/
```

## Dependencies
Wallpickr requires only a zig compiler and gtk4 to build.

Also since it's a main goal is to communicate with hyprpaper you need to be using hyprland as well

## Building
The usual zig way, `zig build`.

For release builds, use `zig build -Doptimize=ReleaseFast`.

## Installation

Arch Linux: wallpickr-git AUR package

For other system users [here](https://wiki.archlinux.org/title/installation_guide)
