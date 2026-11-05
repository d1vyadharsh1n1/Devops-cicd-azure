#!/usr/bin/env bash
# Delete EVERYTHING created by azure-setup.sh (cluster, registry, identity). Do this after your demo/viva.
set -euo pipefail
RG="${RG:-rg-cicd-demo}"
APP_NAME="${APP_NAME:-github-cicd-deployer}"
SUB_ID="$(az account show --query id -o tsv)"
APP_ID="$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)"

if [ -n "${APP_ID}" ]; then
  az role assignment delete --assignee "${APP_ID}" --scope "/subscriptions/${SUB_ID}" || true
  az ad app delete --id "${APP_ID}" || true
fi
# Deleting the resource group removes the registry, the AKS cluster and its node resource group
az group delete --name "${RG}" --yes --no-wait
echo "Deletion started (runs in the background, a few minutes). Check: az group list -o table"
