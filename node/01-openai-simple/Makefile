# Makefile for node/01-openai-simple

.PHONY: run test clean docker-run docker-test help

OISP_SENSOR_BIN ?= ../../bin/oisp-sensor

help:
	@echo "Node.js + OpenAI Simple Example"
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
	@sudo $(OISP_SENSOR_BIN) record --output output/events.jsonl --no-web --process node &
	@sleep 2
	@npm install 2>/dev/null || true
	@node index.js
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
	@python3 ../../shared/scripts/validate.py output/events.jsonl expected-events.json

# Clean up
clean:
	@rm -rf output/ node_modules/
	@docker compose down -v 2>/dev/null || true
