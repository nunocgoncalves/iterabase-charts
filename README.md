# iterabase-charts

Helm charts for the [iterabase](https://iterabase.com) platform. The umbrella chart `iterabase-platform` deploys the platform (inference-gateway + control-plane + Postgres/Redis/MinIO + ingress-nginx + MetalLB + cert-manager/CSI + external-dns) and is a **standalone artifact** — install it with `helm` directly, Flux, Argo, or via [forge](https://github.com/nunocgoncalves/forge).

## Charts

| Chart | Description | Released individually |
|---|---|---|
| `iterabase-platform` | Umbrella — composes all components | ✅ |
| `inference-gateway` | Model-access service | ✅ |
| `control-plane` | Durable workflow/control APIs, operator, and immutable artifact service | ✅ |
| `postgresql` | Self-contained Postgres on the official image | bundled only |
| `redis` | Self-contained Redis (hot-path cache) | bundled only |
| `minio` | Self-contained MinIO object storage | bundled only |
| `cert-issuers` | cert-manager ClusterIssuers (Let's Encrypt DNS-01/Cloudflare + self-signed) | bundled only |
| `metallb-config` | MetalLB IPAddressPool + L2Advertisement (L2 edge for bare-metal/kind/OPO1) | bundled only |
| `observability` | Prometheus + Grafana + Loki + Alertmanager (kube-prometheus-stack + loki) + default alert rules + GPU (DCGM) scraping | bundled only |

control-plane ships standalone and is enabled in the umbrella by default (it provides the shared pgvector Postgres + the schemas the gateway reads).

## Install

The gateway is the only public endpoint, served over HTTPS by the bundled edge
(ingress-nginx + cert-manager). The edge is always a **LoadBalancer** Service —
no hostNetwork. The LB implementation is pluggable:

- **kind/dev** — MetalLB L2 with a pool in the kind docker-bridge subnet. Clone
  this repo and use the `values-kind.yaml` preset:
  ```sh
  helm install iterabase charts/iterabase-platform -n iterabase-system --create-namespace \
    -f values-kind.yaml --wait
  ```
  then curl the self-signed edge:
  ```sh
  LB_IP=$(kubectl get svc -n iterabase-system -l app.kubernetes.io/name=ingress-nginx \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
  curl -k --resolve gateway.iterabase.local:443:"$LB_IP" https://gateway.iterabase.local/health
  ```
- **bare-metal/OPO1** — MetalLB L2 with a real pool (e.g. a VLAN range); see the
  prod overlay below.
- **cloud** — leave MetalLB disabled and set provider annotations on
  `ingress-nginx.controller.service` so the cloud LB provisions the Service.

Get the generated gateway admin API key:

```sh
kubectl get secret iterabase-gateway-admin -n iterabase-system \
  -o jsonpath='{.data.adminApiKey}' | base64 -d
```

Production (OPO1, IPv6-only origin + Cloudflare-proxied dual-stack) — override in
your values/overlay:

```sh
helm install iterabase oci://ghcr.io/nunocgoncalves/iterabase-charts/iterabase-platform \
  --version 0.1.13 -n iterabase-system --create-namespace \
  --set inference-gateway.ingress.host=gateway.opo1.example.com \
  --set inference-gateway.ingress.tls.clusterIssuer=letsencrypt-prod \
  --set ingress-nginx.controller.service.ipFamilyPolicy=SingleStack \
  --set ingress-nginx.controller.service.ipFamilies[0]=IPv6 \
  --set metallb.enabled=true \
  --set metallb-config.enabled=true \
  --set metallb-config.addresses[0]=2001:db8:30::/64 \
  --set cert-issuers.letsencrypt.enabled=true \
  --set cert-issuers.letsencrypt.email=you@example.com \
  --set external-dns.enabled=true \
  --set external-dns.domainFilters[0]=opo1.example.com.
```

(The Cloudflare API-token Secret shared by cert-issuers + external-dns must be
provisioned out-of-band — see the umbrella `values.yaml` comments. For IPv4-first
clients, set `ipFamilies[0]=IPv4` and an IPv4 `metallb-config.addresses` pool.)

## Immutable artifacts

The MinIO chart provisions `iterabase-artifacts` plus a dedicated bucket-scoped
credential consumed only by the control-plane API/gateway. Sandboxes and tool
runners have no object-store credential or direct route. Retention is indefinite
unless `control-plane.artifact.defaultRetention` is configured. See
[`docs/artifact-operations.md`](docs/artifact-operations.md) for round-trip and
explicit deletion validation.

## Develop

```sh
make check   # helm lint (all) + helm template (umbrella + control-plane) + kubeconform
```

Requires `helm` and `kubeconform`. Add the external repos first:

```sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metallb https://metallb.github.io/metallb
helm repo add jetstack https://charts.jetstack.io
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

`make build-deps` resolves the umbrella's local + `ingress-nginx` + `metallb` + `cert-manager` + `cert-manager-csi-driver` (jetstack) + `external-dns` + `reloader` (stakater) + `kube-prometheus-stack` + `loki` (grafana) dependencies.

## Observability (HOR-408)

The optional `observability` subchart (disabled by default) deploys Prometheus +
Grafana + Loki + Alertmanager via `kube-prometheus-stack` + `loki`, with the
Prometheus Operator CRDs (`ServiceMonitor` / `PodMonitor` / `PrometheusRule`),
PV-backed storage, default alert rules, and a Loki Grafana datasource. Enable it
with the preset:

```sh
helm install iterabase charts/iterabase-platform -n iterabase-system --create-namespace \
  -f values-kind.yaml -f values-observability.yaml --wait
```

The preset flips the stack on **and** every component's `metrics.enabled` knob,
so Prometheus scrapes the gateway, control-plane (api/manager), vLLM
(model-backend pods), Postgres/Redis (via dedicated exporters), MinIO (native),
and the upstream substrate (ingress-nginx/cert-manager/external-dns/reloader).
GPU metrics: set `observability.dcgmExporter.enabled=true` (gpu-operator must be
installed out-of-band). Alertmanager **email routing is overlay-owned** — the
chart ships a null-receiver default; set
`observability.kube-prometheus-stack.alertmanager.config` in the prod overlay
(HOR-408: the OPO1 overlay carries the email receiver).

Caveats (HOR-408 tracked gaps): the inference-gateway / control-plane `/metrics`
endpoints and the manager's controller-runtime metrics port are service-repo
concerns — the `ServiceMonitor`s are wired here and scrape once those endpoints
ship. The vLLM `PodMonitor` target labels/port depend on the operator's pod
template; match them in the overlay or via a service-repo ticket.

## Release

Per-chart tags publish to GHCR OCI:

```sh
git tag iterabase-platform-0.1.0 && git push --tags
```
