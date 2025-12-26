# Makefile for edge-cases/pyenv-python

.PHONY: diagnose test clean help

help:
	@echo "pyenv Python Edge Case Example"
	@echo ""
	@echo "Usage:"
	@echo "  make diagnose   Run SSL diagnosis on current Python"
	@echo "  make test       Run full capture test"
	@echo "  make clean      Clean up output files"
	@echo ""
	@echo "This example demonstrates the pyenv static OpenSSL limitation."
	@echo "pyenv-installed Python may use statically-linked OpenSSL,"
	@echo "which cannot be intercepted by OISP Sensor."
	@echo ""
	@echo "Solutions:"
	@echo "  1. Use system Python: apt install python3"
	@echo "  2. Rebuild with shared SSL: PYTHON_CONFIGURE_OPTS=\"--enable-shared\" pyenv install 3.11"
	@echo "  3. Use Docker for testing"
	@echo "  4. Use venv with system Python"

# Run diagnosis only (no API key needed)
diagnose:
	@chmod +x diagnose.sh
	@./diagnose.sh

# Run full test (requires OPENAI_API_KEY)
test:
	@chmod +x test.sh
	@./test.sh

# Clean up
clean:
	@rm -rf output/
	@rm -rf __pycache__/
	@rm -rf .venv/
