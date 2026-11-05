# Azure getting started (first-time user, student account)

Goal: from "no cloud account" to "ready to run `scripts/azure-setup.sh`". About 20-30 minutes.

## 1. Claim Azure for Students (no credit card)
1. Open <https://azure.microsoft.com/free/students> and click **Start free**.
2. Sign in with a Microsoft account, then **verify you are a student** with your college email
   (`...@snuchennai.edu.in`). Microsoft emails a code to that address.
3. Complete the short profile and accept the terms. You get **$100 credit for 12 months, no card needed**.

**Which Microsoft account to sign in with?** If the sign-up lets you choose, use a **personal Microsoft account**
(e.g. Outlook/Gmail-linked) and verify with the college email. College-managed accounts often *cannot create
app registrations* (needed by the keyless pipeline login in `azure-setup.sh` step 5). If you sign in with the
college account and step 5 fails with "Insufficient privileges", redo sign-up with a personal Microsoft account.

If the automated student check fails, Microsoft support cannot grant the credit manually. Then your options are
the regular Azure free account ($200 for 30 days, card required).

## 2. Check the subscription and credit
- Portal: <https://portal.azure.com> -> search **Subscriptions** -> you should see **Azure for Students**.
- **Cost Management + Billing -> Credits** shows the remaining $100.
- Never add a credit card or "upgrade" the subscription. Without a card, Azure cannot bill you; when credit runs
  out the subscription is disabled instead.

## 3. Open Cloud Shell (no installs)
Click the **`>_`** icon at the top of the portal, choose **Bash**. When asked about storage, choose
**"No storage account required"**, pick your subscription, **Apply**. (Files you upload last only for the session.)
It has `az`, `kubectl`, `git` and Maven preinstalled and is already logged in.
```bash
az account show --query "{name:name, id:id}" -o table     # confirm: Azure for Students
```

## 4. Upload the project
Cloud Shell toolbar -> **Manage files -> Upload** -> `devops-cicd-azure.zip`, then:
```bash
unzip devops-cicd-azure.zip && cd devops-cicd-azure
chmod +x scripts/*.sh
```

## 5. Create the GitHub repo
On github.com, create an **empty public repo** named `devops-cicd-azure` (any name works; keep it consistent).
Your `GITHUB_REPO` is `<github-username>/<repo-name>` with **exact capitalisation**. Don't push yet.

## 6. Find a region and VM size your student policy allows
Azure for Students restricts deployments to a handful of regions and VM sizes (they differ per person).
Try the defaults first (Central India, `Standard_B2s`). If a step fails with *"disallowed by policy"*:
- Portal -> **Policy -> Assignments** -> the student/regions policy -> **Parameters** shows allowed locations.
- Pick one and re-run, e.g. `LOCATION=southindia ./scripts/azure-setup.sh`.
- For sizes: `az vm list-skus -l <location> --size Standard_B2 -o table` (use ones without restrictions) and set `NODE_SIZE=...`.

## 7. Provision
```bash
export GITHUB_REPO=<github-username>/<repo-name>
./scripts/azure-setup.sh
```
Takes ~10 minutes. Re-running is safe. Copy the block printed at the end (GitHub secrets/variables).

## 8. Check
```bash
az aks list -o table      # ProvisioningState: Succeeded
az acr list -o table
```
Then continue with `docs/SETUP.md`.

## Common first-timer problems
| Problem | Fix |
|---|---|
| `RequestDisallowedByAzure` / policy error | Region or VM size not allowed: see step 6 |
| `Insufficient privileges` creating the app registration | College tenant blocks it: sign up with a personal Microsoft account (step 1) |
| Quota error (`vCPU`, `QuotaExceeded`) | `NODE_COUNT=1 ./scripts/azure-setup.sh` or another allowed VM size/region |
| `SubscriptionNotFound` / no subscription | Student verification not finished; re-check step 1-2 |
| Cloud Shell timed out | Reopen, re-upload if needed, re-export `GITHUB_REPO`, re-run (idempotent) |
