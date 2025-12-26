#!/bin/bash
# Diagnose pyenv Python SSL linking
#
# This script checks how your Python installation handles SSL
# and whether it can be captured by OISP Sensor.

set -e

echo "=== pyenv Python SSL Diagnosis ==="
echo ""

# Find python
PYTHON_PATH=$(which python3 2>/dev/null || which python 2>/dev/null || echo "")

if [ -z "$PYTHON_PATH" ]; then
    echo "ERROR: Python not found in PATH"
    exit 1
fi

echo "Python Path: $PYTHON_PATH"
echo "Python Version: $($PYTHON_PATH --version 2>&1)"
echo ""

# Check if it's pyenv
if [[ "$PYTHON_PATH" == *".pyenv"* ]]; then
    echo "Installation Type: pyenv"
    echo ""
    echo "WARNING: pyenv-installed Python may use static OpenSSL."
    echo "         SSL capture might not work."
else
    echo "Installation Type: System"
fi

echo ""
echo "=== SSL Library Analysis ==="
echo ""

# Check linked libraries
echo "Linked SSL libraries (via ldd):"
if command -v ldd &> /dev/null; then
    SSL_LIBS=$(ldd "$PYTHON_PATH" 2>/dev/null | grep -E "libssl|libcrypto" || echo "")
    if [ -z "$SSL_LIBS" ]; then
        echo "  No dynamic SSL libraries found in main binary"
        echo ""

        # Check Python's _ssl module
        echo "Checking Python's _ssl module..."
        SSL_MODULE=$($PYTHON_PATH -c "import _ssl; print(_ssl.__file__)" 2>/dev/null || echo "")
        if [ -n "$SSL_MODULE" ] && [ -f "$SSL_MODULE" ]; then
            echo "  _ssl module: $SSL_MODULE"
            SSL_MODULE_LIBS=$(ldd "$SSL_MODULE" 2>/dev/null | grep -E "libssl|libcrypto" || echo "")
            if [ -z "$SSL_MODULE_LIBS" ]; then
                echo "  No dynamic SSL libraries in _ssl module (static linking)"
                echo ""
                echo "  This means:"
                echo "    - OpenSSL is compiled INTO Python"
                echo "    - OISP Sensor cannot hook SSL_read/SSL_write"
                echo "    - SSL capture will NOT work"
            else
                echo "  Dynamic SSL libraries found in _ssl module:"
                echo "$SSL_MODULE_LIBS" | while read line; do
                    echo "    $line"
                done
                echo ""
                echo "  This is good! Dynamic SSL linking detected."
                echo "  OISP Sensor should work with default configuration."
            fi
        else
            echo "  Could not locate _ssl module"
        fi
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
echo "=== Python SSL Info ==="
echo ""

# Get SSL version from Python
$PYTHON_PATH -c "
import ssl
print(f'SSL Library: {ssl.OPENSSL_VERSION}')
print(f'SSL Module File: {ssl.__file__}')
try:
    import _ssl
    print(f'_ssl Module: {_ssl.__file__}')
except Exception as e:
    print(f'_ssl Module: Error - {e}')
" 2>/dev/null || echo "Could not query Python SSL info"

echo ""
echo "=== Recommendations ==="
echo ""

if [[ "$PYTHON_PATH" == *".pyenv"* ]]; then
    # Check _ssl module for dynamic linking
    SSL_MODULE=$($PYTHON_PATH -c "import _ssl; print(_ssl.__file__)" 2>/dev/null || echo "")
    HAS_DYNAMIC_SSL=false
    if [ -n "$SSL_MODULE" ] && [ -f "$SSL_MODULE" ]; then
        if ldd "$SSL_MODULE" 2>/dev/null | grep -q "libssl"; then
            HAS_DYNAMIC_SSL=true
        fi
    fi

    if [ "$HAS_DYNAMIC_SSL" = false ]; then
        echo "Option 1: Use system Python instead of pyenv"
        echo "  sudo apt install python3  # Ubuntu/Debian"
        echo ""
        echo "Option 2: Build pyenv Python with shared OpenSSL"
        echo "  PYTHON_CONFIGURE_OPTS=\"--enable-shared\" \\"
        echo "  LDFLAGS=\"-L/usr/lib/x86_64-linux-gnu\" \\"
        echo "  pyenv install 3.11"
        echo ""
        echo "Option 3: Use Docker for testing"
        echo "  docker run -it python:3.11 python app.py"
        echo ""
        echo "Option 4: Use venv with system Python"
        echo "  /usr/bin/python3 -m venv .venv && source .venv/bin/activate"
    else
        echo "Your pyenv Python uses dynamic SSL linking."
        echo "OISP Sensor should work normally."
    fi
else
    echo "Your Python installation should work with OISP Sensor."
    echo ""
    echo "Test with:"
    echo "  sudo oisp-sensor record --process python3"
fi

echo ""
