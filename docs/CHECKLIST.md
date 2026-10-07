# End-to-end checklist (fresh Mac → final demo)

Tick each box in order. Details for every item are in [SETUP_GUIDE.md](SETUP_GUIDE.md).

## A. Install (Step 1)
- [ ] `xcode-select --install`
- [ ] Homebrew installed, `brew --version` works (Apple Silicon: `shellenv` line added to `~/.zprofile`)
- [ ] `brew install git gh node@24 && brew link --overwrite --force node@24`
- [ ] `brew install --cask docker-desktop`, Docker Desktop opened, Memory ≥ 4 GB (6 GB better)
- [ ] `brew install jenkins-lts`
- [ ] `git --version`, `node --version` (v24+), `docker info` all work

## B. Project & GitHub (Steps 2-3)
- [ ] Project unzipped to `~/Projects/nexus-artifact-demo`
- [ ] `git config --global user.name/user.email` set
- [ ] `git init && git add . && git commit`; `git status` showed no `.env`/`node_modules`
- [ ] `gh auth login` done
- [ ] `gh repo create nexus-artifact-demo --public --source=. --remote=origin --push`
- [ ] Teammate added as collaborator

## C. App & tests (Steps 4-5)
- [ ] `npm ci` ok
- [ ] `npm start` → http://localhost:3000 works, `/health` = UP → **Ctrl+C to stop**
- [ ] `npm test` → 18 passed

## D. Nexus (Step 6)
- [ ] `docker compose up -d`, log shows "Started Sonatype Nexus"
- [ ] Logged in with `/nexus-data/admin.password`, new admin password saved, anonymous access disabled
- [ ] Repository **`devops-artifacts`**, recipe **raw (hosted)**, **Disable redeploy**
- [ ] Role **`ci-deployer`** with `nx-repository-view-raw-devops-artifacts-*`
- [ ] User **`jenkins-ci`** (Active, role ci-deployer), password saved
- [ ] Manual `curl -u jenkins-ci --upload-file` → **HTTP 201** (then delete the test file)
- [ ] `.env` created from `.env.example` with the jenkins-ci password (NOT committed)
- [ ] `bash scripts/local-pipeline.sh` → "Deployment verified"
- [ ] `docker rm -f nexus-artifact-demo-app`

## E. Jenkins (Step 7)
- [ ] `brew services start jenkins-lts`, unlocked with `~/.jenkins/secrets/initialAdminPassword`
- [ ] Suggested plugins installed, admin user created
- [ ] Stage View / Graph View plugin present
- [ ] Credential **`nexus-credentials`** (Username with password: jenkins-ci / password)
- [ ] Job **`nexus-artifact-demo-pipeline`**: Pipeline script from SCM → Git → repo URL → `*/main` → `Jenkinsfile`

## F. Pipeline (Steps 8-12)
- [ ] **Build Now** → all 9 stages green, `Finished: SUCCESS`
- [ ] Test Result shows 18 passed
- [ ] Nexus Browse shows `nexus-artifact-demo/1.0.1/` with `.tgz` + `build-info.json`
- [ ] `docker images nexus-artifact-demo` shows `1.0.1` + `latest`
- [ ] `docker ps` shows `nexus-artifact-demo-app` **(healthy)** on 3000
- [ ] http://localhost:3000 shows version 1.0.1 and build #1
- [ ] Push a change → build starts automatically ("Started by an SCM change") → 1.0.2 deployed
- [ ] Push a failing test → pipeline stops at tests, no new version in Nexus → revert → green
- [ ] Rollback to an older version tested (Step 12)

## G. Submission
- [ ] All screenshots from [DEMO_AND_VIVA.md](DEMO_AND_VIVA.md#d-screenshots-you-must-take-for-submission) taken
- [ ] README "Testing Results" table filled with your real results; screenshots added to the report
- [ ] Final push to GitHub; repo link ready
- [ ] `git log -p | grep -i password` shows no real passwords

## H. Demo day
- [ ] Docker Desktop → Nexus (`docker compose up -d`) → Jenkins (`brew services start jenkins-lts`) started 10 min early
- [ ] One green build done, browser tabs open, Terminal font enlarged, sleep disabled
- [ ] Demo change prepared (uncommitted)
- [ ] Backup: `bash scripts/local-pipeline.sh`
- [ ] 1-minute explanation memorised
