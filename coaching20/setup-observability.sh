#!/bin/bash
set -e

echo "🚀 Setting up Complete Observability Stack..."

# Add Helm repos
echo "📋 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install External-DNS
echo "🌐 Installing External-DNS..."
kubectl apply -f externaldns.yaml

# Install NGINX Ingress
echo "🔀 Installing NGINX Ingress..."
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true

# Create namespace
echo "📦 Creating namespace..."
kubectl create namespace growfatlikeme-prom --dry-run=client -o yaml | kubectl apply -f -

# Install Discord Bridge
echo "💬 Installing Discord Bridge..."
kubectl apply -f alert-discord.yaml

# Install Prometheus Stack
echo "📊 Installing Prometheus Stack..."
helm upgrade --install growfatlikeme-prom prometheus-community/prometheus \
  -f prometheus-values.yaml \
  -n growfatlikeme-prom

# Configure Alertmanager for Discord
echo "🔧 Configuring Alertmanager for Discord..."
kubectl patch configmap growfatlikeme-prom-alertmanager -n growfatlikeme-prom --patch '
{
  "data": {
    "alertmanager.yml": "global:\n  resolve_timeout: 5m\nroute:\n  group_by: [\"alertname\", \"job\", \"instance\"]\n  group_wait: 10s\n  group_interval: 10s\n  repeat_interval: 30s\n  receiver: default-receiver\nreceivers:\n- name: default-receiver\n  webhook_configs:\n    - url: http://alertmanager-discord:9094\n      send_resolved: false\ntemplates:\n- /etc/alertmanager/*.tmpl"
  }
}'

# Restart Alertmanager
echo "🔄 Restarting Alertmanager..."
kubectl rollout restart statefulset/growfatlikeme-prom-alertmanager -n growfatlikeme-prom

# Install Grafana + Loki + Promtail
echo "📈 Installing Grafana + Loki + Promtail..."
helm upgrade --install grafana-stack grafana/loki-stack \
  -f grafana-loki-values.yaml \
  -n growfatlikeme-prom

echo "✅ Complete Observability Stack deployed!"
echo ""
echo "🌍 Access URLs:"
echo "  - Prometheus: http://growfatlikeme-prom.sctp-sandbox.com"
echo "  - Alertmanager: http://growfatlikeme-alertmanager.sctp-sandbox.com"
echo "  - Grafana: http://growfatlikeme-grafana.sctp-sandbox.com (admin/admin123)"
echo ""
echo "📊 Grafana comes pre-configured with:"
echo "  - Prometheus datasource (metrics)"
echo "  - Loki datasource (logs)"
echo "  - Promtail collecting logs from all pods"