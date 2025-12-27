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

# Dynamic targets for individual cookbooks (e.g., make test-python-01-openai-simple)
.PHONY: all test test-python test-node test-self-hosted test-kubernetes test-edge-cases docker-test-all clean download-sensor help $(addprefix test-,$(subst /,-,$(COOKBOOKS)))

# Default sensor version to download
SENSOR_VERSION ?= latest

# Local sensor binary (use local build if set)
OISP_SENSOR_BIN ?= ./bin/oisp-sensor

# Auto-discover all cookbooks (any directory with expected-events.json)
COOKBOOKS := $(shell ./shared/scripts/discover-cookbooks.sh 2>/dev/null || echo "")

# For backward compatibility, categorize by path
PYTHON_EXAMPLES := $(filter python/%,$(COOKBOOKS))
NODE_EXAMPLES := $(filter node/%,$(COOKBOOKS))
SELF_HOSTED_EXAMPLES := $(filter self-hosted/%,$(COOKBOOKS))
KUBERNETES_EXAMPLES := $(filter kubernetes/%,$(COOKBOOKS))
EDGE_CASE_EXAMPLES := $(filter edge-cases/%,$(COOKBOOKS))
MULTI_PROCESS_EXAMPLES := $(filter multi-process/%,$(COOKBOOKS))

ALL_EXAMPLES := $(COOKBOOKS)

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

# Pattern rule for individual cookbook tests (e.g., make test-python-01-openai-simple)
test-%: download-sensor
	@cookbook=$$(echo "$*" | sed 's/-/\//g'); \
	echo "Testing $$cookbook..."; \
	OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./shared/scripts/run-cookbook-test.sh "$$cookbook"

# Run a single example test (backward compatibility)
test-example: download-sensor
ifndef EXAMPLE
	$(error EXAMPLE is not set. Usage: make test-example EXAMPLE=python/01-openai-simple)
endif
	@echo "Testing $(EXAMPLE)..."
	@OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./shared/scripts/run-cookbook-test.sh "$(EXAMPLE)"

# Run all tests (strict policy - all must pass)
test: download-sensor
	@echo "Running all tests (discovered $(words $(COOKBOOKS)) cookbooks)..."
	@failed=0; \
	for cookbook in $(COOKBOOKS); do \
		echo ""; \
		echo "=== Testing $$cookbook ==="; \
		if OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./shared/scripts/run-cookbook-test.sh "$$cookbook"; then \
			echo "[PASS] $$cookbook"; \
		else \
			echo "[FAIL] $$cookbook"; \
			failed=1; \
		fi; \
	done; \
	exit $$failed

# Run Python tests only
test-python: download-sensor
	@echo "Running Python tests ($(words $(PYTHON_EXAMPLES)) cookbooks)..."
	@for cookbook in $(PYTHON_EXAMPLES); do \
		echo "Testing $$cookbook..."; \
		OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./shared/scripts/run-cookbook-test.sh "$$cookbook" || exit 1; \
	done

# Run Node.js tests only
test-node: download-sensor
	@echo "Running Node.js tests ($(words $(NODE_EXAMPLES)) cookbooks)..."
	@for cookbook in $(NODE_EXAMPLES); do \
		echo "Testing $$cookbook..."; \
		OISP_SENSOR_BIN=$(abspath $(OISP_SENSOR_BIN)) ./shared/scripts/run-cookbook-test.sh "$$cookbook" || exit 1; \
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

