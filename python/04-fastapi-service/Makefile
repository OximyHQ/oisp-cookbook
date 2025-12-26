# Makefile for python/04-fastapi-service

.PHONY: run test clean docker-run docker-test help

OISP_SENSOR_BIN ?= ../../bin/oisp-sensor

help:
	@echo "FastAPI AI Service Example"
	@echo ""
	@echo "Usage:"
	@echo "  make run          Run the app with sensor (local, requires Linux)"
	@echo "  make test         Run and validate (local, requires Linux)"
	@echo "  make docker-run   Run with Docker Compose (works on macOS/Windows)"
	@echo "  make docker-test  Run and validate with Docker (works on macOS/Windows)"
	@echo "  make clean        Clean up generated files"

# Run locally with sensor (Linux only)
run:
	@echo "Running with local sensor..."
	@mkdir -p output
	@sudo $(OISP_SENSOR_BIN) record --output output/events.jsonl --no-web --process python &
	@sleep 2
	@python3 -m venv .venv 2>/dev/null || true
	@. .venv/bin/activate && pip install -q -r requirements.txt && python app.py
	@sudo pkill -f "oisp-sensor.*record" || true
	@echo ""
	@echo "Events captured:"
	@cat output/events.jsonl | head -10

# Run and validate locally (Linux only)
test:
	@chmod +x test.sh
	@./test.sh

# Run with Docker Compose (cross-platform)
docker-run:
	@docker compose up --build

# Run and validate with Docker (cross-platform)
docker-test:
	@mkdir -p output
	@docker compose up --build --abort-on-container-exit
	@python3 ../../shared/scripts/validate.py output/events.jsonl expected-events.json

# Clean up
clean:
	@rm -rf output/ .venv/
	@docker compose down -v 2>/dev/null || true
