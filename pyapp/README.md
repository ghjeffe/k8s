# pyapp

A Python Flask microservice deployed to Kubernetes with Istio service mesh integration and CI/CD via GitHub Actions.

## Project Structure

```
pyapp/
├── app.py                  # Flask application (gunicorn, port 8080)
├── Dockerfile              # Container image (python:3.12-slim)
├── requirements.txt        # Python dependencies (flask, gunicorn)
├── chart/                  # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── istio.yaml          # Gateway + VirtualService
│       └── peer-authentication.yaml  # mTLS policy
├── scripts/                # Self-hosted GitHub Actions runner
└── README.md
```

## Application Endpoints

| Endpoint        | Description                              |
|-----------------|------------------------------------------|
| `/`             | Greeting with service name and version   |
| `/health/live`  | Liveness probe                           |
| `/health/ready` | Readiness probe                          |
| `/info`         | Pod metadata (IP, node, hostname)        |

## Architecture

```
Client → Istio IngressGateway → [mTLS] → Envoy Sidecar (istio-proxy) → pyapp (:8080)
```

- Envoy sidecars are automatically injected via the `istio-injection=enabled` namespace label.
- All pod-to-pod traffic is encrypted with STRICT mTLS via PeerAuthentication.
- The Helm chart uses `{{ .Release.Namespace }}` so the deployment namespace is controlled by the `-n` flag.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [istioctl](https://istio.io/latest/docs/setup/getting-started/#download)

### System Tuning (required for multiple kind clusters)

```bash
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# Persist across reboots
echo 'fs.inotify.max_user_watches = 524288' | sudo tee -a /etc/sysctl.d/99-kind.conf
echo 'fs.inotify.max_user_instances = 512' | sudo tee -a /etc/sysctl.d/99-kind.conf
```

## Environment Setup

### 1. Create kind clusters

Each cluster is created with `extraPortMappings` so the Istio ingress gateway is permanently accessible on localhost without port-forwarding. Config files are in `../scripts/kind/`.

```bash
kind create cluster --name learning --config ../scripts/kind/kind-learning.yaml
kind create cluster --name dev      --config ../scripts/kind/kind-dev.yaml
kind create cluster --name uat      --config ../scripts/kind/kind-uat.yaml
```

| Cluster  | HTTP port | HTTPS port | Config file                |
|----------|-----------|------------|----------------------------|
| learning | 8081      | 8444       | `scripts/kind/kind-learning.yaml` |
| dev      | 8082      | 8445       | `scripts/kind/kind-dev.yaml`      |
| uat      | 8083      | 8446       | `scripts/kind/kind-uat.yaml`      |

### 2. Install Istio on each cluster

```bash
istioctl install --context kind-learning --set profile=demo -y
istioctl install --context kind-dev --set profile=demo -y
istioctl install --context kind-uat --set profile=demo -y
```

### 3. Enable permanent ingress access

Patch each ingress gateway to bind its HTTP port (8080) to the host via `hostPort`. This connects the kind `extraPortMappings` to the gateway:

```bash
for ctx in kind-learning kind-dev kind-uat; do
  kubectl --context $ctx patch deployment istio-ingressgateway -n istio-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/ports/1/hostPort","value":80},
         {"op":"add","path":"/spec/template/spec/containers/0/ports/2/hostPort","value":443}]'
done
```

### 4. Create namespaces with sidecar injection

```bash
for ctx in kind-learning kind-dev kind-uat; do
  kubectl --context $ctx create namespace pyapp
  kubectl --context $ctx label namespace pyapp istio-injection=enabled
done
```

### 5. Configure local DNS

```bash
sudo ../scripts/kind-dns-setup.sh
```

This discovers all kind clusters and updates `/etc/hosts` with entries like `pyapp.dev.local`. Re-run after creating or recreating clusters. Use `--clean` to remove entries.

## Manual Deployment

### Build and load the image

```bash
docker build -t pyapp:1.3.0 .
kind load docker-image pyapp:1.3.0 --name dev
```

### Deploy with Helm

```bash
helm install pyapp ./chart \
  -n pyapp \
  --set image.tag=1.3.0 \
  --set istio.gateway.hosts[0]=pyapp.dev.local
```

### Upgrade an existing release

```bash
# Rebuild with new tag
docker build -t pyapp:1.4.0 .
kind load docker-image pyapp:1.4.0 --name dev

# Upgrade
helm upgrade pyapp ./chart \
  -n pyapp \
  --set image.tag=1.4.0 \
  --set istio.gateway.hosts[0]=pyapp.dev.local
```

### Uninstall

```bash
helm uninstall pyapp -n pyapp
```

## CI/CD

A GitHub Actions workflow (`.github/workflows/deploy-to-kind.yml`) automates the build and deploy process using a self-hosted runner.

### Branch-to-cluster mapping

| Branch            | Cluster    | Context        |
|-------------------|------------|----------------|
| `feature/*`       | learning   | kind-learning  |
| `develop`         | dev        | kind-dev       |
| `release/*`       | uat        | kind-uat       |
| `main`            | prod       | kind-prod      |

### Trigger options

- **Push**: Automatically triggers on push to any mapped branch.
- **Manual**: `gh workflow run deploy-to-kind.yml --ref <branch>`

### What the pipeline does

1. Checks out the repository
2. Determines target cluster from branch name
3. Builds the Docker image (tagged with short commit SHA)
4. Loads the image into the target kind cluster
5. Runs `helm upgrade --install` to deploy
6. Validates the deployment (waits for rollout, port-forwards, and checks the response)

## Accessing the Application

### Via Istio ingress gateway (permanent, no port-forward needed)

With the kind `extraPortMappings` and ingress gateway `hostPort` patch applied during setup, each cluster's ingress is permanently accessible:

```bash
curl -s -H "Host: pyapp.learning.local" http://localhost:8081/
curl -s -H "Host: pyapp.dev.local" http://localhost:8082/
curl -s -H "Host: pyapp.uat.local" http://localhost:8083/
```

| Cluster  | URL                      | Host header             |
|----------|--------------------------|-------------------------|
| learning | `http://localhost:8081/`  | `pyapp.learning.local`  |
| dev      | `http://localhost:8082/`  | `pyapp.dev.local`       |
| uat      | `http://localhost:8083/`  | `pyapp.uat.local`       |

### Via port-forward (alternative)

If the permanent ingress is unavailable, use port-forward directly to the service:

```bash
kubectl --context kind-dev port-forward -n pyapp svc/pyapp 8082:80 &
curl http://localhost:8082/
```

## Useful Commands

```bash
# Switch kubectl namespace
kubectl config set-context --current --namespace=pyapp

# Check pod sidecar injection
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{": "}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'

# View Envoy proxy logs
kubectl logs deploy/pyapp -c istio-proxy

# Check Envoy proxy config
istioctl proxy-config clusters deploy/pyapp

# List Helm releases across all namespaces
helm list -A

# Pause/unpause a kind cluster to save resources
docker pause learning-control-plane
docker unpause learning-control-plane
```

## Helm Chart Configuration

| Parameter                  | Default        | Description                        |
|----------------------------|----------------|------------------------------------|
| `replicaCount`             | `2`            | Number of pod replicas             |
| `image.repository`         | `pyapp`        | Container image name               |
| `image.tag`                | `1.3.0`        | Container image tag                |
| `image.pullPolicy`         | `Never`        | Pull policy (Never for kind)       |
| `service.type`             | `ClusterIP`    | Kubernetes service type            |
| `service.port`             | `80`           | Service port                       |
| `service.targetPort`       | `8080`         | Container port                     |
| `istio.gateway.enabled`    | `true`         | Create Gateway + VirtualService    |
| `istio.gateway.hosts`      | `[pyapp.local]`| Ingress gateway hostnames          |
| `istio.mtls.mode`          | `STRICT`       | mTLS enforcement mode              |
