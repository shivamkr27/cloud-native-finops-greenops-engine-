#!/usr/bin/env bash

# ==============================================================================
# Cloud-Native FinOps & GreenOps Engine Setup Script
# ==============================================================================

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}      DEPLOYING CLOUD-NATIVE FINOPS & GREENOPS ENGINE                 ${NC}"
echo -e "${CYAN}======================================================================${NC}"

# Define script and project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Helper function to print steps
print_step() {
    echo -e "\n${BLUE}>>> [STEP] $1...${NC}"
}

# ------------------------------------------------------------------------------
# STEP 1: Verify Kubernetes & Minikube
# ------------------------------------------------------------------------------
print_step "1/8: Verifying Kubernetes cluster status"
PROFILE="${MINIKUBE_PROFILE:-aegis-greenops}"
if ! minikube status -p "${PROFILE}" &>/dev/null; then
    echo -e "${RED}[ERROR] Minikube profile '${PROFILE}' is not running.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Cluster is online.${NC}"

# ------------------------------------------------------------------------------
# STEP 2: Configure Helm Repos
# ------------------------------------------------------------------------------
print_step "2/8: Adding Helm repositories"
helm repo add sustainable-computing-io https://sustainable-computing-io.github.io/kepler-helm-chart
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update
echo -e "${GREEN}[OK] Helm repositories configured.${NC}"

# ------------------------------------------------------------------------------
# STEP 3: Register optional Karpenter CRDs
# ------------------------------------------------------------------------------
if [[ "${INSTALL_CLOUD_TEMPLATES:-false}" == "true" ]]; then
    print_step "3/8: Applying optional Karpenter CustomResourceDefinitions"
    kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.37.0/pkg/apis/crds/karpenter.sh_nodepools.yaml
    kubectl apply -f https://raw.githubusercontent.com/aws/karpenter-provider-aws/v0.37.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml
    echo -e "${GREEN}[OK] Karpenter CRDs registered.${NC}"
else
    echo -e "${YELLOW}[SKIP] AWS Karpenter templates disabled for zero-cost local mode.${NC}"
fi

# ------------------------------------------------------------------------------
# STEP 4: Build & Load Application Images
# ------------------------------------------------------------------------------
print_step "4/8: Building and loading Docker images"
echo -e "${YELLOW}Building batch-processor image...${NC}"
docker build -t batch-processor:latest -f ./cron-scheduler/Dockerfile.batch ./cron-scheduler

echo -e "${YELLOW}Loading batch-processor into Minikube...${NC}"
minikube -p "${PROFILE}" image load batch-processor:latest

echo -e "${YELLOW}Building carbon-scheduler image...${NC}"
docker build -t carbon-scheduler:latest ./cron-scheduler

echo -e "${YELLOW}Loading carbon-scheduler into Minikube...${NC}"
minikube -p "${PROFILE}" image load carbon-scheduler:latest

echo -e "${YELLOW}Building greenops-dashboard image...${NC}"
docker build -t greenops-dashboard:latest ./greenops-dashboard

echo -e "${YELLOW}Loading greenops-dashboard into Minikube...${NC}"
minikube -p "${PROFILE}" image load greenops-dashboard:latest
echo -e "${GREEN}[OK] Images built and loaded successfully.${NC}"

# ------------------------------------------------------------------------------
# STEP 5: Deploy Kepler Energy Telemetry
# ------------------------------------------------------------------------------
print_step "5/8: Deploying Kepler eBPF exporter"
# Kepler requires privileged access to host sensors. In minikube with docker driver,
# it runs with emulation.
helm upgrade --install kepler sustainable-computing-io/kepler \
    --namespace kepler \
    --create-namespace \
    --set serviceMonitor.enabled=true \
    --set serviceMonitor.namespace=monitoring \
    --wait
echo -e "${GREEN}[OK] Kepler deployed successfully.${NC}"

# ------------------------------------------------------------------------------
# STEP 6: Deploy Kubecost Cost Allocation
# ------------------------------------------------------------------------------
print_step "6/8: Deploying Kubecost Cost Analyzer"
helm upgrade --install kubecost kubecost/cost-analyzer \
    --namespace kubecost \
    --create-namespace \
    --version 2.8.6 \
    -f monitoring/kubecost_values.yaml
echo -e "${GREEN}[OK] Kubecost deployed successfully.${NC}"

