#!/usr/bin/env python3
"""
Submit Celery tasks and wait for results.

This script:
1. Submits multiple tasks to Celery
2. Waits for all results
3. Prints which worker handled each task

OISP Sensor captures the OpenAI calls from ALL workers.
"""

import time
from tasks import ai_summarize, ai_classify

def main():
    print("Submitting tasks to Celery workers...")
    print()

    # Sample texts to process
    texts = [
        "The quick brown fox jumps over the lazy dog. This is a test sentence.",
        "I absolutely love this product! It exceeded all my expectations.",
        "The weather today is cloudy with a chance of rain.",
        "This is the worst experience I've ever had. Never again.",
    ]

    # Submit tasks
    results = []
    for i, text in enumerate(texts):
        if i % 2 == 0:
            # Summarize task
            result = ai_summarize.delay(text)
            results.append(("summarize", result, text[:50]))
        else:
            # Classify task
            result = ai_classify.delay(text)
            results.append(("classify", result, text[:50]))

    print(f"Submitted {len(results)} tasks")
    print()

    # Wait for results with timeout
    print("Waiting for results...")
    timeout = 60  # seconds
    start = time.time()

    completed = []
    for task_type, result, text_preview in results:
        try:
            output = result.get(timeout=timeout)
            completed.append((task_type, output, text_preview))
            print(f"  [{task_type}] Worker PID {output['worker_pid']}: {output.get('summary', output.get('sentiment', 'done'))[:50]}")
        except Exception as e:
            print(f"  [{task_type}] FAILED: {e}")

    elapsed = time.time() - start
    print()
    print(f"Completed {len(completed)}/{len(results)} tasks in {elapsed:.1f}s")
    print()

    # Summary
    total_tokens = sum(r[1].get('tokens', 0) for r in completed)
    unique_workers = len(set(r[1]['worker_pid'] for r in completed))

    print("Summary:")
    print(f"  Total tokens used: {total_tokens}")
    print(f"  Unique workers: {unique_workers}")
    print()
    print("OISP Sensor captured all these API calls regardless of which worker handled them!")


if __name__ == "__main__":
    main()
