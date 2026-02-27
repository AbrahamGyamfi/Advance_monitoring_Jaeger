#!/bin/bash
set -euo pipefail

# Load Testing and Observability Validation Script
# Validates alert → trace → log correlation

APP_URL="${1:-http://localhost:5000}"
DURATION_MINUTES="${2:-12}"
PROMETHEUS_URL="${3:-http://localhost:9090}"

echo "🚀 Starting observability validation..."
echo "Target: $APP_URL"
echo "Duration: $DURATION_MINUTES minutes"
echo ""

# Calculate end time
END_TIME=$(($(date +%s) + DURATION_MINUTES * 60))

# Counters
TOTAL_REQUESTS=0
ERROR_REQUESTS=0
LATENCY_REQUESTS=0

echo "📊 Phase 1: Generating normal traffic (2 min)..."
PHASE1_END=$(($(date +%s) + 120))
while [ $(date +%s) -lt $PHASE1_END ]; do
    curl -fsS "$APP_URL/api/tasks" >/dev/null 2>&1 || true
    ((TOTAL_REQUESTS++))
    sleep 0.5
done

echo "⚠️  Phase 2: Triggering high error rate (>5% for 10 min)..."
PHASE2_END=$(($(date +%s) + 600))
while [ $(date +%s) -lt $PHASE2_END ]; do
    # 10% error rate
    if [ $((RANDOM % 10)) -eq 0 ]; then
        curl -fsS "$APP_URL/api/test/error?rate=0.1" >/dev/null 2>&1 || true
        ((ERROR_REQUESTS++))
    else
        curl -fsS "$APP_URL/api/tasks" >/dev/null 2>&1 || true
    fi
    ((TOTAL_REQUESTS++))
    sleep 0.3
done

echo "🐌 Phase 3: Triggering high latency (>300ms for 10 min)..."
PHASE3_END=$(($(date +%s) + 600))
while [ $(date +%s) -lt $PHASE3_END ]; do
    # Add 400ms delay
    curl -fsS "$APP_URL/api/tasks?delay_ms=400" >/dev/null 2>&1 || true
    ((LATENCY_REQUESTS++))
    ((TOTAL_REQUESTS++))
    sleep 0.5
done

echo ""
echo "✅ Load generation complete!"
echo "Total requests: $TOTAL_REQUESTS"
echo "Error requests: $ERROR_REQUESTS"
echo "Latency requests: $LATENCY_REQUESTS"
echo ""

# Check alerts
echo "🔔 Checking Prometheus alerts..."
ALERTS=$(curl -s "$PROMETHEUS_URL/api/v1/alerts" | jq -r '.data.alerts[] | select(.state=="firing") | .labels.alertname' 2>/dev/null || echo "")

if echo "$ALERTS" | grep -q "TaskflowHighErrorRate"; then
    echo "✅ TaskflowHighErrorRate alert is FIRING"
else
    echo "⚠️  TaskflowHighErrorRate alert not firing (may need more time)"
fi

if echo "$ALERTS" | grep -q "TaskflowHighLatency"; then
    echo "✅ TaskflowHighLatency alert is FIRING"
else
    echo "⚠️  TaskflowHighLatency alert not firing (may need more time)"
fi

echo ""
echo "📋 Validation Steps:"
echo "1. Check Grafana dashboard for latency spikes and error rate"
echo "2. Click on a spike to view trace in Jaeger"
echo "3. Copy trace_id from Jaeger"
echo "4. Search Loki logs for that trace_id"
echo "5. Verify log entries contain span_id and error details"
echo ""
echo "🎯 Expected Results:"
echo "- Error rate >5% visible in Grafana"
echo "- p95 latency >300ms visible in Grafana"
echo "- Alerts firing in Alertmanager"
echo "- Traces visible in Jaeger with slow/error spans"
echo "- Logs in Loki correlated with trace_id/span_id"
