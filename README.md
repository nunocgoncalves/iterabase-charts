# iterabase-charts

Helm charts for the [iterabase](https://iterabase.com) platform. The umbrella chart `iterabase-platform` deploys the platform (inference-gateway + control-plane + agent-fleet + Postgres/Redis/MinIO + ingress-nginx) and is a **standalone artifact** — install it with `helm` directly, Flux, Argo, or via [forge](https://github.com/nunocgoncalves/forge).

## Charts

| Chart | Description | Released individually |
|---|---|---|
| `iterabase-platform` | Umbrella — composes all components | ✅ |
| `inference-gateway` | Model-access service | ✅ |
| `control-plane` | Identity store + IdentityMapping operator + JWT/JWKS API | ✅ |
| `agent-fleet` | The agent product (stub) | ✅ |
| `postgresql` | Self-contained Postgres on the official image | bundled only |
| `redis` | Self-contained Redis (hot-path cache) | bundled only |
| `minio` | Self-contained MinIO object storage | bundled only |

agent-fleet is a **disabled stub** until its service ships; control-plane ships standalone and is disabled in the umbrella by default (`control-plane.enabled=false`).

## Install

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install iterabase oci://ghcr.io/nunocgoncalves/iterabase-charts/iterabase-platform \
  --version 0.1.0 -n iterabase-system --create-namespace
```

Get the generated gateway admin API key:

```sh
kubectl get secret iterabase-gateway-admin -n iterabase-system \
  -o jsonpath='{.data.adminApiKey}' | base64 -d
```

## Develop

```sh
make check   # helm lint (all) + helm template (umbrella + control-plane) + kubeconform
```

Requires `helm` and `kubeconform`. `make build-deps` resolves the umbrella's local + `ingress-nginx` dependencies.

## Release

Per-chart tags publish to GHCR OCI:

```sh
git tag iterabase-platform-0.1.0 && git push --tags
```
