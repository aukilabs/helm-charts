# Reconstruction Server Helm Chart

The Reconstruction Server runs local and global refinement pipelines for scene reconstruction, pose refinement, and more.

## Chart Info

| Field | Value |
|-------|-------|
| Chart Version | 0.3.1 |
| App Version | 0.3.1 |
| Type | Application |
| Image | `aukilabs/reconstruction-node` |

## Installation

```bash
helm repo add auki https://charts.aukiverse.com
helm repo update
helm install reconstruction-server auki/reconstruction-server -f values.yaml
```

## Secret Pool — Per-Pod Credentials

The reconstruction server runs as a **StatefulSet**. Each pod needs its own unique identity (a registration secret and a secp256k1 private key). The chart's **secretPool** feature maps Kubernetes Secrets to pod ordinals so that pod `reconstruction-server-0` always reads secret `0`, pod `reconstruction-server-1` reads secret `1`, and so on.

### How It Works

When `secretPool.enabled: true`:

1. A **projected volume** mounts all secrets into a single directory tree.
2. Each Kubernetes Secret is projected into a subdirectory named by its ordinal index:
   ```
   /var/run/reconstruction-server-secrets/
   ├── 0/
   │   ├── REG_SECRET
   │   └── SECP256K1_PRIVHEX
   ├── 1/
   │   ├── REG_SECRET
   │   └── SECP256K1_PRIVHEX
   └── 2/
       ├── REG_SECRET
       └── SECP256K1_PRIVHEX
   ```
3. On startup, the pod's **entrypoint script** extracts its own ordinal from the hostname (e.g. `reconstruction-server-2` → ordinal `2`), reads the matching subdirectory, and exports `REG_SECRET` and `SECP256K1_PRIVHEX` as environment variables before launching the application.

### Step-by-Step Setup

#### 1. Create Kubernetes Secrets

Create one Secret per pod replica. Each secret **must** contain two keys: `REG_SECRET` and `SECP256K1_PRIVHEX`.

The naming convention is `<namePrefix><ordinal>`. With the default prefix `reconstruction-server-std-`, the secrets are named `reconstruction-server-std-0`, `reconstruction-server-std-1`, etc.

```bash
# Secret for pod 0
kubectl create secret generic reconstruction-server-std-0 \
  --from-literal=REG_SECRET='<your-registration-secret-0>' \
  --from-literal=SECP256K1_PRIVHEX='<your-private-key-hex-0>'

# Secret for pod 1
kubectl create secret generic reconstruction-server-std-1 \
  --from-literal=REG_SECRET='<your-registration-secret-1>' \
  --from-literal=SECP256K1_PRIVHEX='<your-private-key-hex-1>'

# Secret for pod 2
kubectl create secret generic reconstruction-server-std-2 \
  --from-literal=REG_SECRET='<your-registration-secret-2>' \
  --from-literal=SECP256K1_PRIVHEX='<your-private-key-hex-2>'
```

Or using a YAML manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: reconstruction-server-std-0
type: Opaque
stringData:
  REG_SECRET: "<your-registration-secret-0>"
  SECP256K1_PRIVHEX: "<your-private-key-hex-0>"
---
apiVersion: v1
kind: Secret
metadata:
  name: reconstruction-server-std-1
type: Opaque
stringData:
  REG_SECRET: "<your-registration-secret-1>"
  SECP256K1_PRIVHEX: "<your-private-key-hex-1>"
---
apiVersion: v1
kind: Secret
metadata:
  name: reconstruction-server-std-2
type: Opaque
stringData:
  REG_SECRET: "<your-registration-secret-2>"
  SECP256K1_PRIVHEX: "<your-private-key-hex-2>"
```

#### 2. Configure values.yaml

Enable the secret pool and set the size to match the number of secrets you created:

```yaml
replicaCount: 3

secretPool:
  enabled: true
  size: 3                                          # must be >= replicaCount
  namePrefix: "reconstruction-server-std-"         # default
  mountPath: "/var/run/reconstruction-server-secrets" # default
```

#### 3. Deploy

```bash
helm upgrade --install reconstruction-server auki/reconstruction-server \
  -f values.yaml \
  --namespace <your-namespace>
