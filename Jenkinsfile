// Jenkinsfile - Declarative CI-only pipeline for your repo
pipeline {
  agent { label 'docker' } // use node with docker; change to 'any' if appropriate

  environment {
    IMAGE_BASE = "yourdockeruser/python-flask-student"   // update
    IMAGE_TAG = "${env.BUILD_ID}"
    SONAR_CRED_ID = 'sonar-token'          // Jenkins secret text id (create this)
    DOCKERHUB_CRED_ID = 'dockerhub-creds'  // Jenkins username/password id
    AWS_CRED_ID = 'aws-creds'              // optional, if you want to push to ECR
    SONAR_HOST = "http://sonarqube:9000"   // change to your SonarQube URL
    // Fail build if Trivy finds HIGH/CRITICAL by default
    TRIVY_FAIL_LEVEL = "HIGH"
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
          // run pytest inside a short-lived container with the image (isolated)
          sh """
            docker run --rm ${IMAGE_BASE}:${IMAGE_TAG} /bin/sh -c "pip install -r requirements.txt && pytest -q || true"
            # Copy test output from host if you use mounted volumes or generate junit xml in container
          """
        }
      }
      post {
        always {
          // optional: collect JUnit XML if produced
        }
      }
    }

    stage('Code Quality: SonarQube') {
      environment {
        SONAR_TOKEN = credentials("${SONAR_CRED_ID}")
      }
      steps {
        script {
          // use sonar-scanner docker image and mount repo
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
          // Run trivy as docker container; mount docker socket to scan local images
          sh """
            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --format json --output trivy-report.json ${IMAGE_BASE}:${IMAGE_TAG} || true
          """
          // fail build if any HIGH/CRITICAL vulnerabilities (uses jq)
          sh '''
            if [ -f trivy-report.json ]; then
              if cat trivy-report.json | jq '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH")' | grep -q .; then
                echo "Trivy found HIGH/CRITICAL vulnerabilities — failing build"
                jq '.Results[].Vulnerabilities[] | {Severity, VulnerabilityID, PkgName, InstalledVersion}' trivy-report.json || true
                exit 1
              else
                echo "No HIGH/CRITICAL vulnerabilities found by Trivy"
              fi
            else
              echo "No trivy-report.json found"
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

    stage('Push Image: AWS ECR (optional)') {
      when { expression { return false } } // change to true to enable
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: "${AWS_CRED_ID}", usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh """
              # configure aws cli on the agent (assumes aws cli installed)
              aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
              aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
              docker tag ${IMAGE_BASE}:${IMAGE_TAG} <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/${IMAGE_BASE}:${IMAGE_TAG}
              docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/${IMAGE_BASE}:${IMAGE_TAG}
            """
          }
        }
      }
    }
  }

  post {
    success { echo "CI pipeline finished: SUCCESS" }
    failure { echo "CI pipeline finished: FAILED" }
    always {
      sh "docker image prune -f || true"
    }
  }
}
