#!/usr/bin/env bash
# Stop almost all running cost between work sessions, keeping everything configured.
# Removes the load balancer IP and STOPS the AKS nodes (no VM compute billing while stopped).
#   Resume: az aks start -g rg-cicd-demo -n aks-cicd-demo   then re-run the pipeline (push or Actions -> Run workflow)
set -euo pipefail
RG="${RG:-rg-cicd-demo}"
AKS="${AKS:-aks-cicd-demo}"
az aks get-credentials --resource-group "${RG}" --name "${AKS}" --admin --overwrite-existing
kubectl -n webapp delete service webapp --ignore-not-found
az aks stop --resource-group "${RG}" --name "${AKS}"
echo "Paused. Resume with: az aks start --resource-group ${RG} --name ${AKS}"
