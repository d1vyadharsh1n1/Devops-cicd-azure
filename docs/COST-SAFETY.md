# Cost safety on Azure for Students

## Why you cannot get a surprise bill
- **Azure for Students** = $100 credit for 12 months, **no credit card**, with spending protection.
  With no payment method on file there is nothing to charge. When the credit is used up (or 12 months pass) the
  subscription is disabled, not billed, unless you choose to upgrade and add a card.
- **The one rule: never add a credit card or upgrade to pay-as-you-go.**
- The credit cannot be spent on Azure Marketplace products (this project uses none).

## What uses credit while it runs
| Resource | Notes |
|---|---|
| AKS worker nodes (2 x Standard_B2s VMs) | The main cost. AKS control plane is on the **Free tier** |
| Standard load balancer + public IP | Created by the `LoadBalancer` Service |
| Azure Container Registry (Basic) | Small daily fee |
| Cloud Shell | Free (ephemeral session) |

Rough estimate: a couple of dollars per day while everything is running, so $100 lasts weeks, not months.
Check the real number in **Cost Management + Billing -> Cost analysis**.

## Habits that keep it near zero
- Do the work in a few sittings. Between sessions run `./scripts/azure-pause.sh` (removes the load balancer IP
  and **stops the nodes**). Resume: `az aks start -g rg-cicd-demo -n aks-cicd-demo`, then re-run the pipeline.
- When completely done (after your viva): `./scripts/azure-teardown.sh` deletes everything.
- Optional: Cost Management -> **Budgets** -> $20 with an email alert.

## Confirm nothing is left running (after teardown)
```bash
az group list -o table          # rg-cicd-demo gone (deletion takes a few minutes)
az resource list -o table       # empty
```
GitHub Actions is free for public repos; SonarCloud and Gitleaks are free for public repos / personal accounts.
