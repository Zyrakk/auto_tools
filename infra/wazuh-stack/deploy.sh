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

# Always use kubectl
KUBECTL="kubectl"
echo -e "${GREEN}Using kubectl${NC}"

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
# Usamos un wait más permisivo porque los pods pueden tardar en iniciar
 $KUBECTL wait --for=condition=available deployment/wazuh-indexer -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Indexer not fully available yet, checking pod status...${NC}"
    kubectl get pods -n wazuh
}
sleep 10

echo ""
echo "Step 4: Initializing Security Plugin (CRITICAL STEP)..."
 $KUBECTL apply -f 07-init-security.yaml

echo ""
echo "Waiting for Security Job to complete..."
 $KUBECTL wait --for=condition=complete job/wazuh-security-init -n wazuh --timeout=300s

echo ""
echo "Step 5: Deploying Wazuh Manager..."
 $KUBECTL apply -f 03-manager.yaml

echo ""
echo "Waiting for Manager to be ready..."
 $KUBECTL wait --for=condition=available deployment/wazuh-manager -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Manager not ready yet, continuing...${NC}"
}
sleep 10

echo ""
echo "Step 6: Deploying Wazuh Dashboard..."
 $KUBECTL apply -f 04-dashboard.yaml

echo ""
echo "Waiting for Dashboard to be ready..."
 $KUBECTL wait --for=condition=available deployment/wazuh-dashboard -n wazuh --timeout=300s || {
    echo -e "${YELLOW}Dashboard not ready yet, continuing...${NC}"
}

echo ""
echo "Step 7: Creating Ingress..."
 $KUBECTL apply -f 05-ingress.yaml

echo ""
echo "Step 8: Deploying Wazuh Agents (DaemonSet)..."
echo -e "${YELLOW}Note: Agents will only run on AMD64 nodes (lake) due to image limitations.${NC}"
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
echo "  $KUBECTL logs -n wazuh job/wazuh-security-init"
echo ""
echo "Dashboard URL: https://wazuh.zyrak.cloud"
echo "Login credentials:"
echo "  Username: admin"
echo "  Password: ZCloud-Indexer-2026!"
echo ""
echo -e "${YELLOW}NOTE: Remember to add DNS record for wazuh.zyrak.cloud${NC}"
echo "  -> Point to oracle1 and oracle2 public IPs (same as grafana)"
echo ""