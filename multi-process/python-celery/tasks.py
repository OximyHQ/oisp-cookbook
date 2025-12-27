"""
Celery tasks that make OpenAI API calls.

Each task runs in a separate worker process - OISP captures all of them.
"""

import os
from celery import Celery
from openai import OpenAI

# Configure Celery with Redis
app = Celery(
    'tasks',
    broker=os.environ.get('CELERY_BROKER_URL', 'redis://localhost:6379/0'),
    backend=os.environ.get('CELERY_RESULT_BACKEND', 'redis://localhost:6379/0'),
)

# Celery config
app.conf.update(
    task_serializer='json',
    result_serializer='json',
    accept_content=['json'],
    task_track_started=True,
    worker_prefetch_multiplier=1,  # Process one task at a time for demo
)


@app.task(bind=True)
def ai_summarize(self, text: str) -> dict:
    """
    Summarize text using OpenAI.

    This task might be handled by any worker process.
    OISP captures the API call regardless of which worker runs it.
    """
    client = OpenAI()

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "Summarize the following text in one sentence."},
            {"role": "user", "content": text},
        ],
        max_tokens=100,
    )

    return {
        "summary": response.choices[0].message.content,
        "tokens": response.usage.total_tokens,
        "worker_pid": os.getpid(),
        "task_id": self.request.id,
    }


@app.task(bind=True)
def ai_classify(self, text: str) -> dict:
    """
    Classify text sentiment using OpenAI.

    Another task type that runs on Celery workers.
    """
    client = OpenAI()

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "Classify the sentiment as: positive, negative, or neutral. Reply with just the classification."},
            {"role": "user", "content": text},
        ],
        max_tokens=10,
    )

    return {
        "sentiment": response.choices[0].message.content.strip().lower(),
        "tokens": response.usage.total_tokens,
        "worker_pid": os.getpid(),
        "task_id": self.request.id,
    }
