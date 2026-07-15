# iterabase-charts

Helm charts for the [iterabase](https://iterabase.com) platform. The umbrella chart `iterabase-platform` deploys the platform (inference-gateway + control-plane + agent-fleet + Postgres/Redis/MinIO + ingress-nginx + MetalLB + cert-manager + external-dns) and is a **standalone artifact** — install it with `helm` directly, Flux, Argo, or via [forge](https://github.com/nunocgoncalves/forge).

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
| `metallb-config` | MetalLB IPAddressPool + L2Advertisement (L2 edge for bare-metal/kind/OPO1) | bundled only |

agent-fleet is a **disabled stub** until its service ships; control-plane ships standalone and is disabled in the umbrella by default (`control-plane.enabled=false`).

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

`make build-deps` resolves the umbrella's local + `ingress-nginx` + `metallb` + `cert-manager` (jetstack) + `external-dns` dependencies.

## Release

Per-chart tags publish to GHCR OCI:

```sh
git tag iterabase-platform-0.1.0 && git push --tags
```
