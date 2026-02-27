pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        AWS_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        APP_SERVER_IP = credentials('app-server-ip')
        MONITORING_HOST = credentials('monitoring-host')
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        AWS_CREDENTIALS_ID = 'aws-credentials'
        
        APP_NAME = credentials('app-name')
        NODE_VERSION = credentials('node-version')
        APP_PORT = credentials('app-port')
        INTEGRATION_TEST_PORT = credentials('integration-test-port')
        HEALTH_CHECK_TIMEOUT = credentials('health-check-timeout')
        HEALTH_CHECK_INTERVAL = credentials('health-check-interval')
        EC2_USER = credentials('ec2-user')
        
        BACKEND_IMAGE = "${ECR_REGISTRY}/${APP_NAME}-backend"
        FRONTEND_IMAGE = "${ECR_REGISTRY}/${APP_NAME}-frontend"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
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
                            echo '🔨 Building backend Docker image...'
                            dir('backend') {
                                sh """
                                    docker build \
                                        --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                        --build-arg VCS_REF=\${GIT_COMMIT} \
                                        --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                        -t ${BACKEND_IMAGE}:${IMAGE_TAG} .
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
                                        -t ${FRONTEND_IMAGE}:${IMAGE_TAG} .
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
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci && npm test'
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
                            echo '🔍 Running backend linting...'
                            dir('backend') {
                                sh """
                                    docker run --rm -v \$(pwd):/app -w /app node:${NODE_VERSION}-alpine sh -c 'npm ci && npm run lint'
                                """
                            }
                        }
                    }
                }
                
                stage('Test Images') {
                    steps {
                        script {
                            echo '🐳 Testing Docker images...'
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
                    echo '🔗 Running integration tests...'
                    sh '''
                        set -euo pipefail
                        CONTAINER_NAME="test-backend-${BUILD_NUMBER}"
                        
                        cleanup() {
                            docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
                        }
                        
                        trap cleanup EXIT
                        cleanup
                        
                        docker run -d --name "$CONTAINER_NAME" -p ${INTEGRATION_TEST_PORT}:${APP_PORT} "${BACKEND_IMAGE}:${IMAGE_TAG}"
                        
                        MAX_ITERATIONS=$((${HEALTH_CHECK_TIMEOUT} / ${HEALTH_CHECK_INTERVAL}))
                        for i in $(seq 1 $MAX_ITERATIONS); do
                            if curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/health >/dev/null 2>&1; then
                                break
                            fi
                            if [ "$i" -eq "$MAX_ITERATIONS" ]; then
                                echo "Health check timeout"
                                docker logs "$CONTAINER_NAME"
                                exit 1
                            fi
                            sleep ${HEALTH_CHECK_INTERVAL}
                        done
                        
                        curl -fsS http://localhost:${INTEGRATION_TEST_PORT}/api/tasks
                        echo "✅ Integration tests passed!"
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo '📤 Pushing images to AWS ECR...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                            docker tag ${BACKEND_IMAGE}:${IMAGE_TAG} ${BACKEND_IMAGE}:latest
                            docker push ${BACKEND_IMAGE}:latest
                            docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                            docker tag ${FRONTEND_IMAGE}:${IMAGE_TAG} ${FRONTEND_IMAGE}:latest
                            docker push ${FRONTEND_IMAGE}:latest
                        """
                    }
                    echo "✅ Images pushed to ECR!"
                }
            }
        }
        
        stage('Deploy to EC2') {
            steps {
                script {
                    echo '🚀 Deploying to EC2...'
                    sh '''
                        mkdir -p ~/.ssh
                        chmod 700 ~/.ssh
                        ssh-keyscan -H ${EC2_HOST} >> ~/.ssh/known_hosts 2>/dev/null || true
                        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} 'mkdir -p ~/taskflow'
                        scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no docker-compose.prod.yml ${EC2_USER}@${EC2_HOST}:~/taskflow/docker-compose.yml
                    '''
                    
                    sh '''
                        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} bash -s ${ECR_REGISTRY} ${IMAGE_TAG} ${AWS_REGION} ${APP_PORT} ${HEALTH_CHECK_TIMEOUT} ${HEALTH_CHECK_INTERVAL} << 'ENDSSH'
set -e
cd ~/taskflow
REGISTRY="$1"
TAG="$2"
REGION="$3"
PORT="$4"
TIMEOUT="$5"
INTERVAL="$6"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker pull "$REGISTRY/taskflow-backend:$TAG"
docker pull "$REGISTRY/taskflow-frontend:$TAG"

export REGISTRY_URL="$REGISTRY"
export IMAGE_TAG="$TAG"
docker-compose up -d

MAX_ITER=$(( $TIMEOUT / $INTERVAL ))
for i in $(seq 1 $MAX_ITER); do
    if curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
        echo "Deployment successful!"
        exit 0
    fi
    sleep "$INTERVAL"
done
echo "Health check failed"
docker-compose logs
exit 1
ENDSSH
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo '🏥 Running health checks...'
                    sh '''
                        ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} 'curl -fsS http://localhost:${APP_PORT}/health'
                    '''
                    echo "✅ Application is healthy!"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo '🧹 Cleaning up...'
                sh """
                    docker rm -f test-backend-${BUILD_NUMBER} 2>/dev/null || true
                    docker image prune -f --filter 'until=24h' || true
                """
            }
        }
        
        success {
            script {
                echo '✅ PIPELINE COMPLETED SUCCESSFULLY!'
                echo "Backend: ${BACKEND_IMAGE}:${IMAGE_TAG}"
                echo "Frontend: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                echo "Deployed to: http://${EC2_HOST}"
            }
        }
        
        failure {
            script {
                echo '❌ PIPELINE FAILED!'
                echo "Build: #${BUILD_NUMBER}"
            }
        }
    }
}
