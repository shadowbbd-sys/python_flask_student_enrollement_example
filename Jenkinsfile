pipeline {
    agent any

    environment {
        IMAGE_BASE = "shadowbbd/python-flask-student"   // update if needed
        IMAGE_TAG = "${BUILD_ID}"
        SONAR_CRED_ID = "sonar-token"
        DOCKERHUB_CRED_ID = "dockerhub-creds"
        SONAR_HOST = "http://host.docker.internal:9000"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                bat """
                docker build -t %IMAGE_BASE%:%IMAGE_TAG% .
                """
            }
        }

        stage('Unit Tests (pytest)') {
            steps {
                // Run tests inside the Linux container using /bin/sh -c (not cmd)
                bat """
                docker run --rm %IMAGE_BASE%:%IMAGE_TAG% /bin/sh -c "pip install -r requirements.txt && pytest -q"
                """
            }
        }

        // ---- SonarQube stage (auth + quality gate wait) ----
        stage('Code Quality: SonarQube') {
            environment {
                // Pull the token from Jenkins credentials (Secret Text)
                SONAR_TOKEN = credentials("${SONAR_CRED_ID}")
                SONAR_PROJECT_KEY = "python_flask_student_enrollement_example"
            }
            steps {
                // quick connectivity test (will fail early if Sonar unreachable)
                bat """
                echo Testing Sonar connectivity at %SONAR_HOST%...
                docker run --rm curlimages/curl:7.88.1 -sS --fail %SONAR_HOST%/api/system/status || (
                  echo ERROR: Cannot reach Sonar at %SONAR_HOST% && exit 1
                )
                """

                // Run sonar-scanner via Docker; pass token both as env and as -Dsonar.login
                bat """
                echo Running Sonar scanner and waiting for quality gate...
                docker run --rm ^
                  -e SONAR_HOST_URL=%SONAR_HOST% ^
                  -e SONAR_LOGIN=%SONAR_TOKEN% ^
                  -e SONAR_TOKEN=%SONAR_TOKEN% ^
                  -v "%cd%":/usr/src ^
                  sonarsource/sonar-scanner-cli ^
                  -Dsonar.projectBaseDir=/usr/src ^
                  -Dsonar.sources=. ^
                  -Dsonar.projectKey=%SONAR_PROJECT_KEY% ^
                  -Dsonar.python.version=3.x ^
                  -Dsonar.login=%SONAR_TOKEN% ^
                  -Dsonar.qualitygate.wait=true ^
                  -Dsonar.qualitygate.timeout=300
                """
            }
            post {
                failure {
                    bat 'echo Sonar scan or quality gate failed — check Sonar UI and scanner logs above.'
                }
                success {
                    bat 'echo Sonar analysis completed and quality gate passed.'
                }
            }
        }

        stage('Security Scan: Trivy') {
            steps {
                // Option A: Use the Trivy Windows binary (recommended on Windows)
                // Put trivy.exe on the agent PATH, then run:
                // bat "trivy image --format json --output trivy-report.json %IMAGE_BASE%:%IMAGE_TAG%"

                // Option B: Run dockerized Trivy and attempt to mount docker socket (may need WSL2/Linux containers)
                bat """
                docker run --rm -v //var/run/docker.sock:/var/run/docker.sock ^
                  aquasec/trivy:latest image --format json --output trivy-report.json %IMAGE_BASE%:%IMAGE_TAG% || exit 0
                """
                // Note: the above may fail if Docker Desktop is in Windows container mode or socket path differs.
            }
        }

        // ---- Modified Push stage: robust branch detection fallback ----
        stage('Push Image: Docker Hub') {
            when {
                expression {
                    // Use BRANCH_NAME if available (multibranch), else fall back to GIT_BRANCH or empty string
                    def branch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    return branch ==~ /(?i).*?(main|master).*?/
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED_ID}", usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    bat """
                    echo %DH_PASS% | docker login -u %DH_USER% --password-stdin
                    docker tag %IMAGE_BASE%:%IMAGE_TAG% %IMAGE_BASE%:latest
                    docker push %IMAGE_BASE%:%IMAGE_TAG%
                    docker push %IMAGE_BASE%:latest
                    docker logout
                    """
                }
            }
        }
    }

    post {
        always {
            bat "docker image prune -f || exit 0"
        }
    }
}