# ------------------------------------------------------------------------------
# STEP 7: Apply Engine Configurations & Dashboards
# ------------------------------------------------------------------------------
print_step "7/8: Applying GreenOps engine resources & dashboards"
if [[ "${INSTALL_CLOUD_TEMPLATES:-false}" == "true" ]]; then
    kubectl apply -f karpenter/ec2nodeclass.yaml
    kubectl apply -f karpenter/nodepool.yaml
fi

# Apply monitoring CRs only when the Prometheus Operator CRDs exist
if kubectl api-resources --api-group=monitoring.coreos.com 2>/dev/null | grep -q servicemonitors; then
    kubectl apply -f kepler-telemetry/servicemonitor.yaml
    kubectl apply -f monitoring/dashboard-servicemonitor.yaml
    kubectl apply -f monitoring/prometheus_rules.yaml
else
    echo -e "${YELLOW}[SKIP] Prometheus Operator CRDs not detected; monitoring CRs were not applied.${NC}"
fi

# Apply batch workload, RBAC, and the Carbon Scheduler CronJob
kubectl apply -f cron-scheduler/batch-deployment.yaml
kubectl apply -f cron-scheduler/rbac.yaml
kubectl apply -f cron-scheduler/cronjob.yaml

# Apply Dashboard & Simulator deployment
kubectl apply -f greenops-dashboard/dashboard-kubernetes.yaml

# Import Grafana Dashboard via labeled ConfigMap
echo -e "${YELLOW}Importing Kepler Sustainability & GreenOps Dashboard into Grafana...${NC}"
kubectl create configmap greenops-kepler-dashboard-configmap -n monitoring \
    --from-file=greenops-kepler-dashboard.json=kepler-telemetry/dashboard_config.json \
    --dry-run=client -o yaml | \
    kubectl patch -f - --local -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}' -o yaml | \
    kubectl apply -f -

echo -e "${GREEN}[OK] All manifests and Grafana dashboard applied.${NC}"

# ------------------------------------------------------------------------------
# STEP 8: Rollout Verification
# ------------------------------------------------------------------------------
print_step "8/8: Verifying rollout status"
echo -e "${YELLOW}Waiting for GreenOps Dashboard rollout...${NC}"
kubectl rollout status deployment/greenops-dashboard -n default --timeout=60s

echo -e "${YELLOW}Waiting for Batch Processor workload rollout...${NC}"
kubectl rollout status deployment/batch-processor -n default --timeout=120s

echo -e "${GREEN}[OK] GreenOps Dashboard and workload are online!${NC}"

# ------------------------------------------------------------------------------
# SETUP COMPLETE
# ------------------------------------------------------------------------------
# Resolve Minikube IP
MINIKUBE_IP=$(minikube -p "${PROFILE}" ip || echo "192.168.58.2")

# Resolve NodePorts
DASHBOARD_PORT=$(kubectl get svc greenops-dashboard -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30505")
GRAFANA_PORT=$(kubectl get svc prometheus-operator-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30441")
KUBECOST_PORT=$(kubectl get svc kubecost-cost-analyzer -n kubecost -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30090")

# Retrieve Passwords
GRAFANA_PASS=$(kubectl --namespace monitoring get secrets prometheus-operator-grafana -o jsonpath="{.data.admin-password}" | base64 -d 2>/dev/null || echo "admin")

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}      GREENOPS & FINOPS ENGINE DEPLOYED COMPLETED SUCCESSFULLY        ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "\n${YELLOW}Access Information, URLs & Credentials:${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "${CYAN}1. Aegis GreenOps Control Center (Web UI)${NC}"
echo -e "   - Direct URL: http://${MINIKUBE_IP}:${DASHBOARD_PORT}"
echo -e "   - Port Forward (Backup): kubectl port-forward svc/greenops-dashboard 5000:80"
echo -e ""
echo -e "${CYAN}2. Grafana Dashboard (Kepler Metrics & Alerts)${NC}"
echo -e "   - Direct URL: http://${MINIKUBE_IP}:${GRAFANA_PORT}"
echo -e "   - Credentials: Username: admin | Password: ${GRAFANA_PASS}"
echo -e "   - Port Forward (Backup): kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
echo -e ""
echo -e "${CYAN}3. Kubecost Console (FinOps Cost Allocation)${NC}"
echo -e "   - Port Forward: kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090"
echo -e "   - Access URL after forward: http://localhost:9090"
echo -e "----------------------------------------------------------------------\n"
