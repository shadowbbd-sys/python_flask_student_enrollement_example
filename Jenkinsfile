pipeline {
    agent any  // Windows controller itself runs the pipeline

    environment {
        IMAGE_BASE = "shadowbbd/python-flask-student"   // update
        IMAGE_TAG = "${BUILD_ID}"
        SONAR_CRED_ID = "sonar-token"
        DOCKERHUB_CRED_ID = "dockerhub-creds"
        SONAR_HOST = "http://localhost:9000" // change to your Sonar URL
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
                bat """
                docker run --rm %IMAGE_BASE%:%IMAGE_TAG% cmd /c "pip install -r requirements.txt && pytest -q"
                """
            }
        }

        stage('Code Quality: SonarQube') {
            environment {
                SONAR_TOKEN = credentials("${SONAR_CRED_ID}")
            }
            steps {
                bat """
                docker run --rm ^
                  -e SONAR_HOST_URL=%SONAR_HOST% ^
                  -e SONAR_LOGIN=%SONAR_TOKEN% ^
                  -v "%cd%":/usr/src ^
                  sonarsource/sonar-scanner-cli ^
                  -Dsonar.projectBaseDir=/usr/src ^
                  -Dsonar.sources=. ^
                  -Dsonar.projectKey=python_flask_student_enrollement_example
                """
            }
        }

        stage('Security Scan: Trivy') {
            steps {
                bat """
                docker run --rm -v //var/run/docker.sock:/var/run/docker.sock ^
                  aquasec/trivy:latest image --format json --output trivy-report.json %IMAGE_BASE%:%IMAGE_TAG%
                """
            }
        }

        stage('Push Image: Docker Hub') {
            when {
                expression { return env.BRANCH_NAME ==~ /(?i)main|master/ }
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
            bat """
            docker image prune -f
            """
        }
    }
}
