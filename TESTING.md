# OISP Cookbook Testing Guide

This guide explains how to test OISP cookbooks locally and in CI/CD.

## Quick Start

### Test All Cookbooks

```bash
# From cookbook root directory
export OPENAI_API_KEY="sk-your-key-here"
make test
```

This auto-discovers and tests **all** cookbooks. Currently finds 10 cookbooks across Python, Node.js, edge cases, multi-process, self-hosted, and Kubernetes.

### Test Specific Cookbook

```bash
# Test by name (converts slashes to hyphens)
make test-python-01-openai-simple
make test-node-01-openai-simple
make test-python-02-litellm

# Or test by path
./shared/scripts/run-cookbook-test.sh python/01-openai-simple
```

### Test by Category

```bash
make test-python        # All Python cookbooks
make test-node          # All Node.js cookbooks
make test-edge-cases    # Diagnostic tests
```

## How It Works

### Auto-Discovery

The testing infrastructure uses **convention-based auto-discovery**:

- Any directory with `expected-events.json` is automatically discovered as a testable cookbook
- No need to edit test files or CI configuration when adding new cookbooks
- Language is auto-detected from `requirements.txt` (Python) or `package.json` (Node.js)

### Shared Test Harness

All cookbooks use the same test harness ([shared/scripts/run-cookbook-test.sh](shared/scripts/run-cookbook-test.sh)):

1. **Auto-detect language** from files present
2. **Start OISP sensor** with appropriate process filter
3. **Setup environment** (Python venv or npm install)
4. **Run application** (app.py or index.js)
5. **Wait for events** to be captured
6. **Validate events** against expected-events.json
7. **Cleanup** and report results

### What Gets Tested

✅ **SSL/TLS interception** - eBPF uprobes capture plaintext after decryption
✅ **HTTP parsing** - Request/response headers and bodies
✅ **GZIP decompression** - Handles compressed responses
✅ **Chunked encoding** - Reassembles chunked transfer encoding
✅ **Multi-read responses** - Stitches data from multiple SSL_read calls
✅ **AI event detection** - Identifies ai.request and ai.response events

## Adding a New Cookbook

Adding a new cookbook is simple - **just add one file**:

```bash
# 1. Create your cookbook directory
mkdir python/05-my-example

# 2. Add your application code
cat > python/05-my-example/app.py <<EOF
import openai
client = openai.OpenAI()
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
EOF

# 3. Add dependencies
cat > python/05-my-example/requirements.txt <<EOF
openai>=1.0.0
EOF

# 4. Add test expectations
cat > python/05-my-example/expected-events.json <<EOF
{
  "minimum_events": 2,
  "events": [
    {
      "event_type": "ai.request",
      "required_fields": {
        "data.provider.name": "openai",
        "data.model.id": "/gpt-4/",
        "data.streaming": false
      }
    },
    {
      "event_type": "ai.response",
      "required_fields": {
        "data.success": true,
        "data.usage.total_tokens": "> 0"
      }
    }
  ]
}
EOF

# 5. Test it!
make test-python-05-my-example
```

**That's it!** Your cookbook is now:
- ✅ Testable via `make test-python-05-my-example`
- ✅ Included in `make test` (all cookbooks)
- ✅ Automatically tested in GitHub Actions nightly runs
- ✅ Automatically tested in PR validation (if files change)

## Requirements

### Linux (Native)

- **Kernel**: Linux 5.8+ with eBPF and BTF support
- **Privileges**: Root or sudo access (for eBPF probes)
- **Mounted**: `/sys/kernel/debug` and `/sys/fs/bpf`
- **Tools**: Python 3.11+ or Node.js 20+ (depending on cookbook)

### macOS / Windows (Docker)

- **Docker Desktop** installed and running
- Sensor runs in privileged Linux container
- Automatic fallback when running on non-Linux OS

## CI/CD Integration

### Nightly Tests

Every night at 2 AM UTC, GitHub Actions:

1. **Auto-discovers** all cookbooks
2. **Tests all in parallel** (matrix strategy)
3. **Requires all to pass** (fail-fast: false, strict policy)
4. **Uploads logs** on failure (7-day retention)

