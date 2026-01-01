# Contributing to OISP Cookbook

Thank you for your interest in contributing to the OISP Cookbook! This repository contains working examples that validate [OISP Sensor](https://github.com/oximyhq/sensor) functionality.

## Getting Started

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/oisp-cookbook.git
   cd oisp-cookbook
   ```

2. Create a branch from `main`:
   ```bash
   git checkout -b your-feature-branch
   ```

## Adding a New Example

Each example must be self-contained and testable. Follow this structure:

### Required Files

| File | Purpose |
|------|---------|
| `README.md` | Step-by-step instructions for running the example |
| `docker-compose.yml` | Defines the app and sensor services |
| `app.py` / `app.js` | Application code demonstrating sensor usage |
| `requirements.txt` / `package.json` | Dependencies |
| `expected-events.json` | Events the sensor MUST capture for the test to pass |
| `test.sh` | CI entry point that runs and validates the example |
| `Makefile` | Local development commands (`make run`, `make test`) |

### Directory Structure

Place your example in the appropriate category:

```
python/XX-example-name/     # Python examples
node/XX-example-name/       # Node.js examples
self-hosted/example-name/   # Self-hosted tools (n8n, etc.)
kubernetes/example-name/    # Kubernetes deployments
```

Use sequential numbering (01, 02, 03...) for language-specific examples.

### Example Template

```bash
# Create new example directory
mkdir -p python/05-your-example
cd python/05-your-example

# Copy structure from existing example
cp ../01-openai-simple/Makefile .
cp ../01-openai-simple/test.sh .
# Then customize for your use case
```

### Writing expected-events.json

Define the events your example must capture:

```json
{
  "required_events": [
    {
      "type": "llm_request",
      "provider": "openai",
      "model_pattern": "gpt-*"
    }
  ],
  "min_count": 1
}
```

### Writing test.sh

Your `test.sh` must:
1. Set up the environment
2. Run the application with the sensor
3. Validate captured events against `expected-events.json`
4. Exit with code 0 on success, non-zero on failure

## Running Tests Locally

### Prerequisites

- Docker and Docker Compose
- OISP Sensor binary (downloaded automatically or local build)
- API keys for the services your example uses

### Run a Single Example

```bash
export OPENAI_API_KEY=sk-...
cd python/01-openai-simple
make test
```

### Run All Examples

```bash
make test-all
```

### Using Local Sensor Build

```bash
export OISP_SENSOR_BIN=/path/to/oisp-sensor/target/release/oisp-sensor
make test
```

## Code Style

- Keep examples minimal and focused on demonstrating one concept
- Use clear, descriptive variable names
- Include inline comments explaining sensor-specific configuration
- Follow existing patterns in similar examples

## Pull Request Process

1. Ensure your example passes locally:
   ```bash
   cd your-example
   make test
   ```

2. Update the main README.md if adding a new example to the table

3. Create a pull request against `main`

4. Ensure CI passes - all examples run nightly and on every PR

## CI/CD

- **Nightly Tests**: All examples run every night at 2 AM UTC
- **Release Validation**: Core examples run when a new sensor version is released
- PR checks validate your changes work with the current sensor

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include:
  - Your OS and Docker version
  - Sensor version (`oisp-sensor --version`)
  - Full error output
  - Steps to reproduce

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