```

### Validation Rules

The chart enforces the following at render time (template-level validation):

| Rule | Error |
|------|-------|
| `secretPool.enabled` requires `secretPool.size >= 1` | `secretPool.size must be >= 1 when secretPool.enabled is true` |
| `secretPool.enabled` requires `secretPool.namePrefix` to be set | `secretPool.namePrefix must be set when secretPool.enabled is true` |
| `replicaCount` must not exceed `secretPool.size` | `replicaCount cannot exceed secretPool.size when secretPool.enabled is true` |

If a pod starts and its ordinal subdirectory is missing from the mount, the entrypoint script logs an error and exits with code 1.

### Scaling Up

To add more replicas:

1. Create the additional secret(s) first:
   ```bash
   kubectl create secret generic reconstruction-server-std-3 \
     --from-literal=REG_SECRET='<secret-3>' \
     --from-literal=SECP256K1_PRIVHEX='<key-3>'
   ```
2. Update `values.yaml`:
   ```yaml
   replicaCount: 4
   secretPool:
     size: 4
   ```
3. Re-deploy:
   ```bash
   helm upgrade reconstruction-server auki/reconstruction-server -f values.yaml
   ```

> **Important:** Always create the Kubernetes Secret *before* bumping `secretPool.size` and `replicaCount`. The secret must already exist when the pod starts, or the projected volume will fail to mount.

### Custom Name Prefix

If you want a different naming scheme (e.g. per environment), set `secretPool.namePrefix`:

```yaml
secretPool:
  enabled: true
  size: 2
  namePrefix: "recon-prod-"
```

This expects secrets named `recon-prod-0`, `recon-prod-1`, etc.

## Other Configuration

### Extra Environment Variables

Use `extraEnvMap` for non-secret environment variables. Keys are sorted alphabetically for deterministic output:

```yaml
extraEnvMap:
  LOG_LEVEL: "debug"
  SOME_FLAG: "true"
```

### envFrom (Shared Secrets / ConfigMaps)

For environment variables that are the **same across all pods** (not per-pod), use `envFrom`:

```yaml
envFrom:
  - secretRef:
      name: shared-credentials
  - configMapRef:
      name: common-config
```

### GPU / Node Scheduling

```yaml
tolerations:
  - key: "dedicated"
    value: "gpuGroup"
    effect: "NoSchedule"

nodeSelector:
  cloud.google.com/gke-accelerator: "nvidia-tesla-t4"

resources:
  limits:
    memory: 7Gi
    cpu: 8
    nvidia.com/gpu: 1
  requests:
    memory: 7Gi
    cpu: 6
    nvidia.com/gpu: 1
```

### Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    kubernetes.io/tls-acme: "true"
  path: /
  pathType: Prefix
  servicePort: app
  hosts:
    - reconstruction.example.com
  tls:
    - secretName: reconstruction-tls
      hosts:
        - reconstruction.example.com
```

### Monitoring

Enable a PodMonitor for Prometheus scraping:

```yaml
monitoring:
  namespace: monitoring
  podMonitor:
    create: true
    scrapeInterval: 10s
```

## All Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `aukilabs/reconstruction-node` | Container image repository |
| `image.tag` | string | `""` (defaults to `v<appVersion>`) | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | list | `[]` | Docker registry pull secrets |
| `replicaCount` | int | `1` | Number of StatefulSet replicas |
| `secretPool.enabled` | bool | `false` | Enable per-pod secret pool |
| `secretPool.size` | int | `0` | Number of secrets in the pool (must be ≥ `replicaCount`) |
| `secretPool.namePrefix` | string | `reconstruction-server-std-` | Prefix for secret names (`<prefix><ordinal>`) |
| `secretPool.mountPath` | string | `/var/run/reconstruction-server-secrets` | Mount path for projected secrets |
| `extraEnvMap` | map | `{}` | Extra non-secret env vars (key → value) |
| `envFrom` | list | `[]` | Additional envFrom sources (secretRef / configMapRef) |
| `apiKey` | string | `""` | *Deprecated (≤ 0.2.0)*. Use secretPool instead |
| `containerPorts.app.port` | int | `8080` | Application port |
| `containerPorts.admin.port` | int | `18190` | Admin/metrics port |
| `service.enabled` | bool | `true` | Create a Service |
| `service.ports.app.port` | int | `80` | Service port for app traffic |
| `service.ports.admin.port` | int | `18190` | Service port for admin traffic |
| `ingress.enabled` | bool | `false` | Create an Ingress |
| `monitoring.podMonitor.create` | bool | `false` | Create a PodMonitor |
| `shmSizeLimit` | string | `512Mi` | Shared memory (`/dev/shm`) size limit |
| `tolerations` | list | `[]` | Pod tolerations |
| `nodeSelector` | map | `{}` | Node selector labels |
| `affinity` | map | `{}` | Pod affinity rules |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | Override ServiceAccount name |
| `podAnnotations` | map | `{}` | Additional pod annotations |
| `podSecurityContext.fsGroup` | int | `1000` | Pod filesystem group |
| `securityContext` | map | *(drop ALL, read-only root, non-root user 1000)* | Container security context |
| `deploymentStrategy.enabled` | bool | `true` | Use explicit update strategy |
| `deploymentStrategy.type` | string | `Recreate` | StatefulSet update strategy |
