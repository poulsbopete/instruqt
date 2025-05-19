#!/bin/bash

set -euo pipefail

echo "🔧 Installing dependencies..."

# Update and install tools
apt-get update
apt-get install -y curl git unzip jq

# Install Helm
HELM_VERSION="v3.14.4"
curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm
rm -rf helm.tar.gz linux-amd64

# Install k3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode=644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /root/.bashrc

echo "✅ k3s and Helm installed."

# Wait for Kubernetes to be ready
echo "⏳ Waiting for k3s to become ready..."
until kubectl get nodes &> /dev/null; do
  sleep 2
done

kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Clone the OpenTelemetry demo
echo "📦 Cloning the OpenTelemetry Demo..."
cd /root
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo

# Use Instruqt parameter-injected environment variables
echo "🌐 Elastic endpoint: $OTEL_ELASTIC_ENDPOINT"
echo "🔐 Elastic API key length: ${#OTEL_ELASTIC_API_KEY}"

# Replace default OTEL Collector config with customized version
echo "🛠️  Injecting user-provided values into OTEL config..."
envsubst < /workspace/elastic.yml > otel-collector-config.yaml

# 🚀 Deploy the demo using Helm
echo "🚀 Deploying OpenTelemetry Demo with Helm..."
make deploy

echo "✅ OpenTelemetry Demo deployed with dynamic Elastic config!"


# Auto-export KUBECONFIG for interactive terminal use
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Optional: verify it's working
echo "🔍 Verifying Kubernetes setup:"
kubectl get nodes
