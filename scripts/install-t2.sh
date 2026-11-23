#!/bin/sh
# Builds the desktop app from this checkout and installs it as `t2`: the AppImage
# at ~/.local/bin/t2, a launcher entry, and its icon. Run with `mise run install`.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
bin="$HOME/.local/bin/t2"
icon="$HOME/.local/share/icons/t2.png"
desktop_file="$HOME/.local/share/applications/t2.desktop"

fail() {
  printf 'install t2: %s\n' "$1" >&2
  exit 1
}

# Native tools mise cannot provide. The desktop build checks these too, but this fails first.
missing=
command -v cc >/dev/null 2>&1 && command -v make >/dev/null 2>&1 || missing="$missing compiler"
pkg-config --exists libsecret-1 2>/dev/null || missing="$missing libsecret"
command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1 || missing="$missing imagemagick"
if [ -n "$missing" ]; then
  fail "missing:${missing}.
  Debian/Ubuntu: sudo apt-get install build-essential pkg-config libsecret-1-dev imagemagick
  Arch/Omarchy:  sudo pacman -S --needed base-devel libsecret imagemagick"
fi

cd "$repo"
vp i
# Native modules link against this machine's glibc, so the release ceiling (2.39) would reject them.
T3CODE_LINUX_GLIBC_CEILING="$(getconf GNU_LIBC_VERSION | awk '{print $2}')"
export T3CODE_LINUX_GLIBC_CEILING
vp run dist:desktop:linux

appimage="$(ls -t "$repo"/release/*.AppImage 2>/dev/null | head -n 1)"
[ -n "$appimage" ] || fail "the build left no AppImage in $repo/release"

# The AppImage's own icon, read from its extracted contents, so no icon has to be checked in.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
(cd "$work" && "$appimage" --appimage-extract >/dev/null) || fail "could not unpack $appimage for its icon"

# install writes a sibling file and mv renames it over the old binary, so a running t2 keeps its inode.
mkdir -p "$(dirname "$bin")"
install -m 755 "$appimage" "$bin.new"
mv -f "$bin.new" "$bin"

mkdir -p "$(dirname "$icon")"
cp -L "$work/squashfs-root/.DirIcon" "$icon"

mkdir -p "$(dirname "$desktop_file")"
cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=t2
Comment=T3 Code, built from this checkout
Exec=$bin %U
Icon=$icon
Terminal=false
Categories=Development;
StartupWMClass=com.t3tools.T3Code
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$(dirname "$desktop_file")" || true
fi

printf 'Installed %s\n  launcher: %s\n' "$bin" "$desktop_file"
resolved="$(command -v t2 || true)"
if [ "$resolved" != "$bin" ]; then
  printf 'note: `t2` on PATH resolves to %s, not %s.\n' "${resolved:-nothing}" "$bin"
  printf '      Run %s directly, or use the launcher.\n' "$bin"
fi
