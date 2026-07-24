# Internal TLS certificate rotation

This chart provisions internal (in-cluster) TLS for Postgres, Redis, and the
control-plane API via cert-manager `Certificate` resources signed by the
internal CA (`charts/cert-issuers`). Leaf certs are 90 days, renewed by
cert-manager 15 days before expiry (`renewBefore: 360h`).

## What cert-manager does NOT do

cert-manager renews the mounted `tls.crt`/`tls.key` **Secret in place**, and
kubelet syncs the updated files into the pod's mounted volume (~every 60s). The
three TLS servers, however, **do not hot-reload** that material:

| Component | Loads TLS at | Hot-reload? |
| -- | -- | -- |
| PostgreSQL | startup / SIGHUP | only on SIGHUP (see below) |
| Redis | startup | no — restart required |
| control-plane API (Go `ListenAndServeTLS`) | startup | no — restart required |

So a renewed leaf is **not** served until the workload re-reads the files. Without
a rotation step, clients keep trusting the old leaf and reject the connection at
expiry (day 90). cert-manager's renewal alone is not sufficient.

## Managed rotation procedure

cert-manager renews each leaf at day 75 (90 − 15). The 15-day window is the
operator's lead time to roll the workloads so they pick up the renewed material.
Run this after cert-manager reports the Certificate `Ready` with a new
`notAfter` (or on any alert that a leaf was renewed):

```sh
kubectl rollout restart statefulset -n <ns> <release>-postgresql
kubectl rollout restart deployment  -n <ns> <release>-redis
kubectl rollout restart deployment  -n <ns> <release>-control-plane-manager
kubectl rollout restart deployment  -n <ns> <release>-control-plane-api
```

A `helm upgrade` (e.g. the next Forge deploy) has the same effect, since the
pods are recreated. The single-replica workloads incur a brief interruption;
for multi-tenant hardening, schedule this within a maintenance window or raise
replicas first.

PostgreSQL can alternatively reload `ssl_cert_file`/`ssl_key_file` without a
full restart via a SIGHUP:

```sh
kubectl exec -n <ns> <release>-postgresql-0 -- gosu postgres pg_ctl reload -D "$PGDATA"
```

(Redis and the Go API have no equivalent hot-reload and must be restarted.)

## Monitoring

Alert on cert-manager renewal so the rotation step is triggered, not on expiry:

- `certmanager_certificate_ready_status{condition="Ready",status="False"}` — issuance failing.
- `certmanager_certificate_expiration_timestamp_seconds` — < 15d means a renewed
  leaf is pending rollout; < 7d means the rotation step was missed and expiry is
  imminent. Re-run the restart steps above immediately.

## CA rotation

The internal root CA (`<release>-internal-ca-root`) is also a cert-manager
`Certificate` (isCA) with its own duration (see `cert-issuers.values.internal.ca.duration`).
When the CA renews, the `ca.crt` in its Secret updates and is sync'd into client
trust mounts automatically; new client connections pick it up. Leaves signed by
the previous CA key remain valid until their own renewal (cert-manager signs new
leaves with the current CA). No separate action is required for CA rotation
beyond ensuring leaves are allowed to renew normally.

## Future: automated restart-on-change

This chart does not bundle a controller to restart workloads automatically when
their cert Secret changes. The standard solution is Stakater Reloader (or
equivalent) with a `reloader.stakater.com/auto` annotation on each TLS
workload, which triggers a rollout exactly when the Secret updates — no periodic
restarts, no manual step. Adding it is a recommended follow-up (new controller
dependency, out of scope for HOR-371).
