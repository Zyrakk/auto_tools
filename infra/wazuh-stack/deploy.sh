#!/bin/bash
# Wazuh Stack Deployment Script for ZCloud
# Run from the directory containing the manifests

set -e

echo "=========================================="
echo "  ZCloud - Wazuh SIEM Deployment"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check kubectl/zcloud access
if command -v zcloud &> /dev/null; then
    KUBECTL="zcloud k"
    echo -e "${GREEN}Using zcloud CLI${NC}"
else
    KUBECTL="kubectl"
    echo -e "${YELLOW}Using kubectl directly${NC}"
fi

echo ""
echo "Step 1: Creating namespace and secrets..."
$KUBECTL apply -f 00-namespace-secrets.yaml
sleep 2

echo ""
echo "Step 2: Creating storage (PVCs)..."
$KUBECTL apply -f 01-storage.yaml

echo ""
echo "Waiting for PVCs to be bound..."
$KUBECTL wait --for=jsonpath='{.status.phase}'=Bound pvc/wazuh-certs -n wazuh --timeout=120s || true
$KUBECTL wait --for=jsonpath='{.status.phase}'=Bound pvc/wazuh-indexer-data -n wazuh --timeout=120s || true
$KUBECTL wait --for=jsonpath='{.status.phase}'=Bound pvc/wazuh-manager-data -n wazuh --timeout=120s || true
sleep 5

echo ""
echo "Step 3: Deploying Wazuh Indexer..."
$KUBECTL apply -f 02-indexer.yaml

echo ""
echo "Waiting for Indexer to be ready (this may take 2-3 minutes)..."
$KUBECTL rollout status deployment/wazuh-indexer -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Indexer not ready yet, continuing anyway...${NC}"
}
sleep 10

echo ""
echo "Step 4: Deploying Wazuh Manager..."
$KUBECTL apply -f 03-manager.yaml

echo ""
echo "Waiting for Manager to be ready (this may take 2-3 minutes)..."
$KUBECTL rollout status deployment/wazuh-manager -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Manager not ready yet, continuing anyway...${NC}"
}
sleep 10

echo ""
echo "Step 5: Deploying Wazuh Dashboard..."
$KUBECTL apply -f 04-dashboard.yaml

echo ""
echo "Waiting for Dashboard to be ready..."
$KUBECTL rollout status deployment/wazuh-dashboard -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Dashboard not ready yet, continuing anyway...${NC}"
}

echo ""
echo "Step 6: Creating Ingress..."
$KUBECTL apply -f 05-ingress.yaml

echo ""
echo "Step 7: Deploying Wazuh Agents (DaemonSet)..."
$KUBECTL apply -f 06-agent-daemonset.yaml

echo ""
echo "=========================================="
echo -e "${GREEN}  Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "To check status:"
echo "  $KUBECTL get pods -n wazuh"
echo ""
echo "To view logs:"
echo "  $KUBECTL logs -n wazuh -l app=wazuh-indexer"
echo "  $KUBECTL logs -n wazuh -l app=wazuh-manager"
echo "  $KUBECTL logs -n wazuh -l app=wazuh-dashboard"
echo ""
echo "Dashboard URL: https://wazuh.zyrak.cloud"
echo "Login credentials:"
echo "  Username: admin"
echo "  Password: ZCloud-Indexer-2026!"
echo ""
echo -e "${YELLOW}NOTE: Remember to add DNS record for wazuh.zyrak.cloud${NC}"
echo "  -> Point to oracle1 and oracle2 public IPs (same as grafana)"
echo ""