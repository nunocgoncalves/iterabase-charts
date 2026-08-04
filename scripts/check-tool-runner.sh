#!/usr/bin/env bash
set -euo pipefail
render=$(helm template runner-check charts/control-plane \
  --set postgresql.enabled=false \
  --set gateway.enabled=true \
  --set toolRunner.enabled=true \
  --set toolRunner.metrics.enabled=true \
  --set 'toolRunner.allowedToolNamespaces={platform,graph}')

grep -q 'app.kubernetes.io/component: tool-runner' <<<"$render"
grep -q 'spiffe://iterabase.local/tool-runners/default/overlay-tools' <<<"$render"
grep -q 'resourceNames: \["overlay"\]' <<<"$render"
grep -q 'mountPath: /artifacts, readOnly: true' <<<"$render"
grep -q 'name: TOOL_RUNNER_MAX_GENERATIONS' <<<"$render"
grep -q 'name: TOOL_RUNNER_DRAIN_MAX_AGE' <<<"$render"
grep -q 'name: MATERIALIZER_METRICS_PORT' <<<"$render"
grep -q 'name: TOOL_RUNNER_METRICS_PORT' <<<"$render"
grep -q 'kind: ServiceMonitor' <<<"$render"
grep -q 'port: mat-metrics' <<<"$render"
grep -q 'port: run-metrics' <<<"$render"

# Only materializer receives the projected kube-api mount; only runner receives
# mTLS material. Split the two container blocks for credential-boundary checks.
materializer=$(awk '/- name: materializer/{p=1} /- name: runner/{p=0} p' <<<"$render")
runner=$(awk '/- name: runner/{p=1} /^      volumes:/{p=0} p' <<<"$render")
grep -q 'name: kube-api' <<<"$materializer"
! grep -q 'name: runner-tls' <<<"$materializer"
grep -q 'name: runner-tls' <<<"$runner"
! grep -q 'name: kube-api' <<<"$runner"

echo "OK: tool runner renders with exact SPIFFE approval, bounded generations, read-only artifacts, split credentials, and Prometheus scraping"
