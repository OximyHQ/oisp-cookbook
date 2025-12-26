# OISP Cookbook Makefile
#
# Usage:
#   make test                    # Run all tests
#   make test-python             # Run Python tests only
#   make test-node               # Run Node.js tests only
#   make test EXAMPLE=python/01-openai-simple  # Run specific example
#
# Environment:
#   OISP_SENSOR_BIN    Path to local sensor binary (optional, downloads if not set)
#   OPENAI_API_KEY     Required for OpenAI examples
#   ANTHROPIC_API_KEY  Required for Anthropic examples

.PHONY: all test test-python test-node test-self-hosted test-kubernetes test-edge-cases docker-test-all clean download-sensor help

# Default sensor version to download
SENSOR_VERSION ?= latest

# Local sensor binary (use local build if set)
OISP_SENSOR_BIN ?= ./bin/oisp-sensor

# Examples to test
PYTHON_EXAMPLES := python/01-openai-simple python/02-litellm python/03-langchain-agent python/04-fastapi-service
NODE_EXAMPLES := node/01-openai-simple
SELF_HOSTED_EXAMPLES := self-hosted/n8n
KUBERNETES_EXAMPLES := kubernetes/daemonset
EDGE_CASE_EXAMPLES := edge-cases/nvm-node edge-cases/pyenv-python

ALL_EXAMPLES := $(PYTHON_EXAMPLES) $(NODE_EXAMPLES) $(SELF_HOSTED_EXAMPLES)

help:
	@echo "OISP Cookbook - Examples and Validation Tests"
	@echo ""
	@echo "Usage:"
	@echo "  make test                  Run all tests"
	@echo "  make test-python           Run Python tests only"
	@echo "  make test-node             Run Node.js tests only"
	@echo "  make test-self-hosted      Run self-hosted tests only"
	@echo "  make test-kubernetes       Run Kubernetes tests (requires k3d)"
	@echo "  make test-edge-cases       Run edge case diagnostic tests"
	@echo "  make docker-test-all       Run all tests in Linux Docker (for macOS/Windows)"
	@echo "  make test EXAMPLE=<path>   Run specific example"
	@echo "  make download-sensor       Download latest sensor binary"
	@echo "  make clean                 Clean up generated files"
	@echo ""
	@echo "Environment Variables:"
	@echo "  OISP_SENSOR_BIN           Path to local sensor binary"
	@echo "  OPENAI_API_KEY            Required for OpenAI examples"
	@echo "  ANTHROPIC_API_KEY         Required for Anthropic examples"

# Download sensor binary if not using local build
download-sensor:
	@if [ ! -f "$(OISP_SENSOR_BIN)" ]; then \
		echo "Downloading OISP Sensor..."; \
		./shared/scripts/download-sensor.sh $(SENSOR_VERSION); \
	else \
		echo "Using sensor binary: $(OISP_SENSOR_BIN)"; \
	fi

# Run a single example test
test-example: download-sensor
ifndef EXAMPLE
	$(error EXAMPLE is not set. Usage: make test-example EXAMPLE=python/01-openai-simple)
endif
	@echo "Testing $(EXAMPLE)..."
	@cd $(EXAMPLE) && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh

# Run all tests
test: download-sensor
	@echo "Running all tests..."
	@failed=0; \
	for example in $(ALL_EXAMPLES); do \
		echo ""; \
		echo "=== Testing $$example ==="; \
		if cd $$example && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh; then \
			echo "[PASS] $$example"; \
		else \
			echo "[FAIL] $$example"; \
			failed=1; \
		fi; \
		cd $(CURDIR); \
	done; \
	exit $$failed

# Run Python tests only
test-python: download-sensor
	@echo "Running Python tests..."
	@for example in $(PYTHON_EXAMPLES); do \
		echo "Testing $$example..."; \
		cd $$example && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh || exit 1; \
		cd $(CURDIR); \
	done

# Run Node.js tests only
test-node: download-sensor
	@echo "Running Node.js tests..."
	@for example in $(NODE_EXAMPLES); do \
		echo "Testing $$example..."; \
		cd $$example && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh || exit 1; \
		cd $(CURDIR); \
	done

# Run self-hosted tests only
test-self-hosted: download-sensor
	@echo "Running self-hosted tests..."
	@for example in $(SELF_HOSTED_EXAMPLES); do \
		echo "Testing $$example..."; \
		cd $$example && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh || exit 1; \
		cd $(CURDIR); \
	done

# Run Kubernetes tests only (requires k3d)
test-kubernetes:
	@echo "Running Kubernetes tests..."
	@echo "Note: Requires k3d to be installed"
	@for example in $(KUBERNETES_EXAMPLES); do \
		echo "Testing $$example..."; \
		cd $$example && ./test.sh || exit 1; \
		cd $(CURDIR); \
	done

# Run edge case tests (diagnostic)
test-edge-cases: download-sensor
	@echo "Running edge case diagnostic tests..."
	@echo "Note: These tests diagnose SSL linking issues"
	@for example in $(EDGE_CASE_EXAMPLES); do \
		echo "Testing $$example..."; \
		cd $$example && OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./test.sh || exit 1; \
		cd $(CURDIR); \
	done

# Run all tests in Linux Docker (for macOS/Windows development)
# IMPORTANT: Requires Linux host with kernel 5.8+ for eBPF
# On macOS Docker Desktop, this will NOT work for eBPF capture
docker-test-all:
	@echo "Building and running tests in Linux Docker..."
	@echo ""
	@echo "NOTE: This requires a Linux host with kernel 5.8+ for eBPF support."
	@echo "      Docker Desktop on macOS does NOT support eBPF uprobes."
	@echo ""
	docker build -f Dockerfile.test-runner -t oisp-test-runner ..
	docker run --rm --privileged \
		-v /sys/kernel/debug:/sys/kernel/debug:rw \
		-v /sys/fs/bpf:/sys/fs/bpf \
		-e OPENAI_API_KEY=$(OPENAI_API_KEY) \
		oisp-test-runner

# Clean up
clean:
	@echo "Cleaning up..."
	@rm -rf bin/
	@for example in $(ALL_EXAMPLES); do \
		rm -rf $$example/output/; \
		rm -rf $$example/.venv/; \
		rm -rf $$example/node_modules/; \
	done
	@echo "Done."

