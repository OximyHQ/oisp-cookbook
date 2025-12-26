# Makefile for edge-cases/nvm-node

.PHONY: diagnose test clean help

help:
	@echo "NVM Node.js Edge Case Example"
	@echo ""
	@echo "Usage:"
	@echo "  make diagnose   Run SSL diagnosis on current Node.js"
	@echo "  make test       Run full capture test"
	@echo "  make clean      Clean up output files"
	@echo ""
	@echo "This example demonstrates the NVM static OpenSSL limitation."
	@echo "NVM-installed Node.js typically uses statically-linked OpenSSL,"
	@echo "which cannot be intercepted by OISP Sensor."
	@echo ""
	@echo "Solutions:"
	@echo "  1. Use system Node.js: apt install nodejs"
	@echo "  2. Rebuild with shared SSL: nvm install 20 --shared-openssl"
	@echo "  3. Use Docker for testing"

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
	@rm -rf node_modules/
	@rm -f package-lock.json
