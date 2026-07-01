#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Install camera driver (device tree overlay + kernel module via DKMS)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Status line formatter (matches Makefile's PRINT)
print() { printf '  %-7s %s\n' "$1" "$2"; }

PACKAGE_NAME=$(grep '^PACKAGE_NAME=' "$SCRIPT_DIR/dkms.conf" | cut -d'"' -f2)
VERSION=$(grep '^PACKAGE_VERSION=' "$SCRIPT_DIR/dkms.conf" | cut -d'"' -f2)

echo "Kurokesu Camera Driver Installer"

if [ -z "$PACKAGE_NAME" ] || [ -z "$VERSION" ]; then
	echo "" >&2
	echo "Error: Failed to read PACKAGE_NAME or PACKAGE_VERSION from dkms.conf" >&2
	exit 1
fi

echo "${PACKAGE_NAME} v${VERSION}"
echo ""

DKMS_SRC="/usr/src/${PACKAGE_NAME}-${VERSION}"

if ! command -v dkms >/dev/null 2>&1; then
	echo "Error: dkms is not installed. Install with:" >&2
	echo "    sudo apt install -y --no-install-recommends dkms" >&2
	exit 1
fi

SENSOR=${PACKAGE_NAME%-rpi-dkms}
NAMES="$PACKAGE_NAME"
if [ "$SENSOR" != "$PACKAGE_NAME" ]; then
	NAMES="$NAMES ${SENSOR}-dkms ${SENSOR}"
fi

for name in $NAMES; do
	ver=$(dkms status -m "$name" 2>/dev/null | awk -F'[/,: ]' '{print $2; exit}')
	if [ -n "$ver" ]; then
		print CLEAN "${name}/${ver}"
		if ! out=$(dkms remove "${name}/${ver}" --all 2>&1); then
			print WARN "could not fully remove ${name}/${ver}" >&2
			printf '%s\n' "$out" >&2
		fi
	fi
done

print COPY "driver source -> $DKMS_SRC"
rm -rf "$DKMS_SRC"
mkdir -p "$DKMS_SRC"
cp "$SCRIPT_DIR/dkms.conf" "$DKMS_SRC/"
cp "$SCRIPT_DIR/dkms.postinst" "$DKMS_SRC/"
cp "$SCRIPT_DIR/Makefile" "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.c "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.dts "$DKMS_SRC/"

print DKMS "add ${PACKAGE_NAME}/${VERSION}"
dkms add -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "build ${PACKAGE_NAME}/${VERSION}"
dkms build -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "install ${PACKAGE_NAME}/${VERSION}"
dkms install -m "$PACKAGE_NAME" -v "$VERSION"

echo ""
echo "Done."
