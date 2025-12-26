#!/usr/bin/env python3
"""
Simple OpenAI API call for OISP testing.

This makes a single, non-streaming chat completion request.
"""

import os
import sys

from openai import OpenAI


def main():
    # Get API key from environment
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set")
        sys.exit(1)

    print("Creating OpenAI client...")
    client = OpenAI(api_key=api_key)

    print("Making chat completion request...")
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Say 'Hello OISP!' and nothing else."},
        ],
        max_tokens=50,
    )

    # Print response
    content = response.choices[0].message.content
    print(f"Response: {content}")

    # Print usage
    usage = response.usage
    print(f"Tokens - Input: {usage.prompt_tokens}, Output: {usage.completion_tokens}, Total: {usage.total_tokens}")

    print("Done!")


if __name__ == "__main__":
    main()

