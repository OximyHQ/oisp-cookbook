#!/bin/bash
# Download OISP Sensor binary
#
# Usage: ./download-sensor.sh [version]
# Examples:
#   ./download-sensor.sh           # Download latest
#   ./download-sensor.sh v0.2.0    # Download specific version
#   ./download-sensor.sh latest    # Download latest

set -e

VERSION="${1:-latest}"
REPO="oximyHQ/oisp-sensor"
BIN_DIR="${BIN_DIR:-./bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect OS and build target triple
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux)
        TARGET="${ARCH}-unknown-linux-gnu"
        ARCHIVE_EXT="tar.gz"
        ;;
    darwin)
        TARGET="${ARCH}-apple-darwin"
        ARCHIVE_EXT="tar.gz"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

ARCHIVE_NAME="oisp-sensor-${TARGET}.${ARCHIVE_EXT}"

# Create bin directory
mkdir -p "$BIN_DIR"

# Get download URL
if [ "$VERSION" = "latest" ]; then
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"
else
    RELEASE_URL="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
fi

echo "Fetching release info from: $RELEASE_URL"

# Get the download URL for the archive
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url.*${ARCHIVE_NAME}" | head -1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Could not find archive for $ARCHIVE_NAME in release $VERSION"
    echo "Available assets:"
    curl -s "$RELEASE_URL" | grep "browser_download_url" | cut -d '"' -f 4
    exit 1
fi

echo "Downloading: $DOWNLOAD_URL"

# Download and extract
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

curl -L -o "${TEMP_DIR}/${ARCHIVE_NAME}" "$DOWNLOAD_URL"

echo "Extracting..."
tar -xzf "${TEMP_DIR}/${ARCHIVE_NAME}" -C "${TEMP_DIR}"

# Find and copy the binary
if [ -f "${TEMP_DIR}/oisp-sensor" ]; then
    cp "${TEMP_DIR}/oisp-sensor" "${BIN_DIR}/oisp-sensor"
elif [ -f "${TEMP_DIR}/oisp-sensor-${TARGET}/oisp-sensor" ]; then
    cp "${TEMP_DIR}/oisp-sensor-${TARGET}/oisp-sensor" "${BIN_DIR}/oisp-sensor"
else
    echo "Could not find oisp-sensor binary in archive"
    echo "Contents:"
    ls -la "${TEMP_DIR}"
    exit 1
fi

chmod +x "${BIN_DIR}/oisp-sensor"

echo "Downloaded to: ${BIN_DIR}/oisp-sensor"
"${BIN_DIR}/oisp-sensor" --version

