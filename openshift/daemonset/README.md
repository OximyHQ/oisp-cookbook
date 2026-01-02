# OpenShift DaemonSet Cookbook

Deploy OISP Sensor across your OpenShift cluster to monitor AI API calls from all pods.

## Overview

**What this demonstrates:**
- OpenShift DaemonSet deployment with Security Context Constraints (SCC)
- Cluster-wide AI API monitoring
- eBPF-based SSL/TLS interception
- Event capture and validation

**Complexity:** ⭐⭐ Intermediate
**Time:** 15 minutes

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     OpenShift Cluster                           │
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  OISP Sensor     │         │  Your App Pod    │             │
│  │  (DaemonSet)     │         │                  │             │
│  │                  │  eBPF   │  Python/Node.js  │             │
│  │  - Runs on every │◄────────│  app calling     │             │
│  │    node          │ captures│  OpenAI/Anthropic│             │
│  │  - eBPF hooks    │ traffic │  APIs            │             │
│  │  - Writes to     │         │                  │             │
│  │    events.jsonl  │         │                  │             │
│  └──────────────────┘         └──────────────────┘             │
│           │                            │                        │
│           │                            │ HTTPS                  │
│           ▼                            ▼                        │
│    /var/log/oisp-sensor/        api.openai.com                  │
│    events.jsonl                 api.anthropic.com               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

The sensor:
1. Deploys on every node as a DaemonSet
2. Uses eBPF to intercept SSL/TLS traffic (without decryption keys)
3. Detects AI API calls to 20+ providers
4. Captures request/response events in JSONL format

## Prerequisites

- **OpenShift 4.x** / **OKD 4.x** / **MicroShift**
- **Cluster admin access** (required for SCC)
- **Linux nodes** with kernel 5.8+ and BTF support
- **oc CLI** (OpenShift client)

## Quick Deploy

### 1. Clone the repository

```bash
git clone https://github.com/oximyhq/oisp-cookbook.git
cd oisp-cookbook/openshift/daemonset
```

### 2. Deploy with Kustomize

```bash
# Deploy all resources (requires cluster-admin for SCC)
oc apply -k manifests/
```

### 3. Verify deployment

```bash
# Check sensor pods are running
oc get pods -n oisp-sensor

# Check SCC is applied
oc get scc oisp-sensor-scc

# View sensor logs
oc logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor
```

### 4. Test with a sample workload

```bash
# Create API key secret
oc create secret generic openai-api-key \
  -n oisp-sensor \
  --from-literal=OPENAI_API_KEY="sk-..."

# Deploy test application
oc apply -f manifests/test-app.yaml

# Wait for completion
oc wait --for=condition=complete job/test-app -n oisp-sensor --timeout=180s

# View captured events
oc exec -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -- \
  cat /output/events.jsonl | head -10
```

## Manual Deployment (Step by Step)

If you prefer to apply resources individually:

```bash
# 1. Create namespace
oc apply -f manifests/namespace.yaml

# 2. Create SCC (requires cluster-admin)
oc apply -f manifests/scc.yaml

# 3. Create ServiceAccount and RBAC
oc apply -f manifests/service-account.yaml

# 4. Create ConfigMap
oc apply -f manifests/configmap.yaml

# 5. Deploy DaemonSet
oc apply -f manifests/daemonset.yaml
```

## Files Included

| File | Description |
|------|-------------|
| `manifests/namespace.yaml` | Creates `oisp-sensor` namespace |
| `manifests/scc.yaml` | Security Context Constraint for eBPF access |
| `manifests/service-account.yaml` | ServiceAccount and RBAC permissions |
| `manifests/configmap.yaml` | Sensor configuration |
| `manifests/daemonset.yaml` | DaemonSet deployment |
| `manifests/test-app.yaml` | Test Job for validation |
| `manifests/kustomization.yaml` | Kustomize configuration |
| `expected-events.json` | Event validation rules |
| `test.sh` | CI test script (MicroShift) |

## OpenShift-Specific: Security Context Constraints

OpenShift uses SCCs instead of PodSecurityPolicies. The sensor requires privileged access for eBPF:

```yaml
# Key SCC settings (see manifests/scc.yaml)
allowPrivilegedContainer: true
allowHostPID: true
allowHostNetwork: true
allowedCapabilities:
  - SYS_ADMIN    # eBPF program loading
  - SYS_PTRACE   # uprobe attachment
  - NET_ADMIN    # Network inspection
  - BPF          # eBPF operations
  - PERFMON      # Performance monitoring
```

