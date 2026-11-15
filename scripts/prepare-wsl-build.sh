#!/bin/bash
# Copy/sync pbsbc01h3-build to a space-free native Linux path in WSL2 and repair Windows extraction artifacts.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${1:-${HOME}/pbsbc01h3-build}"

if grep -q "[[:space:]]" <<<"$DEST_DIR"; then
	echo "Error: destination path contains whitespace: $DEST_DIR" >&2
	exit 1
fi

DEST_PARENT="$(dirname "$DEST_DIR")"
mkdir -p "$DEST_PARENT"
DEST_FSTYPE="$(findmnt -n -o FSTYPE -T "$DEST_PARENT" 2>/dev/null || true)"
if [[ "$DEST_FSTYPE" == "9p" || "$DEST_FSTYPE" == "drvfs" || "$DEST_FSTYPE" == "ntfs" ]]; then
	echo "Error: destination must be on a native WSL2 Linux filesystem (e.g. ext4 ~/pbsbc01h3-build), not $DEST_FSTYPE" >&2
	exit 1
fi

echo "Syncing $SRC_DIR -> $DEST_DIR ..."
if command -v rsync >/dev/null 2>&1; then
	mkdir -p "$DEST_DIR"
	rsync -a --info=progress2 --exclude='output/' "$SRC_DIR/" "$DEST_DIR/"
else
	rm -rf "$DEST_DIR"
	cp -a "$SRC_DIR" "$DEST_DIR"
fi

echo "Restoring POSIX symlinks ..."
bash "$DEST_DIR/scripts/fix-symlinks.sh" "$DEST_DIR"

echo "Normalizing DEBIAN control dirs, systemd units, and script permissions ..."
find "$DEST_DIR/external" -type d -name DEBIAN -exec chmod 755 {} +
find "$DEST_DIR/external/packages/bsp" -path '*/systemd/*' -type f -exec chmod 644 {} +
find "$DEST_DIR/scripts" -maxdepth 1 -type f -name '*.sh' -exec sed -i 's/\r$//' {} + -exec chmod +x {} +
sed -i 's/\r$//' "$DEST_DIR/build.sh"
chmod +x "$DEST_DIR/build.sh"
if [[ -d "$DEST_DIR/userpatches" ]]; then
	find "$DEST_DIR/userpatches" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.conf' \) -exec sed -i 's/\r$//' {} +
	[[ -f "$DEST_DIR/userpatches/customize-image.sh" ]] && chmod +x "$DEST_DIR/userpatches/customize-image.sh"
fi

echo
echo "WSL2 native workspace is ready at: $DEST_DIR"
echo "Run the build with:"
echo "  cd $DEST_DIR && sudo ./build.sh"
echo "Or build Ubuntu 26.04 (resolute) CLI image for pbsbc01h3 non-interactively:"
echo "  cd $DEST_DIR && sudo ./build.sh BOARD=pbsbc01h3 BRANCH=current RELEASE=resolute BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no"
