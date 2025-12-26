# FastAPI AI Service Example

This example demonstrates a production-style [FastAPI](https://fastapi.tiangolo.com/) service that makes AI API calls. This is a common pattern for building AI-powered backends.

## What This Tests

- FastAPI async service with OpenAI integration
- Multiple API requests from a single service
- Real-world production patterns

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

## API Endpoints

The service exposes the following endpoints:

### `GET /health`

Health check endpoint.

```bash
curl http://localhost:8000/health
# {"status": "healthy"}
```

### `POST /chat`

Chat completion endpoint.

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!", "system_prompt": "You are helpful."}'
```

Response:
```json
{
  "response": "Hello! How can I assist you today?",
  "prompt_tokens": 15,
  "completion_tokens": 9,
  "total_tokens": 24
}
```

## What Gets Captured

The OISP Sensor captures all AI API calls made by the FastAPI service:

```json
{
  "event_type": "ai.request",
  "data": {
    "provider": { "name": "openai" },
    "model": { "id": "gpt-4o-mini" },
    "request_type": "chat"
  }
}
```

Each request to `/chat` generates an `ai.request` and `ai.response` event pair.

## Production Patterns Demonstrated

1. **Async/Await** - Non-blocking I/O for high concurrency
2. **Pydantic Models** - Type-safe request/response validation
3. **Dependency Injection** - OpenAI client initialized at startup
4. **Health Checks** - Kubernetes-ready health endpoint
5. **Error Handling** - Proper HTTP error responses

## Files

| File | Description |
|------|-------------|
| `app.py` | FastAPI application with chat endpoint |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | Container image definition |
| `docker-compose.yml` | Docker Compose setup with sensor |
| `expected-events.json` | Event validation schema |
| `test.sh` | CI test script |
| `Makefile` | Development commands |
