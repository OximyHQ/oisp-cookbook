# Edge Case: pyenv Python

This example documents the pyenv/static OpenSSL edge case for OISP Sensor.

## The Problem

pyenv-installed Python may use statically-linked OpenSSL, which cannot be
intercepted by OISP Sensor's eBPF probes.

### Why This Happens

When you run `pyenv install 3.11.0`, pyenv compiles Python from source.
By default, it links OpenSSL statically into the Python binary, meaning:

1. OpenSSL functions are embedded in the python binary itself
2. They are not loaded from system shared libraries (libssl.so)
3. OISP Sensor's uprobe on libssl.so doesn't intercept these calls

### How to Check

Run our diagnosis script:

```bash
./diagnose.sh
```

Or manually check:

```bash
# Find your Python
PYTHON_PATH=$(which python3)

# Check linked libraries
ldd $PYTHON_PATH | grep ssl

# If empty, OpenSSL is likely static
# If shows libssl.so, dynamic linking is used
```

## Solutions

### Option 1: Use System Python (Recommended for Development)

System-installed Python uses shared OpenSSL:

```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip

# Fedora
sudo dnf install python3 python3-pip

# Then use system Python
/usr/bin/python3 your_app.py
```

### Option 2: Build pyenv Python with Shared OpenSSL

Force pyenv to use system OpenSSL as a shared library:

```bash
# Install OpenSSL development files
sudo apt install libssl-dev

# Build Python with shared SSL
PYTHON_CONFIGURE_OPTS="--enable-shared" \
LDFLAGS="-L/usr/lib/x86_64-linux-gnu -Wl,-rpath,/usr/lib/x86_64-linux-gnu" \
pyenv install 3.11.0
```

### Option 3: Use Docker

The official Python Docker images use dynamic OpenSSL:

```bash
docker run -it python:3.11 python your_app.py
```

### Option 4: Use Virtual Environment with System Python

```bash
# Create venv with system Python
/usr/bin/python3 -m venv .venv

# Activate and use
source .venv/bin/activate
pip install openai
python your_app.py
```

## Testing

### Check Your Installation

```bash
make diagnose
```

### Run Full Test

```bash
export OPENAI_API_KEY="your-key"
make test
```

## Understanding the Output

The test script will detect your Python installation type and set expectations:

- **pyenv with static SSL**: Test passes with warning (expected behavior)
- **System Python**: Test expects events to be captured
- **pyenv with shared SSL**: Test expects events to be captured

## Files in This Example

- `app.py` - Simple script that makes an OpenAI API call
- `diagnose.sh` - Diagnoses SSL linking for your Python installation
- `test.sh` - Full test with appropriate expectations
- `Makefile` - Development commands
