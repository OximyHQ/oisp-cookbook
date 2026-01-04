# OISP Cookbook

Working examples and CI validation for OISP Sensor.

## Quick Reference

```bash
# Run example locally
cd python/01-openai-simple
make run                    # Run the example
make test                   # Run with validation

# Run with local sensor build
export OISP_SENSOR_BIN=../oisp-sensor/target/release/oisp-sensor
make test

# Run CI locally with act
act -j python-01-openai-simple --secret-file .secrets

# Run all tests
make test-all
./test-all.sh
```

## Repository Structure

```
python/
├── 01-openai-simple/       # Basic OpenAI chat
└── 03-langchain-agent/     # LangChain with tools

node/
└── 01-openai-simple/       # Node.js OpenAI SDK

self-hosted/
└── n8n/                    # n8n workflow automation

edge-cases/                 # Unusual scenarios for testing

shared/scripts/
├── validate.py             # Event validation logic
├── wait-for-events.sh      # Wait for sensor output
└── download-sensor.sh      # Fetch sensor binary

.github/workflows/
├── nightly.yml             # Scheduled: all examples
└── on-sensor-release.yml   # Triggered by sensor release
```

## Each Example Contains

| File | Purpose |
|------|---------|
| `README.md` | Instructions |
| `docker-compose.yml` | App + sensor setup |
| `app.py` / `app.js` | Application code |
| `requirements.txt` / `package.json` | Dependencies |
| `expected-events.json` | Events that MUST be captured |
| `test.sh` | CI entry point |
| `Makefile` | Local commands |

## Key Concepts

**Purpose:**
1. Provide copy-paste examples for users
2. CI validation proves sensor actually works

**Validation flow:**
1. Start sensor with JSONL output
2. Run application making AI calls
3. Wait for events to appear
4. Validate against `expected-events.json`

**Linux requirement**: OISP Sensor needs eBPF, which requires native Linux kernel. Cannot run in Docker on macOS/Windows.

## Common Tasks

**Add new example:**
1. Create directory: `python/XX-name/` or `node/XX-name/`
2. Add `docker-compose.yml`, `app.py/js`, `Makefile`
3. Create `expected-events.json` with required event types
4. Add `test.sh` for CI
5. Add job to `.github/workflows/nightly.yml`

**Debug failing test:**
```bash
# Check sensor output
cat output/events.jsonl | jq .

# Run validation manually
python shared/scripts/validate.py output/events.jsonl expected-events.json
```

**Test with local sensor changes:**
```bash
# Build sensor
cd ../oisp-sensor && cargo build --release

# Use in cookbook
export OISP_SENSOR_BIN=$(pwd)/../oisp-sensor/target/release/oisp-sensor
cd python/01-openai-simple && make test
```

## Secrets

Create `.secrets` file for local testing:
```
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```
