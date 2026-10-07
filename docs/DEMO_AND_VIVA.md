# HOW TO DEMONSTRATE THIS PROJECT TO THE PROFESSOR

Total time: **about 8 minutes**. Two speakers - split the parts between Kashvi and Rushabh.

## Before the professor arrives (10 minutes earlier)

```bash
open -a Docker                                  # wait until running
cd ~/Projects/nexus-artifact-demo
docker compose up -d                            # Nexus, wait 2-3 min
brew services start jenkins-lts
curl -s -o /dev/null -w "Nexus %{http_code}\n" http://localhost:8081/service/rest/v1/status   # 200
```
- Run one green build in Jenkins so the latest version is deployed.
- Prepare a tiny visible change to push live (e.g. badge text in `src/app.js`), **not yet committed**.
- Open browser tabs: (1) GitHub repo (2) Jenkins job (3) Nexus Browse → devops-artifacts
  (logged in) (4) http://localhost:3000
- One Terminal window in the project folder, font size large (Cmd +).
- Disable Mac sleep, close other apps (Nexus + Jenkins need memory).
- **Backup plan:** if Jenkins fails during the demo, run `bash scripts/local-pipeline.sh` -
  it performs the same stages from the terminal.

---

### 1. Introduction + architecture (1 min)
**Show:** `docs/architecture.png` (or the README on GitHub).
**Say:** "Our project is *Automated Artifact Management Using Nexus Repository*. Every
code change goes from GitHub to Jenkins, is tested, packaged into a versioned artifact,
stored in Nexus, and then deployed as a Docker container built from that exact Nexus
artifact. Nexus is the bridge between build and deployment."

### 2. GitHub repository (45 s)
**Show:** GitHub repo: `src/`, `tests/`, `Jenkinsfile`, `Dockerfile`, `docker-compose.yml`, commit history, `.gitignore`.
**Say:** "All code and the pipeline itself are version-controlled - pipeline as code. The
`.gitignore` keeps `node_modules`, build outputs and `.env` files out of Git, so no
passwords are ever committed. Build outputs are not stored in Git - that's Nexus's job."

### 3. Application (30 s)
**Show:** http://localhost:3000, then `/health` and `/api/calculate?op=add&a=10&b=5`.
**Say:** "A simple Express app. The home page shows the artifact version, the Jenkins build
number, the Git commit and the Nexus URL the artifact was downloaded from - so we can
always prove which build is running."

### 4. Automated tests (30 s)
**Show:** Terminal: `npm test`.
**Say:** "18 Jest tests - unit tests for the logic and API tests with Supertest. If any
test fails, the command returns an error code and Jenkins stops the pipeline."

