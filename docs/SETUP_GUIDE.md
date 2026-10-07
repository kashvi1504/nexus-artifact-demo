# Setup Guide - from a fresh Mac to a working pipeline

Project: **Automated Artifact Management Using Nexus Repository**
Team: Kashvi Vora, Rushabh Vora

Follow the steps in order. Every step ends with a **✅ Verify** block - do not continue
until it passes. If something fails, look at the **⚠️ Common problems** of that step, or
the full [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Recommended architecture (and why)

| Decision | Choice | Why it is the simplest reliable option |
|---|---|---|
| App stack | Node.js + Express, Jest, npm | Preferred stack; tiny code base, fast tests |
| Artifact | `npm pack` → `nexus-artifact-demo-1.0.<build>.tgz` | One standard command, one clear file |
| Nexus repository | **raw (hosted)**, upload with `curl` | One HTTP PUT; no npm realms/tokens/.npmrc to configure |
| Nexus runtime | Docker container (`docker-compose.yml`) | One command, no Java install, data kept in a volume |
| Jenkins runtime | **Native via Homebrew** (`jenkins-lts`) | Runs as your Mac user → can use Docker Desktop, Node and `localhost:8081` directly. Jenkins-inside-Docker needs Docker-socket mounting, a Docker CLI and Node inside the container, and `host.docker.internal` networking - much more to go wrong |
| Trigger | Poll SCM every 2 min | GitHub webhooks cannot reach `localhost` without a tunnel |
| Deployment | Docker container on the Mac, port 3000 | Free, reliable during the demo, same image could run anywhere |

Ports used: **Jenkins 8080**, **Nexus 8081**, **App 3000**.

---

## STEP 1 - Install prerequisites

Open **Terminal** (Cmd+Space → "Terminal").

### 1.1 Apple command-line tools (gives you `git`)
```bash
xcode-select --install
```
Click *Install* in the pop-up. If it says "already installed", that's fine.

### 1.2 Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
At the end Homebrew prints "Next steps". On **Apple Silicon (M1/M2/M3/M4)** run:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```
(On Intel Macs Homebrew lives in `/usr/local` and is already on the PATH.)

### 1.3 Git, Node.js, GitHub CLI
```bash
brew install git gh
brew install node@24
brew link --overwrite --force node@24
```
`node@24` is the current Node.js LTS line and matches the Docker base image `node:24-alpine`.
*Fallback:* if `brew link` complains, use `brew install node` (latest Node works too).

### 1.4 Docker Desktop
```bash
brew install --cask docker-desktop
```
*Fallback (older Homebrew):* `brew install --cask docker`, or download from
https://www.docker.com/products/docker-desktop/ (choose Apple Silicon or Intel).

Then **open Docker Desktop** from Applications, accept the terms, skip sign-in.
Go to **Settings → Resources** and set **Memory to at least 4 GB (6 GB recommended)** -
Nexus needs it. Click *Apply & restart*.

### 1.5 Jenkins (brings Java 21 automatically)
```bash
brew install jenkins-lts
```
Java is needed **only** for Jenkins. Nexus runs in Docker and includes its own Java.

### ✅ Verify Step 1
```bash
git --version            # git version 2.x
node --version           # v24.x (or newer)
npm --version            # 10.x or 11.x
docker --version         # Docker version 2x.x
docker info >/dev/null && echo "Docker is running"
gh --version
brew list jenkins-lts && echo "Jenkins installed"
```

### ⚠️ Common problems
| Problem | Fix |
|---|---|
| `brew: command not found` | Run the two `shellenv` lines from 1.2, then open a new Terminal tab |
| `node: command not found` after installing node@24 | `brew link --overwrite --force node@24`, open a new tab |
| `Cannot connect to the Docker daemon` | Docker Desktop is not running - open it and wait for the whale icon to stop animating |

---

## STEP 2 - Create the project

### 2.1 Put the project files in place
Unzip `nexus-artifact-demo.zip` (it contains every file listed in Step 3) into a projects folder:
```bash
mkdir -p ~/Projects
cd ~/Projects
unzip ~/Downloads/nexus-artifact-demo.zip      # creates ~/Projects/nexus-artifact-demo
cd nexus-artifact-demo
ls -la
```

### 2.2 Configure Git and initialise the repository
```bash
git config --global user.name  "Kashvi Vora"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main

git init
git add .
git status            # check: NO .env, node_modules, dist or artifact folders listed
git commit -m "Initial commit: Nexus artifact management DevOps project"
```

### 2.3 Create the GitHub repository and push
The easiest login method is the GitHub CLI (it handles authentication for `git push` too):
```bash
gh auth login
#  -> GitHub.com -> HTTPS -> Yes (authenticate Git) -> Login with a web browser
gh repo create nexus-artifact-demo --public --source=. --remote=origin --push
```
**Public** is recommended: Jenkins can clone it without credentials and the professor can view it.
(For a private repo see Step 7.6.)

*Fallback without gh:* create an empty repo named `nexus-artifact-demo` on github.com
(no README), then:
```bash
git remote add origin https://github.com/<your-username>/nexus-artifact-demo.git
git push -u origin main      # password = a Personal Access Token, not your GitHub password
```

### ✅ Verify Step 2
```bash
git log --oneline            # shows your commit
git remote -v                # shows github.com/<you>/nexus-artifact-demo
gh repo view --web           # opens the repo in the browser
```
Add your teammate: GitHub repo → **Settings → Collaborators → Add people**.

---

## STEP 3 - Project files

Every file is complete and already in the project folder. Open the folder in an editor
(`code .` if you use VS Code) to read them.

| File | Purpose |
|---|---|
| `package.json` | App metadata, version, dependencies, `npm test`/`npm start` scripts, Jest config (JUnit report). `"files": ["src/"]` controls what goes into the artifact. |
| `package-lock.json` | Exact dependency versions, used by `npm ci` (must be committed). |
| `src/app.js` | Express application: home page, `/health`, `/api/info`, `/api/calculate`, 404 handler. Exported so tests can call it without a real server. |
| `src/server.js` | Starts the server on `PORT` (default 3000), graceful shutdown for `docker stop`. |
| `src/utils/calculator.js` | Small business logic (add/subtract/multiply/divide with validation) for unit tests. |
| `tests/calculator.test.js` | 9 unit tests for the calculator. |
| `tests/app.test.js` | 9 API tests using Supertest. |
| `scripts/common.sh` | Shared helpers: Nexus URL/repo defaults, credential handling, SHA-1, readable HTTP error messages. |
| `scripts/publish-to-nexus.sh` | Uploads the `.tgz` and `build-info.json` to Nexus, then downloads it back and compares checksums. |
| `scripts/download-from-nexus.sh` | Downloads a given version from Nexus into `artifact/app.tgz` and verifies its checksum. |
| `scripts/verify-deployment.sh` | Waits for `/health` = UP, checks the version and calls the API. |
| `scripts/local-pipeline.sh` | Runs all pipeline stages from the terminal (to test before Jenkins, or as a demo backup). |
| `Jenkinsfile` | The 9-stage CI/CD pipeline. |
| `Dockerfile` | Builds the runtime image from the Nexus artifact on `node:24-alpine`. |
| `.dockerignore` | Allow-list: Docker can only see `artifact/app.tgz`. |
| `docker-compose.yml` | Runs Nexus Repository on port 8081 with a persistent volume. |
| `.env.example` | Template of variables for manual runs. Copy to `.env` (git-ignored). |
| `.gitignore` | Keeps dependencies, build output and secrets out of Git. |
| `README.md` | Project documentation (21 sections). |
| `docs/*` | This guide, troubleshooting, demo & viva notes, checklist, architecture diagram. |

### ✅ Verify Step 3
```bash
ls src tests scripts docs
cat .gitignore | grep -E "^\.env$|node_modules"     # both lines must exist
```

---

## STEP 4 - Run the application locally

```bash
cd ~/Projects/nexus-artifact-demo
npm ci          # installs exact versions from package-lock.json (creates node_modules/)
npm start
```
Expected output:
```
> nexus-artifact-demo@1.0.0 start
> node src/server.js

nexus-artifact-demo v1.0.0 listening on http://localhost:3000
```
Open http://localhost:3000 - you see the project title, team, and a table where
*Jenkins build* and *Git commit* say `local` (they will show real values after Jenkins deploys it).

In a **second Terminal tab**:
```bash
curl http://localhost:3000/health
# {"status":"UP","version":"1.0.0","uptimeSeconds":5,"timestamp":"..."}

curl "http://localhost:3000/api/calculate?op=add&a=10&b=5"
# {"op":"add","a":10,"b":5,"result":15}

curl "http://localhost:3000/api/calculate?op=divide&a=1&b=0"
# {"error":"Division by zero is not allowed"}
```
Stop the server with **Ctrl+C** in the first tab. **Important:** stop it before running the
pipeline, otherwise port 3000 is busy.

### ✅ Verify Step 4
The three `curl` commands return the JSON shown above.

### ⚠️ Common problems
| Problem | Fix |
|---|---|
| `EADDRINUSE: address already in use :::3000` | `lsof -i :3000` then `kill <PID>`, or `PORT=3100 npm start` |
| `npm ci` error about lock file | Run `npm install` once, commit the new `package-lock.json` |
| `Cannot find module 'express'` | You skipped `npm ci` |

---

## STEP 5 - Run automated tests

```bash
npm test
```
Expected result:
```
PASS tests/app.test.js
PASS tests/calculator.test.js

Test Suites: 2 passed, 2 total
Tests:       18 passed, 18 total
Snapshots:   0 total
Time:        ~1 s
Ran all test suites.
```
A JUnit report is written to `reports/junit.xml` (Jenkins reads it). Optional coverage:
`npm run test:coverage`.

**See what a failure looks like** (you will use this in the demo):
```bash
# temporarily break the add operation
sed -i '' 's/add: (a, b) => a + b/add: (a, b) => a - b/' src/utils/calculator.js
npm test ; echo "exit code = $?"        # tests FAIL, exit code = 1
git checkout src/utils/calculator.js    # undo the change
npm test                                # 18 passed again
```

### ✅ Verify Step 5
`Tests: 18 passed, 18 total` and `ls reports/junit.xml` exists.

---

## STEP 6 - Set up Nexus Repository

### 6.1 Start Nexus
Make sure Docker Desktop is running, then from the project folder:
```bash
docker compose up -d
docker logs -f nexus
```
Wait **2-4 minutes** until the log shows a line like
`Started Sonatype Nexus COMMUNITY 3.x.x`. Press **Ctrl+C** to stop following the log
(Nexus keeps running).

Check that it answers:
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/service/rest/v1/status
# 200
```

### 6.2 First login
Get the generated admin password:
```bash
docker exec nexus cat /nexus-data/admin.password ; echo
```
Open **http://localhost:8081** → **Sign in** (top-right) → username `admin`, password from above.
The setup wizard opens:

1. **Next**
2. **New password** - choose an admin password and write it down (never commit it).
3. **Configure Anonymous Access** - choose **Disable anonymous access** (only logged-in
   users can read artifacts - more secure, and it shows that credentials really matter).
4. If your version shows a **licence / EULA / usage** screen, accept it (Community Edition is free).
5. **Finish**.

(The `admin.password` file is deleted automatically after the wizard.)

### 6.3 Create the artifact repository
1. Click the **gear icon** (Administration) in the top bar.
2. **Repository → Repositories → Create repository**.
3. Choose recipe **`raw (hosted)`**.
4. Settings:

| Field | Value |
|---|---|
| Name | `devops-artifacts` (exactly - the Jenkinsfile uses it) |
| Online | ✔ |
| Blob store | `default` |
| Strict Content Type Validation | leave default |
| **Deployment policy** | **Disable redeploy** |

5. **Create repository**.

*Repository type explained:* **hosted** = Nexus stores files we upload (as opposed to
*proxy* = cache of an external repo, *group* = several repos behind one URL).
**raw** = any file type, stored at the path we choose. *Disable redeploy* = once
`1.0.5` is uploaded it can never be overwritten, so a version always means the same file.

### 6.4 Create a dedicated CI role and user (least privilege)
Jenkins should not use the admin account.

**Role:** Administration → **Security → Roles → Create role**
- Type: **Nexus role**
- Role ID: `ci-deployer`
- Role name: `CI deployer`
- Privileges: search `devops-artifacts` and add **`nx-repository-view-raw-devops-artifacts-*`**
  (= browse, read, add, edit on this repository only)
- **Save**

**User:** Administration → **Security → Users → Create local user**
- ID: `jenkins-ci`
- First name `Jenkins`, Last name `CI`, Email `jenkins-ci@example.com`
- Password: choose one (avoid spaces), write it down - **this goes into Jenkins later**
- Status: **Active**
- Roles: move **`ci-deployer`** to *Granted*
- **Create local user**

### 6.5 Test the upload manually (proves repo + user + permissions)
```bash
echo "hello nexus" > /tmp/hello.txt
curl -u jenkins-ci -w "\nHTTP %{http_code}\n" --upload-file /tmp/hello.txt \
  http://localhost:8081/repository/devops-artifacts/test/hello.txt
# curl asks for the password -> HTTP 201
```
In Nexus: **Browse** (cube icon) → `devops-artifacts` → `test/hello.txt` is there.
Delete it: select the file → **Delete asset** (as admin).

### 6.6 Run the whole pipeline once WITHOUT Jenkins (recommended)
This proves Nexus, Docker and the scripts work before adding Jenkins:
```bash
cp .env.example .env
open -e .env               # set NEXUS_PASSWORD=<the jenkins-ci password>, save
bash scripts/local-pipeline.sh
```
You will see the stages run and finish with `Deployment verified`. The version looks like
`1.0.0-local.1728212345`. Open http://localhost:3000.
Then stop that container so Jenkins can use port 3000 later (Jenkins replaces it anyway):
```bash
docker rm -f nexus-artifact-demo-app
```

### Where the artifact appears
Nexus → **Browse** → `devops-artifacts` →
```
nexus-artifact-demo/
  1.0.<build>/
    nexus-artifact-demo-1.0.<build>.tgz
    build-info.json
```
Direct URL pattern:
`http://localhost:8081/repository/devops-artifacts/nexus-artifact-demo/<version>/nexus-artifact-demo-<version>.tgz`

### ✅ Verify Step 6
- `curl ... /service/rest/v1/status` → `200`
- Manual upload in 6.5 → `HTTP 201`
- `local-pipeline.sh` ended with `Deployment verified`

### ⚠️ Common problems
| Problem | Fix |
|---|---|
| Browser "can't connect" to 8081 | Nexus still starting - `docker logs -f nexus`, wait for "Started Sonatype Nexus" |
| Container keeps restarting / exit code 137 | Not enough memory: Docker Desktop → Settings → Resources → Memory 6 GB |
| `admin.password: No such file` | Wizard already completed (file is deleted). Use your new admin password. Forgotten? `docker compose down -v` deletes ALL Nexus data, then start again |
| Upload `HTTP 401` | Wrong user/password, or user status not Active |
| Upload `HTTP 403` | User has no `nx-repository-view-raw-devops-artifacts-*` privilege |
| Upload `HTTP 404` | Repo name is not exactly `devops-artifacts`, or it is not a *raw* repo |
| Upload `HTTP 400` | That exact path/version already exists and *Disable redeploy* is on - expected behaviour |
| Port 8081 in use | `lsof -i :8081`; or change compose to `"8082:8081"` **and** `NEXUS_URL` in Jenkinsfile/.env |

---

## STEP 7 - Set up Jenkins

### 7.1 Start Jenkins
```bash
brew services start jenkins-lts
```
Wait ~30 s, open **http://localhost:8080**. Get the unlock password:
```bash
cat ~/.jenkins/secrets/initialAdminPassword
```
*Fallback (if not found):* `find ~ -name initialAdminPassword -path "*secrets*" 2>/dev/null`

### 7.2 First-time wizard
1. Paste the password → **Continue**.
2. **Install suggested plugins** (takes a few minutes).
3. Create the first admin user (e.g. `admin` + a password you remember).
4. Jenkins URL: keep `http://localhost:8080/` → **Save and Finish → Start using Jenkins**.

### 7.3 Required plugins
**Manage Jenkins → Plugins → Installed plugins** - check these exist (all come with
"suggested plugins"):

| Plugin | Used for |
|---|---|
| Pipeline | `Jenkinsfile` support |
| Git | Cloning from GitHub |
| Credentials Binding | `withCredentials(...)` for Nexus credentials |
| JUnit | Test Result page |
| Pipeline: Stage View *or* Pipeline Graph View | Coloured stage view for the demo |

If the stage view is missing: **Available plugins** → search **"Pipeline: Stage View"** (or
"Pipeline Graph View") → Install → restart Jenkins (`brew services restart jenkins-lts`).

### 7.4 Add the Nexus credential (this is how Jenkins connects to Nexus)
**Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**

| Field | Value |
|---|---|
| Kind | **Username with password** |
| Scope | Global |
| Username | `jenkins-ci` |
| Password | the jenkins-ci password from Step 6.4 |
| ID | **`nexus-credentials`** (must match the Jenkinsfile) |
| Description | Nexus CI user |

**Create**. Jenkins stores it encrypted. The Jenkinsfile only contains the ID.

How the connection works: the Jenkinsfile sets `NEXUS_URL = 'http://localhost:8081'`.
Because Jenkins runs directly on the Mac, `localhost:8081` reaches the Nexus container
through the port published in `docker-compose.yml`. `withCredentials` puts the username and
password into `NEXUS_USER` / `NEXUS_PASSWORD` only during the Nexus stages.

### 7.5 How Jenkins uses Docker and Node
Homebrew's Jenkins runs **as your macOS user**, so it already has permission to use Docker
Desktop - no `docker` group or socket changes needed. The only issue is PATH (services
don't get your shell PATH); the Jenkinsfile fixes this by adding `/opt/homebrew/bin`,
`/usr/local/bin` and Docker Desktop's bin folder.

### 7.6 Connect Jenkins to GitHub
- **Public repository (recommended):** nothing to configure.
- **Private repository:** GitHub → Settings → Developer settings → **Personal access tokens →
  Fine-grained token** → only this repo → *Contents: Read-only* → Generate.
  In Jenkins add a credential: Kind *Username with password*, Username = your GitHub
  username, Password = the token, ID `github-credentials`. Select it in 7.7.

### 7.7 Create the pipeline job
1. Dashboard → **New Item**
2. Name: `nexus-artifact-demo-pipeline` → **Pipeline** → **OK**
3. **Description:** "GitHub → Test → Package → Nexus → Docker → Deploy"
4. Scroll to **Pipeline**:

| Field | Value |
|---|---|
| Definition | **Pipeline script from SCM** |
| SCM | **Git** |
| Repository URL | `https://github.com/<your-username>/nexus-artifact-demo.git` |
| Credentials | *- none -* (public) or `github-credentials` (private) |
| Branch Specifier | `*/main` |
| Script Path | `Jenkinsfile` |
| Lightweight checkout | ✔ |

5. **Save**.

You do **not** need to tick "Poll SCM" in the job: the `triggers { pollSCM(...) }` block in
the Jenkinsfile registers it automatically **after the first build**.

### ✅ Verify Step 7
- http://localhost:8080 shows the job `nexus-artifact-demo-pipeline`
- Credentials page lists `nexus-credentials` (password shown as `****`)

### ⚠️ Common problems
| Problem | Fix |
|---|---|
| http://localhost:8080 not loading | `brew services list` → jenkins-lts must be `started`; `brew services restart jenkins-lts`; `brew services info jenkins-lts` shows errors; or run it in the foreground to see the log: `brew services stop jenkins-lts && jenkins-lts` (Ctrl+C to stop) |
| Port 8080 already used | Edit `$(brew --prefix)/opt/jenkins-lts/homebrew.mxcl.jenkins-lts.plist`, change `--httpPort=8080` to `8090`, `brew services restart jenkins-lts` |
| Plugin install failures | Manage Jenkins → Plugins → Available → retry; check internet |
| Unlock password file missing | Jenkins already initialised - log in with the admin you created |

---

## STEP 8 - The Jenkinsfile explained

| Part / stage | What it does, in simple terms |
|---|---|
| `agent any` | Run on the Jenkins machine itself (your Mac). |
| `options` | Keep 15 old builds, never run two builds at once, abort after 20 minutes. |
| `triggers { pollSCM('H/2 * * * *') }` | Every ~2 minutes Jenkins asks GitHub "any new commit?" and builds if yes. |
| `environment` | Settings for all stages: PATH fix for macOS, app name, **version `1.0.${BUILD_NUMBER}`**, Nexus URL/repo, **credential ID** (not the password), container name, port. |
| **1. Checkout** | Downloads the code from GitHub, stores the short commit ID, prints node/npm/docker versions (proves the tools are found). |
| **2. Install Dependencies** | `npm ci` - clean install of the exact versions in `package-lock.json`. |
| **3. Automated Tests** | `npm test` runs Jest. Any failing test → non-zero exit → stage red → **pipeline stops**. The JUnit report is always published (even on failure). |
| **4. Build / Package** | `npm version 1.0.N` stamps the version into `package.json` (workspace only); `npm pack` creates `dist/nexus-artifact-demo-1.0.N.tgz` and lists its contents. |
| **5. Publish Artifact to Nexus** | `withCredentials` injects the Nexus user/password (masked as `****` in logs). `publish-to-nexus.sh` checks Nexus is up, uploads the `.tgz` and `build-info.json` with HTTP PUT, then downloads it back and compares SHA-1. |
| **6. Fetch Artifact from Nexus** | Deletes local build output, downloads version 1.0.N **from Nexus** into `artifact/app.tgz` and verifies its checksum. |
| **7. Build Docker Image** | `docker build` from the Nexus artifact; tags `nexus-artifact-demo:1.0.N` and `:latest`. |
| **8. Deploy Application** | Removes the old container, starts the new one on port 3000, passing build number, commit and Nexus URL as environment variables. |
| **9. Verify Deployment** | `verify-deployment.sh` waits for `/health` = UP, checks the version is 1.0.N, tests the API and home page. |
| `post` | Prints a success summary or a failure message; always prunes dangling Docker images. |

---

## STEP 9 - Run the complete pipeline

Before running: Docker Desktop running, Nexus running (`docker ps` shows `nexus`), nothing
else on port 3000.

### 9.1 First run (manual)
Jenkins → `nexus-artifact-demo-pipeline` → **Build Now**.
Click the build number (**#1**) → **Console Output** to watch, or look at the Stage View.

What you should see:

| Stage | Look for in the console |
|---|---|
| Checkout | `Building nexus-artifact-demo version 1.0.1 from commit abc1234`, then node/npm/docker versions |
| Install Dependencies | `added NNN packages` |
| Automated Tests | `Tests: 18 passed, 18 total` |
| Build / Package | `nexus-artifact-demo-1.0.1.tgz` and the 5 files inside it |
| Publish Artifact to Nexus | `Nexus is up`, `Uploaded ... (HTTP 201)` twice, `Verified: the copy stored in Nexus is identical...` |
| Fetch Artifact from Nexus | `Downloaded to artifact/app.tgz`, `Checksum verified` |
| Build Docker Image | Docker build steps, then `docker images` listing `1.0.1` and `latest` |
| Deploy Application | container ID, `docker ps` row with `0.0.0.0:3000->3000/tcp` |
| Verify Deployment | `Health check`, `Running version is 1.0.1`, `Deployment verified` |
| End | `PIPELINE SUCCESS` box, `Finished: SUCCESS` |

The first run takes longer (downloads `node:24-alpine`).

### 9.2 Automatic run on a code change
```bash
# make a visible change, e.g. in src/app.js change 'RUNNING' to 'RUNNING v2'
git add . && git commit -m "Update status badge" && git push
```
Within ~2 minutes build **#2** starts by itself (*"Started by an SCM change"*). It creates
version **1.0.2** in Nexus and redeploys. Refresh http://localhost:3000 - new version and build number.

### 9.3 Failing-test run (shows the quality gate)
```bash
sed -i '' 's/add: (a, b) => a + b/add: (a, b) => a - b/' src/utils/calculator.js
git commit -am "Introduce a bug (demo)" && git push
```
Build #3 turns **red at Automated Tests**; *Build/Package, Publish, Docker, Deploy* are
**skipped**. Nexus has **no 1.0.3**, and http://localhost:3000 still runs 1.0.2.
Fix it:
```bash
git revert --no-edit HEAD && git push
```
Build #4 is green → version 1.0.4 deployed.

### ✅ Verify Step 9
Build is blue/green, console ends with `Finished: SUCCESS`, **Test Result** link shows 18 passed.

---

## STEP 10 - Verify Nexus

### In the browser
1. http://localhost:8081 → sign in.
2. **Browse** (cube icon) → **devops-artifacts**.
3. Expand `nexus-artifact-demo` → `1.0.1` → click `nexus-artifact-demo-1.0.1.tgz`.
4. The right panel shows **Path, Size, Content type, Last modified, Uploader (`jenkins-ci`)**
   and checksums. The **Path** is a download link.
5. Click `build-info.json` → shows build number, Jenkins URL, commit, SHA-1, time.

### From the terminal
```bash
# list all files in the repository (REST API)
curl -s -u jenkins-ci "http://localhost:8081/service/rest/v1/search/assets?repository=devops-artifacts" \
  | grep -E '"(path|downloadUrl)"'

# download a specific version
curl -u jenkins-ci -O \
  http://localhost:8081/repository/devops-artifacts/nexus-artifact-demo/1.0.1/nexus-artifact-demo-1.0.1.tgz
tar -tzf nexus-artifact-demo-1.0.1.tgz
```
Anonymous access is disabled, so without `-u` you get **401** - that's correct.

### ✅ Verify Step 10
Version folders for every successful build exist; no folder for the failed build.

---

## STEP 11 - Verify Docker

```bash
docker images nexus-artifact-demo
# REPOSITORY            TAG      IMAGE ID   CREATED         SIZE
# nexus-artifact-demo   1.0.2    ...        2 minutes ago   ~1xx MB
# nexus-artifact-demo   latest   ...        (same ID)

docker ps
# nexus-artifact-demo-app   Up 2 minutes (healthy)   0.0.0.0:3000->3000/tcp
# nexus                     Up 1 hour                0.0.0.0:8081->8081/tcp

docker logs nexus-artifact-demo-app
# nexus-artifact-demo v1.0.2 listening on http://localhost:3000

docker inspect --format '{{.State.Health.Status}}' nexus-artifact-demo-app     # healthy
docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' nexus-artifact-demo:latest
```

**Run a container yourself** (e.g. an older version, side by side, on port 3001):
```bash
docker run -d --name demo-manual -p 3001:3000 nexus-artifact-demo:1.0.1
open http://localhost:3001
docker rm -f demo-manual
```

---

## STEP 12 - Verify deployment

| URL | Expected |
|---|---|
| http://localhost:3000 | Home page with **Artifact version 1.0.N**, **Jenkins build #N**, commit, and the Nexus URL in *Artifact source* |
| http://localhost:3000/health | `{"status":"UP","version":"1.0.N",...}` |
| http://localhost:3000/api/info | Build info JSON |
| http://localhost:3000/api/calculate?op=multiply&a=6&b=7 | `"result":42` |

```bash
bash scripts/verify-deployment.sh http://localhost:3000
curl -s http://localhost:3000/api/info
```

### Rollback to an older version from Nexus (great for the viva)
```bash
cd ~/Projects/nexus-artifact-demo
set -a; . ./.env; set +a                             # loads jenkins-ci credentials
bash scripts/download-from-nexus.sh 1.0.1 artifact/app.tgz
docker build -t nexus-artifact-demo:1.0.1 .
docker rm -f nexus-artifact-demo-app
docker run -d --name nexus-artifact-demo-app -p 3000:3000 nexus-artifact-demo:1.0.1
bash scripts/verify-deployment.sh http://localhost:3000 1.0.1
```
The next Jenkins build deploys the newest version again.

---

## Daily start / stop

```bash
# start (after a reboot)
open -a Docker                       # wait until Docker is running
cd ~/Projects/nexus-artifact-demo
docker compose up -d                 # Nexus (wait 2-3 min)
brew services start jenkins-lts      # Jenkins
docker start nexus-artifact-demo-app 2>/dev/null   # last deployed app (restarts automatically too)

# stop
brew services stop jenkins-lts
docker compose stop
docker stop nexus-artifact-demo-app
```
Never run `docker compose down -v` unless you want to **delete all Nexus data**.
