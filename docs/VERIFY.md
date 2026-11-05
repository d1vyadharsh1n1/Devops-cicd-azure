# Verification guide: is it implemented, and is it actually working?

Each check has a **command**, the **expected result**, and (where useful) the **screenshot** it gives you
for the assignment deliverables. Set these once:

```bash
export RG=rg-cicd-demo  AKS=aks-cicd-demo  ACR=<your-acr-name>  APP_ID=<AZURE_CLIENT_ID>
az aks get-credentials -g $RG -n $AKS --admin --overwrite-existing
```

---
## A. Local checks (before pushing)

| # | Command | Expected |
|---|---|---|
| A1 | `mvn -B verify` | `BUILD SUCCESS`, `Tests run: 4, Failures: 0`; `target/app.jar` and `target/site/jacoco/index.html` exist |
| A2 | `docker build -t webapp:local . && docker run --rm -p 8080:8080 webapp:local` | Starts in a few seconds |
| A3 | `curl localhost:8080/api/version` | `{"version":"local","message":"Hello from AKS - version 1"}` |
| A4 | `curl localhost:8080/actuator/health/readiness` | `{"status":"UP"}` |
| A5 | `docker run --rm webapp:local id` | `uid=10001(app)` - **not root** |
| A6 | `docker run --rm -it zricethezav/gitleaks:v8.21.2 --version` then `gitleaks detect -v` in the repo | `no leaks found` |

---
## B. Cloud infrastructure exists  *(screenshot: cloud resources & cluster)*

| # | Command | Expected |
|---|---|---|
| B1 | `az aks list -o table` | `aks-cicd-demo` ... `Succeeded` |
| B2 | `az acr list -o table` | Your registry, SKU `Basic` |
| B3 | `az ad app federated-credential list --id $APP_ID --query "[].{name:name,subject:subject}" -o table` | Subjects `repo:<you>/<repo>:ref:refs/heads/main` and `repo:<you>/<repo>:environment:production` - only your repo can log in |
| B4 | `az ad app credential list --id $APP_ID -o table` | **Empty** - proves no client secret/password exists |
| B5 | `az role assignment list --assignee $APP_ID --all --query "[].{role:roleDefinitionName,scope:scope}" -o table` | `AcrPush` (registry), `Azure Kubernetes Service Cluster Admin Role` (cluster), `Reader` (subscription) |

Portal view: **Kubernetes services**, **Container registries**, **Resource groups -> rg-cicd-demo**.


---
## C. Pipeline stages ran and gates work  *(screenshot: successful pipeline run)*

Actions tab → latest run on `main` → all four jobs green:

| Job | What to look at | Proves |
|---|---|---|
| `secret-scan` | Log ends with `no leaks found` | Gitleaks scanned the full history |
| `build-test` | `BUILD SUCCESS`, "Unit test results" summary on the run page, `test-reports` + `app-jar` artifacts | Compile, tests and packaging |
| `build-test` → SonarCloud step | `QUALITY GATE STATUS: PASSED`; project dashboard on sonarcloud.io shows coverage % | SAST / quality gate is enforced (`sonar.qualitygate.wait=true`) |
| `docker` | Trivy table shows 0 fixable HIGH/CRITICAL; push log; summary shows `...webapp@sha256:...` | Image scanned **before** push |
| `deploy` | Ansible `PLAY RECAP ... failed=0`; `deployment "webapp" successfully rolled out`; "New version is serving traffic" | Deploy + verification stage |

---
## D. Image is in the registry  *(screenshot: container image in registry)*

```bash
az acr repository show-tags -n $ACR --repository webapp --orderby time_desc -o table
az acr repository show -n $ACR --image webapp:<git-sha> --query digest -o tsv
```
Expected: `webapp` with a tag equal to the **git commit SHA** and a `sha256:` digest.
Portal: **Container registries -> your registry -> Repositories -> webapp**.


---
## E. Kubernetes deployment is healthy  *(screenshot: pods Running / deployment ready)*

```bash
kubectl -n webapp get deploy,pods,svc,hpa,pdb -o wide
```
Expected: `deployment.apps/webapp   2/2   2   2`, two pods `1/1 Running`, service `EXTERNAL-IP` populated,
HPA with a CPU target, PDB `MIN AVAILABLE 1`.

```bash
# The image running in the cluster is the one in the registry, pinned by digest
kubectl -n webapp get deploy webapp -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
Expected: `...webapp@sha256:<same digest as in D>`.

```bash
kubectl -n webapp rollout history deployment/webapp
```

---
## F. Application reachable  *(screenshot: browser)*

```bash
IP=$(kubectl -n webapp get svc webapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); echo http://$IP
curl -s http://$IP/api/version
curl -s http://$IP/actuator/health
```
Open `http://<IP>` in a browser: the heading **"Hello from AKS - version 1"** and the commit SHA.
Expected: `/api/version` returns the **same SHA as `git rev-parse HEAD`**.

---
## G. Change & redeployment demonstration  *(the key demo)*

1. Edit `src/main/resources/application.properties`:
   `app.message=Hello from AKS - version 2 (via CI/CD)`
