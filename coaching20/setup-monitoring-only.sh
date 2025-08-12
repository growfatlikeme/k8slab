#!/bin/bash
set -e

echo "🗑️ Destroying existing Prometheus namespace..."
kubectl delete namespace growfatlikeme-prom --ignore-not-found=true

echo "⏳ Waiting for namespace cleanup..."
sleep 10

echo "📦 Creating namespace..."
kubectl create namespace growfatlikeme-prom

echo "💬 Installing Discord Bridge..."
kubectl apply -f alert-discord.yaml

echo "📊 Installing Prometheus Stack..."
helm upgrade --install growfatlikeme-prom prometheus-community/prometheus \
  -f prometheus-values.yaml \
  -n growfatlikeme-prom

echo "🔧 Configuring Alertmanager for Discord..."
kubectl patch configmap growfatlikeme-prom-alertmanager -n growfatlikeme-prom --patch '
{
  "data": {
    "alertmanager.yml": "global:\n  resolve_timeout: 5m\nroute:\n  group_by: [\"alertname\", \"job\", \"instance\"]\n  group_wait: 10s\n  group_interval: 10s\n  repeat_interval: 30s\n  receiver: default-receiver\nreceivers:\n- name: default-receiver\n  webhook_configs:\n    - url: http://alertmanager-discord:9094\n      send_resolved: false\ntemplates:\n- /etc/alertmanager/*.tmpl"
  }
}'

echo "🔄 Restarting Alertmanager..."
kubectl rollout restart statefulset/growfatlikeme-prom-alertmanager -n growfatlikeme-prom

echo "✅ Monitoring stack recreated! Check Discord for alerts in ~30 seconds."