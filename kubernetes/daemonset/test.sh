#!/bin/bash
#
# Kubernetes DaemonSet Test
#
# This test creates a temporary k3d cluster, builds and deploys the sensor DaemonSet,
# runs a test application, and validates captured AI events.
#
# Prerequisites:
#   - k3d: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
#   - kubectl
#   - docker
#   - OPENAI_API_KEY environment variable
#
# The script expects oisp-sensor repo to be available. In CI, the workflow checks
# out both repos. For local testing, set SENSOR_DIR to point to oisp-sensor.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CLUSTER_NAME="oisp-test-$$"
OUTPUT_DIR="$SCRIPT_DIR/output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
EXPECTED_FILE="$SCRIPT_DIR/expected-events.json"
VALIDATE_SCRIPT="$SCRIPT_DIR/../../shared/scripts/validate.py"

# Image name for local build
IMAGE_NAME="oisp-sensor:test-local"

# Sensor source directory (default assumes CI checkout structure)
# Override with SENSOR_DIR env var for local testing
SENSOR_DIR="${SENSOR_DIR:-$SCRIPT_DIR/../../../../oisp-sensor}"

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

if ! command -v docker &> /dev/null; then
    error "docker not found"
    exit 2
fi

if [ -z "$OPENAI_API_KEY" ]; then
    error "OPENAI_API_KEY not set"
    exit 2
fi

# Check sensor source exists
if [ ! -d "$SENSOR_DIR" ]; then
    error "Sensor source not found at: $SENSOR_DIR"
    error "Set SENSOR_DIR environment variable to point to oisp-sensor checkout"
    exit 2
fi

if [ ! -f "$SENSOR_DIR/Dockerfile" ]; then
    error "Dockerfile not found in sensor directory: $SENSOR_DIR/Dockerfile"
    exit 2
fi

# Setup output
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE"

# Build sensor image locally
log "Building sensor image from $SENSOR_DIR..."
docker build -t "$IMAGE_NAME" "$SENSOR_DIR" || {
    error "Failed to build sensor image"
    exit 1
}

# Create k3d cluster
log "Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create "$CLUSTER_NAME" --wait

# Import the locally built image into k3d
log "Importing sensor image into k3d cluster..."
k3d image import "$IMAGE_NAME" -c "$CLUSTER_NAME"

# Create a temporary daemonset.yaml with our local image
log "Generating DaemonSet manifest with local image..."
TEMP_DAEMONSET=$(mktemp)
sed "s|ghcr.io/oximyhq/oisp-sensor:latest|$IMAGE_NAME|g" manifests/daemonset.yaml > "$TEMP_DAEMONSET"
# Also change imagePullPolicy to Never since we imported locally
sed -i.bak 's/imagePullPolicy: Always/imagePullPolicy: Never/g' "$TEMP_DAEMONSET" && rm -f "$TEMP_DAEMONSET.bak"

# Deploy namespace and configmap first
log "Deploying namespace and config..."
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/configmap.yaml

# Deploy the modified daemonset
log "Deploying sensor DaemonSet..."
kubectl apply -f "$TEMP_DAEMONSET"
rm -f "$TEMP_DAEMONSET"

# Wait for sensor to be ready
log "Waiting for sensor pods (timeout: 120s)..."
if ! kubectl wait --for=condition=ready pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor --timeout=120s; then
    error "Sensor pod failed to become ready"
    log "Pod status:"
    kubectl get pods -n oisp-sensor -o wide
    log "Pod description:"
    kubectl describe pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor
    log "Pod logs:"
    kubectl logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor --tail=50 || true
    exit 1
fi

log "Sensor pod is ready"

# Create API key secret for test app
log "Creating API key secret..."
kubectl create secret generic openai-api-key \
    -n oisp-sensor \
    --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY"

# Deploy test application
log "Deploying test application..."
kubectl apply -f manifests/test-app.yaml

# Wait for test app to complete
log "Waiting for test app to complete (timeout: 180s)..."
if ! kubectl wait --for=condition=complete job/test-app -n oisp-sensor --timeout=180s; then
    error "Test app job failed or timed out"
    log "Job status:"
    kubectl get jobs -n oisp-sensor
    log "Pod status:"
    kubectl get pods -n oisp-sensor -l app.kubernetes.io/name=test-app
    log "Test app logs:"
    kubectl logs -n oisp-sensor -l app.kubernetes.io/name=test-app --tail=50 || true
    exit 1
fi

log "Test app completed successfully"

# Give sensor time to process captured events
log "Waiting for sensor to process events..."
sleep 10

# Extract events from sensor pod
log "Extracting captured events..."
SENSOR_POD=$(kubectl get pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -o jsonpath='{.items[0].metadata.name}')

# Events are written to hostPath /var/log/oisp-sensor on the node
# The sensor writes to /output which maps to this hostPath
# We need to copy from the pod's /output mount
if ! kubectl cp "oisp-sensor/$SENSOR_POD:/output/events.jsonl" "$EVENTS_FILE" 2>/dev/null; then
    log "No events file yet, checking if sensor is capturing..."

    # Check sensor logs for any errors
    log "Sensor logs:"
    kubectl logs -n oisp-sensor "$SENSOR_POD" --tail=30 || true

    # Try to list what's in the output directory
    log "Output directory contents:"
    kubectl exec -n oisp-sensor "$SENSOR_POD" -- ls -la /output/ 2>/dev/null || true

    # Create empty events file if none exists
    touch "$EVENTS_FILE"
fi

# Show what was captured
log ""
log "Events captured:"
if [ -s "$EVENTS_FILE" ]; then
    wc -l "$EVENTS_FILE"
    head -5 "$EVENTS_FILE"
else
    log "No events captured (file is empty)"
fi

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
    cat "$EVENTS_FILE" 2>/dev/null | head -20 || echo "(no events)"
    error ""
    error "Sensor logs:"
    kubectl logs -n oisp-sensor "$SENSOR_POD" --tail=50 || true
    error ""
    error "Test app logs:"
    kubectl logs -n oisp-sensor -l app.kubernetes.io/name=test-app --tail=30 || true
    exit 1
fi
