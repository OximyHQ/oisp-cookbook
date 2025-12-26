# Kubernetes DaemonSet Deployment

This example demonstrates deploying OISP Sensor as a Kubernetes DaemonSet to capture AI API calls from all pods in a cluster.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                 │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Node 1    │  │   Node 2    │  │   Node 3    │  │
│  │             │  │             │  │             │  │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │  │
│  │ │ Sensor  │ │  │ │ Sensor  │ │  │ │ Sensor  │ │  │
│  │ │(DaemonSet)│ │  │ │(DaemonSet)│ │  │ │(DaemonSet)│ │  │
│  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │  │
│  │      │      │  │      │      │  │      │      │  │
│  │ ┌────▼────┐ │  │ ┌────▼────┐ │  │ ┌────▼────┐ │  │
│  │ │  Apps   │ │  │ │  Apps   │ │  │ │  Apps   │ │  │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

The DaemonSet ensures one sensor pod runs on every node, capturing AI API calls from all application pods on that node.

## Prerequisites

- Kubernetes cluster (1.21+)
- kubectl configured
- For testing: k3d (`curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`)

## Quick Start

### Deploy to Existing Cluster

```bash
# Deploy sensor DaemonSet
make deploy

# Check status
kubectl get pods -n oisp-sensor

# View captured events
kubectl exec -it -n oisp-sensor $(kubectl get pods -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -o jsonpath='{.items[0].metadata.name}') -- cat /output/events.jsonl
```

### Run Full Test with k3d

```bash
# Set your API key
export OPENAI_API_KEY=sk-...

# Run automated test (creates temporary cluster)
make test
```

## Manifest Files

| File | Description |
|------|-------------|
| `manifests/namespace.yaml` | Namespace for sensor resources |
| `manifests/configmap.yaml` | Sensor configuration |
| `manifests/daemonset.yaml` | DaemonSet deployment |
| `manifests/test-app.yaml` | Test application for validation |
| `manifests/kustomization.yaml` | Kustomize configuration |

## Configuration

The sensor is configured via ConfigMap (`manifests/configmap.yaml`):

```yaml
config.yaml: |
  output:
    format: jsonl
    path: /output/events.jsonl
  filters:
    ai_only: true
  redaction:
    enabled: false
```

## Security Context

The sensor requires privileged access for eBPF:

```yaml
securityContext:
  privileged: true
  capabilities:
    add:
      - SYS_ADMIN
      - SYS_PTRACE
      - NET_ADMIN
      - BPF
```

**Note**: Review your cluster's security policies before deploying.

## Resource Requirements

Default resource limits per sensor pod:

| Resource | Request | Limit |
|----------|---------|-------|
| Memory | 128Mi | 512Mi |
| CPU | 100m | 500m |

Adjust based on your workload in `manifests/daemonset.yaml`.

## Output Location

Events are written to `/var/log/oisp-sensor/events.jsonl` on each node. For production, consider:

1. **Persistent Volumes** - For durability
2. **Log Shipping** - Forward to Elasticsearch, Loki, etc.
3. **Remote Storage** - S3, GCS, or similar

## Troubleshooting

### Sensor not starting

```bash
# Check pod status
kubectl describe pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor

# Check logs
kubectl logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor
```

### No events captured

```bash
# Verify sensor is running
kubectl exec -it -n oisp-sensor <pod> -- oisp-sensor status

# Check if eBPF is working
kubectl exec -it -n oisp-sensor <pod> -- cat /sys/kernel/debug/tracing/trace_pipe
```

### Permission denied

Ensure your cluster allows privileged containers. For managed Kubernetes:

- **GKE**: Enable `--enable-gke-autopilot=false`
- **EKS**: Use managed node groups with appropriate permissions
- **AKS**: Disable pod security policies or configure exceptions

## Files

| File | Description |
|------|-------------|
| `manifests/` | Kubernetes manifest files |
| `expected-events.json` | Event validation schema |
| `test.sh` | Automated test script |
| `Makefile` | Development commands |
| `README.md` | This file |
