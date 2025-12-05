#!/bin/bash
# apply-patches.sh - Apply SIBOS GTK patches to local GTK source

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/../patches"

usage() {
    echo "Usage: $0 <gtk-source-dir> <gtk3|gtk4>"
    echo ""
    echo "Apply SIBOS X11 Shape extension patches to GTK source"
    echo ""
    echo "Arguments:"
    echo "  gtk-source-dir  Path to GTK source directory"
    echo "  gtk3|gtk4       Which GTK version to patch"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/gtk-3.24 gtk3"
    echo "  $0 /path/to/gtk-main gtk4"
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

GTK_SRC="$1"
GTK_VERSION="$2"

if [ ! -d "$GTK_SRC" ]; then
    echo "Error: GTK source directory not found: $GTK_SRC"
    exit 1
fi

case "$GTK_VERSION" in
    gtk3)
        PATCH_FILE="$PATCHES_DIR/gtk3-x11-shape-corners.patch"
        CHECK_FILE="$GTK_SRC/gtk/gtkwindow.c"
        ;;
    gtk4)
        PATCH_FILE="$PATCHES_DIR/gtk4-x11-shape-corners.patch"
        CHECK_FILE="$GTK_SRC/gtk/gtkwindow.c"
        ;;
    *)
        echo "Error: Unknown GTK version: $GTK_VERSION"
        echo "Use 'gtk3' or 'gtk4'"
        exit 1
        ;;
esac

if [ ! -f "$CHECK_FILE" ]; then
    echo "Error: GTK source structure not recognized"
    echo "Expected file not found: $CHECK_FILE"
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file not found: $PATCH_FILE"
    exit 1
fi

echo "Applying $GTK_VERSION patch to $GTK_SRC..."
echo ""
echo "Note: These patches are conceptual and may need manual adjustment"
echo "for your specific GTK version."
echo ""

# Try to apply the patch
cd "$GTK_SRC"

# For git-format patches, use git apply
if head -1 "$PATCH_FILE" | grep -q "^From:"; then
    echo "Attempting git apply..."
    if git apply --check "$PATCH_FILE" 2>/dev/null; then
        git apply "$PATCH_FILE"
        echo "Patch applied successfully with git apply"
    else
        echo "git apply failed, trying manual approach..."
        echo ""
        echo "The patch needs manual application. Key changes:"
        echo ""
        echo "1. Add to $GTK_VERSION/gtk/gtkwindow.c:"
        echo "   - create_rounded_corner_region() function"
        echo "   - update_x11_bounding_shape() function"
        echo "   - Calls in gtk_window_enable_csd(), gtk_window_realize()"
        echo ""
        if [ "$GTK_VERSION" = "gtk4" ]; then
            echo "2. Add to gdk/x11/gdksurface-x11.c:"
            echo "   - gdk_x11_surface_set_bounding_shape() function"
        fi
        echo ""
        echo "See CLAUDE.md for detailed implementation guide."
    fi
else
    # Standard patch
    if patch --dry-run -p1 < "$PATCH_FILE" >/dev/null 2>&1; then
        patch -p1 < "$PATCH_FILE"
        echo "Patch applied successfully"
    else
        echo "Patch could not be applied automatically."
        echo "Manual adjustment needed for your GTK version."
    fi
fi

echo ""
echo "Done. To build GTK:"
echo "  cd $GTK_SRC"
echo "  meson setup _build -Dx11_backend=true"
echo "  ninja -C _build"
