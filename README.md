# SIBOS GTK Flatpak Runtime - Patched for X11 Shape Extension Rounded Corners

This project provides patched GTK3 and GTK4 libraries that use the **X11 Shape extension** for window rounded corners instead of relying on alpha transparency and compositing.

## The Problem

GTK's Client-Side Decorations (CSD) implement rounded window corners using **alpha transparency**. This works perfectly on composited displays (GNOME, KDE with compositor, Wayland), but fails on **non-composited X11** window managers like:

- SBWM (SIBOS Window Manager)
- i3, dwm, awesome (without compositor)
- Any X11 environment without a compositor

On non-composited X11, GTK falls back to the `.solid-csd` CSS class which has `border-radius: 0` - meaning **no rounded corners at all**.

### Visual Comparison

| Environment | Stock GTK | Patched GTK |
|-------------|-----------|-------------|
| Composited (GNOME/KDE/Wayland) | Rounded corners (alpha) | Rounded corners (alpha) |
| Non-composited X11 | **Square corners** | **Rounded corners (Shape ext)** |

## The Solution

This patch modifies GTK to use the **X11 Shape extension** (`ShapeBounding`) for window corners on non-composited X11 displays:

1. **Detects non-composited X11** via `gdk_display_is_composited()`
2. **Creates a cairo_region_t** representing the rounded rectangle window shape
3. **Applies the bounding shape** via `gdk_window_shape_combine_region()` (GTK3) or equivalent (GTK4)

The X11 Shape extension has been available since X11R5 (1991) and is universally supported.

## Files

```
.
├── README.md                           # This file
├── patches/
│   ├── gtk3-x11-shape-corners.patch    # GTK 3.24.x patch
│   └── gtk4-x11-shape-corners.patch    # GTK 4.x patch
└── .github/
    └── workflows/
        └── build-flatpak-runtime.yml   # GitHub Actions workflow
```

## Building

### Prerequisites

- Linux system with Flatpak installed
- BuildStream 2.x (for building gnome-build-meta)
- bubblewrap, ostree
- ~50GB disk space for build artifacts

### Local Build (Full Runtime)

```bash
# Clone gnome-build-meta for GNOME 47
git clone --branch gnome-47 https://gitlab.gnome.org/GNOME/gnome-build-meta.git
cd gnome-build-meta

# Copy our GTK4 patch
mkdir -p patches
cp /path/to/gtk4-x11-shape-corners.patch patches/

# Modify elements/sdk/gtk.bst to include the patch as a source

# Build the Flatpak runtime
bst build flatpak-runtimes.bst
bst artifact checkout flatpak-runtimes.bst --directory repo
```

### Standalone GTK Build (For Testing)

```bash
# Clone GTK4
git clone --branch 4.14.4 https://github.com/GNOME/gtk.git
cd gtk

# Apply patch
git apply /path/to/gtk4-x11-shape-corners.patch

# Build
meson setup _build -Dx11-backend=true
ninja -C _build
```

### GitHub Actions

The included workflow automatically:
1. Validates patches against GTK source structure
2. Builds patched GTK3 and GTK4 standalone (for CI validation)
3. Creates release artifacts with gnome-build-meta integration files
4. Optionally builds full GNOME runtime (manual trigger)

## Using the Patched Runtime

### Installing the Patched Runtime

```bash
# Add the local repository containing the patched runtime
flatpak remote-add --user --no-gpg-verify sibos-gnome /path/to/repo

# Install the patched GNOME Platform runtime
flatpak install sibos-gnome org.gnome.Platform//47
flatpak install sibos-gnome org.gnome.Sdk//47  # Optional: for development
```

### For Flatpak Apps

Override the default runtime with the patched version:

```bash
# Override for a specific app to use the patched runtime
flatpak override --user --runtime=org.gnome.Platform/x86_64/47 com.example.App

# Or run with the patched runtime directly
flatpak run --runtime=org.gnome.Platform/x86_64/47 com.example.App
```

### System-wide Override

```bash
# Override runtime for all apps from a specific origin
flatpak override --user --runtime=org.gnome.Platform/x86_64/47
```

## Technical Details

### GTK3 Patch Summary

The patch modifies `gtk/gtkwindow.c`:

1. **New function**: `create_rounded_corner_region()` - Creates a cairo_region_t approximating a rounded rectangle using scanlines
2. **New function**: `update_x11_bounding_shape()` - Applies the shape to the X11 window
3. **Modified**: `gtk_window_enable_csd()` - Calls shape update when `use_client_shadow` is FALSE
4. **Modified**: `update_realized_window_properties()` - Updates shape when window properties change

### GTK4 Patch Summary

Similar changes adapted for GTK4's API:

1. **New function**: `gdk_x11_surface_set_bounding_shape()` in `gdk/x11/gdksurface-x11.c`
2. **Modified**: Window CSD handling to apply bounding shape on non-composited X11

### Region Creation Algorithm

The rounded corner region is created by approximating the curved corners with horizontal scanlines:

```c
// For each row in the corner
for (y = 0; y < radius; y++) {
    // Calculate x offset using circle equation
    x_offset = radius - sqrt(radius*radius - (radius-y)*(radius-y));
    // Add rectangle for this scanline
    cairo_region_union_rectangle(region, &rect);
}
```

This creates a smooth approximation using the native X11 rectangle-based shape regions.

## Compatibility

- **GTK 3.24.x**: Tested with 3.24.43+
- **GTK 4.x**: Tested with 4.14+
- **X11 Servers**: Any X11 server with Shape extension (virtually all)
- **GNOME Runtime**: org.gnome.Platform 47+
- **Flatpak**: Works with any Flatpak version supporting GNOME runtimes

## References

- [X11 Shape Extension](https://www.x.org/releases/X11R7.7/doc/libXext/shapelib.html)
- [GTK CSD Documentation](https://docs.gtk.org/gtk4/class.Window.html)
- [GNOME Build Meta](https://gitlab.gnome.org/GNOME/gnome-build-meta)
- [GNOME Build Meta Releases](https://gitlab.gnome.org/GNOME/gnome-build-meta/-/releases)
- [BuildStream](https://buildstream.build/)

## License

Patches are provided under the same license as GTK (LGPL-2.1-or-later).

## Contributing

Issues and pull requests welcome. Please test on non-composited X11 before submitting.

## Credits

- SIBOS Project - Initial implementation
- GTK Team - Original GTK CSD implementation
- Freedesktop SDK Team - Build infrastructure
