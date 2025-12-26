#!/bin/bash
# Test script for kubernetes/daemonset
#
# This script:
# 1. Creates a local k3d cluster
# 2. Deploys the OISP sensor DaemonSet
# 3. Deploys a test app that makes OpenAI API calls
# 4. Validates captured events
#
# Requirements:
#   - k3d (https://k3d.io)
#   - kubectl
#   - OPENAI_API_KEY environment variable
#
# Note: This test creates a temporary k3d cluster and cleans up after.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
CLUSTER_NAME="oisp-test"
NAMESPACE="oisp-sensor"
OUTPUT_DIR="./output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
EXPECTED_FILE="./expected-events.json"
VALIDATE_SCRIPT="../../shared/scripts/validate.py"
WAIT_SCRIPT="../../shared/scripts/wait-for-events.sh"

# Check requirements
if ! command -v k3d &> /dev/null; then
    echo "ERROR: k3d is required but not installed"
    echo "Install: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    exit 2
fi

if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is required but not installed"
    exit 2
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY not set"
    exit 2
fi

echo "=== Kubernetes DaemonSet Test ==="
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Delete cluster
    k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Create output directory
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE"

# Create k3d cluster
echo "Creating k3d cluster..."
k3d cluster create "$CLUSTER_NAME" \
    --no-lb \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Deploy sensor
echo ""
echo "Deploying OISP Sensor DaemonSet..."
kubectl apply -k manifests/

# Wait for sensor to be ready
echo "Waiting for sensor to be ready..."
kubectl wait --for=condition=Ready pods \
    -l app.kubernetes.io/name=oisp-sensor \
    -n "$NAMESPACE" \
    --timeout=120s

# Create secret with API key
echo ""
echo "Creating OpenAI credentials secret..."
kubectl create secret generic openai-credentials \
    --from-literal=api-key="$OPENAI_API_KEY" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy test app
echo ""
echo "Deploying test app..."
kubectl apply -f manifests/test-app.yaml

# Wait for test app to complete
echo "Waiting for test app to run..."
kubectl wait --for=condition=Ready pods \
    -l app.kubernetes.io/name=test-app \
    -n "$NAMESPACE" \
    --timeout=120s

# Give it time to make the API call
sleep 10

# Get events from sensor pod
echo ""
echo "Retrieving events from sensor..."
SENSOR_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=oisp-sensor -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "$NAMESPACE" "$SENSOR_POD" -- cat /output/events.jsonl > "$EVENTS_FILE" 2>/dev/null || true

# Check if we got events
if [ ! -s "$EVENTS_FILE" ]; then
    echo "WARNING: No events captured yet, waiting longer..."
    sleep 20
    kubectl exec -n "$NAMESPACE" "$SENSOR_POD" -- cat /output/events.jsonl > "$EVENTS_FILE" 2>/dev/null || true
fi

# Show test app logs
echo ""
echo "Test app logs:"
TEST_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=test-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n "$NAMESPACE" "$TEST_POD" --tail=20 || true

# Validate events
echo ""
echo "Validating captured events..."
if [ -s "$EVENTS_FILE" ]; then
    python3 "$VALIDATE_SCRIPT" "$EVENTS_FILE" "$EXPECTED_FILE"
    RESULT=$?
else
    echo "ERROR: No events were captured"
    RESULT=1
fi

# Show summary
echo ""
if [ $RESULT -eq 0 ]; then
    echo "=== TEST PASSED ==="
else
    echo "=== TEST FAILED ==="
    echo ""
    echo "Captured events:"
    cat "$EVENTS_FILE" 2>/dev/null | head -20 || echo "(none)"
    echo ""
    echo "Sensor logs:"
    kubectl logs -n "$NAMESPACE" "$SENSOR_POD" --tail=50 || true
fi

exit $RESULT
