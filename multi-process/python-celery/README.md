# Python + Celery + OpenAI Example

This example demonstrates OISP Sensor capturing AI API calls from **multiple Celery worker processes**.

## Why This Matters

In production, AI workloads often run in:
- Celery task queues
- Multiple worker processes
- Distributed systems

OISP Sensor captures ALL OpenAI calls across all workers, regardless of which process handles the task.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OISP Sensor (eBPF)                       │
│              Captures SSL from ALL processes                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         Host                                 │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐             │
│  │ Worker 1  │   │ Worker 2  │   │ Worker 3  │  ...        │
│  │ (Celery)  │   │ (Celery)  │   │ (Celery)  │             │
│  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘             │
│        │               │               │                    │
│        └───────────────┴───────────────┘                    │
│                        │                                     │
│                   ┌────┴────┐                               │
│                   │  Redis  │                               │
│                   │ (Queue) │                               │
│                   └─────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

## What's Captured

- AI API calls from **all worker processes**
- Process attribution (which worker made which call)
- Full request/response data with token usage
- Timing information

## Prerequisites

- Docker and Docker Compose
- OpenAI API key

## Quick Start

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run the test
make test

# Or manually:
docker compose up --build
```

## Files

| File | Description |
|------|-------------|
| `app.py` | Flask app that submits Celery tasks |
| `tasks.py` | Celery tasks that call OpenAI |
| `docker-compose.yml` | Full stack (Redis + Workers + Sensor) |
| `expected-events.json` | Expected AI events for validation |
| `test.sh` | CI test script |

## Expected Output

The sensor should capture events like:

```json
{"event_type": "ai.request", "data": {"provider": {"name": "openai"}, "process": {"name": "celery", "pid": 123}}}
{"event_type": "ai.response", "data": {"usage": {"total_tokens": 50}, "process": {"pid": 123}}}
{"event_type": "ai.request", "data": {"provider": {"name": "openai"}, "process": {"name": "celery", "pid": 456}}}
{"event_type": "ai.response", "data": {"usage": {"total_tokens": 45}, "process": {"pid": 456}}}
```

Note how different PIDs show different workers handling tasks.

## Key Points

1. **eBPF captures all processes** - No code changes needed in your app
2. **Worker identification** - Each event includes the process PID
3. **No lost events** - All SSL traffic is captured at the kernel level
4. **Zero overhead** - eBPF runs in kernel space, minimal impact
