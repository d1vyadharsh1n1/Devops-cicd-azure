#!/usr/bin/env bash
# One-time Azure provisioning. Idempotent: safe to re-run.
# Run in Azure Cloud Shell (Bash), already logged in:
#   export GITHUB_REPO=<github-user>/devops-cicd-azure       # owner/repo, exact case
#   ./scripts/azure-setup.sh
# Optional overrides: LOCATION, NODE_SIZE, NODE_COUNT, RG, ACR_NAME, AKS
set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO as owner/repo (exact case)}"
LOCATION="${LOCATION:-centralindia}"
RG="${RG:-rg-cicd-demo}"
AKS="${AKS:-aks-cicd-demo}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"
NODE_COUNT="${NODE_COUNT:-2}"
APP_NAME="${APP_NAME:-github-cicd-deployer}"

SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
# ACR names must be globally unique, lowercase alphanumeric. Derive a stable one from the subscription id.
ACR_NAME="${ACR_NAME:-cicd$(echo "${SUB_ID}" | tr -d '-' | cut -c1-12)}"

echo "Subscription: $(az account show --query name -o tsv)  (${SUB_ID})"
echo "Location: ${LOCATION}   Node size: ${NODE_SIZE} x ${NODE_COUNT}   ACR: ${ACR_NAME}"

echo "==> 1/6 Registering resource providers (first time only, may take a few minutes)"
for ns in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.Network Microsoft.Compute Microsoft.Storage; do
  az provider register --namespace "${ns}" --wait
done

echo "==> 2/6 Resource group (${RG})"
az group create --name "${RG}" --location "${LOCATION}" --output none

echo "==> 3/6 Azure Container Registry (${ACR_NAME}, Basic SKU, admin user disabled)"
az acr show --name "${ACR_NAME}" >/dev/null 2>&1 || \
  az acr create --resource-group "${RG}" --name "${ACR_NAME}" --sku Basic --admin-enabled false --output none

echo "==> 4/6 AKS cluster (${AKS}) - takes ~5-10 minutes the first time"
az aks show --resource-group "${RG}" --name "${AKS}" >/dev/null 2>&1 || \
  az aks create --resource-group "${RG}" --name "${AKS}" \
    --tier free --node-count "${NODE_COUNT}" --node-vm-size "${NODE_SIZE}" \
    --generate-ssh-keys --attach-acr "${ACR_NAME}" --output none

echo "==> 5/6 App registration + federated credentials (keyless GitHub -> Azure trust)"
APP_ID="$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)"
if [ -z "${APP_ID}" ]; then
  APP_ID="$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)"
fi
az ad sp show --id "${APP_ID}" >/dev/null 2>&1 || az ad sp create --id "${APP_ID}" --output none

create_fic() {  # name subject
  local existing
  existing="$(az ad app federated-credential list --id "${APP_ID}" --query "[?name=='$1'] | length(@)" -o tsv)"
  if [ "${existing}" = "0" ]; then
    az ad app federated-credential create --id "${APP_ID}" --output none --parameters \
      "{\"name\":\"$1\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$2\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
  fi
}
# 'docker' job runs on main (no environment); 'deploy' job runs in the 'production' environment
create_fic github-main "repo:${GITHUB_REPO}:ref:refs/heads/main"
create_fic github-env-production "repo:${GITHUB_REPO}:environment:production"

echo "==> 6/6 Least-privilege role assignments"
SP_OID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)"
ACR_ID="$(az acr show --name "${ACR_NAME}" --query id -o tsv)"
AKS_ID="$(az aks show --resource-group "${RG}" --name "${AKS}" --query id -o tsv)"

assign() {  # role scope
  local n
  n="$(az role assignment list --assignee "${APP_ID}" --role "$1" --scope "$2" --query 'length(@)' -o tsv)"
  if [ "${n}" = "0" ]; then
    az role assignment create --assignee-object-id "${SP_OID}" --assignee-principal-type ServicePrincipal \
      --role "$1" --scope "$2" --output none
  fi
}
assign "AcrPush" "${ACR_ID}"                                          # push images to THIS registry only
assign "Azure Kubernetes Service Cluster Admin Role" "${AKS_ID}"      # fetch kubeconfig for THIS cluster only
assign "Reader" "/subscriptions/${SUB_ID}"                            # read-only, lets 'az acr login' find the registry

cat <<OUT

=====================================================================
 GitHub -> Settings -> Secrets and variables -> Actions
---------------------------------------------------------------------
 SECRETS
   AZURE_CLIENT_ID        ${APP_ID}
   AZURE_TENANT_ID        ${TENANT_ID}
   AZURE_SUBSCRIPTION_ID  ${SUB_ID}
   SONAR_TOKEN            (from sonarcloud.io -> My Account -> Security)
 VARIABLES
   AZURE_RESOURCE_GROUP   ${RG}
   ACR_NAME               ${ACR_NAME}
   AKS_CLUSTER            ${AKS}
   SONAR_ORGANIZATION     (your SonarCloud organization key)
   SONAR_PROJECT_KEY      (your SonarCloud project key)
 ALSO: Settings -> Environments -> New environment named exactly: production
=====================================================================
OUT
