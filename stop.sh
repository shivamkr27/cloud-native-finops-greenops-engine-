#!/usr/bin/env bash

# ==============================================================================
# Cloud-Native FinOps & GreenOps Engine Teardown Script
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}      CLEANING UP CLOUD-NATIVE FINOPS & GREENOPS ENGINE               ${NC}"
echo -e "${CYAN}======================================================================${NC}"

# Define script and project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Helper function to print steps
print_step() {
    echo -e "\n${BLUE}>>> [STEP] $1...${NC}"
}

# ------------------------------------------------------------------------------
# STEP 1: Delete Kubernetes Workloads & Engine Configs
# ------------------------------------------------------------------------------
print_step "1/4: Deleting workload and dashboard resources"
kubectl delete -f greenops-dashboard/dashboard-kubernetes.yaml --ignore-not-found
kubectl delete -f cron-scheduler/cronjob.yaml --ignore-not-found
kubectl delete -f cron-scheduler/rbac.yaml --ignore-not-found
kubectl delete -f cron-scheduler/batch-deployment.yaml --ignore-not-found
kubectl delete -f monitoring/prometheus_rules.yaml --ignore-not-found
kubectl delete -f kepler-telemetry/servicemonitor.yaml --ignore-not-found
kubectl delete -f karpenter/nodepool.yaml --ignore-not-found
kubectl delete -f karpenter/ec2nodeclass.yaml --ignore-not-found
kubectl delete configmap greenops-kepler-dashboard-configmap -n monitoring --ignore-not-found
echo -e "${GREEN}[OK] Workload resources deleted.${NC}"

# ------------------------------------------------------------------------------
# STEP 2: Uninstall Helm Releases
# ------------------------------------------------------------------------------
print_step "2/4: Uninstalling Kepler and Kubecost Helm releases"
helm uninstall kepler -n kepler || true
helm uninstall kubecost -n kubecost || true
echo -e "${GREEN}[OK] Kepler and Kubecost uninstalled.${NC}"

# ------------------------------------------------------------------------------
# STEP 3: Delete Karpenter CRDs
# ------------------------------------------------------------------------------
print_step "3/4: Deleting Karpenter CustomResourceDefinitions"
kubectl delete crd nodepools.karpenter.sh --ignore-not-found
kubectl delete crd ec2nodeclasses.karpenter.k8s.aws --ignore-not-found
echo -e "${GREEN}[OK] Karpenter CRDs removed.${NC}"

# ------------------------------------------------------------------------------
# STEP 4: Delete namespaces
# ------------------------------------------------------------------------------
print_step "4/4: Deleting namespaces"
kubectl delete namespace kepler --ignore-not-found || true
kubectl delete namespace kubecost --ignore-not-found || true
echo -e "${GREEN}[OK] Namespaces deleted.${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}      TEARDOWN COMPLETED SUCCESSFULLY                                 ${NC}"
echo -e "${GREEN}======================================================================${NC}"
