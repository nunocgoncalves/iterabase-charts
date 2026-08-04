# Immutable artifact operations (HOR-399)

The installation is the tenant boundary. Artifact metadata is in Postgres and
immutable bytes are in the `iterabase-artifacts` MinIO bucket. Only the
control-plane API/gateway receive the dedicated bucket credential. Do not copy
MinIO credentials into AgentPool, supervisor, runner, or sandbox configuration.

## Install validation

```sh
kubectl -n <namespace> rollout status statefulset/<release>-minio
kubectl -n <namespace> wait --for=condition=complete job \
  -l app.kubernetes.io/component=artifact-provisioner --timeout=5m
kubectl -n <namespace> get secret <release>-minio-artifacts
kubectl -n <namespace> rollout status deployment/<release>-control-plane-api
kubectl -n <namespace> rollout status deployment/<release>-control-plane-gateway
```

The workload ArtifactService is available only through the mandatory-mTLS
`<release>-control-plane-gateway:8090` Service. AgentPools use that Service as
their `toolGateway`, trust the chart-generated
`<release>-control-plane-gateway-ca`, and receive leaves from the
`platform-spiffe-ca` ClusterIssuer. The gateway and API mount the bucket-scoped
artifact Secret; supervisors mount only their workload leaf and CA chain.

Validate through the artifact API rather than MinIO:

```sh
printf 'artifact round trip' > /tmp/artifact.txt
curl -fsS -H "Authorization: Bearer $WORK_API_KEY" \
  -H 'Content-Type: text/plain' \
  --data-binary @/tmp/artifact.txt \
  https://<control-plane>/v1/artifacts > /tmp/artifact.json
ARTIFACT_ID=$(jq -r .artifactId /tmp/artifact.json)
curl -fsS -H "Authorization: Bearer $WORK_API_KEY" \
  "https://<control-plane>/v1/artifacts/$ARTIFACT_ID" | cmp - /tmp/artifact.txt
```

Record the chart revision, artifact ID, canonical SHA-256 digest, and command
results as deployment evidence. Never record API keys or MinIO credentials.

## Explicit deletion

Explicit deletion is admin-only. It immediately makes reads unavailable,
removes MinIO bytes, and retains a metadata tombstone and historical work links.

```sh
curl -fsS -X DELETE -H "Authorization: Bearer $ADMIN_API_KEY" \
  "https://<control-plane>/v1/artifacts/$ARTIFACT_ID"
```

A subsequent work-scope `GET` must return `410 Gone`. Retention expiry uses the
same lifecycle automatically. `retention_until = NULL` means indefinite.

## Manual backup/restore validation

HOR-399 does **not** add a backup system. OPO1 validation uses the existing
Postgres and MinIO tools with an operator-controlled, encrypted backup mount.
Do not send customer data to an unapproved cloud destination.

1. Quiesce artifact writers by scaling the control-plane API and gateway to
   zero during the maintenance window.
2. Run `pg_dump --format=custom` against the control-plane database.
3. Run `mc mirror --preserve local/iterabase-artifacts /backup/artifacts` from a
   temporary operator pod that mounts the approved backup filesystem. Give that
   pod the release's `app.kubernetes.io/name=minio`,
   `app.kubernetes.io/instance=<release>`, and
   `app.kubernetes.io/component=artifact-backup` labels so the MinIO
   NetworkPolicy admits it; delete the pod and its temporary credential mount
   when validation finishes.
4. Save a manifest containing artifact ID, object key, size, and canonical
   SHA-256 digest from Postgres; hash every mirrored file and compare it.
5. Restore into empty Postgres/MinIO storage in a validation namespace, rerun
   the manifest comparison, and retrieve a representative artifact through the
   control-plane API.
6. Resume writers only after backup or restore verification succeeds.

Example tool operations (credentials supplied through temporary Secret refs,
never command-line literals):

```sh
pg_dump "$DATABASE_URL" --format=custom --file=/backup/control-plane.dump
mc alias set local "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
mc mirror --preserve local/iterabase-artifacts /backup/artifacts
```

Backup destination, encryption, schedule, transfer, and retention are defined
by the OPO1/customer data agreement, not by this chart.
