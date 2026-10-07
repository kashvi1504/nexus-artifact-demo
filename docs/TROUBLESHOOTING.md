# Troubleshooting

How to read a failed Jenkins build: open the build → **Console Output** (or click the red
stage in Stage View) and scroll to the **first** red error line. The scripts in `scripts/`
print `[FAIL]` with a plain-English reason.

Quick health check of everything:
```bash
docker info >/dev/null && echo "Docker OK"
docker ps --format '{{.Names}}  {{.Status}}  {{.Ports}}'
curl -s -o /dev/null -w "Nexus %{http_code}\n" http://localhost:8081/service/rest/v1/status
curl -s -o /dev/null -w "Jenkins %{http_code}\n" http://localhost:8080/login
curl -s http://localhost:3000/health; echo
brew services list | grep jenkins
```

---

## 1. Docker not running
**Symptoms:** `Cannot connect to the Docker daemon at unix:///.../docker.sock. Is the docker daemon running?`
**Fix:** `open -a Docker`, wait until the whale icon in the menu bar stops animating, re-run.
Turn on *Docker Desktop → Settings → General → Start Docker Desktop when you sign in*.

## 2. Jenkins cannot find docker / node / npm
**Symptoms:** `docker: command not found`, `npm: command not found` (exit code 127) in Checkout.
**Cause:** Jenkins started by `brew services` has a minimal PATH.
**Fix:** the Jenkinsfile already adds `/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin`.
Check where your tools are and add the folder to the `PATH` line if different:
```bash
which node npm docker
```
Alternative: *Manage Jenkins → System → Global properties → Environment variables* →
Name `PATH+EXTRA`, Value `/opt/homebrew/bin:/usr/local/bin`.

## 3. `docker-credential-desktop: executable file not found in $PATH`
**Stage:** Build Docker Image (while pulling `node:24-alpine`).
**Fix:** the Jenkinsfile's PATH includes Docker.app's bin folder, which contains this helper.
If it still happens, edit `~/.docker/config.json` and remove the line `"credsStore": "desktop"`
(or rename it to `"credStore"`), then rebuild.

## 4. Jenkins permission problems
| Symptom | Fix |
|---|---|
| `permission denied while trying to connect to the Docker daemon socket` | Only happens if Jenkins runs as a different user (e.g. Jenkins in Docker). Use the Homebrew Jenkins (`brew services start jenkins-lts`) - it runs as your user. Don't run `sudo brew services ...` |
| `EACCES` / cannot delete workspace files | A previous run as root left files. `sudo rm -rf ~/.jenkins/workspace/nexus-artifact-demo-pipeline` then rebuild |
| `Scripts not permitted to use method ...` | You pasted a script into the job instead of using *Pipeline script from SCM*. Use SCM (Step 7.7) |

## 5. Jenkins cannot connect to Nexus
**Symptom:** `[FAIL] Nexus is not reachable at http://localhost:8081 (HTTP '000')`.
1. `docker ps` - is `nexus` running? If not: `docker compose up -d` (in the project folder).
2. Just started? Wait for `Started Sonatype Nexus` in `docker logs -f nexus` (2-4 min).
3. Container restarting / `Exited (137)` → out of memory → Docker Desktop memory 6 GB.
4. Nexus on another port? Update `NEXUS_URL` in the `Jenkinsfile` (and `.env`).
5. If you ever run Jenkins **inside Docker**, `localhost` means the Jenkins container itself -
   use `http://host.docker.internal:8081` instead.

## 6. Nexus credentials failure
**Symptom:** `Upload ... failed: 401 Unauthorized`.
- Jenkins → Manage Jenkins → Credentials → `nexus-credentials` → *Update* → re-type the password.
- The credential **ID** must be exactly `nexus-credentials`. A different ID gives:
  `ERROR: Could not find credentials entry with ID 'nexus-credentials'`.
- Nexus → Security → Users → `jenkins-ci` → Status must be **Active**.
- Test outside Jenkins: `curl -u jenkins-ci -o /dev/null -w "%{http_code}\n" http://localhost:8081/service/rest/v1/status/check`
  (`200` = credentials OK; `401` = wrong; `403` = OK but not an admin - also fine for this test).
- Forgotten Nexus **admin** password and no other admin: you must reset Nexus data
  (`docker compose down -v && docker compose up -d`) and redo Step 6.

## 7. Nexus repository configuration errors
| Error | Meaning / fix |
|---|---|
| `404 Not Found` on upload | Repo `devops-artifacts` doesn't exist, has a different name, or is not **raw**. Repository URL must be `http://localhost:8081/repository/devops-artifacts/` |
| `403 Forbidden` | Role `ci-deployer` lacks `nx-repository-view-raw-devops-artifacts-*`, or user doesn't have the role |
| `400 Bad Request` | Version already exists + *Disable redeploy*. Happens if you delete/recreate the Jenkins job (build numbers restart at 1). Fix: Job → Configure → *Next build number* plugin, or delete old versions in Nexus, or rename the job and also change the version pattern in `Jenkinsfile` to e.g. `1.1.${env.BUILD_NUMBER}` |
| Repository is *maven2* / *npm* format | Delete it and create **raw (hosted)** |
| "Repository is offline" | Edit repo → tick *Online* |

