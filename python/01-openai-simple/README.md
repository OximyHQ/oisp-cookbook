# Python + OpenAI Simple

The simplest possible example: a Python script making one OpenAI API call.

## What This Tests

- Basic SSL/TLS capture
- OpenAI provider detection
- Request/response parsing
- Token usage extraction

## Prerequisites

- Docker and Docker Compose
- `OPENAI_API_KEY` environment variable

## Quick Start

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run the example
make run

# Or test it (validates captured events)
make test
```

## What Happens

1. OISP Sensor starts and attaches to the Python process
2. Python script calls OpenAI API (chat completion)
3. Sensor captures the SSL traffic
4. Events are written to `output/events.jsonl`
5. Validation checks that expected events were captured

## Expected Events

The sensor should capture:

1. **ai.request** - The outgoing request to OpenAI
   - Provider: openai
   - Model: gpt-4o-mini
   - Streaming: false

2. **ai.response** - The response from OpenAI
   - Success: true
   - Usage: token counts

## Files

| File | Purpose |
|------|---------|
| `app.py` | Simple Python script calling OpenAI |
| `requirements.txt` | Python dependencies |
| `docker-compose.yml` | App + Sensor configuration |
| `expected-events.json` | Validation rules |
| `test.sh` | CI entry point |
| `Makefile` | Local commands |

## Troubleshooting

**No events captured:**
- Check that the sensor is running with root/sudo
- Verify the Python process is using system OpenSSL
- Check `output/sensor.log` for errors

**Wrong provider detected:**
- Ensure you're calling `api.openai.com`
- Check if using a proxy that changes the domain

