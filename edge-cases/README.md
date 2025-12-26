# Edge Cases

This directory documents known edge cases where OISP Sensor may not work with default configuration.

## Why Edge Cases Exist

OISP Sensor intercepts SSL/TLS traffic by hooking into the system's OpenSSL library (`libssl.so`). This works when applications dynamically link to the system OpenSSL. However, some applications statically compile OpenSSL into their binaries, making interception impossible.

## Common Edge Cases

### NVM Node.js ([nvm-node/](nvm-node/))

Node.js installed via NVM typically uses statically-linked OpenSSL. The OpenSSL functions are embedded directly into the `node` binary.

**Solutions:**
- Use system Node.js (`apt install nodejs`)
- Rebuild with shared SSL (`nvm install 20 --shared-openssl`)
- Use Docker (`docker run -it node:20`)

### pyenv Python ([pyenv-python/](pyenv-python/))

Python installed via pyenv may use statically-linked OpenSSL in the `_ssl` module.

**Solutions:**
- Use system Python (`apt install python3`)
- Rebuild with shared SSL (`PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install 3.11`)
- Use Docker (`docker run -it python:3.11`)
- Use venv with system Python

## Diagnosing Issues

Each edge case example includes a `diagnose.sh` script that checks your installation:

```bash
# Check Node.js
cd edge-cases/nvm-node
./diagnose.sh

# Check Python
cd edge-cases/pyenv-python
./diagnose.sh
```

## Using the New Sensor Commands

The sensor now includes built-in diagnostic commands:

```bash
# Diagnose a specific process
sudo oisp-sensor diagnose --pid <PID>

# Show system SSL library info
sudo oisp-sensor ssl-info
```

## Testing

These examples run as **diagnostic tests**. Unlike other examples that expect events to be captured, edge case tests:

1. Detect the installation type (NVM/pyenv vs system)
2. Check for static vs dynamic SSL linking
3. Set appropriate expectations for the test
4. Pass if behavior matches expectations (even if no events are captured)

Run all edge case tests:

```bash
make test-edge-cases
```
