# NVM Node.js Edge Case

This example demonstrates how to capture AI API calls from Node.js installed via [NVM](https://github.com/nvm-sh/nvm) (Node Version Manager).

## The Challenge

NVM-installed Node.js typically **statically links OpenSSL**, meaning the SSL library is compiled directly into the Node binary rather than dynamically loaded from the system. This prevents the OISP Sensor from hooking into SSL functions using the default configuration.

## Solution

There are two approaches:

### Option 1: Use System Node.js (Recommended for Production)

Install Node.js from your system package manager instead of NVM:

```bash
# Ubuntu/Debian
sudo apt install nodejs npm

# RHEL/CentOS
sudo dnf install nodejs npm

# macOS (Homebrew)
brew install node
```

System-installed Node.js typically uses dynamic OpenSSL linking.

### Option 2: Configure Binary Paths (For NVM Users)

If you must use NVM, you can try configuring the sensor to probe the Node binary directly. However, **this may not work** depending on how Node.js was compiled.

1. Find your NVM Node.js binary:
   ```bash
   which node
   # Example: /home/user/.nvm/versions/node/v20.10.0/bin/node
   ```

2. Create a sensor config file (`~/.config/oisp-sensor/config.yaml`):
   ```yaml
   capture:
     ssl_binary_paths:
       - /home/user/.nvm/versions/node/v20.10.0/bin/node
   ```

3. Run the sensor with this config.

**Note**: This approach has limited success with statically-linked binaries.

## Diagnosis

Use the `diagnose` command to check if a Node.js process can be captured:

```bash
# Find your Node.js process PID
pgrep -f "node"

# Diagnose it
sudo oisp-sensor diagnose --pid <PID>
```

If you see "No libssl.so loaded", the Node binary is statically linked and capture won't work with the default approach.

## Testing This Example

This example demonstrates the limitation and workaround:

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run the test (will show diagnostic information)
make test
```

## Expected Behavior

| Node.js Source | SSL Capture | Notes |
|----------------|:-----------:|-------|
| System package manager | ✅ Works | Uses system OpenSSL |
| NVM (default) | ❌ Fails | Statically linked |
| NVM (--shared-openssl) | ✅ Works | Requires custom build |
| Docker (official images) | ✅ Works | Uses image's OpenSSL |

## Building NVM Node with Shared OpenSSL

For advanced users who need NVM with SSL capture:

```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Build Node.js with shared OpenSSL
nvm install 20 --shared-openssl
```

This compiles Node.js to use the system's OpenSSL dynamically.

## Files

| File | Description |
|------|-------------|
| `app.js` | Simple OpenAI call using Node.js |
| `package.json` | Dependencies |
| `diagnose.sh` | Script to diagnose NVM Node.js |
| `test.sh` | Test script showing the limitation |
| `Makefile` | Development commands |
| `README.md` | This file |
