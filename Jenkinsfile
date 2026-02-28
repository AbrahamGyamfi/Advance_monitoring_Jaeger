pipeline {
    agent any
    
    triggers {
        githubPush()
    }
    
    environment {
        AWS_REGION = credentials('aws-region')
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        APP_SERVER_IP = credentials('app-server-ip')
        APP_PRIVATE_IP = credentials('app-private-ip')
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
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                                dir('backend') {
                                    sh """
                                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                        docker pull ${BACKEND_IMAGE}:latest || true
                                        docker build \
                                            --cache-from ${BACKEND_IMAGE}:latest \
                                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                            --build-arg VCS_REF=\${GIT_COMMIT} \
                                            --build-arg BUILD_NUMBER=\${BUILD_NUMBER} \
                                            -t ${BACKEND_IMAGE}:${IMAGE_TAG} .
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
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                                dir('frontend') {
                                    sh """
                                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                        docker pull ${FRONTEND_IMAGE}:latest || true
                                        docker build \
                                            --cache-from ${FRONTEND_IMAGE}:latest \
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
        
        stage('Deploy to ECS') {
            steps {
                script {
                    echo 'Deploying to ECS with CodeDeploy Blue/Green...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh """
                            # Get ECS task execution and task role ARNs
                            EXECUTION_ROLE_ARN=\$(aws iam get-role --role-name taskflow-cloudwatch-logs-ecs-execution --query 'Role.Arn' --output text)
                            TASK_ROLE_ARN=\$(aws iam get-role --role-name taskflow-cloudwatch-logs-ecs-task --query 'Role.Arn' --output text)
                            
                            # Create task definition from template
                            sed -e "s|<BACKEND_IMAGE>|${BACKEND_IMAGE}:${IMAGE_TAG}|g" \
                                -e "s|<FRONTEND_IMAGE>|${FRONTEND_IMAGE}:${IMAGE_TAG}|g" \
                                -e "s|<EXECUTION_ROLE_ARN>|\${EXECUTION_ROLE_ARN}|g" \
                                -e "s|<TASK_ROLE_ARN>|\${TASK_ROLE_ARN}|g" \
                                -e "s|<MONITORING_HOST>|${MONITORING_HOST}|g" \
                                -e "s|<AWS_REGION>|${AWS_REGION}|g" \
                                taskdef.json > taskdef-${BUILD_NUMBER}.json
                            
                            # Register new task definition
                            TASK_DEF_ARN=\$(aws ecs register-task-definition \
                                --cli-input-json file://taskdef-${BUILD_NUMBER}.json \
                                --region ${AWS_REGION} \
                                --query 'taskDefinition.taskDefinitionArn' \
                                --output text)
                            
                            echo "Registered task definition: \${TASK_DEF_ARN}"
                            
                            # Create appspec for CodeDeploy
                            sed "s|<TASK_DEFINITION>|\${TASK_DEF_ARN}|g" appspec.yaml > appspec-${BUILD_NUMBER}.yaml
                            
                            # Create CodeDeploy deployment
                            aws deploy create-deployment \
                                --application-name taskflow-cluster \
                                --deployment-group-name taskflow-service-dg \
                                --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"'\$(cat appspec-${BUILD_NUMBER}.yaml | base64 -w 0)'"}}' \
                                --region ${AWS_REGION}
                            
                            echo "CodeDeploy Blue/Green deployment initiated!"
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo 'Waiting for CodeDeploy deployment...'
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDENTIALS_ID}"]]) {
                        sh """
                            # Get ALB DNS name
                            ALB_DNS=\$(aws elbv2 describe-load-balancers \
                                --names taskflow-cluster-alb \
                                --region ${AWS_REGION} \
                                --query 'LoadBalancers[0].DNSName' \
                                --output text)
                            
                            echo "ALB DNS: \${ALB_DNS}"
                            
                            # Wait for deployment (max 10 minutes)
                            for i in {1..60}; do
                                if curl -fsS http://\${ALB_DNS}/health >/dev/null 2>&1; then
                                    echo "Application is healthy!"
                                    exit 0
                                fi
                                echo "Waiting for deployment... (\${i}/60)"
                                sleep 10
                            done
                            
                            echo "Health check timeout!"
                            exit 1
                        """
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
                    echo "Deployed to ECS with Blue/Green deployment"
                    echo "Check ALB for application URL"
                } catch (Exception e) {
                    echo '=================================='
                    echo 'PIPELINE COMPLETED SUCCESSFULLY!'
                    echo '=================================='
                    echo "Build: #${BUILD_NUMBER}"
                    echo "Deployed to ECS with Blue/Green"
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
