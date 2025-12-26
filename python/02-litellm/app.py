#!/usr/bin/env python3
"""
LiteLLM Example - Unified API for multiple LLM providers.

This example demonstrates using LiteLLM to make API calls through a unified
interface. LiteLLM supports 100+ LLM providers with a consistent API.

The OISP Sensor captures these calls regardless of which provider is used,
since all traffic goes through standard SSL/TLS connections.
"""

import os
import sys

from litellm import completion


def main():
    # Get API key from environment
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)

    print("=== LiteLLM Example ===")
    print()

    # LiteLLM uses the model prefix to determine the provider
    # "gpt-4o-mini" -> OpenAI
    # "claude-3-haiku-20240307" -> Anthropic (if ANTHROPIC_API_KEY set)
    # "gemini/gemini-pro" -> Google (if GOOGLE_API_KEY set)

    print("Making request via LiteLLM...")
    print("Model: gpt-4o-mini (OpenAI)")
    print()

    # Make a simple chat completion request
    response = completion(
        model="gpt-4o-mini",
        messages=[
            {
                "role": "system",
                "content": "You are a helpful assistant. Keep responses brief.",
            },
            {
                "role": "user",
                "content": "What is LiteLLM and why is it useful? Answer in 2 sentences.",
            },
        ],
        api_key=api_key,
    )

    # Extract response content
    content = response.choices[0].message.content
    usage = response.usage

    print("Response:")
    print(f"  {content}")
    print()
    print(f"Usage:")
    print(f"  Input tokens:  {usage.prompt_tokens}")
    print(f"  Output tokens: {usage.completion_tokens}")
    print(f"  Total tokens:  {usage.total_tokens}")
    print()
    print("Done!")


if __name__ == "__main__":
    main()
