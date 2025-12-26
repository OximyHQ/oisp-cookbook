#!/bin/bash
# Diagnose NVM Node.js SSL linking
#
# This script checks how your Node.js installation handles SSL
# and whether it can be captured by OISP Sensor.

set -e

echo "=== NVM Node.js SSL Diagnosis ==="
echo ""

# Find node
NODE_PATH=$(which node 2>/dev/null || echo "")

if [ -z "$NODE_PATH" ]; then
    echo "ERROR: Node.js not found in PATH"
    exit 1
fi

echo "Node.js Path: $NODE_PATH"
echo "Node.js Version: $(node --version)"
echo ""

# Check if it's NVM
if [[ "$NODE_PATH" == *".nvm"* ]]; then
    echo "Installation Type: NVM"
    echo ""
    echo "WARNING: NVM-installed Node.js typically uses static OpenSSL."
    echo "         SSL capture may not work."
else
    echo "Installation Type: System"
fi

echo ""
echo "=== SSL Library Analysis ==="
echo ""

# Check linked libraries
echo "Linked SSL libraries (via ldd):"
if command -v ldd &> /dev/null; then
    SSL_LIBS=$(ldd "$NODE_PATH" 2>/dev/null | grep -E "libssl|libcrypto" || echo "")
    if [ -z "$SSL_LIBS" ]; then
        echo "  No dynamic SSL libraries found (likely static linking)"
        echo ""
        echo "  This means:"
        echo "    - OpenSSL is compiled INTO the Node binary"
        echo "    - OISP Sensor cannot hook SSL_read/SSL_write"
        echo "    - SSL capture will NOT work"
    else
        echo "$SSL_LIBS" | while read line; do
            echo "  $line"
        done
        echo ""
        echo "  This is good! Dynamic SSL linking detected."
        echo "  OISP Sensor should work with default configuration."
    fi
else
    echo "  ldd not available (not Linux?)"
fi

echo ""
echo "=== Recommendations ==="
echo ""

if [[ "$NODE_PATH" == *".nvm"* ]]; then
    SSL_LIBS=$(ldd "$NODE_PATH" 2>/dev/null | grep -E "libssl" || echo "")
    if [ -z "$SSL_LIBS" ]; then
        echo "Option 1: Use system Node.js instead of NVM"
        echo "  sudo apt install nodejs  # Ubuntu/Debian"
        echo ""
        echo "Option 2: Build NVM Node with shared OpenSSL"
        echo "  nvm install 20 --shared-openssl"
        echo ""
        echo "Option 3: Use Docker for testing"
        echo "  docker run -it node:20 node app.js"
    else
        echo "Your NVM Node.js uses dynamic SSL linking."
        echo "OISP Sensor should work normally."
    fi
else
    echo "Your Node.js installation should work with OISP Sensor."
    echo ""
    echo "Test with:"
    echo "  sudo oisp-sensor record --process node"
fi

echo ""
