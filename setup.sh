#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026, UAB Kurokesu. All rights reserved.
#
# Install camera driver (device tree overlay + kernel module via DKMS)

# Exit on errors
set -e

# Status line formatter (matches Makefile's PRINT)
print() { printf '  %-7s %s\n' "$1" "$2"; }

# Package identity and install paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DKMS_CONF="$SCRIPT_DIR/dkms.conf"
VERSION=$(grep '^PACKAGE_VERSION=' "$DKMS_CONF" | cut -d'"' -f2)
PACKAGE_NAME=$(grep '^PACKAGE_NAME=' "$DKMS_CONF" | cut -d'"' -f2)
SENSOR=$(grep '^BUILT_MODULE_NAME=' "$DKMS_CONF" | cut -d'"' -f2)
DKMS_SRC="/usr/src/${PACKAGE_NAME}-${VERSION}"

# Check required variables
if [ -z "$VERSION" ] || [ -z "$PACKAGE_NAME" ] || [ -z "$SENSOR" ]; then
	echo "Error: failed to parse $DKMS_CONF" >&2
	exit 1
fi

echo "Kurokesu Camera Driver Installer"
echo "${PACKAGE_NAME} v${VERSION}"
echo ""

# Check prerequisites
if ! command -v dkms >/dev/null 2>&1; then
	echo "Error: dkms not installed. Run:" >&2
	echo "sudo apt install -y --no-install-recommends dkms" >&2
	exit 1
fi

# Remove DKMS registrations matching sensor name, sweep their source trees
dkms status 2>/dev/null | sed 's/[,:].*//' | sort -u | while read -r ENTRY; do
	case "${ENTRY%%/*}" in
	*"$SENSOR"*)
		print DKMS "remove $ENTRY"
		if OUT=$(dkms remove "$ENTRY" --all 2>&1); then
			# dkms remove only deregisters, source tree is installer's to clean
			OLD_SRC="/usr/src/${ENTRY%%/*}-${ENTRY#*/}"
			if [ -f "$OLD_SRC/dkms.conf" ]; then
				print CLEAN "$OLD_SRC"
				rm -rf "$OLD_SRC" || print WARN "could not remove $OLD_SRC" >&2
			fi
		else
			print WARN "could not fully remove $ENTRY" >&2
			printf '%s\n' "$OUT" >&2
		fi
		;;
	esac
done

# Copy source to DKMS tree
print COPY "driver source -> $DKMS_SRC"
rm -rf "$DKMS_SRC"
mkdir -p "$DKMS_SRC"
cp "$DKMS_CONF" "$DKMS_SRC/"
cp "$SCRIPT_DIR/dkms.postinst" "$DKMS_SRC/"
cp "$SCRIPT_DIR/Makefile" "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.c "$DKMS_SRC/"
cp "$SCRIPT_DIR"/*.dts "$DKMS_SRC/"

# DKMS add + build + install
print DKMS "add ${PACKAGE_NAME}/${VERSION}"
dkms add -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "build ${PACKAGE_NAME}/${VERSION}"
dkms build -m "$PACKAGE_NAME" -v "$VERSION"

print DKMS "install ${PACKAGE_NAME}/${VERSION}"
dkms install -m "$PACKAGE_NAME" -v "$VERSION"

echo ""
echo "Done."
