# OISP Cookbook

> Working examples and validation tests for [OISP Sensor](https://github.com/oximyhq/sensor)

[![Nightly Tests](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml/badge.svg)](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml)
[![Release Validation](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/on-sensor-release.yml/badge.svg)](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/on-sensor-release.yml)

## Purpose

This repository serves two purposes:

1. **Examples** - Working code you can copy and adapt
2. **Validation** - Nightly CI proves the sensor actually works

Every example here is tested automatically. If the badge is green, it works.

## Examples

| Example | Status | Description |
|---------|:------:|-------------|
| [python/01-openai-simple](./python/01-openai-simple) | [![Python OpenAI](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml/badge.svg?branch=main&job=python-01-openai-simple)](https://github.com/oximyHQ/oisp-cookbook/actions) | Basic OpenAI chat completion |
| [python/03-langchain-agent](./python/03-langchain-agent) | [![LangChain](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml/badge.svg?branch=main&job=python-03-langchain-agent)](https://github.com/oximyHQ/oisp-cookbook/actions) | LangChain agent with tool calls |
| [node/01-openai-simple](./node/01-openai-simple) | [![Node OpenAI](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml/badge.svg?branch=main&job=node-01-openai-simple)](https://github.com/oximyHQ/oisp-cookbook/actions) | Node.js OpenAI SDK |
| [self-hosted/n8n](./self-hosted/n8n) | [![n8n](https://github.com/oximyHQ/oisp-cookbook/actions/workflows/nightly.yml/badge.svg?branch=main&job=self-hosted-n8n)](https://github.com/oximyHQ/oisp-cookbook/actions) | n8n workflow automation |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- OISP Sensor binary (downloaded automatically, or use local build)

### Run an Example

```bash
# Clone the repo
git clone https://github.com/oximyHQ/oisp-cookbook.git
cd oisp-cookbook

# Set your API key
export OPENAI_API_KEY=sk-...

# Run an example
cd python/01-openai-simple
make run

# Or test it (validates captured events)
make test
```

### Using a Local Sensor Build

```bash
# Build sensor locally
cd ../oisp-sensor
cargo build --release

# Use local binary in cookbook
cd ../oisp-cookbook
export OISP_SENSOR_BIN=../oisp-sensor/target/release/oisp-sensor
make test
```

## Local Development with `act`

Run GitHub Actions locally using [act](https://github.com/nektos/act):

```bash
# Create secrets file
cat > .secrets << EOF
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
EOF

# Run specific job
act -j python-01-openai-simple --secret-file .secrets

# Run all tests
act -j test-matrix --secret-file .secrets
```

## Verification Status

> **Important**: OISP Sensor requires **native Linux** with eBPF support. It cannot run in Docker on macOS/Windows.

| What | Status | Notes |
|------|:------:|-------|
| Python + OpenAI | CI | Runs nightly on Ubuntu |
| Python + LangChain | CI | Agent with tool calls |
| Node.js + OpenAI | CI | Uses system OpenSSL |
| n8n Self-Hosted | CI | Workflow automation |
| NVM/pyenv support | Manual | Requires binary path config |
| Docker (on Linux) | Manual | eBPF works with privileged mode |

## Directory Structure

```
oisp-cookbook/
├── .github/workflows/
│   ├── nightly.yml           # Scheduled: all examples
│   └── on-sensor-release.yml # Triggered by sensor release
├── shared/
│   └── scripts/
│       ├── validate.py       # Event validation logic
│       ├── wait-for-events.sh
│       └── download-sensor.sh
├── python/
│   ├── 01-openai-simple/     # Basic OpenAI
│   └── 03-langchain-agent/   # LangChain agent
├── node/
│   └── 01-openai-simple/     # Node.js OpenAI
├── self-hosted/
│   └── n8n/                  # n8n workflow automation
└── Makefile
```

## Each Example Contains

| File | Purpose |
|------|---------|
| `README.md` | Step-by-step instructions |
| `docker-compose.yml` | App + Sensor together |
| `app.py` / `app.js` | Application code |
| `requirements.txt` / `package.json` | Dependencies |
| `expected-events.json` | Events that MUST be captured |
| `test.sh` | CI entry point |
| `Makefile` | Local commands |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to add new examples.

## License

Apache 2.0 - See [LICENSE](./LICENSE)

