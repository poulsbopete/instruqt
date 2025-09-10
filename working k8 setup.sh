#!/usr/bin/env bash
set -Eeuo pipefail

# ── Config ──────────────────────────────────────────────────────────────
HOME_DIR="${HOME:-/root}"
VALUES_FILE="${VALUES_FILE:-$HOME_DIR/elastic-demo.yaml}"
REL="${REL:-otel-demo}"
NS="${NS:-otel-demo}"
CHART="open-telemetry/opentelemetry-demo"

# Versions to try to dodge the tpl/BasePath bug
TRY_VERSIONS=("0.33.8" "0.33.7" "0.33.6" "0.34.2" "0.35.1" "0.36.1" "0.36.4")

# Optional: comma-separated individual toggles: "flagA=ENABLED,flagB=DISABLED"
FLAG_TOGGLES="${FLAG_TOGGLES:-}"

# Optional: bulk toggle all flags to one state (ENABLED or DISABLED)
FLAG_ALL_STATE="${FLAG_ALL_STATE:-}"   # leave empty to skip

# Optional: skip waiting (set SKIP_WAIT=true to skip the loop)
SKIP_WAIT="${SKIP_WAIT:-false}"

log() { printf '%s\n' "[$(date +%H:%M:%S)] $*"; }

# ── Flag helper functions (no PATH needed) ──────────────────────────────
_get_flag_cm_key() {
  # Echo "CM KEY" to stdout. Return 1 on failure.
  local ns="${1:-otel-demo}"
  local cm key
  cm=$(kubectl -n "$ns" get deploy otel-demo-flagd -o jsonpath='{.spec.template.spec.volumes[?(@.configMap)].configMap.name}' 2>/dev/null || true)
  [ -z "$cm" ] && return 1

  key=$(kubectl -n "$ns" get cm "$cm" -o jsonpath='{.data}' 2>/dev/null \
        | jq -r 'keys[]|select(test("flag|json|yaml"; "i"))' | head -n1 || true)
  [ -z "$key" ] && return 1

  printf '%s %s\n' "$cm" "$key"
}

toggle_flag() {
  # usage: toggle_flag [ns] <flag_key> <ENABLED|DISABLED>
  local ns="${1:-otel-demo}"
  local flag="${2:-}"
  local state="${3:-}"

  if [ -z "$flag" ] || [ -z "$state" ]; then
    echo "usage: toggle_flag [namespace] <flag_key> <ENABLED|DISABLED>" >&2
    return 1
  fi

  local cm key
  if ! read -r cm key < <(_get_flag_cm_key "$ns"); then
    echo "❌ Unable to discover flagd ConfigMap/key in namespace '$ns'" >&2
    return 1
  fi

  local tmp_orig tmp_new
  tmp_orig=$(mktemp); tmp_new=$(mktemp)
  kubectl -n "$ns" get cm "$cm" -o jsonpath="{.data.${key}}" > "$tmp_orig"

  if ! jq -e . "$tmp_orig" >/dev/null 2>&1; then
    echo "❌ ConfigMap data '$cm/$key' is not JSON; adjust toggle_flag for YAML." >&2
    rm -f "$tmp_orig" "$tmp_new"
    return 1
  fi

  jq --arg f "$flag" --arg s "$state" '.flags[$f].state = $s' "$tmp_orig" > "$tmp_new"

  kubectl -n "$ns" get cm "$cm" -o json \
  | jq --arg k "$key" --rawfile new "$tmp_new" '.data[$k] = $new' \
  | kubectl apply -f - >/dev/null

  rm -f "$tmp_orig" "$tmp_new"
  echo "✔ Flag '$flag' => '$state' in $cm/$key"
}

toggle_all_flags() {
  # usage: toggle_all_flags [ns] <ENABLED|DISABLED>
  local ns="${1:-otel-demo}"
  local state="${2:-ENABLED}"

  local cm key
  if ! read -r cm key < <(_get_flag_cm_key "$ns"); then
    echo "❌ Unable to discover flagd ConfigMap/key in namespace '$ns'" >&2
    return 1
  fi

  kubectl -n "$ns" get cm "$cm" -o json \
  | jq --arg k "$key" --arg s "$state" '
      .data[$k] |= (fromjson | (.flags |= with_entries(.value.state = $s)) | tojson)
    ' \
  | kubectl apply -f - >/dev/null

  echo "✔ All flags set to $state in $cm/$key"
}

list_flags() {
  # usage: list_flags [ns]
  local ns="${1:-otel-demo}"
  local cm key
  if ! read -r cm key < <(_get_flag_cm_key "$ns"); then
    echo "❌ Unable to discover flagd ConfigMap/key in namespace '$ns'" >&2
    return 1
  fi
  kubectl -n "$ns" get cm "$cm" -o jsonpath="{.data.${key}}" | jq '.flags | keys'
}

