#!/bin/bash
#
# OpenShift DaemonSet Test
#
# This test creates a temporary MicroShift environment, builds and deploys
# the sensor DaemonSet, runs a test application, and validates captured AI events.
#
# MicroShift is Red Hat's lightweight OpenShift for edge deployments and CI.
# It provides OpenShift APIs (including SCCs) in a single container.
#
# Prerequisites:
#   - docker or podman
#   - oc CLI (OpenShift client)
#   - OPENAI_API_KEY environment variable
#
# The script expects oisp-sensor repo to be available. In CI, the workflow checks
# out both repos. For local testing, set SENSOR_DIR to point to oisp-sensor.
#
# Usage:
#   export OPENAI_API_KEY=sk-...
#   ./test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
MICROSHIFT_CONTAINER="oisp-microshift-test-$$"
MICROSHIFT_IMAGE="quay.io/microshift/microshift-aio:latest"
OUTPUT_DIR="$SCRIPT_DIR/output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
EXPECTED_FILE="$SCRIPT_DIR/expected-events.json"
VALIDATE_SCRIPT="$SCRIPT_DIR/../../shared/scripts/validate.py"
KUBECONFIG_FILE="$OUTPUT_DIR/kubeconfig"

# Image name for local build
IMAGE_NAME="oisp-sensor:test-local"

# Sensor source directory (default assumes CI checkout structure)
# Override with SENSOR_DIR env var for local testing
SENSOR_DIR="${SENSOR_DIR:-$SCRIPT_DIR/../../../../oisp-sensor}"

# Container runtime (docker or podman)
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2
}

cleanup() {
    log "Cleaning up..."
    $CONTAINER_RUNTIME rm -f "$MICROSHIFT_CONTAINER" 2>/dev/null || true
    rm -f "$KUBECONFIG_FILE" 2>/dev/null || true
}

trap cleanup EXIT

log "=== OpenShift DaemonSet Test (MicroShift) ==="
log ""

# Prerequisites check
if ! command -v $CONTAINER_RUNTIME &> /dev/null; then
    # Try podman if docker not found
    if command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
    else
        error "Neither docker nor podman found"
        exit 2
    fi
fi
log "Using container runtime: $CONTAINER_RUNTIME"

if ! command -v oc &> /dev/null; then
    # Fall back to kubectl if oc not available
    if command -v kubectl &> /dev/null; then
        log "Warning: 'oc' not found, using 'kubectl' (SCC commands may not work)"
        alias oc=kubectl
    else
        error "Neither 'oc' nor 'kubectl' found"
        exit 2
    fi
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

# Setup output directory
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE"

# Build sensor image locally
log "Building sensor image from $SENSOR_DIR..."
$CONTAINER_RUNTIME build -t "$IMAGE_NAME" "$SENSOR_DIR" || {
    error "Failed to build sensor image"
    exit 1
}

# Start MicroShift container
log "Starting MicroShift container..."
$CONTAINER_RUNTIME run -d \
    --name "$MICROSHIFT_CONTAINER" \
    --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -p 6443:6443 \
    "$MICROSHIFT_IMAGE"

# Wait for MicroShift to be ready
log "Waiting for MicroShift to initialize (this may take 1-2 minutes)..."
RETRIES=60
until $CONTAINER_RUNTIME exec "$MICROSHIFT_CONTAINER" test -f /var/lib/microshift/resources/kubeadmin/kubeconfig 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
        error "MicroShift failed to initialize"
        $CONTAINER_RUNTIME logs "$MICROSHIFT_CONTAINER" --tail=50
        exit 1
    fi
    sleep 5
    echo -n "."
done
echo ""
log "MicroShift is initializing..."

# Extract kubeconfig
log "Extracting kubeconfig..."
$CONTAINER_RUNTIME cp "$MICROSHIFT_CONTAINER:/var/lib/microshift/resources/kubeadmin/kubeconfig" "$KUBECONFIG_FILE"

# Update kubeconfig to use localhost
sed -i.bak 's|server:.*|server: https://127.0.0.1:6443|g' "$KUBECONFIG_FILE" && rm -f "$KUBECONFIG_FILE.bak"

export KUBECONFIG="$KUBECONFIG_FILE"

# Wait for API server to be responsive
log "Waiting for OpenShift API server..."
RETRIES=30
until oc get nodes &>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -eq 0 ]; then
        error "OpenShift API server not responding"
        exit 1
    fi
    sleep 5
    echo -n "."