2. `git commit -am "Update greeting" && git push` &nbsp;(*screenshot: commit/push*)
3. Actions tab: a new run starts **by itself** within seconds (*screenshot*).
4. When finished, confirm:
```bash
git rev-parse HEAD                                    # new SHA
az acr repository show-tags -n $ACR --repository webapp --orderby time_desc -o table   # new tag present
kubectl -n webapp get pods                            # new pods (AGE = seconds/minutes)
kubectl -n webapp rollout history deployment/webapp   # revision incremented
curl -s http://$IP/api/version                        # new message + new SHA
```
5. Refresh the browser: **"Hello from AKS - version 2 (via CI/CD)"**.

**Zero-downtime proof:** in a second terminal during step 3 run
`while true; do curl -s -o /dev/null -w "%{http_code} " http://$IP/api/version; sleep 0.5; done`
→ you should only ever see `200`.

---
## H. Prove the security gates actually block bad changes (negative tests)

Use throwaway branches + a PR. Never merge them.

**H1. Gitleaks blocks a leaked secret**
```bash
git checkout -b test/leak
echo "aws_access_key_id = \"AKIA$(echo ZXCVBNMQWERTYUI2)\"" > leak.txt   # fake key assembled at run time, so this doc itself holds no key-like text
git add leak.txt
gitleaks detect --no-git --source . -v   # local check: should report a finding, exit code 1
git commit -m "test leak" && git push -u origin test/leak          # open a PR
```
Expected: `secret-scan` job **fails** on the PR and `docker`/`deploy` never run. (GitHub push protection may
block the push itself - that is also a working control.) Clean up: `git checkout main && git branch -D test/leak && git push origin --delete test/leak`.

**H2. Failing unit test blocks the release**
Change an assertion in `HomeControllerTest` to the wrong value, push on a branch/PR → `build-test` fails at `mvn verify`; no image is built.

**H3. SonarCloud quality gate blocks bad code**
Add an obvious bug/vulnerability (e.g. a hard-coded password string `String password = "admin123";` or an unused, untested 100-line method) on a branch → the Sonar step fails with `QUALITY GATE STATUS: FAILED` (or the issue appears in the dashboard under *Issues / Security Hotspots*).

**H4. Trivy blocks a vulnerable image**
Temporarily set `FROM eclipse-temurin:17.0.1_12-jre-alpine` (an old image) in a branch → `docker` job fails at the Trivy step before the push. (Revert afterwards.)

**H5. Deploy verification catches a broken release**
Make the app fail to start (e.g. invalid property) on a branch merged to a test repo → `rollout status` times out, pipeline fails and the old pods keep serving traffic (rolling update with `maxUnavailable: 0`).

**H6. Other repositories cannot deploy to your project (WIF trust)**
In a *different* repo run a workflow that uses your `AZURE_CLIENT_ID` → login fails with `AADSTS70021: No matching federated identity record`, because of check B3.

---
## I. Runtime hardening checks

```bash
POD=$(kubectl -n webapp get pod -l app.kubernetes.io/name=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl -n webapp exec $POD -- id                      # uid=10001 (non-root)
kubectl -n webapp exec $POD -- touch /app/x            # FAILS: read-only file system
kubectl -n webapp exec $POD -- sh -c 'ls /var/run/secrets/kubernetes.io 2>&1'   # no SA token mounted
kubectl get ns webapp --show-labels                    # pod-security.kubernetes.io/enforce=restricted
kubectl -n webapp describe deploy webapp | grep -A3 -E "Liveness|Readiness|Startup|Limits"
```

## J. Self-healing, scaling, rollback

```bash
kubectl -n webapp delete pod $POD && kubectl -n webapp get pods -w   # replacement pod appears; site stays up
kubectl -n webapp rollout undo deployment/webapp                     # instant rollback to previous revision
kubectl -n webapp get hpa                                            # TARGETS shows cpu x%/70%
```

---
## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `azure/login` fails: `AADSTS70021 No matching federated identity record` | Repo name case differs from `GITHUB_REPO`, or the `production` environment doesn't exist / is named differently. Re-run `azure-setup.sh` with the exact repo name and create the environment |
| `az acr login` / push `unauthorized` | Role missing: re-run `azure-setup.sh` (role assignments can take a minute to propagate) |
| `az aks get-credentials` `AuthorizationFailed` | Cluster Admin role not assigned to the app, or still propagating: wait 2 min and re-run the job |
| Pods `ImagePullBackOff` | AKS not attached to ACR: `az aks update -g $RG -n $AKS --attach-acr $ACR` |
| `RequestDisallowedByAzure` during setup | Student policy blocks that region or VM size: see `docs/AZURE-GETTING-STARTED.md` step 6 |
| Pods `Pending` (insufficient cpu/memory) | Nodes full: use a bigger VM size, `NODE_COUNT=3`, or lower the HPA max |
| Sonar: *"You are running CI analysis while Automatic Analysis is enabled"* | Turn Automatic Analysis off in SonarCloud |
| Sonar step skipped | `SONAR_TOKEN` secret missing (step is conditional on it) |
| Gitleaks action asks for a license | Repo is under a GitHub *organization*: add a free `GITLEAKS_LICENSE` secret, or use a personal account |
| Trivy fails on a fresh base image | A fixable HIGH/CRITICAL CVE exists: rebuild with a patched base tag |
| `EXTERNAL-IP <pending>` for minutes | Normal on first deploy (1-3 min); `kubectl -n webapp describe svc webapp` |
| Pod rejected by Pod Security | Manifest changed to run as root / lacks seccomp: keep the `securityContext` blocks |
| `ansible ... kubernetes.core` import error | `pip install kubernetes PyYAML jsonpatch` in the same Python that runs Ansible |