### Verifying SCC Assignment

```bash
# Check which SCC the sensor pod is using
oc get pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor \
  -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}'
# Expected: oisp-sensor-scc

# Describe the SCC
oc describe scc oisp-sensor-scc
```

## Expected Events

When an application makes an AI API call, the sensor captures:

**ai.request:**
```json
{
  "event_type": "ai.request",
  "ts": "2024-12-26T14:32:15.123456Z",
  "data": {
    "provider": {"name": "openai"},
    "model": {"id": "gpt-4o-mini"},
    "request_type": "chat",
    "messages": [{"role": "user", "content": "..."}]
  }
}
```

**ai.response:**
```json
{
  "event_type": "ai.response",
  "ts": "2024-12-26T14:32:16.456789Z",
  "data": {
    "success": true,
    "usage": {
      "prompt_tokens": 15,
      "completion_tokens": 18,
      "total_tokens": 33
    }
  }
}
```

## Supported AI Providers

The sensor auto-detects calls to:

- OpenAI (api.openai.com)
- Anthropic (api.anthropic.com)
- Azure OpenAI (*.openai.azure.com)
- Google AI (generativelanguage.googleapis.com)
- AWS Bedrock (bedrock-runtime.*.amazonaws.com)
- Cohere, Mistral, Groq, Together, Fireworks
- Ollama, LM Studio, vLLM (self-hosted)
- And 10+ more...

## Troubleshooting

### SCC Not Applied

```bash
# Error: pods "oisp-sensor-xxx" is forbidden: unable to validate against any security context constraint

# Solution: Ensure SCC is created and ServiceAccount is bound
oc get scc oisp-sensor-scc
oc get sa -n oisp-sensor oisp-sensor

# Re-apply SCC with cluster-admin
oc login -u kubeadmin
oc apply -f manifests/scc.yaml
```

### Sensor Pod Not Starting

```bash
# Check pod events
oc describe pod -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor

# Check logs
oc logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor

# Common issues:
# - Node doesn't have BTF support (kernel too old)
# - SELinux blocking eBPF (should be handled by SCC)
# - Missing host volumes
```

### No Events Captured

```bash
# 1. Check sensor is running
oc get pods -n oisp-sensor

# 2. Check sensor logs for errors
oc logs -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor | tail -50

# 3. Verify test app ran successfully
oc get jobs -n oisp-sensor
oc logs -n oisp-sensor -l app.kubernetes.io/name=test-app

# 4. Check output directory
oc exec -n oisp-sensor -l app.kubernetes.io/name=oisp-sensor -- ls -la /output/
```

### SELinux Issues

```bash
# Check for SELinux denials (on node)
ausearch -m avc -ts recent | grep oisp

# The SCC should handle this, but if issues persist:
# - Verify seLinuxContext: type: RunAsAny in SCC
# - Check node SELinux mode: getenforce
```

## CI Testing

The cookbook includes automated testing using MicroShift:

```bash
# Run test (requires docker/podman and OPENAI_API_KEY)
export OPENAI_API_KEY=sk-...
./test.sh
```

The test:
1. Starts a MicroShift container
2. Builds and imports the sensor image
3. Deploys all manifests
4. Runs the test application
5. Validates captured events
6. Cleans up

## Production Considerations

### Event Export

For production, configure remote export instead of local files:

```yaml
# In configmap.yaml, add OTLP export:
export:
  otlp:
    endpoint: "otel-collector.monitoring:4317"
    insecure: true
```

### Resource Limits

Adjust based on your workload:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Node Selector

To run only on specific nodes:

```yaml
nodeSelector:
  node-role.kubernetes.io/worker: ""
```

## Cleanup

```bash
# Remove all resources
oc delete -k manifests/

# Or individually
oc delete daemonset -n oisp-sensor oisp-sensor
oc delete scc oisp-sensor-scc
oc delete namespace oisp-sensor
```

## Next Steps

- [Kubernetes DaemonSet](../kubernetes/daemonset/) - Standard Kubernetes deployment
- [Python OpenAI Simple](../python/01-openai-simple/) - Application-level example
- [OISP Sensor Documentation](https://docs.oisp.dev) - Full documentation
