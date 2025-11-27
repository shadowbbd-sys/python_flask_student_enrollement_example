// Jenkinsfile - corrected (Declarative CI-only)
pipeline {
  agent { label 'docker' }

  environment {
    IMAGE_BASE = "yourdockeruser/python-flask-student"   // <- update to your Docker Hub repo
    IMAGE_TAG = "${env.BUILD_ID}"
    SONAR_CRED_ID = 'sonar-token'          // <- update if different
    DOCKERHUB_CRED_ID = 'dockerhub-creds'  // <- update if different
    SONAR_HOST = "http://sonarqube:9000"   // <- update to your SonarQube URL
  }

  options {
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
          sh "docker build -t ${IMAGE_BASE}:${IMAGE_TAG} ."
        }
      }
    }

    stage('Unit Tests (pytest)') {
      steps {
        script {
          // Run tests inside container for isolation
          sh """
            docker run --rm ${IMAGE_BASE}:${IMAGE_TAG} /bin/sh -c "pip install -r requirements.txt && pytest -q"
          """
        }
      }
      post {
        // ensure this post block is not empty
        always {
          echo "Unit tests finished (success/failure). Collect results if available."
          // If you generate junit xml inside the container, copy it to workspace and use junit step
          // junit '**/TEST-*.xml'
        }
      }
    }

    stage('Code Quality: SonarQube') {
      environment {
        SONAR_TOKEN = credentials("${SONAR_CRED_ID}")
      }
      steps {
        script {
          sh """
            docker run --rm \
              -e SONAR_HOST_URL='${SONAR_HOST}' \
              -e SONAR_LOGIN='${SONAR_TOKEN}' \
              -v "${pwd()}":/usr/src \
              sonarsource/sonar-scanner-cli \
              -Dsonar.projectBaseDir=/usr/src \
              -Dsonar.sources=. \
              -Dsonar.projectKey=python_flask_student_enrollement_example \
              -Dsonar.python.version=3.x
          """
        }
      }
    }

    stage('Security Scan: Trivy') {
      steps {
        script {
          sh """
            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --format json --output trivy-report.json ${IMAGE_BASE}:${IMAGE_TAG} || true
          """

          // Fail build if HIGH/CRITICAL found (requires jq on agent). If jq missing, this prints the report and continues.
          sh '''
            if [ -f trivy-report.json ]; then
              if command -v jq >/dev/null 2>&1; then
                if cat trivy-report.json | jq '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH")' | grep -q .; then
                  echo "Trivy found HIGH/CRITICAL vulnerabilities — failing build"
                  cat trivy-report.json
                  exit 1
                else
                  echo "No HIGH/CRITICAL vulnerabilities found by Trivy"
                fi
              else
                echo "jq not installed on agent; printing Trivy report for manual inspection"
                cat trivy-report.json || true
              fi
            else
              echo "trivy-report.json not produced"
            fi
          '''
        }
      }
    }

    stage('Push Image: Docker Hub') {
      when {
        expression { return env.BRANCH_NAME ==~ /(?i)main|master|release.*/ }
      }
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED_ID}", usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh "echo ${DH_PASS} | docker login -u ${DH_USER} --password-stdin"
            sh "docker tag ${IMAGE_BASE}:${IMAGE_TAG} ${IMAGE_BASE}:latest"
            sh "docker push ${IMAGE_BASE}:${IMAGE_TAG}"
            sh "docker push ${IMAGE_BASE}:latest"
            sh "docker logout"
          }
        }
      }
    }
  }

  post {
    success {
      echo "CI pipeline completed successfully."
    }
    failure {
      echo "CI pipeline failed. Check logs."
    }
    always {
      script {
        echo "Cleaning up local images and temporary files"
        sh "docker image prune -f || true"
      }
    }
  }
}
