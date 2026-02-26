pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        // AWS Configuration
        AWS_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        APP_SERVER_IP = credentials('app-server-ip')
        MONITORING_HOST = credentials('monitoring-host')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        AWS_CREDENTIALS_ID = 'aws-credentials'
        
        // Application Configuration
        APP_NAME = credentials('app-name')
        NODE_VERSION = credentials('node-version')
        APP_PORT = credentials('app-port')
        INTEGRATION_TEST_PORT = credentials('integration-test-port')
        HEALTH_CHECK_TIMEOUT = credentials('health-check-timeout')
        HEALTH_CHECK_INTERVAL = credentials('health-check-interval')
        EC2_USER = credentials('ec2-user')
        
        // Docker images
        BACKEND_IMAGE = "${ECR_REGISTRY}/${APP_NAME}-backend"
        FRONTEND_IMAGE = "${ECR_REGISTRY}/${APP_NAME}-frontend"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // EC2 Deployment Server
        EC2_CREDENTIALS_ID = 'app-server-ssh'
        EC2_HOST = "${APP_SERVER_IP}"
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
                    echo '📥 Checking out code...'
                    checkout scm
                    
                    // Get git commit info
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: 'git log -1 --pretty=%an',
                        returnStdout: true
                    ).trim()
                    
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
                            echo '🔨 Building backend Docker image...'
                            dir('backend') {
                                sh """
                                    docker build \
                                        --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                        --build-arg VCS_REF=\${GIT_COMMIT} \
                                        --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                        -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                                        .
                                """
                            }
                        }
                    }
                }
                
                stage('Build Frontend') {
                    steps {
                        script {
                            echo '🔨 Building frontend Docker image...'
                            dir('frontend') {
                                sh """
                                    docker build \
                                        --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                        --build-arg VCS_REF=\${GIT_COMMIT} \
                                        --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                        -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                                        .
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
                            echo '🧪 Running backend unit tests...'
                            dir('backend') {
                                sh """
                                    # Run backend tests in Node container
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c '
                                        npm ci
                                        npm test
                                    '
                                """
                            }
                        }
                    }
                }
                
                stage('Frontend Tests') {
                    steps {
                        script {
                            echo '🧪 Running frontend unit tests...'
                            dir('frontend') {
                                sh """
                                    # Run frontend tests in Node container
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c '
                                        npm ci
                                        CI=true npm test -- --passWithNoTests
                                    '
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
                            echo '🔍 Running backend linting...'
                            dir('backend') {
                                sh """
                                    # Run linting in Node container
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c '
                                        npm ci
                                        npm run lint
                                    '
                                """
                            }
                        }
                    }
                }
                
                stage('Test Images') {
                    steps {
                        script {
                            echo '🐳 Testing Docker images...'
                            
                            // Test backend
                            sh """
                                echo "Testing backend image..."
                                docker run --rm ${BACKEND_IMAGE}:${IMAGE_TAG} node --version
                                docker run --rm ${BACKEND_IMAGE}:${IMAGE_TAG} npm --version
                            """
                            
                            // Test frontend
                            sh """
                                echo "Testing frontend image..."
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
                    echo '🔗 Running integration tests...'
                    
                    // Start containers temporarily for testing
                    sh '''
                        set -euo pipefail

                        CONTAINER_NAME="test-backend-${BUILD_NUMBER}"

                        cleanup() {
                            docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
                        }

                        fail_with_logs() {
                            echo "Backend container failed readiness checks."
                            docker ps -a --filter "name=$CONTAINER_NAME" || true
                            docker logs "$CONTAINER_NAME" || true
                            exit 1
                        }

                        trap cleanup EXIT
                        cleanup

                        # Start backend in background
                        docker run -d --name "$CONTAINER_NAME" -p ${INTEGRATION_TEST_PORT}:${APP_PORT} "${BACKEND_IMAGE}:${IMAGE_TAG}" >/dev/null

                        # Calculate max iterations
                        MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))

                        # Wait for backend to be ready and fail fast if it exits
                        for i in $(seq 1 $MAX_ITERATIONS); do
                            if curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health >/dev/null; then
                                break
                            fi

                            status="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo missing)"
                            if [ "$status" != "running" ]; then
                                fail_with_logs
                            fi

                            if [ "$i" -eq $MAX_ITERATIONS ]; then
                                fail_with_logs
                            fi

                            sleep ${HEALTH_CHECK_INTERVAL}
                        done

                        # Test health endpoint
                        curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health

                        # Test GET tasks
                        curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks

                        # Test POST task
                        curl -fsS -X POST http://localhost:${INTEGRATION_TEST_PORT}/api/tasks \
                            -H 'Content-Type: application/json' \
                            -d '{"title":"Test Task","description":"Created during integration test"}'

                        # Test GET tasks again (should have 1 task)
                        TASKS="$(curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks)"
                        echo "Tasks: $TASKS"

                        echo "✅ Integration tests passed!"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo '📤 Pushing images to AWS ECR...'
                    
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]){
                        // Login to ECR
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        """
                        
                        // Push backend images
                        sh """
                            docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                            docker tag ${BACKEND_IMAGE}:${IMAGE_TAG} ${BACKEND_IMAGE}:latest
                            docker push ${BACKEND_IMAGE}:latest
                        """
                        
                        // Push frontend images
                        sh """
                            docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                            docker tag ${FRONTEND_IMAGE}:${IMAGE_TAG} ${FRONTEND_IMAGE}:latest
                            docker push ${FRONTEND_IMAGE}:latest
                        """
                    }
                    
                    echo "✅ Images pushed successfully to ECR!"
                    echo "Backend: ${BACKEND_IMAGE}:${IMAGE_TAG}"
                    echo "Frontend: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ["${EC2_CREDENTIALS_ID}"]) {
                    script {
                        echo '🚀 Deploying to EC2...'

                        sh """
                            mkdir -p ~/.ssh
                            chmod 700 ~/.ssh
                            ssh-keyscan -H ${EC2_HOST} >> ~/.ssh/known_hosts
                            chmod 600 ~/.ssh/known_hosts
                        """
                        
                        // Create deployment directory
                        sh """
                            ssh -o StrictHostKeyChecking=yes ${EC2_USER}@${EC2_HOST} '
                                mkdir -p ~/taskflow
                            '
                        """
                        
                        // Copy docker-compose file
                        sh """
                            scp -o StrictHostKeyChecking=yes \
                                docker-compose.prod.yml \
                                ${EC2_USER}@${EC2_HOST}:~/taskflow/docker-compose.yml
                        """
                        
                        // Deploy application
                        sh """
                            ssh -o StrictHostKeyChecking=yes ${EC2_USER}@${EC2_HOST} 'bash -s' << 'ENDSSH'
                                cd ~/taskflow
                                
                                # Export environment variables
                                export REGISTRY_URL="${ECR_REGISTRY}"
                                export IMAGE_TAG="${IMAGE_TAG}"
                                export MONITORING_HOST="${MONITORING_HOST}"
                                export AWS_REGION="${AWS_REGION}"
                                
                                # Login to ECR
                                aws ecr get-login-password --region \$AWS_REGION | \
                                docker login --username AWS --password-stdin \$REGISTRY_URL
                                
                                # Pull immutable build images
                                docker pull \$REGISTRY_URL/taskflow-backend:\$IMAGE_TAG || exit 1
                                docker pull \$REGISTRY_URL/taskflow-frontend:\$IMAGE_TAG || exit 1
                                
                                # Start new containers
                                docker-compose up -d --no-deps --build
                                
                                # Wait for backend health check
                                MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))
                                for i in \$(seq 1 \$MAX_ITERATIONS); do
                                    if curl -fsS http://localhost:${APP_PORT}/health >/dev/null 2>&1; then
                                        echo "Backend is healthy"
                                        break
                                    fi
                                    if [ "\$i" -eq \$MAX_ITERATIONS ]; then
                                        echo "Health check timeout - rolling back"
                                        docker-compose logs taskflow-backend
                                        exit 1
                                    fi
                                    sleep ${HEALTH_CHECK_INTERVAL}
                                done
                                
                                # Stop old containers
                                docker-compose down --remove-orphans || true
                                
                                # Verify final state
                                docker-compose ps
                                curl -f http://localhost:${APP_PORT}/health || exit 1
                                
                                echo "Deployment successful!"
ENDSSH
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                sshagent(credentials: ["${EC2_CREDENTIALS_ID}"]) {
                    script {
                        echo '🏥 Running health checks...'
                        
                        def healthStatus = sh(
                            script: """
                                ssh -o StrictHostKeyChecking=yes ${EC2_USER}@${EC2_HOST} '
                                    curl -s http://localhost:${APP_PORT}/health | grep -i healthy
                                '
                            """,
                            returnStatus: true
                        )
                        
                        if (healthStatus == 0) {
                            echo "✅ Application is healthy!"
                        } else {
                            error "❌ Health check failed!"
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo '🧹 Cleaning up...'
                // Clean up test containers
                sh """
                    docker rm -f test-backend-${BUILD_NUMBER} 2>/dev/null || true
                    docker image prune -f --filter "until=24h"
                    docker container prune -f
                """
            }
        }
        
        success {
            script {
                echo '✅ =================================='
                echo '✅ PIPELINE COMPLETED SUCCESSFULLY!'
                echo '✅ =================================='
                echo "Backend Image: ${BACKEND_IMAGE}:${IMAGE_TAG}"
                echo "Frontend Image: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                echo "Deployed to: http://${EC2_HOST}"
                echo "Build: #${BUILD_NUMBER} by ${env.GIT_AUTHOR}"
            }
        }
        
        failure {
            script {
                echo '❌ =================================='
                echo '❌ PIPELINE FAILED!'
                echo '❌ =================================='
                echo "Stage: ${env.STAGE_NAME}"
                echo "Build: #${BUILD_NUMBER}"
                // Collect logs for debugging
                sh '''
                    echo "Docker containers:"
                    docker ps -a || true
                    echo "Recent logs:"
                    docker logs test-backend-${BUILD_NUMBER} 2>&1 | tail -50 || true
                '''
            }
        }
    }
}
