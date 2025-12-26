# n8n Self-Hosted + AI Monitoring

Monitor AI API calls from self-hosted n8n workflows.

## What This Tests

- Capturing AI calls from n8n workflows
- SSL/TLS traffic from Node.js runtime (n8n is Node.js based)
- OpenAI integration via n8n's built-in AI nodes

## Prerequisites

- Docker and Docker Compose
- `OPENAI_API_KEY` environment variable

## Quick Start

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Start n8n with sensor
make run

# Access n8n at http://localhost:5678
# Create a workflow with an AI node and execute it
# Events are captured in output/events.jsonl
```

## How It Works

1. n8n runs in a container alongside OISP Sensor
2. When you execute workflows with AI nodes (OpenAI, Anthropic, etc.)
3. Sensor captures the API calls via SSL interception
4. Events are written to `output/events.jsonl`

## Testing

The automated test:
1. Starts n8n with OISP Sensor
2. Imports a pre-built workflow via n8n API
3. Executes the workflow
4. Validates captured AI events

```bash
make test
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | n8n + Sensor configuration |
| `workflow.json` | Pre-built n8n workflow |
| `expected-events.json` | Validation rules |
| `test.sh` | CI entry point |
| `Makefile` | Local commands |

## Notes

- n8n uses Node.js with system OpenSSL in the official Docker image
- The sensor can capture AI calls from any n8n AI node
- For production, deploy sensor as a sidecar or DaemonSet
