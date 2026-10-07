// =============================================================================
// Jenkinsfile - CI/CD pipeline for "Automated Artifact Management Using Nexus
// Repository" (Kashvi Vora & Rushabh Vora)
//
// Flow: Checkout -> Install -> Test -> Package -> Publish to Nexus
//       -> Fetch from Nexus -> Docker Build -> Deploy -> Verify
//
// If any stage fails, Jenkins stops and the later stages are SKIPPED, so a
// failing test can never publish an artifact or deploy the application.
// =============================================================================
pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '15'))
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }

    // Check GitHub for new commits every ~2 minutes. (Local Jenkins cannot
    // receive GitHub webhooks without a tunnel, so polling is the reliable choice.)
    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        // Jenkins installed with Homebrew does not see the normal macOS PATH.
        // /opt/homebrew/bin  = Homebrew on Apple Silicon (node, npm, git)
        // /usr/local/bin     = Homebrew on Intel Macs + Docker CLI symlink
        // Docker.app/.../bin = docker + docker-credential-desktop
        PATH = "/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:${env.PATH}"

        APP_NAME             = 'nexus-artifact-demo'
        // Every build gets a unique, traceable version: 1.0.<jenkins build number>
        APP_VERSION          = "1.0.${env.BUILD_NUMBER}"

        NEXUS_URL            = 'http://localhost:8081'
        NEXUS_REPO           = 'devops-artifacts'
        // ID of the "Username with password" credential created in Jenkins.
        // The actual username/password are stored encrypted in Jenkins, not here.
        NEXUS_CREDENTIALS_ID = 'nexus-credentials'

        CONTAINER_NAME       = 'nexus-artifact-demo-app'
        APP_PORT             = '3000'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                echo "Building ${APP_NAME} version ${APP_VERSION} from commit ${env.GIT_SHORT}"
                sh 'node --version && npm --version && docker --version'
            }
        }

        stage('Install Dependencies') {
            steps {
                // npm ci = clean, exact install from package-lock.json
                sh 'npm ci --no-audit --no-fund'
            }
        }

        stage('Automated Tests') {
            steps {
                // Non-zero exit code if any test fails -> the pipeline stops here
                sh 'npm test'
            }
            post {
                always {
                    // Shows the test results/trend in Jenkins (JUnit plugin)
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        stage('Build / Package') {
            steps {
                // Stamp the build version into package.json (workspace copy only, no git commit)
                sh 'npm version "$APP_VERSION" --no-git-tag-version'
                // npm pack -> dist/nexus-artifact-demo-<version>.tgz  (this is our ARTIFACT)
                sh '''
                    rm -rf dist && mkdir -p dist
                    npm pack --pack-destination dist
                    echo "Artifact created:"
                    ls -l dist
                    tar -tzf "dist/${APP_NAME}-${APP_VERSION}.tgz"
                '''
            }
        }

        stage('Publish Artifact to Nexus') {
            steps {
                // Injects NEXUS_USER / NEXUS_PASSWORD only for this block; Jenkins masks them in the log
                withCredentials([usernamePassword(credentialsId: "${NEXUS_CREDENTIALS_ID}",
                                                  usernameVariable: 'NEXUS_USER',
                                                  passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh 'GIT_COMMIT="$GIT_SHORT" bash scripts/publish-to-nexus.sh "dist/${APP_NAME}-${APP_VERSION}.tgz"'
                }
            }
        }

        stage('Fetch Artifact from Nexus') {
            steps {
                // Deployment uses the copy STORED IN NEXUS, not the local build output
                sh 'rm -rf artifact dist'
                withCredentials([usernamePassword(credentialsId: "${NEXUS_CREDENTIALS_ID}",
                                                  usernameVariable: 'NEXUS_USER',
                                                  passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh 'bash scripts/download-from-nexus.sh "$APP_VERSION" artifact/app.tgz'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      --build-arg APP_VERSION="$APP_VERSION" \
                      -t "$APP_NAME:$APP_VERSION" \
                      -t "$APP_NAME:latest" \
                      .
                    docker images "$APP_NAME"
                '''
            }
        }

        stage('Deploy Application') {
            steps {
                sh '''
                    # Replace the previous version (if any) with the new one
                    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
                    docker run -d \
                      --name "$CONTAINER_NAME" \
                      -p "$APP_PORT:3000" \
                      --restart unless-stopped \
                      -e BUILD_NUMBER="$BUILD_NUMBER" \
                      -e GIT_COMMIT="$GIT_SHORT" \
                      -e ARTIFACT_SOURCE="$NEXUS_URL/repository/$NEXUS_REPO/$APP_NAME/$APP_VERSION/$APP_NAME-$APP_VERSION.tgz" \
                      "$APP_NAME:$APP_VERSION"
                    docker ps --filter "name=$CONTAINER_NAME"
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh 'bash scripts/verify-deployment.sh "http://localhost:$APP_PORT" "$APP_VERSION"'
            }
        }
    }

    post {
        success {
            echo """
            =====================================================
             PIPELINE SUCCESS
             Version  : ${APP_VERSION}
             Nexus    : ${NEXUS_URL}/#browse/browse:${NEXUS_REPO}
             App      : http://localhost:${APP_PORT}
            =====================================================
            """
        }
        failure {
            echo 'PIPELINE FAILED - open the red stage above to see the error. Nothing after the failed stage was executed.'
        }
        always {
            // Remove old dangling image layers to save disk space
            sh 'docker image prune -f >/dev/null 2>&1 || true'
        }
    }
}
