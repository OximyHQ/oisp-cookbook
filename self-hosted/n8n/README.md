# n8n Self-Hosted + AI Monitoring

Monitor AI API calls from self-hosted n8n workflows.

## What This Tests

- Capturing AI calls from Node.js applications (n8n is Node.js based)
- SSL/TLS traffic interception via eBPF
- OpenAI API calls via the official Node.js SDK

## About n8n

[n8n](https://n8n.io/) is a workflow automation tool that supports AI nodes for OpenAI, Anthropic, and other providers. This cookbook demonstrates that OISP Sensor can capture AI API calls from n8n's Node.js runtime.

## Test Approach

The automated test uses a Node.js script that mimics n8n's OpenAI integration:
1. Uses the same OpenAI Node.js SDK that n8n uses internally
2. Runs in the same Node.js 20 LTS environment as n8n
3. Makes a chat completion request to OpenAI
4. Verifies OISP Sensor captures both request and response

**Note**: We use a direct Node.js approach rather than full n8n workflow import because:
- n8n's CLI workflow import has complex schema requirements that change between versions
- The OpenAI SDK behavior is identical whether called from n8n or standalone Node.js
- This ensures reliable, reproducible tests

## Prerequisites

- Docker
- `OPENAI_API_KEY` environment variable

## Running the Test

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run via the test runner
cd oisp-cookbook
./test-all.sh self-hosted/n8n

# Or build and run directly
docker build \
  -f self-hosted/n8n/Dockerfile.test \
  -t oisp-test-n8n:latest \
  --build-context oisp-sensor="../oisp-sensor" \
  --build-context oisp-cookbook="." \
  ..

docker run --rm --privileged \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  oisp-test-n8n:latest
```

## How It Works

1. The test container runs Ubuntu 24.04 with Node.js 20 (same as n8n)
2. OISP Sensor starts and attaches eBPF probes to the Node binary
3. A Node.js script makes an OpenAI API call
4. Sensor captures the TLS traffic and decodes the AI events
5. Events are validated against expected patterns

## Production Deployment

For monitoring actual n8n instances:

1. Deploy OISP Sensor as a sidecar alongside n8n
2. Configure sensor to attach to the n8n process
3. Events are captured as n8n executes AI workflows

```yaml
# Example docker-compose.yml
services:
  n8n:
    image: n8nio/n8n:latest
    volumes:
      - n8n_data:/home/node/.n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false

  oisp-sensor:
    image: oximy/oisp-sensor:latest
    privileged: true
    pid: "host"
    volumes:
      - ./output:/output
    command: record --output /output/events.jsonl
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.test` | Test image with Node.js and sensor |
| `expected-events.json` | Validation rules |
| `workflow.json` | Sample n8n workflow (for reference) |

## Notes

- n8n's official Docker image uses Alpine (musl libc), but our sensor requires glibc
- The test uses Ubuntu with n8n installed via npm for glibc compatibility
- The sensor captures all OpenAI SDK calls regardless of whether they originate from n8n or other Node.js code