done
echo ""
log "OpenShift API server is ready"

# Import sensor image into MicroShift
log "Importing sensor image into MicroShift..."
# Save and load the image
$CONTAINER_RUNTIME save "$IMAGE_NAME" | $CONTAINER_RUNTIME exec -i "$MICROSHIFT_CONTAINER" ctr -n k8s.io images import -

# Create temporary manifests with local image
log "Generating manifests with local image..."
TEMP_DIR=$(mktemp -d)

# Copy manifests and update image
cp manifests/namespace.yaml "$TEMP_DIR/"
cp manifests/scc.yaml "$TEMP_DIR/"
cp manifests/service-account.yaml "$TEMP_DIR/"
cp manifests/configmap.yaml "$TEMP_DIR/"
cp manifests/test-app.yaml "$TEMP_DIR/"

# Update daemonset with local image
sed "s|ghcr.io/oximyhq/sensor:latest|$IMAGE_NAME|g" manifests/daemonset.yaml > "$TEMP_DIR/daemonset.yaml"
sed -i.bak 's/imagePullPolicy: Always/imagePullPolicy: Never/g' "$TEMP_DIR/daemonset.yaml" && rm -f "$TEMP_DIR/daemonset.yaml.bak"

# Deploy resources in order
log "Deploying namespace..."
oc apply -f "$TEMP_DIR/namespace.yaml"

log "Deploying SCC (requires cluster-admin)..."
oc apply -f "$TEMP_DIR/scc.yaml"

log "Deploying ServiceAccount and RBAC..."
oc apply -f "$TEMP_DIR/service-account.yaml"

log "Deploying ConfigMap..."
oc apply -f "$TEMP_DIR/configmap.yaml"

log "Deploying sensor DaemonSet..."
oc apply -f "$TEMP_DIR/daemonset.yaml"

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Wait for sensor to be ready
log "Waiting for sensor pods (timeout: 180s)..."
if ! oc wait --for=condition=ready pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor --timeout=180s; then
    error "Sensor pod failed to become ready"
    log "Pod status:"
    oc get pods -n oisp-sensor -o wide
    log "Pod description:"
    oc describe pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor
    log "Pod logs:"
    oc logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor --tail=50 || true
    log "SCC status:"
    oc get scc oisp-sensor-scc -o yaml || true
    exit 1
fi

log "Sensor pod is ready"

# Create API key secret
log "Creating API key secret..."
oc create secret generic openai-api-key \
    -n oisp-sensor \
    --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
    --dry-run=client -o yaml | oc apply -f -

# Deploy test application
log "Deploying test application..."
oc apply -f manifests/test-app.yaml

# Wait for test app to complete
log "Waiting for test app to complete (timeout: 180s)..."
if ! oc wait --for=condition=complete job/test-app -n oisp-sensor --timeout=180s; then
    error "Test app job failed or timed out"
    log "Job status:"
    oc get jobs -n oisp-sensor
    log "Pod status:"
    oc get pods -n oisp-sensor -l app.kubernetes.io/name=test-app
    log "Test app logs:"
    oc logs -n oisp-sensor -l app.kubernetes.io/name=test-app --tail=50 || true
    exit 1
fi

log "Test app completed successfully"

# Give sensor time to process captured events
log "Waiting for sensor to process events..."
sleep 10

# Extract events from sensor pod
log "Extracting captured events..."
SENSOR_POD=$(oc get pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -o jsonpath='{.items[0].metadata.name}')

if ! oc cp "oisp-sensor/$SENSOR_POD:/output/events.jsonl" "$EVENTS_FILE" 2>/dev/null; then
    log "No events file yet, checking sensor status..."

    log "Sensor logs:"
    oc logs -n oisp-sensor "$SENSOR_POD" --tail=30 || true

    log "Output directory contents:"
    oc exec -n oisp-sensor "$SENSOR_POD" -- ls -la /output/ 2>/dev/null || true

    # Create empty events file if none exists
    touch "$EVENTS_FILE"
fi

# Show what was captured
log ""
log "Events captured:"
if [ -s "$EVENTS_FILE" ]; then
    wc -l "$EVENTS_FILE"
    log "First 5 events:"
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
    oc logs -n oisp-sensor "$SENSOR_POD" --tail=50 || true
    error ""
    error "Test app logs:"
    oc logs -n oisp-sensor -l app.kubernetes.io/name=test-app --tail=30 || true
    exit 1
fi
