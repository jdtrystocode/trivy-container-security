pipeline {
    agent any

    environment {
        IMAGE = "trivy-demo:${BUILD_NUMBER}"
        TRIVY = "aquasec/trivy:0.75.0"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t $IMAGE .'
            }
        }

        stage('Trivy Scan (report)') {
            steps {
                sh '''
                    mkdir -p reports
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v "$WORKSPACE/reports:/reports" \
                      $TRIVY image --format json --output /reports/trivy-report.json $IMAGE
                '''
            }
        }

        stage('Security Gate') {
            steps {
                sh '''
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      $TRIVY image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $IMAGE
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    docker rm -f trivy-demo-container || true
                    docker run -d --name trivy-demo-container -p 8081:80 $IMAGE
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/*.json', allowEmptyArchive: true
        }
    }
}
