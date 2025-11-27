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
                docker run --rm -v "%cd%":/usr/src %IMAGE_BASE%:%IMAGE_TAG% /bin/sh -c "pip install -r requirements.txt && pytest --junitxml=/usr/src/test-results/pytest-report
