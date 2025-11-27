pipeline {
    agent any

    environment {
        IMAGE_BASE = "shadowbbd/python-flask-student"
        // IMAGE_TAG is computed in the Build stage to include commit short hash
        SONAR_CRED_ID = "sonar-token"
        DOCKERHUB_CRED_ID = "dockerhub-creds"
        // Use host.docker.internal so containerized scanner reaches Sonar on the Windows host
        SONAR_HOST = "http://host.docker.internal:9000"
    }

    options {
        // keep pipeline logs tidy
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // compute a stable tag that includes commit short hash
                    def commit = bat(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    env.IMAGE_TAG = "${BUILD_ID}-${commit}"
                }
                bat """
                echo Building image %IMAGE_BASE%:%IMAGE_TAG%
                docker build --pull -t %IMAGE_BASE%:%IMAGE_TAG% .
                docker images --format "table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}" | findstr %IMAGE_BASE% || docker images
                """
            }
        }

        stage('Unit Tests (pytest)') {
            steps {
                script {
                    // make sure results folder exists in workspace
                    bat 'if not exist test-results mkdir test-results'
                }

                // Run pytest inside the image. Mount workspace so junit xml lands on host.
                bat '''
                docker run --rm -v "%cd%":/usr/src %IMAGE_BASE%:%IMAGE_TAG% /bin/sh -c "pip install -r requirements.txt && pytest --junitxml=/usr/src/test-results/pytest-report.xml -q"
                '''
            }
            post {
                always {
                    // Publish test results to Jenkins (marks unstable if failures)
                    junit allowEmptyResults: false, testResults: 'test-results/pytest-report.xml'
                    bat 'echo Tests completed. Report: %cd%\\test-results\\pytest-report.xml'
                }
            }
        }

        stage('Code Quality: SonarQube (with Quality Gate)') {
            environment {
                // Bind Sonar token from Jenkins credentials
                SONAR_TOKEN = credentials("${SONAR_CRED_ID}")
                SONAR_PROJECT_KEY = "python_flask_student_enrollement_example"
            }
            steps {
                // quick connectivity test (will fail early if Sonar unreachable)
                bat """
                echo Testing Sonar connectivity to %SONAR_HOST%...
                docker run --rm curlimages/curl:7.88.1 -sS --fail %SONAR_HOST%/api/system/status || (
                  echo Cannot reach Sonar at %SONAR_HOST% && exit 1
                )
                """

                // Run sonar-scanner and wait for quality gate result
                bat """
                echo Running SonarScanner (waiting for quality gate)...
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
                    bat 'echo Sonar analysis or quality gate failed - inspect the Sonar UI and scanner logs above.'
                }
                success {
                    bat 'echo Sonar analysis passed and Quality Gate is OK.'
                }
            }
        }

        stage('Security Scan: Trivy (docker)') {
            environment {
                TRIVY_REPORT = "trivy-report.json"
                TRIVY_SEVERITY = "HIGH,CRITICAL"
            }
            steps {
                // Dockerized Trivy scans the built image. On Windows Docker Desktop this requires Linux containers mode.
                bat """
                echo Running Trivy scan for %IMAGE_BASE%:%IMAGE_TAG% (severity=%TRIVY_SEVERITY%)...
                docker run --rm -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --format json --output %TRIVY_REPORT% --exit-code 1 --severity %TRIVY_SEVERITY% %IMAGE_BASE%:%IMAGE_TAG% || set TRV_EXIT=%ERRORLEVEL%
                echo Trivy finished with exit code=%TRV_EXIT%
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                    bat 'echo Trivy report archived to workspace\\trivy-report.json'
                }
                failure {
                    bat 'echo Trivy detected HIGH/CRITICAL vulnerabilities - build FAILED. Inspect trivy-report.json for details.'
                }
            }
        }

        stage('Push Image: Docker Hub') {
            when {
                expression { return env.BRANCH_NAME ==~ /(?i)main|master|release.*/ }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED_ID}", usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    bat """
                    echo Pushing image to Docker Hub: %IMAGE_BASE%:%IMAGE_TAG%
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
        success {
            bat 'echo CI pipeline completed SUCCESS'
        }
        failure {
            bat 'echo CI pipeline FAILED - check console output'
        }
        always {
            // safe cleanup: prune unused images
            bat "docker image prune -f || exit 0"
        }
    }
}

