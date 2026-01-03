#!/usr/bin/env python3
"""
FastAPI AI Service Example.

This example demonstrates a production-style FastAPI service that makes
AI API calls. This is a common pattern for building AI-powered backends.

The OISP Sensor captures all AI API calls made by the service, providing
visibility into your AI usage in production environments.
"""

import os
import sys
import asyncio

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from openai import AsyncOpenAI
import uvicorn

# Initialize FastAPI app
app = FastAPI(
    title="AI Chat Service",
    description="A simple AI-powered chat service",
    version="1.0.0",
)

# Initialize OpenAI client
client: AsyncOpenAI = None


class ChatRequest(BaseModel):
    message: str
    system_prompt: str = "You are a helpful assistant. Keep responses brief."


class ChatResponse(BaseModel):
    response: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


@app.on_event("startup")
async def startup():
    global client
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)
    client = AsyncOpenAI(api_key=api_key)
    print("FastAPI AI Service started")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Chat endpoint that makes an AI API call.

    This is the main endpoint that OISP Sensor will capture.
    """
    try:
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": request.system_prompt},
                {"role": "user", "content": request.message},
            ],
        )

        content = response.choices[0].message.content
        usage = response.usage

        return ChatResponse(
            response=content,
            prompt_tokens=usage.prompt_tokens,
            completion_tokens=usage.completion_tokens,
            total_tokens=usage.total_tokens,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def run_test_requests():
    """Run test requests after server starts."""
    import httpx

    await asyncio.sleep(2)  # Wait for server to be ready

    print()
    print("=== Running Test Requests ===")
    print()

    # Helper function with retry logic
    async def make_request_with_retry(http_client, url, json_data, max_retries=3):
        """Make HTTP request with retry logic for timeouts."""
        for attempt in range(max_retries):
            try:
                response = await http_client.post(
                    url,
                    json=json_data,
                    timeout=60.0,  # Increased timeout
                )
                return response
            except httpx.ReadTimeout:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 5
                    print(f"  Timeout, retrying in {wait_time}s (attempt {attempt + 2}/{max_retries})...")
                    await asyncio.sleep(wait_time)
                else:
                    raise

    async with httpx.AsyncClient() as http_client:
        # Test 1: Simple chat
        print("Test 1: Simple chat request...")
        response = await make_request_with_retry(
            http_client,
            "http://localhost:8000/chat",
            {"message": "What is FastAPI? Answer in one sentence."},
        )
        data = response.json()
        print(f"  Response: {data['response'][:100]}...")
        print(f"  Tokens: {data['total_tokens']}")
        print()

        # Test 2: Custom system prompt
        print("Test 2: Custom system prompt...")
        response = await make_request_with_retry(
            http_client,
            "http://localhost:8000/chat",
            {
                "message": "Say hello",
                "system_prompt": "You are a pirate. Respond like a pirate.",
            },
        )
        data = response.json()
        print(f"  Response: {data['response'][:100]}...")
        print(f"  Tokens: {data['total_tokens']}")
        print()

    print("=== Test Requests Complete ===")
    print()

    # Signal to shut down after tests
    await asyncio.sleep(1)
    os._exit(0)


def main():
    """Main entry point."""
    print("=== FastAPI AI Service Example ===")
    print()

    # Check for API key
    if not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)

    # Start test requests in background
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # Schedule test requests
    loop.create_task(run_test_requests())

    # Run the server
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="warning",
        loop="asyncio",
    )
    server = uvicorn.Server(config)
    loop.run_until_complete(server.serve())


if __name__ == "__main__":
    main()
