# CLAUDE.md - Development Guide for SIBOS GTK Flatpak Patches

## Project Purpose

This project provides patches to GTK3 and GTK4 that enable rounded window corners on **non-composited X11 displays** using the X11 Shape extension instead of alpha transparency.

## Technical Background

### The Problem
GTK's Client-Side Decorations (CSD) use alpha transparency for rounded corners. This requires:
1. An RGBA visual
2. A compositing manager to blend the alpha channel

On non-composited X11 (SBWM, i3, dwm without compositor), GTK falls back to `.solid-csd` which has `border-radius: 0` - no rounded corners.

### Our Solution
Use the X11 Shape extension (`ShapeBounding`) which has been available since X11R5 (1991). This extension allows defining non-rectangular window boundaries without requiring compositing.

## Key Files

### GTK3 Patch (`patches/gtk3-x11-shape-corners.patch`)

**Modified file:** `gtk/gtkwindow.c`

Key functions added:
- `create_rounded_corner_region()` - Creates cairo_region_t with rounded corners using scanline approximation
- `update_x11_bounding_shape()` - Applies shape to X11 window
- `clear_x11_bounding_shape()` - Removes shape for maximized/fullscreen

Integration points:
- `gtk_window_enable_csd()` - Calls shape update when `use_client_shadow` is FALSE
- `update_realized_window_properties()` - Updates shape on property changes
- `gtk_window_realize()` - Applies initial shape
- `gtk_window_state_callback()` - Updates shape on maximize/fullscreen

### GTK4 Patch (`patches/gtk4-x11-shape-corners.patch`)

**Modified files:**
- `gdk/x11/gdksurface-x11.c` - Adds `gdk_x11_surface_set_bounding_shape()`
- `gdk/x11/gdkx11surface.h` - Declares new public function
- `gtk/gtkwindow.c` - Same logic as GTK3, adapted for GTK4 API

Key API differences from GTK3:
- `GdkSurface` instead of `GdkWindow`
- `gtk_native_get_surface()` instead of `_gtk_widget_get_window()`
- `gdk_display_is_composited()` check in `gtk_window_is_composited()`

## Algorithm: Rounded Corner Region Creation

The scanline algorithm creates a cairo_region_t (rectangle-based) that approximates a rounded rectangle:

```
For corner radius R:
1. Top rounded section (y = 0 to R-1):
   - For each scanline y, calculate x_offset using circle equation
   - x_offset = R - sqrt(R² - (R-y-0.5)²)
   - Add rectangle from x_offset to (width - x_offset)

2. Middle section (y = R to height-R-1):
   - Full-width rectangle

3. Bottom rounded section (y = height-R to height-1):
   - Mirror of top section
```

## Building and Testing

### Quick Validation
```bash
# Clone GTK and check structure
git clone --depth 1 --branch gtk-3-24 https://github.com/GNOME/gtk.git /tmp/gtk3
ls /tmp/gtk3/gtk/gtkwindow.c  # Should exist
ls /tmp/gtk3/gdk/x11/gdkwindow-x11.c  # Should exist
```

### Full Build (requires many dependencies)
```bash
# GTK3
cd /tmp/gtk3
meson setup _build -Dx11_backend=true
ninja -C _build

# GTK4
cd /tmp/gtk4
meson setup _build -Dx11-backend=true
ninja -C _build
```

### Testing on Non-Composited X11
1. Use a window manager without compositor (i3, dwm, SBWM)
2. Disable any running compositor (`killall picom` etc.)
3. Run a GTK app and check for rounded corners

## Integration with Freedesktop SDK

To build a complete Flatpak runtime with these patches:

1. Clone freedesktop-sdk:
   ```bash
   git clone https://gitlab.com/freedesktop-sdk/freedesktop-sdk.git
   ```

2. Add patches to `patches/` directory

3. Modify `elements/components/gtk3.bst` and `elements/components/gtk.bst` to include patches

4. Build with BuildStream:
   ```bash
   make export EXPORT_PATH=/path/to/export
   ```

## Known Limitations

1. **Corner smoothness**: The scanline approximation creates stepped corners (pixel-level aliasing). This is inherent to X11 Shape extension which works with rectangles.

2. **Dynamic radius**: Currently uses a fixed radius (8px GTK3, 12px GTK4). Could be enhanced to read CSS `border-radius`.

3. **Per-corner radius**: All corners use the same radius. CSS allows different radii per corner.

## Future Enhancements

1. Read `border-radius` from CSS for each corner
2. Support oval corners (different horizontal/vertical radii)
3. Better integration with theme changes
4. Wayland fallback (though Wayland always composites)
