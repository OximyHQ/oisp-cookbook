# Makefile for multi-process/python-celery example

.PHONY: run test clean logs

# Run the full stack
run:
	docker compose up --build

# Run automated test
test:
	./test.sh

# Clean up
clean:
	docker compose down -v
	rm -rf output/
	rm -rf __pycache__/

# View logs
logs:
	docker compose logs -f

# View just sensor logs
sensor-logs:
	docker compose logs -f sensor

# View captured events
events:
	@cat output/events.jsonl 2>/dev/null | head -20 || echo "No events captured yet"

# Build images
build:
	docker compose build