# ── Wait loop (pods/controllers) ─────────────────────────────────────────
wait_for_namespace() {
  local ns="${1:-otel-demo}"
  local timeout="${2:-900}"   # seconds
  local interval="${3:-5}"    # polling interval

  _w_log() { printf '%s\n' "[$(date +%H:%M:%S)] $*"; }

  _wait_ctrl() {
    local kind="$1" cond="$2"
    if kubectl -n "$ns" get "$kind" >/dev/null 2>&1; then
      kubectl -n "$ns" wait --for="condition=${cond}" "$kind" --all --timeout="${timeout}s" 2>/dev/null || true
    fi
  }

  _w_log "⏳ Waiting for controllers in '$ns' (timeout=${timeout}s)"
  _wait_ctrl deployments.apps   Available
  _wait_ctrl statefulsets.apps  Ready
  _wait_ctrl daemonsets.apps    Available

  _w_log "⏳ Watching pods become Ready…"
  local start_ts now_ts elapsed
  start_ts=$(date +%s)

  while true; do
    now_ts=$(date +%s)
    elapsed=$(( now_ts - start_ts ))
    if [ "$elapsed" -ge "$timeout" ]; then
      _w_log "❌ Timeout (${timeout}s). Some pods are still not Ready."
      kubectl -n "$ns" get pods -o wide
      _w_log "🔎 Recent events:"
      kubectl -n "$ns" get events --sort-by=.lastTimestamp | tail -30
      return 1
    fi

    local not_ready
    not_ready=$(kubectl -n "$ns" get pods --no-headers 2>/dev/null \
      | awk '$2 !~ $3 {print $1}' | wc -l | tr -d ' ')

    if [ "$not_ready" -eq 0 ]; then
      _w_log "✅ All pods Ready in $ns (elapsed ${elapsed}s)."
      kubectl -n "$ns" get pods
      return 0
    fi

    local summary
    summary=$(kubectl -n "$ns" get pods --no-headers 2>/dev/null \
      | awk '{print $1"="$2"/"$3}' | paste -sd ' ')
    printf "\r[%03ss] Waiting… (%s)" "$elapsed" "$summary"
    sleep "$interval"
  done
}

# ── 0) Ensure values file exists (placeholders, no env expansion) ───────
if [ ! -s "$VALUES_FILE" ]; then
  cat > "$VALUES_FILE" <<'EOF'
opentelemetry-collector:
  config:
    receivers:
      otlp:
        protocols:
          grpc: {}
          http: {}
    processors:
      memory_limiter:
        check_interval: 1s
        limit_mib: 450
        spike_limit_mib: 128
      batch:
        send_batch_size: 512
        timeout: 200ms
    exporters:
      otlphttp/elastic:
        endpoint: "PASTE_ELASTIC_OTLP_ENDPOINT_HERE"
        headers:
          Authorization: "ApiKey PASTE_ELASTIC_API_KEY_HERE"
        compression: gzip
        retry_on_failure:
          enabled: true
        sending_queue:
          enabled: true
          num_consumers: 2
          queue_size: 10000
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter,batch]
          exporters: [otlphttp/elastic]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter,batch]
          exporters: [otlphttp/elastic]
        logs:
          receivers: [otlp]
          processors: [memory_limiter,batch]
          exporters: [otlphttp/elastic]
EOF
  log "✔  $VALUES_FILE created (placeholders inside)"
else
  log "ℹ  $VALUES_FILE already exists; leaving it"
fi

# ── 1) Repo + namespace ─────────────────────────────────────────────────
log "⎈  Updating Helm repo"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
helm repo update
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

# ── 2) Clean any FAILED/PENDING install so name is reusable ─────────────
if helm ls -n "$NS" --all --failed -q | grep -Fx "$REL" >/dev/null 2>&1; then
  log "⚠  Removing failed release '$REL'"
  helm uninstall "$REL" -n "$NS" || true
fi

# ── 3) Try versions until one works ─────────────────────────────────────
success=0
for ver in "${TRY_VERSIONS[@]}"; do
  errlog=$(mktemp)
  if helm status "$REL" -n "$NS" >/dev/null 2>&1; then
    ACTION=upgrade
  else
    ACTION=install
  fi

  log "⎈  helm $ACTION $REL (chart=${CHART}${ver:+, version=$ver})"
  set +e
  if [ -z "$ver" ]; then
    helm $ACTION "$REL" "$CHART" \
      -n "$NS" -f "$VALUES_FILE" --debug --wait=false 2>&1 | tee "$errlog"
  else
    helm $ACTION "$REL" "$CHART" --version "$ver" \
      -n "$NS" -f "$VALUES_FILE" --debug --wait=false 2>&1 | tee "$errlog"
  fi
  rc=${PIPESTATUS[0]}
  set -e

  if [ $rc -eq 0 ]; then
    success=1
    break
  fi

  if grep -q "cannot re-use a name that is still in use" "$errlog"; then
    log "⚠  Name stuck; uninstalling and retrying"
    helm uninstall "$REL" -n "$NS" || true
  fi
done

if [ $success -ne 1 ]; then
  log "❌ All chart versions failed. Tail of last error:"
  tail -50 "$errlog" || true
  exit 1
fi

# ── 3.1) Wait for pods (unless skipped) ─────────────────────────────────
if [ "$SKIP_WAIT" != "true" ]; then
  wait_for_namespace "$NS" 900 5 || exit 1
else
  log "⏭  SKIP_WAIT=true; not waiting for pods"
  kubectl -n "$NS" get pods
fi

# ── 5) Apply individual FLAG_TOGGLES if provided ────────────────────────
if [ -n "$FLAG_TOGGLES" ]; then
  IFS=',' read -ra PAIRS <<<"$FLAG_TOGGLES"
  for pair in "${PAIRS[@]}"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    log "⚙  Toggling $key=$val"
    toggle_flag "$NS" "$key" "$val" || log "⚠  Failed toggling $key"
  done
fi

# ── 6) Apply bulk state if requested ────────────────────────────────────
if [ -n "$FLAG_ALL_STATE" ]; then
  log "⚙  Bulk toggling ALL flags to $FLAG_ALL_STATE"
  toggle_all_flags "$NS" "$FLAG_ALL_STATE" || log "⚠  Bulk toggle failed"
fi

log "🎉 Setup complete."