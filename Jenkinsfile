pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        AWS_CREDENTIALS_ID = 'aws-credentials'
        IMAGE_TAG = "${BUILD_NUMBER}"
        BUILD_START_TIME = "${System.currentTimeMillis()}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo 'Checking out code...'
                    checkout scm
                    env.GIT_COMMIT_MSG = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    env.GIT_AUTHOR = sh(script: 'git log -1 --pretty=%an', returnStdout: true).trim()
                    echo "Commit: ${env.GIT_COMMIT_MSG}"
                    echo "Author: ${env.GIT_AUTHOR}"
                }
            }
        }
        
        stage('Security Scans') {
            parallel {
                stage('Secret Scan') {
                    steps {
                        script {
                            echo 'Scanning for secrets with Gitleaks...'
                            sh '''
                                chmod +x security-scans/gitleaks-scan.sh
                                ./security-scans/gitleaks-scan.sh
                            '''
                        }
                    }
                }
                stage('SAST - Backend') {
                    steps {
                        script {
                            echo 'Running SonarQube SAST on backend...'
                            withCredentials([
                                string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
                                string(credentialsId: 'sonar-host-url', variable: 'SONAR_HOST_URL')
                            ]) {
                                sh '''
                                    chmod +x security-scans/sonarqube-scan.sh
                                    ./security-scans/sonarqube-scan.sh taskflow-backend backend
                                '''
                            }
                        }
                    }
                }
                stage('SCA - Backend') {
                    steps {
                        script {
                            echo 'Running Snyk SCA on backend...'
                            withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                                sh '''
                                    chmod +x security-scans/snyk-scan.sh
                                    ./security-scans/snyk-scan.sh backend backend
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            echo 'Building backend Docker image with layer caching...'
                            withCredentials([
                                [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials'],
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                dir('backend') {
                                    sh """
                                        aws ecr get-login-password --region \${AWS_REGION} | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
                                        docker pull \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:latest || true
                                        DOCKER_BUILDKIT=0 docker build \
                                            --cache-from \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:latest \
                                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                            --build-arg VCS_REF=\${GIT_COMMIT} \
                                            --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                            -t \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${BUILD_NUMBER} .
                                    """
                                }
                            }
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        script {
                            echo 'Building frontend Docker image with layer caching...'
                            withCredentials([
                                [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials'],
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                dir('frontend') {
                                    sh """
                                        aws ecr get-login-password --region \${AWS_REGION} | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
                                        docker pull \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:latest || true
                                        DOCKER_BUILDKIT=0 docker build \
                                            --cache-from \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:latest \
                                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                            --build-arg VCS_REF=\${GIT_COMMIT} \
                                            --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                            -t \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${BUILD_NUMBER} .
                                    """
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Container Security Scan') {
            parallel {
                stage('Scan Backend') {
                    steps {
                        script {
                            echo 'Scanning backend image with Trivy...'
                            withCredentials([
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    chmod +x security-scans/trivy-scan.sh
                                    ./security-scans/trivy-scan.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${BUILD_NUMBER} backend
                                """
                            }
                        }
                    }
                }
                stage('Scan Frontend') {
                    steps {
                        script {
                            echo 'Scanning frontend image with Trivy...'
                            withCredentials([
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    chmod +x security-scans/trivy-scan.sh
                                    ./security-scans/trivy-scan.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${BUILD_NUMBER} frontend
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage('Generate SBOM') {
            parallel {
                stage('Backend SBOM') {
                    steps {
                        script {
                            echo 'Generating backend SBOM...'
                            withCredentials([
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    chmod +x security-scans/sbom-generate.sh
                                    ./security-scans/sbom-generate.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${BUILD_NUMBER} backend
                                """
                            }
                        }
                    }
                }
                stage('Frontend SBOM') {
                    steps {
                        script {
                            echo 'Generating frontend SBOM...'
                            withCredentials([
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    chmod +x security-scans/sbom-generate.sh
                                    ./security-scans/sbom-generate.sh \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${BUILD_NUMBER} frontend
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage('Run Unit Tests') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        script {
                            echo 'Running backend unit tests...'
                            withCredentials([
                                string(credentialsId: 'node-version', variable: 'NODE_VERSION')
                            ]) {
                                dir('backend') {
                                    sh """
                                        docker run --rm -v \$(pwd):/app -w /app node:\${NODE_VERSION}-alpine sh -c 'npm ci && npm test'
                                    """
                                }
                            }
                        }
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        script {
                            echo 'Running frontend unit tests...'
                            withCredentials([
                                string(credentialsId: 'node-version', variable: 'NODE_VERSION')
                            ]) {
                                dir('frontend') {
                                    sh """
                                        docker run --rm -v \$(pwd):/app -w /app node:\${NODE_VERSION}-alpine sh -c 'npm ci && CI=true npm test -- --passWithNoTests'
                                    """
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Backend Lint') {
                    steps {
                        script {
                            echo 'Running backend linting...'
                            withCredentials([
                                string(credentialsId: 'node-version', variable: 'NODE_VERSION')
                            ]) {
                                dir('backend') {
                                    sh """
                                        docker run --rm -v \$(pwd):/app -w /app node:\${NODE_VERSION}-alpine sh -c 'npm ci && npm run lint'
                                    """
                                }
                            }
                        }
                    }
                }
                stage('Frontend Lint') {
                    steps {
                        script {
                            echo 'Running frontend linting...'
                            withCredentials([
                                string(credentialsId: 'node-version', variable: 'NODE_VERSION')
                            ]) {
                                dir('frontend') {
                                    sh """
                                        docker run --rm -v \$(pwd):/app -w /app node:\${NODE_VERSION}-alpine sh -c 'npm ci --legacy-peer-deps && npm run lint'
                                    """
                                }
                            }
                        }
                    }
                }
                stage('Test Images') {
                    steps {
                        script {
                            echo 'Testing Docker images...'
                            withCredentials([
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    docker run --rm \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${IMAGE_TAG} node --version
                                    docker run --rm \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${IMAGE_TAG} nginx -v
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    echo 'Running integration tests...'
                    withCredentials([
                        string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                        string(credentialsId: 'app-name', variable: 'APP_NAME'),
                        string(credentialsId: 'app-port', variable: 'APP_PORT'),
                        string(credentialsId: 'integration-test-port', variable: 'INTEGRATION_TEST_PORT'),
                        string(credentialsId: 'health-check-timeout', variable: 'HEALTH_CHECK_TIMEOUT'),
                        string(credentialsId: 'health-check-interval', variable: 'HEALTH_CHECK_INTERVAL')
                    ]) {
                        sh '''
                            set -euo pipefail
                            CONTAINER_NAME="test-backend-${BUILD_NUMBER}"
                            cleanup() { docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true; }
                            trap cleanup EXIT
                            cleanup
                            docker run -d --name "$CONTAINER_NAME" -p ${INTEGRATION_TEST_PORT}:${APP_PORT} "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}-backend:${BUILD_NUMBER}"
                            MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))
                            for i in $(seq 1 $MAX_ITERATIONS); do
                                if curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health >/dev/null 2>&1; then break; fi
                                if [ "$i" -eq "$MAX_ITERATIONS" ]; then docker logs "$CONTAINER_NAME"; exit 1; fi
                                sleep ${HEALTH_CHECK_INTERVAL}
                            done
                            curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks
                            echo "Integration tests passed!"
                        '''
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            parallel {
                stage('Push Backend Images') {
                    steps {
                        script {
                            echo 'Pushing backend images to ECR...'
                            withCredentials([
                                [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"],
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    aws ecr get-login-password --region \${AWS_REGION} | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
                                    docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${IMAGE_TAG}
                                    docker tag \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:${IMAGE_TAG} \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:latest
                                    docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-backend:latest
                                """
                            }
                            echo "Backend images pushed!"
                        }
                    }
                }
                stage('Push Frontend Images') {
                    steps {
                        script {
                            echo 'Pushing frontend images to ECR...'
                            withCredentials([
                                [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"],
                                string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                                string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                                string(credentialsId: 'app-name', variable: 'APP_NAME')
                            ]) {
                                sh """
                                    aws ecr get-login-password --region \${AWS_REGION} | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com
                                    docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${IMAGE_TAG}
                                    docker tag \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:${IMAGE_TAG} \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:latest
                                    docker push \${AWS_ACCOUNT_ID}.dkr.ecr.\${AWS_REGION}.amazonaws.com/\${APP_NAME}-frontend:latest
                                """
                            }
                            echo "Frontend images pushed!"
                        }
                    }
                }
            }
        }
        
        stage('Deploy via CodeDeploy') {
            steps {
                script {
                    echo 'Creating deployment package...'
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"],
                        string(credentialsId: 'aws-region', variable: 'AWS_REGION'),
                        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID')
                    ]) {
                        sh """
                            zip -r deployment-${BUILD_NUMBER}.zip docker-compose.yml appspec.yml hooks/
                            
                            aws s3 cp deployment-${BUILD_NUMBER}.zip s3://taskflow-codedeploy-\${AWS_ACCOUNT_ID}/
                            
                            aws deploy create-deployment \
                                --application-name taskflow-app \
                                --deployment-group-name taskflow-blue-green \
                                --s3-location bucket=taskflow-codedeploy-\${AWS_ACCOUNT_ID},key=deployment-${BUILD_NUMBER}.zip,bundleType=zip \
                                --region \${AWS_REGION} \
                                --output json > deployment-output.json
                            
                            DEPLOYMENT_ID=\$(cat deployment-output.json | grep -o '"deploymentId": "[^"]*' | cut -d'"' -f4)
                            echo "Deployment ID: \${DEPLOYMENT_ID}"
                            
                            aws deploy wait deployment-successful --deployment-id \${DEPLOYMENT_ID} --region \${AWS_REGION}
                            echo "Blue-Green deployment completed successfully!"
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Running health checks via ALB...'
                    def healthStatus = sh(
                        script: '''
                            sleep 10
                            curl -f http://taskflow-alb-365219180.eu-west-1.elb.amazonaws.com/health
                        ''',
                        returnStatus: true
                    )
                    if (healthStatus == 0) {
                        echo "Application is healthy via ALB!"
                    } else {
                        echo "Warning: Health check failed, but deployment completed"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo 'Archiving security reports...'
                archiveArtifacts artifacts: 'trivy-*-report.json,sbom-*.json,gitleaks-report.json,snyk-*-report.json', allowEmptyArchive: true
                
                echo 'Cleaning up...'
                sh """
                    # Remove test containers
                    docker rm -f test-backend-${BUILD_NUMBER} 2>/dev/null || true
                    
                    # Remove stopped containers
                    docker container prune -f
                    
                    # Remove dangling images
                    docker image prune -f
                    
                    # Clean workspace node_modules with sudo
                    sudo rm -rf backend/node_modules frontend/node_modules || true
                    
                    # Show disk usage
                    echo "Disk usage:"
                    df -h / | tail -1
                """
                
                // Calculate and display build duration
                try {
                    def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                    echo "Total build duration: ${duration}s (${duration/60}m)"
                } catch (Exception e) {
                    echo "Could not calculate build duration"
                }
            }
        }
        success {
            script {
                try {
                    def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                    echo '=================================='
                    echo 'PIPELINE COMPLETED SUCCESSFULLY!'
                    echo '=================================='
                    echo "Duration: ${duration}s (${duration/60}m)"
                    echo "Build: #${BUILD_NUMBER}"
                    echo "Deployed via CodeDeploy Blue-Green"
                    echo "Application URL: http://taskflow-alb-365219180.eu-west-1.elb.amazonaws.com"
                } catch (Exception e) {
                    echo '=================================='
                    echo 'PIPELINE COMPLETED SUCCESSFULLY!'
                    echo '=================================='
                    echo "Build: #${BUILD_NUMBER}"
                }
            }
        }
        failure {
            script {
                try {
                    def duration = (System.currentTimeMillis() - env.BUILD_START_TIME.toLong()) / 1000
                    echo '=================================='
                    echo 'PIPELINE FAILED!'
                    echo '=================================='
                    echo "Duration: ${duration}s"
                    echo "Build: #${BUILD_NUMBER}"
                    echo "Check logs: ${BUILD_URL}console"
                } catch (Exception e) {
                    echo '=================================='
                    echo 'PIPELINE FAILED!'
                    echo '=================================='
                    echo "Build: #${BUILD_NUMBER}"
                }
            }
        }
    }
}
