# LiteLLM Example

This example demonstrates using [LiteLLM](https://github.com/BerriAI/litellm) with OISP Sensor. LiteLLM provides a unified API for 100+ LLM providers.

## What This Tests

- LiteLLM unified completion API
- OpenAI provider through LiteLLM
- Token usage tracking

## Prerequisites

- Docker and Docker Compose
- OpenAI API key

## Quick Start

### Using Docker (Recommended)

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run the example
make docker-run

# Or run with validation
make docker-test
```

### Local Development (Linux only)

```bash
# Download sensor binary
cd ../.. && make download-sensor && cd -

# Set your API key
export OPENAI_API_KEY=sk-...

# Run the test
make test
```

## What Gets Captured

The OISP Sensor captures all AI API calls made through LiteLLM:

```json
{
  "event_type": "ai.request",
  "data": {
    "provider": { "name": "openai" },
    "model": { "id": "gpt-4o-mini" },
    "request_type": "chat",
    "streaming": false
  }
}
```

```json
{
  "event_type": "ai.response",
  "data": {
    "success": true,
    "usage": {
      "prompt_tokens": 42,
      "completion_tokens": 38,
      "total_tokens": 80
    }
  }
}
```

## Why LiteLLM?

LiteLLM is a popular choice for:

1. **Multi-provider support** - Switch between OpenAI, Anthropic, Cohere, etc. with one line change
2. **Unified API** - Same interface regardless of provider
3. **Cost tracking** - Built-in token and cost tracking
4. **Fallbacks** - Automatic fallback to alternative models

OISP Sensor captures all these calls transparently, giving you visibility into your AI usage across all providers.

## Files

| File | Description |
|------|-------------|
| `app.py` | Main application using LiteLLM |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | Container image definition |
| `docker-compose.yml` | Docker Compose setup with sensor |
| `expected-events.json` | Event validation schema |
| `test.sh` | CI test script |
| `Makefile` | Development commands |
