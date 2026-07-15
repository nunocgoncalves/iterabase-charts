# iterabase-charts

Helm charts for the [iterabase](https://iterabase.com) platform. The umbrella chart `iterabase-platform` deploys the platform (inference-gateway + control-plane + agent-fleet + Postgres/Redis/MinIO + ingress-nginx + cert-manager + external-dns) and is a **standalone artifact** — install it with `helm` directly, Flux, Argo, or via [forge](https://github.com/nunocgoncalves/forge).

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
| `cert-issuers` | cert-manager ClusterIssuers (Let's Encrypt DNS-01/Cloudflare + self-signed) | bundled only |

agent-fleet is a **disabled stub** until its service ships; control-plane ships standalone and is disabled in the umbrella by default (`control-plane.enabled=false`).

## Install

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install iterabase oci://ghcr.io/nunocgoncalves/iterabase-charts/iterabase-platform \
  --version 0.1.12 -n iterabase-system --create-namespace
```

Get the generated gateway admin API key:

```sh
kubectl get secret iterabase-gateway-admin -n iterabase-system \
  -o jsonpath='{.data.adminApiKey}' | base64 -d
```

The gateway is the only public endpoint and is reachable over HTTPS via the
bundled edge (ingress-nginx + cert-manager). Defaults render a working kind/dev
edge: a self-signed cert for `gateway.iterabase.local` (curl with `-k` and
`--resolve gateway.iterabase.local:443:127.0.0.1`). For production, override in
your values/overlay:

```sh
helm install iterabase oci://ghcr.io/nunocgoncalves/iterabase-charts/iterabase-platform \
  --version 0.1.12 -n iterabase-system --create-namespace \
  --set inference-gateway.ingress.host=gateway.opo1.example.com \
  --set inference-gateway.ingress.tls.clusterIssuer=letsencrypt-prod \
  --set cert-issuers.letsencrypt.enabled=true \
  --set cert-issuers.letsencrypt.email=you@example.com \
  --set external-dns.enabled=true \
  --set external-dns.domainFilters[0]=opo1.example.com.
```

(The Cloudflare API-token Secret shared by cert-issuers + external-dns must be
provisioned out-of-band — see the umbrella `values.yaml` comments.)

Ingress-nginx exposure is configurable: **hostNetwork** (single-node, default —
binds 80/443 directly on the node) or **LoadBalancer** (HA/cloud — switch to it
when 80/443 conflict, e.g. the GPU-E2E `FailedScheduling`, or for HA). See the
commented `LoadBalancer mode` block in the umbrella `values.yaml`.

## Develop

```sh
make check   # helm lint (all) + helm template (umbrella + control-plane) + kubeconform
```

Requires `helm` and `kubeconform`. Add the external repos first:

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

`make build-deps` resolves the umbrella's local + `ingress-nginx` + `cert-manager` (jetstack) + `external-dns` dependencies.

## Release

Per-chart tags publish to GHCR OCI:

```sh
git tag iterabase-platform-0.1.0 && git push --tags
```
