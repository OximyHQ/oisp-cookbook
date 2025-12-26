# Python + LangChain Agent

A LangChain agent example demonstrating tool calling and multi-turn conversations.

## What This Tests

- Agent-based tool calling
- Multi-turn conversation tracking
- Tool call and result events
- Request/response correlation across turns

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
2. LangChain agent is invoked with a question that requires tool use
3. Agent calls a mock calculator tool
4. Sensor captures all API calls and tool interactions
5. Events are written to `output/events.jsonl`
6. Validation checks that expected events were captured

## Expected Events

The sensor should capture:

1. **ai.request** - Initial request with tool definitions
2. **ai.response** - Response with tool call
3. **ai.request** - Follow-up request with tool result
4. **ai.response** - Final response with answer

## Files

| File | Purpose |
|------|---------|
| `app.py` | LangChain agent with tools |
| `requirements.txt` | Python dependencies |
| `docker-compose.yml` | App + Sensor configuration |
| `expected-events.json` | Validation rules |
| `test.sh` | CI entry point |
| `Makefile` | Local commands |
