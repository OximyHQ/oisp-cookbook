# Makefile for self-hosted/n8n

.PHONY: run test clean docker-run docker-test help

OISP_SENSOR_BIN ?= ../../bin/oisp-sensor

help:
	@echo "n8n Self-Hosted Example"
	@echo ""
	@echo "Usage:"
	@echo "  make run          Start n8n with sensor (local, requires Linux)"
	@echo "  make test         Run automated test (local, requires Linux)"
	@echo "  make docker-run   Run with Docker Compose (works on macOS/Windows)"
	@echo "  make docker-test  Run and validate with Docker (works on macOS/Windows)"
	@echo "  make clean        Clean up containers and data"

# Run interactively (local sensor - Linux only)
run:
	@echo "Starting n8n with OISP Sensor..."
	@echo ""
	@echo "Once running:"
	@echo "  1. Open http://localhost:5678"
	@echo "  2. Create a workflow with AI nodes"
	@echo "  3. Execute the workflow"
	@echo "  4. Check output/events.jsonl for captured events"
	@echo ""
	@mkdir -p output
	@docker compose up

# Run automated test (local sensor - Linux only)
test:
	@chmod +x test.sh
	@./test.sh

# Run with Docker Compose (cross-platform)
docker-run:
	@echo "Starting n8n with OISP Sensor via Docker..."
	@echo ""
	@echo "Once running:"
	@echo "  1. Open http://localhost:5678"
	@echo "  2. Create a workflow with AI nodes"
	@echo "  3. Execute the workflow"
	@echo "  4. Check output/events.jsonl for captured events"
	@echo ""
	@mkdir -p output
	@docker compose up --build

# Run and validate with Docker (cross-platform)
docker-test:
	@mkdir -p output
	@docker compose up --build --abort-on-container-exit
	@python3 ../../shared/scripts/validate.py output/events.jsonl expected-events.json

# Clean up
clean:
	@rm -rf output/
	@docker compose down -v 2>/dev/null || true