### 5. Live pipeline run (2 min)
**Do:** commit and push the prepared change:
```bash
git commit -am "Demo change" && git push
```
Then in Jenkins click **Build Now** (don't wait for the 2-minute poll).
**Show:** Stage View filling up; open **Console Output** at *Publish Artifact to Nexus*.
**Say (while it runs):** "Jenkins checks out the code, runs `npm ci`, runs the tests,
then `npm pack` creates `nexus-artifact-demo-1.0.N.tgz` - the version is 1.0 plus the
Jenkins build number, so every build is unique. Now it uploads to Nexus with an HTTP PUT.
Notice the password is shown as stars - it comes from the Jenkins credential store, not
from the code. The script downloads the file back and compares SHA-1 checksums to prove
the upload is correct. Next stage downloads the artifact *from Nexus* and Docker builds
the image from it - Docker cannot even see our source code because of `.dockerignore`.
Finally Jenkins replaces the container and checks `/health`."

### 6. Nexus Repository + uploaded artifact (1.5 min) - the main part
**Show:** Nexus → Administration → Repositories → `devops-artifacts` (raw, hosted, *Disable redeploy*).
Then **Browse → devops-artifacts → nexus-artifact-demo** → several version folders →
open the new version → `.tgz` details (size, SHA-1, uploader `jenkins-ci`) → `build-info.json`.
**Say:** "This is a raw hosted repository. Each build creates a version folder with the
artifact and a build-info file that links it to the Jenkins build and Git commit. Redeploy is
disabled, so version 1.0.5 can never be overwritten. Jenkins uses a dedicated
`jenkins-ci` user that can only access this one repository - least privilege. Anonymous
access is disabled, so downloads also need credentials." Optionally show the curl download
from SETUP_GUIDE Step 10.

### 7. Docker image and running container (45 s)
```bash
docker images nexus-artifact-demo
docker ps
```
**Say:** "The image is tagged with the same version as the Nexus artifact. The container is
running and Docker reports it *healthy* using our `/health` endpoint."

### 8. Deployed application (30 s)
**Show:** refresh http://localhost:3000 - new version + new build number + your change.
**Say:** "The new version is live. Every deployment is traceable: version → Nexus artifact →
Jenkins build → Git commit."

### 9. Failure scenario (1 min, if time permits - impressive)
Show a previously failed build in Jenkins (from SETUP_GUIDE 9.3), or do it live:
```bash
sed -i '' 's/add: (a, b) => a + b/add: (a, b) => a - b/' src/utils/calculator.js
git commit -am "Bug" && git push      # then Build Now
```
**Say:** "Tests fail, the pipeline stops at *Automated Tests*, the later stages are skipped.
No artifact goes to Nexus and the running app is untouched." Then `git revert --no-edit HEAD && git push`.

### 10. Wrap-up (15 s)
**Say:** "So: tested code only, versioned artifacts in Nexus, deployment from Nexus, no
secrets in code, and rollback possible to any version still stored in Nexus. Thank you."

---

# VIVA PREPARATION

## A. 10 likely viva questions

1. **What is the role of Nexus in your project?**
   It stores every tested build of our application as a versioned artifact. Jenkins uploads to
   it after the tests pass, and the deployment downloads the artifact from it. It is the single
   trusted source of deployable builds.

2. **What exactly is your artifact and how is it created?**
   A `.tgz` file created by `npm pack`: `nexus-artifact-demo-1.0.<build>.tgz`. It contains `src/`,
   `package.json` and the README - only what is needed to run the app (no tests, no node_modules).

3. **How do you version artifacts?**
   `1.0.<Jenkins build number>`. Jenkins stamps it with `npm version` before packaging, so each
   build is unique and maps to one Jenkins build and Git commit (recorded in `build-info.json`).

4. **Why a raw repository and not npm or Maven?**
   Raw accepts any file with a simple HTTP PUT, so it is the simplest reliable setup and the
   version folders are easy to see. npm (hosted) with `npm publish` is the next step (future scope).
   Maven is for Java projects.

5. **How does Jenkins authenticate to Nexus without exposing the password?**
   The username/password are stored encrypted in Jenkins as credential `nexus-credentials`.
   `withCredentials` injects them as environment variables only during the Nexus stages,
   Jenkins masks them as `****` in logs, and our script gives them to curl via stdin.

6. **What happens if the same version is uploaded twice?**
   The repository uses *Disable redeploy*, so Nexus returns HTTP 400 - a released version is
   immutable. Our build numbers are unique, so normally this never happens.

7. **How does deployment use the artifact from Nexus?**
   The *Fetch Artifact from Nexus* stage downloads the version from Nexus, verifies the SHA-1,
   and the Dockerfile copies only that file (`.dockerignore` allows nothing else), extracts it
   and installs production dependencies.

8. **How would you roll back?**
   Download an older version from Nexus, build the image and run it (commands in SETUP_GUIDE
   Step 12). Old versions are never deleted or overwritten.

9. **Why did you run Jenkins natively instead of in Docker?**
   Jenkins from Homebrew runs as our macOS user, so it can directly use Docker Desktop, Node.js
   and reach Nexus on localhost. Jenkins in a container would need Docker-socket mounting and
   extra networking - more complexity for no benefit in a lab.

10. **Why poll SCM instead of a webhook?**
    Our Jenkins runs on `localhost`, which GitHub cannot reach from the internet. Polling every
    2 minutes works without exposing the laptop. With a public Jenkins URL (or ngrok) we would
    use a webhook.

Bonus: **What is `npm ci` vs `npm install`?** `npm ci` installs exactly what's in
`package-lock.json` and fails if it doesn't match - reproducible builds for CI.

## B. Key concepts in simple words

**What is DevOps?**
A culture and set of practices where development and operations work together and automate
building, testing and releasing software, so changes reach users faster and more reliably.

**What is CI/CD?**
*Continuous Integration*: every change is automatically built and tested. *Continuous
Delivery/Deployment*: every change that passes is automatically packaged and released to an
environment. Our Jenkins pipeline does both.

**What is an artifact?**
The output of a build that is ready to deploy - e.g. `.tgz`, `.jar`, `.war`, `.exe`, a Docker
image. Ours is `nexus-artifact-demo-1.0.N.tgz`.

**Why do we need Nexus?**
To store artifacts in one secure place with versions, access control, checksums and download
URLs; to avoid rebuilding for each environment; to make releases immutable and allow rollback;
and (with proxy repos) to cache third-party dependencies.

**Nexus vs GitHub**
GitHub stores **source code** and its history (text, diffs, branches, pull requests). Nexus
stores **built binaries** (artifacts) by version. Putting build outputs in Git makes the repo huge
and mixes source with results.

**Nexus vs Docker Hub**
Docker Hub is a public cloud registry for **Docker images only**. Nexus is a self-hosted,
universal repository manager for **many formats** (raw, npm, Maven, PyPI, Docker, ...) that a
company controls itself (private, on its own network). Nexus can even act as a private Docker registry.

**What is Jenkins?**
An open-source automation server. It watches the Git repository and runs the stages defined in
the `Jenkinsfile` (build, test, publish, deploy), showing results and logs for each run.

**Why Docker?**
It packages the app with its runtime (Node.js) and dependencies into an image that runs the same
on any machine - no "works on my machine" problems, easy start/stop/replace, isolation.

**What happens when code is pushed to GitHub?**
Within ~2 minutes Jenkins polling detects the new commit and starts the pipeline: checkout →
install → tests → package → upload to Nexus → download from Nexus → Docker build → deploy →
verify. The new version is live automatically.

**What happens when a test fails?**
`npm test` returns a non-zero exit code, the *Automated Tests* stage turns red, Jenkins marks the
build FAILED and skips all later stages - nothing is published to Nexus and the running app
stays on the last good version. The Test Result page shows which test failed.

**Why should credentials not be hardcoded?**
Anything in code ends up in Git history, which is copied to every clone and (for public repos)
to the whole internet - and is hard to remove. Stored credentials can be rotated without code
changes, are masked in logs, and access can be controlled. That's why we use Jenkins
credentials and a git-ignored `.env`.

## C. 1-minute explanation (memorise)

> "Our project is *Automated Artifact Management Using Nexus Repository*. We built a small
> Node.js Express web app with 18 automated Jest tests, and a complete CI/CD pipeline in
> Jenkins. When we push code to GitHub, Jenkins picks up the change, installs dependencies and
> runs the tests. If any test fails, the pipeline stops. If they pass, Jenkins packages the app
> with npm pack into a versioned artifact - version 1.0 plus the build number - and uploads it to
> a raw hosted repository in Sonatype Nexus, using credentials stored securely in Jenkins.
> Nexus keeps every version, doesn't allow overwriting, and records build information. The
> pipeline then downloads that exact artifact back from Nexus, verifies its checksum, builds a
> Docker image from it and deploys it as a container, and finally checks the health endpoint.
> So every deployment is tested, versioned, traceable to its commit, and can be rolled back to
> any earlier version from Nexus."

## D. Screenshots you MUST take for submission

1. GitHub repository main page (file list) and commit history
2. `npm test` in Terminal - 18 passed
3. Nexus - repository list showing `devops-artifacts` (raw, hosted)
4. Nexus - `devops-artifacts` settings with **Disable redeploy**
5. Nexus - role `ci-deployer` and user `jenkins-ci`
6. Jenkins - credential `nexus-credentials` (password hidden)
7. Jenkins - job configuration (Pipeline script from SCM, repo URL, Jenkinsfile)
8. Jenkins - **Stage View with all 9 stages green**
9. Jenkins - Console Output of *Publish Artifact to Nexus* (HTTP 201, checksum verified, `****`)
10. Jenkins - Test Result (18 tests)
11. Nexus - Browse tree with **several version folders**
12. Nexus - artifact details (path, size, SHA-1, uploader)
13. Nexus - `build-info.json` content
14. Terminal - `docker images nexus-artifact-demo` and `docker ps`
15. Browser - http://localhost:3000 showing version, build, commit, Nexus source
16. Browser - `/health` JSON
17. Jenkins - **failed build** (red tests stage, later stages skipped) + Nexus without that version
18. Jenkins - build history showing "Started by an SCM change"
