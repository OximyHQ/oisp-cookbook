# Makefile for python/01-openai-simple

.PHONY: run test clean docker-run docker-test help

OISP_SENSOR_BIN ?= ../../bin/oisp-sensor

help:
	@echo "Python + OpenAI Simple Example"
	@echo ""
	@echo "Usage:"
	@echo "  make run          Run the app with sensor (local)"
	@echo "  make test         Run and validate (local)"
	@echo "  make docker-run   Run with Docker Compose"
	@echo "  make docker-test  Run and validate with Docker"
	@echo "  make clean        Clean up generated files"

# Run locally with sensor
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

# Run and validate locally
test:
	@chmod +x test.sh
	@./test.sh

# Run with Docker Compose
docker-run:
	@docker compose up --build

# Run and validate with Docker
docker-test:
	@docker compose up --build --abort-on-container-exit
	@python ../../shared/scripts/validate.py output/events.jsonl expected-events.json

# Clean up
clean:
	@rm -rf output/ .venv/
	@docker compose down -v 2>/dev/null || true

