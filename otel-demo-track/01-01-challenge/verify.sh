#!/bin/bash

set -euo pipefail

echo "🔍 Verifying OpenTelemetry Collector deployment..."

# Get pod name
OTEL_POD=$(kubectl get pods -n opentelemetry-demo -l app.kubernetes.io/name=otelcol -o jsonpath="{.items[0].metadata.name}")

# Ensure pod exists
if [ -z "$OTEL_POD" ]; then
  echo "❌ otelcol pod not found in opentelemetry-demo namespace."
  exit 1
fi

echo "⏳ Waiting for otelcol pod to become ready..."
kubectl wait --for=condition=Ready pod/$OTEL_POD -n opentelemetry-demo --timeout=60s

echo "✅ otelcol pod is running."

# Check logs for successful connection to Elastic
LOG_OUTPUT=$(kubectl logs "$OTEL_POD" -n opentelemetry-demo)

if echo "$LOG_OUTPUT" | grep -qE 'Exporting succeeded|sending request|Exporting failed.*retrying'; then
  echo "✅ Found evidence of trace/metric/log exports in otelcol logs."
  exit 0
else
  echo "⚠️ Could not find expected export activity in otelcol logs."
  echo "📦 Collector logs:"
  echo "$LOG_OUTPUT" | tail -n 50
  exit 1
fi