View: [.github/workflows/nightly.yml](.github/workflows/nightly.yml)

### PR Validation

On pull requests:

1. **Detects changed cookbooks** from git diff
2. **Tests only affected cookbooks** (fast feedback)
3. **Tests all if shared/ changes** (infrastructure change)
4. **Provides summary** in PR checks

View: [.github/workflows/pr-validation.yml](.github/workflows/pr-validation.yml)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ App (Python/Node.js)                                        │
└────────────────┬────────────────────────────────────────────┘
                 │ API call
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ libssl.so (OpenSSL)                                         │
│   SSL_read() / SSL_write()                                  │
└────────────────┬────────────────────────────────────────────┘
                 │ eBPF uprobe
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ OISP Sensor (Rust + eBPF)                                   │
│   1. Captures plaintext after SSL decryption                │
│   2. Reassembles HTTP requests/responses                    │
│   3. Decompresses gzip, decodes chunked encoding            │
│   4. Parses JSON, detects AI events                         │
└────────────────┬────────────────────────────────────────────┘
                 │ events.jsonl
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Validation (shared/scripts/validate.py)                     │
│   - Checks event types match expected-events.json           │
│   - Validates required fields exist and match patterns      │
│   - Reports pass/fail with detailed diff                    │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### "Sensor failed to start"

Check sensor log:
```bash
cat <cookbook>/output/sensor.log
```

Common causes:
- Not running as root/sudo
- Kernel too old (need 5.8+)
- BTF not available (`pahole --version`)

### "No events captured"

1. Check sensor is filtering correct process:
   ```bash
   grep "Attached to process" <cookbook>/output/sensor.log
   ```

2. Verify SSL library is loaded:
   ```bash
   lsof -p <PID> | grep libssl
   ```

3. Enable debug logging:
   ```bash
   RUST_LOG=debug ./shared/scripts/run-cookbook-test.sh python/01-openai-simple
   ```

### "Validation failed"

Events were captured but don't match expectations:

1. View captured events:
   ```bash
   cat <cookbook>/output/events.jsonl | jq .
   ```

2. Compare with expected:
   ```bash
   cat <cookbook>/expected-events.json | jq .
   ```

3. Update expected-events.json if behavior changed intentionally

## Advanced Usage

### Run with Custom Sensor Binary

```bash
export OISP_SENSOR_BIN=/path/to/custom/oisp-sensor
make test-python-01-openai-simple
```

### Debug Mode

```bash
RUST_LOG=debug ./shared/scripts/run-cookbook-test.sh python/01-openai-simple
```

### Docker Testing (Force)

```bash
./test-all.sh --docker python/01-openai-simple
```

## File Structure

```
oisp-cookbook/
├── shared/
│   └── scripts/
│       ├── discover-cookbooks.sh      # Auto-discovery
│       ├── detect-language.sh         # Language detection
│       ├── run-cookbook-test.sh       # Shared test harness
│       ├── validate.py                # Event validation
│       └── wait-for-events.sh         # Event polling
├── python/01-openai-simple/
│   ├── app.py                         # Application code
│   ├── requirements.txt               # Dependencies
│   └── expected-events.json           # Test expectations
├── node/01-openai-simple/
│   ├── index.js                       # Application code
│   ├── package.json                   # Dependencies
│   └── expected-events.json           # Test expectations
├── Makefile                           # Dynamic test targets
├── test-all.sh                        # Master test runner
└── .github/workflows/
    ├── nightly.yml                    # Nightly tests
    └── pr-validation.yml              # PR validation
```

## Performance

- **Test execution**: ~30 seconds per cookbook (sensor startup + app run + validation)
- **CI/CD runtime**: ~5 minutes for all cookbooks (parallel execution)
- **Sensor overhead**: < 3% CPU, < 50MB memory per monitored process

## See Also

- [README.md](README.md) - Cookbook overview and examples
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [shared/scripts/validate.py](shared/scripts/validate.py) - Validation schema reference
