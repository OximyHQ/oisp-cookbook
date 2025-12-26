#!/usr/bin/env python3
"""
Simple OpenAI API call for testing SSL capture.

This script makes a basic chat completion request to verify
whether OISP Sensor can capture the SSL traffic.
"""

import os
import sys

# Check for pyenv
python_path = sys.executable
is_pyenv = ".pyenv" in python_path

if is_pyenv:
    print("=" * 60)
    print("WARNING: Running with pyenv Python")
    print(f"Path: {python_path}")
    print("")
    print("pyenv Python may use static OpenSSL, which cannot be")
    print("intercepted by OISP Sensor. See README.md for solutions.")
    print("=" * 60)
    print("")

# Check for API key
api_key = os.environ.get("OPENAI_API_KEY")
if not api_key:
    print("ERROR: OPENAI_API_KEY not set")
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed")
    print("Run: pip install openai")
    sys.exit(1)

print(f"Python: {sys.version}")
print(f"Executable: {python_path}")
print("")

# Make API call
print("Making OpenAI API call...")
client = OpenAI()

response = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[
        {"role": "user", "content": "Say 'pyenv test successful' in exactly 3 words."}
    ],
    max_tokens=10
)

print(f"Response: {response.choices[0].message.content}")
print("")
print("API call completed successfully!")
