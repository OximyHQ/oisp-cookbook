#!/bin/bash
#
# Kubernetes DaemonSet Test
#
# This test creates a temporary k3d cluster, deploys the sensor DaemonSet,
# runs a test application, and validates captured AI events.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CLUSTER_NAME="oisp-test-$$"
OUTPUT_DIR="$SCRIPT_DIR/output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
EXPECTED_FILE="$SCRIPT_DIR/expected-events.json"
VALIDATE_SCRIPT="$SCRIPT_DIR/../../shared/scripts/validate.py"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2
}

cleanup() {
    log "Cleaning up..."
    k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
}

trap cleanup EXIT

log "=== Kubernetes DaemonSet Test ==="
log ""

# Prerequisites
if ! command -v k3d &> /dev/null; then
    error "k3d not found - install: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    exit 2
fi

if ! command -v kubectl &> /dev/null; then
    error "kubectl not found"
    exit 2
fi

if [ -z "$OPENAI_API_KEY" ]; then
    error "OPENAI_API_KEY not set"
    exit 2
fi

# Setup output
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE"

# Create k3d cluster
log "Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create "$CLUSTER_NAME" --wait

# Deploy manifests
log "Deploying sensor DaemonSet..."
kubectl apply -k manifests/

# Wait for sensor to be ready
log "Waiting for sensor pods..."
kubectl wait --for=condition=ready pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor --timeout=60s

# Create API key secret for test app
log "Creating API key secret..."
kubectl create secret generic openai-api-key \
    -n oisp-sensor \
    --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY"

# Deploy test application
log "Deploying test application..."
kubectl apply -f manifests/test-app.yaml

# Wait for test app to complete
log "Waiting for test app to complete..."
kubectl wait --for=condition=complete job/test-app -n oisp-sensor --timeout=120s

# Extract events from sensor pod
log "Extracting captured events..."
SENSOR_POD=$(kubectl get pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -o jsonpath='{.items[0].metadata.name}')
kubectl cp "oisp-sensor/$SENSOR_POD:/output/events.jsonl" "$EVENTS_FILE" || {
    error "Failed to extract events from sensor pod"
    kubectl logs -n oisp-sensor "$SENSOR_POD" | tail -50
    exit 1
}

# Validate events
log ""
log "Validating captured events..."
if python3 "$VALIDATE_SCRIPT" "$EVENTS_FILE" "$EXPECTED_FILE"; then
    log ""
    log "=== TEST PASSED ==="
    exit 0
else
    error ""
    error "=== TEST FAILED ==="
    error ""
    error "Captured events:"
    cat "$EVENTS_FILE" | head -20 || true
    error ""
    error "Sensor logs:"
    kubectl logs -n oisp-sensor "$SENSOR_POD" | tail -50
    exit 1
fi
