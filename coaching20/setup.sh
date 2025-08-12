#!/bin/bash
set -e

echo "🚀 Starting EKS Monitoring Stack Setup..."

# Phase 1: Infrastructure
echo "📦 Applying Terraform..."
cd ~/k8slab/terraform
terraform apply -auto-approve
cd ~/k8slab/coaching20

# Update kubeconfig
aws eks update-kubeconfig --name growfatlikeme-eks-cluster --region ap-southeast-1

# Phase 2: Helm repos
echo "📋 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Phase 3: Core components
echo "🌐 Installing External-DNS..."
kubectl apply -f externaldns.yaml

echo "🔀 Installing NGINX Ingress..."
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true

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

echo "✅ Setup complete! Check Discord for alerts in ~30 seconds."
echo "🌍 Access URLs:"
echo "  - Prometheus: http://growfatlikeme-prom.sctp-sandbox.com"
echo "  - Alertmanager: http://growfatlikeme-alertmanager.sctp-sandbox.com"