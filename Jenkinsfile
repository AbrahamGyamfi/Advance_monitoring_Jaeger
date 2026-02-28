pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        AWS_CREDENTIALS_ID = 'aws-credentials'
        
        BACKEND_IMAGE = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}-backend"
        FRONTEND_IMAGE = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}-frontend"
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
        
        stage('Run Unit Tests') {
            parallel {
                stage('Backend Tests') {
                    steps {
                        script {
                            echo 'Running backend unit tests...'
                            dir('backend') {
                                sh """
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci && npm test'
                                """
                            }
                        }
                    }
                }
                stage('Frontend Tests') {
                    steps {
                        script {
                            echo 'Running frontend unit tests...'
                            dir('frontend') {
                                sh """
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci && CI=true npm test -- --passWithNoTests'
                                """
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
                            dir('backend') {
                                sh """
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci && npm run lint'
                                """
                            }
                        }
                    }
                }
                stage('Frontend Lint') {
                    steps {
                        script {
                            echo 'Running frontend linting...'
                            dir('frontend') {
                                sh """
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci --legacy-peer-deps && npm run lint'
                                """
                            }
                        }
                    }
                }
                stage('Test Images') {
                    steps {
                        script {
                            echo 'Testing Docker images...'
                            sh """
                                docker run --rm ${BACKEND_IMAGE}:${IMAGE_TAG} node --version
                                docker run --rm ${FRONTEND_IMAGE}:${IMAGE_TAG} nginx -v
                            """
                        }
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    echo 'Running integration tests...'
                    sh '''
                        set -euo pipefail
                        CONTAINER_NAME="test-backend-${BUILD_NUMBER}"
                        cleanup() { docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true; }
                        trap cleanup EXIT
                        cleanup
                        docker run -d --name "$CONTAINER_NAME" -p ${INTEGRATION_TEST_PORT}:${APP_PORT} "${BACKEND_IMAGE}:${IMAGE_TAG}"
                        MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))
                        for i in $(seq 1 $MAX_ITERATIONS); do
                            if curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health >/dev/null 2>&1; then break; fi
                            if [ "$i" -eq "$MAX_ITERATIONS" ]; then docker logs "$CONTAINER_NAME"; exit 1; fi
                            sleep ${HEALTH_CHECK_INTERVAL}
                        done
                        curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks
                        echo "✅ Integration tests passed!"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            parallel {
                stage('Push Backend Images') {
                    steps {
                        script {
                            echo 'Pushing backend images to ECR...'
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                                sh """
                                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                    docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                                    docker tag ${BACKEND_IMAGE}:${IMAGE_TAG} ${BACKEND_IMAGE}:latest
                                    docker push ${BACKEND_IMAGE}:latest
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
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                                sh """
                                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                    docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                                    docker tag ${FRONTEND_IMAGE}:${IMAGE_TAG} ${FRONTEND_IMAGE}:latest
                                    docker push ${FRONTEND_IMAGE}:latest
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
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh """
                            # Create deployment bundle
                            zip -r deployment-${BUILD_NUMBER}.zip docker-compose.yml appspec.yml
                            
                            # Upload to S3
                            aws s3 cp deployment-${BUILD_NUMBER}.zip s3://taskflow-codedeploy-${AWS_ACCOUNT_ID}/
                            
                            # Trigger CodeDeploy Blue-Green deployment
                            aws deploy create-deployment \
                                --application-name taskflow-app \
                                --deployment-group-name taskflow-blue-green \
                                --s3-location bucket=taskflow-codedeploy-${AWS_ACCOUNT_ID},key=deployment-${BUILD_NUMBER}.zip,bundleType=zip \
                                --region ${AWS_REGION} \
                                --output json > deployment-output.json
                            
                            # Get deployment ID
                            DEPLOYMENT_ID=\$(cat deployment-output.json | grep -o '"deploymentId": "[^"]*' | cut -d'"' -f4)
                            echo "Deployment ID: \$DEPLOYMENT_ID"
                            
                            # Wait for deployment to complete
                            aws deploy wait deployment-successful --deployment-id \$DEPLOYMENT_ID --region ${AWS_REGION}
                            echo "Blue-Green deployment completed successfully!"
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Running health checks...'
                    def healthStatus = sh(
                        script: """
                            ssh -i /var/lib/jenkins/.ssh/id_rsa -o StrictHostKeyChecking=no ${EC2_USER}@${APP_PRIVATE_IP} 'curl -s http://localhost:${APP_PORT}/health | grep healthy'
                        """,
                        returnStatus: true
                    )
                    if (healthStatus == 0) {
                        echo "Application is healthy!"
                    } else {
                        error "Health check failed!"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
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
                    echo "Backend: ${BACKEND_IMAGE}:${IMAGE_TAG}"
                    echo "Frontend: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                    echo "Deployed to: http://${EC2_HOST}"
                    echo "Metrics: http://${EC2_HOST}:5000/metrics"
                } catch (Exception e) {
                    echo '=================================='
                    echo 'PIPELINE COMPLETED SUCCESSFULLY!'
                    echo '=================================='
                    echo "Build: #${BUILD_NUMBER}"
                    echo "Deployed to: http://${EC2_HOST}"
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