## 8. npm / build errors
| Error | Fix |
|---|---|
| `npm ci` can only install with an existing package-lock.json | Commit `package-lock.json` (`git add package-lock.json`) |
| `npm ci` lock file out of sync | Run `npm install` locally, commit the updated lock file |
| `ETIMEDOUT` / `ENOTFOUND registry.npmjs.org` | Internet / proxy issue; college Wi-Fi may block npm - try a mobile hotspot |
| `npm version` error `Version not changed` | Only if package.json already has that version - harmless when re-running; the Jenkinsfile runs on a fresh checkout |
| Tests fail only in Jenkins | Run `npm ci && npm test` locally; check Node version printed in Checkout |

## 9. Port already in use
| Port | Who | Find & fix |
|---|---|---|
| 3000 | App | `lsof -i :3000` → stop `npm start` (Ctrl+C) or `kill <PID>`; `docker ps` for other containers on 3000 → `docker rm -f <name>`. Or change `APP_PORT` in the Jenkinsfile |
| 8080 | Jenkins | Another app (e.g. Tomcat). Change Jenkins port (SETUP_GUIDE Step 7, problems table) |
| 8081 | Nexus | `lsof -i :8081`; or map `"8082:8081"` in compose and update `NEXUS_URL` |

Error text looks like `Bind for 0.0.0.0:3000 failed: port is already allocated` or `EADDRINUSE`.

## 10. Docker image build failure
| Error | Fix |
|---|---|
| `"/artifact/app.tgz": not found` | The *Fetch Artifact from Nexus* stage didn't run/succeed. For manual builds run `download-from-nexus.sh` first |
| `failed to resolve source metadata for docker.io/library/node:24-alpine` | No internet / Docker Hub blocked. Try another network; `docker pull node:24-alpine` manually |
| `npm ERR!` during `RUN ... npm install` | Network problem inside Docker; retry. Docker Desktop → Settings → Docker Engine: add `"dns": ["8.8.8.8"]` |
| `no space left on device` | `docker system prune -a` (removes unused images; Nexus data volume is kept) |
| Apple Silicon: `exec format error` | You pulled an amd64-only image. `node:24-alpine` and `sonatype/nexus3` are multi-arch; run `docker pull` again without `--platform` |

## 11. GitHub authentication issues
| Error | Fix |
|---|---|
| `git push`: `Authentication failed` / `Support for password authentication was removed` | Use `gh auth login` (easiest) or a Personal Access Token as the password |
| `remote: Repository not found` | Wrong URL or private repo without access: `git remote -v`, fix with `git remote set-url origin <url>` |
| Jenkins: `Failed to connect to repository : Command "git ls-remote ..." returned status code 128` | Repo is private → add `github-credentials` (token) in Jenkins and select it in the job; check URL ends in `.git` |
| Jenkins: `Couldn't find any revision to build` | Branch is `master` not `main` → set Branch Specifier to `*/master` (or rename branch) |
| `git: command not found` in Jenkins | Run `xcode-select --install`; or Manage Jenkins → Tools → Git → path `/opt/homebrew/bin/git` |

## 12. Jenkins webhook / trigger issues
- **Builds don't start after a push:** polling is registered only **after the first build**
  - run *Build Now* once. Then check *Job → Git Polling Log*.
- Polling interval is ~2 minutes (`H/2`) - wait, or click *Build Now* during the demo.
- **GitHub webhooks** cannot reach `http://localhost:8080` from the internet. Polling is the
  intended solution for this project. *Optional:* `brew install ngrok`, `ngrok http 8080`,
  then GitHub → repo → Settings → Webhooks → Payload URL `https://<id>.ngrok-free.app/github-webhook/`,
  content type `application/json`; in the Jenkinsfile replace `pollSCM(...)` with `githubPush()`
  (needs the GitHub plugin). The ngrok URL changes on each restart.
- Mac went to sleep → Jenkins paused. Keep the lid open / disable sleep during the demo.

## 13. Pipeline stage-specific
| Stage | Typical message | Fix |
|---|---|---|
| Automated Tests | `Tests: 1 failed` | Working as designed. Fix the code/test and push |
| Verify Deployment | `Application did not become healthy` | `docker logs nexus-artifact-demo-app` for the real error |
| Verify Deployment | `Expected version 1.0.5 but the app reports ... 1.0.4` | Old container still on port 3000 (e.g. started by compose or manually). `docker ps`, remove it, rebuild |
| Any | `Timeout has been exceeded` | First run downloads images; increase `timeout(time: 30 ...)` |

## 14. Start completely fresh (last resort)
```bash
docker rm -f nexus-artifact-demo-app
docker compose down -v          # WARNING: deletes Nexus users, repos and artifacts
brew services stop jenkins-lts
mv ~/.jenkins ~/.jenkins.bak    # resets Jenkins (keep the backup until things work)
```
Then redo Steps 6 and 7.
