# Makefile for kubernetes/daemonset

.PHONY: deploy test clean help

help:
	@echo "Kubernetes DaemonSet Example"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy   Deploy sensor DaemonSet to current cluster"
	@echo "  make test     Run full test with k3d cluster"
	@echo "  make clean    Clean up test cluster and resources"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - k3d (for testing): curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
	@echo "  - kubectl"
	@echo "  - OPENAI_API_KEY environment variable"

# Deploy to current cluster
deploy:
	@echo "Deploying OISP Sensor DaemonSet..."
	kubectl apply -k manifests/
	@echo ""
	@echo "Waiting for sensor to be ready..."
	kubectl wait --for=condition=Ready pods \
		-l app.kubernetes.io/name=oisp-sensor \
		-n oisp-sensor \
		--timeout=120s
	@echo ""
	@echo "Sensor deployed! Check logs with:"
	@echo "  kubectl logs -f -l app.kubernetes.io/name=oisp-sensor -n oisp-sensor"

# Run full test with k3d
test:
	@chmod +x test.sh
	@./test.sh

# Clean up
clean:
	@echo "Cleaning up..."
	@k3d cluster delete oisp-test 2>/dev/null || true
	@kubectl delete -k manifests/ 2>/dev/null || true
	@rm -rf output/
