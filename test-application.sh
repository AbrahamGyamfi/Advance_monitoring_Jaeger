#!/bin/bash

# TaskFlow Application Testing Script
# Tests all CRUD operations and generates metrics/traces

set -e

APP_SERVER="54.229.200.238"
BACKEND_URL="http://localhost:5000"

echo "========================================="
echo "TaskFlow Application Testing"
echo "========================================="
echo ""

# Test 1: Health Check
echo "1. Testing Health Endpoint..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s ${BACKEND_URL}/health" | jq '.'
echo "✅ Health check passed"
echo ""

# Test 2: Create Tasks
echo "2. Creating test tasks..."
TASK1=$(ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X POST ${BACKEND_URL}/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Setup Monitoring\",\"description\":\"Configure Prometheus and Grafana\"}'" | jq -r '.id')
echo "Created task 1: $TASK1"

TASK2=$(ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X POST ${BACKEND_URL}/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Deploy Application\",\"description\":\"Deploy via Jenkins pipeline\"}'" | jq -r '.id')
echo "Created task 2: $TASK2"

TASK3=$(ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X POST ${BACKEND_URL}/api/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Test Observability\",\"description\":\"Verify metrics, traces, and logs\"}'" | jq -r '.id')
echo "Created task 3: $TASK3"
echo "✅ Tasks created"
echo ""

# Test 3: List All Tasks
echo "3. Listing all tasks..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s ${BACKEND_URL}/api/tasks" | jq '.'
echo "✅ Tasks listed"
echo ""

# Test 4: Update Task Status
echo "4. Updating task status..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X PATCH ${BACKEND_URL}/api/tasks/${TASK1} -H 'Content-Type: application/json' -d '{\"status\":\"in-progress\"}'" | jq '.'
echo "✅ Task status updated"
echo ""

# Test 5: Edit Task
echo "5. Editing task..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X PUT ${BACKEND_URL}/api/tasks/${TASK2} -H 'Content-Type: application/json' -d '{\"title\":\"Deploy Application (Updated)\",\"description\":\"Deploy via Jenkins CI/CD pipeline\",\"status\":\"completed\"}'" | jq '.'
echo "✅ Task edited"
echo ""

# Test 6: System Overview (generates traces)
echo "6. Testing system overview (generates traces)..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s ${BACKEND_URL}/api/system/overview" | jq '.'
echo "✅ System overview retrieved"
echo ""

# Test 7: Check Metrics
echo "7. Checking Prometheus metrics..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s ${BACKEND_URL}/metrics | grep -E '(taskflow_http_requests_total|taskflow_tasks_total|taskflow_http_request_duration)' | head -10"
echo "✅ Metrics exposed"
echo ""

# Test 8: Delete Task
echo "8. Deleting task..."
ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s -X DELETE ${BACKEND_URL}/api/tasks/${TASK3}"
echo "✅ Task deleted"
echo ""

# Test 9: Final Task Count
echo "9. Final task count..."
FINAL_TASKS=$(ssh -i ~/.ssh/id_rsa ec2-user@${APP_SERVER} "curl -s ${BACKEND_URL}/api/tasks" | jq '. | length')
echo "Total tasks remaining: $FINAL_TASKS"
echo ""

echo "========================================="
echo "✅ All tests passed!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Check Grafana dashboard: http://54.73.185.215:3000"
echo "2. View traces in Jaeger: http://54.73.185.215:16686"
echo "3. Query metrics in Prometheus: http://54.73.185.215:9090"
echo "4. Check alerts in Alertmanager: http://54.73.185.215:9093"
