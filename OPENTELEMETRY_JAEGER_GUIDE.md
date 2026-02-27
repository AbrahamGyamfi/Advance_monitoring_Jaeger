# OpenTelemetry & Jaeger - Complete Guide

## Overview

Your TaskFlow application uses **OpenTelemetry** for distributed tracing and **Jaeger** as the tracing backend. This enables you to track requests across your system and correlate them with logs.

---

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    TaskFlow Backend (Node.js)                   │
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ HTTP Request │───▶│ OpenTelemetry│───▶│   Logger     │      │
│  │   (Express)  │    │     SDK      │    │ (trace_id)   │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                    │                    │              │
│         │                    │                    │              │
│         ▼                    ▼                    ▼              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Metrics    │    │    Spans     │    │  JSON Logs   │      │
│  │ (Prometheus) │    │  (OTLP/HTTP) │    │   (stdout)   │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │                    │
                              │                    │
                              ▼                    ▼
                    ┌──────────────┐    ┌──────────────┐
                    │    Jaeger    │    │     Loki     │
                    │  (Port 4318) │    │  (Port 3100) │
                    │              │    │              │
                    │ Trace Storage│    │ Log Storage  │
                    └──────────────┘    └──────────────┘
                              │                    │
                              └────────┬───────────┘
                                       │
                                       ▼
                              ┌──────────────┐
                              │   Grafana    │
                              │  (Port 3000) │
                              │              │
                              │  Dashboards  │
                              └──────────────┘
```

---

## Component Breakdown

### 1. OpenTelemetry SDK (`telemetry.js`)

**Purpose**: Automatically instruments your Node.js application to create traces.

**Key Configuration**:
```javascript
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'taskflow-backend',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'production'
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://monitoring-host:4318/v1/traces'  // Jaeger OTLP endpoint
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => request.url === '/metrics'
      }
    })
  ]
});
```

**What it does**:
- Automatically creates spans for HTTP requests
- Automatically creates spans for outgoing HTTP calls
- Exports traces to Jaeger via OTLP protocol
- Ignores `/metrics` endpoint to avoid noise

---

### 2. Automatic Instrumentation

**HTTP Server Spans** (created automatically):
```
Span Name: GET /api/tasks
├─ trace_id: 1a2b3c4d5e6f7g8h9i0j
├─ span_id: a1b2c3d4e5f6g7h8
├─ duration: 45ms
├─ status_code: 200
└─ attributes:
   ├─ http.method: GET
   ├─ http.route: /api/tasks
   ├─ http.status_code: 200
   └─ http.target: /api/tasks?delay_ms=100
```

**HTTP Client Spans** (created automatically):
```
Span Name: GET http://127.0.0.1:5000/health
├─ trace_id: 1a2b3c4d5e6f7g8h9i0j  (same as parent)
├─ span_id: b2c3d4e5f6g7h8i9
├─ parent_span_id: a1b2c3d4e5f6g7h8
├─ duration: 12ms
└─ attributes:
   ├─ http.method: GET
   ├─ http.url: http://127.0.0.1:5000/health
   └─ http.status_code: 200
```

---

### 3. Logger Integration (`logger.js`)

**Purpose**: Correlate logs with traces by injecting `trace_id` and `span_id`.

**How it works**:
```javascript
function getTraceFields() {
  const activeSpan = trace.getSpan(context.active());
  if (!activeSpan) return {};
  
  const spanContext = activeSpan.spanContext();
  return {
    trace_id: spanContext.traceId,
    span_id: spanContext.spanId
  };
}

function writeLog(level, message, fields = {}) {
  const logPayload = {
    timestamp: new Date().toISOString(),
    level,
    service: 'taskflow-backend',
    message,
    ...getTraceFields(),  // ← Injects trace_id and span_id
    ...fields
  };
  
  process.stdout.write(`${JSON.stringify(logPayload)}\n`);
}
```

**Example Log Output**:
```json
{
  "timestamp": "2024-02-15T10:30:45.123Z",
  "level": "info",
  "service": "taskflow-backend",
  "message": "http_request_completed",
  "trace_id": "1a2b3c4d5e6f7g8h9i0j",
  "span_id": "a1b2c3d4e5f6g7h8",
  "method": "GET",
  "route": "/api/tasks",
  "status_code": 200,
  "duration_ms": 45.23
}
```

---

### 4. Middleware Integration (`app.js`)

**Purpose**: Capture trace context for every HTTP request.

```javascript
app.use((req, res, next) => {
  const startTime = process.hrtime.bigint();
  const spanContext = trace.getSpan(context.active())?.spanContext();
  const traceContext = spanContext
    ? {
        trace_id: spanContext.traceId,
        span_id: spanContext.spanId
      }
    : {};
  
  res.on('finish', () => {
    const elapsed = process.hrtime.bigint() - startTime;
    const durationSeconds = Number(elapsed) / 1e9;
    
    logger.info('http_request_completed', {
      method: req.method,
      route: normalizePath(req.path),
      status_code: res.statusCode,
      duration_ms: Number((durationSeconds * 1000).toFixed(2)),
      ...traceContext  // ← Logs include trace_id and span_id
    });
  });
  
  next();
});
```

---

### 5. Jaeger Backend

**Purpose**: Store and visualize distributed traces.

**Configuration** (`monitoring/docker-compose.yml`):
```yaml
jaeger:
  image: jaegertracing/all-in-one:1.58
  container_name: jaeger
  environment:
    - COLLECTOR_OTLP_ENABLED=true  # ← Enables OTLP protocol
  ports:
    - "16686:16686"  # Jaeger UI
    - "4318:4318"    # OTLP HTTP receiver
```

**What Jaeger stores**:
- Trace ID (unique per request)
- Span ID (unique per operation)
- Parent-child relationships between spans
- Timing information (start time, duration)
- Tags/attributes (HTTP method, status code, etc.)
- Logs attached to spans

---

## Request Flow Example

### Scenario: User creates a task

**1. Frontend sends request**:
```
POST http://app-server:5000/api/tasks
Body: { "title": "Buy groceries", "description": "Milk, eggs, bread" }
```

**2. OpenTelemetry creates root span**:
```
Trace ID: 1a2b3c4d5e6f7g8h9i0j
Span ID: a1b2c3d4e5f6g7h8
Span Name: POST /api/tasks
Start Time: 2024-02-15T10:30:45.000Z
```

**3. Express middleware executes**:
- Captures trace context
- Processes request
- Creates task in memory

**4. Logger writes structured log**:
```json
{
  "timestamp": "2024-02-15T10:30:45.123Z",
  "level": "info",
  "service": "taskflow-backend",
  "message": "http_request_completed",
  "trace_id": "1a2b3c4d5e6f7g8h9i0j",
  "span_id": "a1b2c3d4e5f6g7h8",
  "method": "POST",
  "route": "/api/tasks",
  "status_code": 201,
  "duration_ms": 12.45
}
```

**5. OpenTelemetry exports span to Jaeger**:
```
POST http://monitoring-host:4318/v1/traces
Body: [protobuf-encoded span data]
```

**6. Jaeger stores the trace**:
- Indexed by trace_id
- Searchable by service name, operation, tags
- Viewable in UI at http://monitoring-host:16686

---

## Trace Visualization in Jaeger

### Jaeger UI Structure

**Search Page** (`http://monitoring-host:16686`):
```
┌─────────────────────────────────────────────────────────┐
│ Service: taskflow-backend                               │
│ Operation: POST /api/tasks                              │
│ Tags: http.status_code=201                              │
│ Lookback: Last 1 hour                                   │
│                                                          │
│ [Find Traces]                                           │
└─────────────────────────────────────────────────────────┘

Results:
┌─────────────────────────────────────────────────────────┐
│ POST /api/tasks                          12.45ms  201   │
│ trace_id: 1a2b3c4d5e6f7g8h9i0j                          │
│ 1 span                                                   │
└─────────────────────────────────────────────────────────┘
```

**Trace Detail Page**:
```
Trace: 1a2b3c4d5e6f7g8h9i0j
Duration: 12.45ms
Spans: 1

Timeline:
┌─────────────────────────────────────────────────────────┐
│ taskflow-backend                                        │
│   POST /api/tasks                          12.45ms      │
│   ████████████████████████████████████████              │
│                                                          │
│   Tags:                                                 │
│     http.method: POST                                   │
│     http.route: /api/tasks                              │
│     http.status_code: 201                               │
│     http.target: /api/tasks                             │
└─────────────────────────────────────────────────────────┘
```

---

## Advanced Example: Nested Spans

### Scenario: `/api/system/overview` endpoint

This endpoint makes an internal HTTP call to `/health`, creating a parent-child span relationship.

**Code** (`app.js`):
```javascript
app.get('/api/system/overview', async (req, res) => {
  try {
    const upstreamHealth = await fetchInternalHealth();  // ← HTTP call
    
    res.status(200).json({
      service: 'taskflow-backend',
      timestamp: new Date().toISOString(),
      tasksCount: tasks.length,
      upstreamHealth
    });
  } catch (error) {
    logger.error('system_overview_failed', { ...extractErrorFields(error) });
    res.status(502).json({ error: 'Unable to retrieve internal health state' });
  }
});

function fetchInternalHealth() {
  return new Promise((resolve, reject) => {
    const request = http.request({
      hostname: '127.0.0.1',
      port: 5000,
      path: '/health',
      method: 'GET'
    }, (response) => {
      // ... handle response
    });
    request.end();
  });
}
```

**Resulting Trace**:
```
Trace ID: 2b3c4d5e6f7g8h9i0j1k
Duration: 45ms

┌─────────────────────────────────────────────────────────┐
│ taskflow-backend                                        │
│   GET /api/system/overview                 45ms         │
│   ████████████████████████████████████████              │
│     │                                                    │
│     └─ GET http://127.0.0.1:5000/health    12ms         │
│        ████████████                                      │
└─────────────────────────────────────────────────────────┘
```

**Parent Span**:
- Span Name: `GET /api/system/overview`
- Span ID: `c1d2e3f4g5h6i7j8`
- Duration: 45ms

**Child Span**:
- Span Name: `GET http://127.0.0.1:5000/health`
- Span ID: `d2e3f4g5h6i7j8k9`
- Parent Span ID: `c1d2e3f4g5h6i7j8`
- Duration: 12ms

---

## Log-Trace Correlation

### How to correlate logs with traces

**1. Find error in logs** (Loki/Grafana):
```json
{
  "timestamp": "2024-02-15T10:35:22.456Z",
  "level": "error",
  "service": "taskflow-backend",
  "message": "task_create_failed",
  "trace_id": "3c4d5e6f7g8h9i0j1k2l",
  "span_id": "e3f4g5h6i7j8k9l0",
  "error_name": "ValidationError",
  "error_message": "Title is required"
}
```

**2. Copy `trace_id`**: `3c4d5e6f7g8h9i0j1k2l`

**3. Search in Jaeger**:
```
http://monitoring-host:16686/trace/3c4d5e6f7g8h9i0j1k2l
```

**4. View full request context**:
- See all spans in the request
- See timing breakdown
- See all tags and attributes
- Identify bottlenecks

---

## Environment Variables

### Backend Configuration

```bash
# OpenTelemetry
OTEL_SERVICE_NAME=taskflow-backend
OTEL_EXPORTER_OTLP_ENDPOINT=http://monitoring-host:4318
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://monitoring-host:4318/v1/traces
OTEL_SDK_DISABLED=false  # Set to 'true' to disable tracing

# Debugging
OTEL_DIAGNOSTIC_LOG_LEVEL=debug  # Enable OTel debug logs

# Application
NODE_ENV=production
PORT=5000
```

### Docker Compose Configuration

```yaml
services:
  taskflow-backend:
    image: taskflow-backend:latest
    environment:
      - OTEL_SERVICE_NAME=taskflow-backend
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318
      - NODE_ENV=production
    networks:
      - monitoring
```

---

## Testing the Setup

### 1. Generate a trace
```bash
curl -X POST http://app-server:5000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task","description":"Testing OpenTelemetry"}'
```

### 2. Check logs for trace_id
```bash
docker logs taskflow-backend-prod | grep trace_id
```

**Output**:
```json
{"timestamp":"2024-02-15T10:40:12.789Z","level":"info","service":"taskflow-backend","message":"http_request_completed","trace_id":"4d5e6f7g8h9i0j1k2l3m","span_id":"f4g5h6i7j8k9l0m1","method":"POST","route":"/api/tasks","status_code":201,"duration_ms":15.67}
```

### 3. View trace in Jaeger
```bash
# Open Jaeger UI
http://monitoring-host:16686

# Search for:
Service: taskflow-backend
Operation: POST /api/tasks
Lookback: Last 1 hour
```

### 4. Verify trace in Grafana
```bash
# Open Grafana
http://monitoring-host:3000

# Navigate to: Explore → Loki
# Query: {service="taskflow-backend"} |= "trace_id"
# Click on trace_id link → Opens Jaeger
```

---

## Key Benefits

### 1. Request Tracing
- Track requests across services
- Identify slow operations
- Debug distributed systems

### 2. Log Correlation
- Link logs to specific requests
- Find all logs for a failed request
- Understand request context

### 3. Performance Analysis
- Measure operation duration
- Identify bottlenecks
- Optimize slow endpoints

### 4. Error Debugging
- See full request flow for errors
- Understand failure context
- Reproduce issues

---

## Common Use Cases

### Use Case 1: Debug Slow Request

**Problem**: `/api/tasks` is slow

**Steps**:
1. Open Jaeger UI
2. Search for `GET /api/tasks` operations
3. Sort by duration (longest first)
4. Click on slow trace
5. Analyze span timeline
6. Identify bottleneck (e.g., database query, external API call)

### Use Case 2: Investigate Error

**Problem**: User reports 500 error

**Steps**:
1. Check Grafana logs for errors
2. Find log entry with error details
3. Copy `trace_id` from log
4. Open trace in Jaeger
5. See full request context
6. Identify root cause

### Use Case 3: Monitor Service Health

**Problem**: Want to track service performance

**Steps**:
1. Open Jaeger UI
2. View service graph
3. Check operation latencies
4. Identify degraded operations
5. Set up alerts in Prometheus

---

## Troubleshooting

### Traces not appearing in Jaeger

**Check 1**: Verify OTLP endpoint
```bash
curl http://monitoring-host:4318/v1/traces
# Should return 405 Method Not Allowed (POST required)
```

**Check 2**: Check backend logs
```bash
docker logs taskflow-backend-prod | grep otel
```

**Check 3**: Verify Jaeger is running
```bash
docker ps | grep jaeger
curl http://monitoring-host:16686
```

### Logs missing trace_id

**Check 1**: Verify OpenTelemetry is initialized
```bash
docker logs taskflow-backend-prod | grep otel_sdk_started
```

**Check 2**: Check if endpoint is instrumented
```bash
# /metrics is ignored by default
curl http://app-server:5000/metrics
# Should NOT have trace_id in logs
```

---

## Summary

**OpenTelemetry**:
- Automatically instruments your Node.js app
- Creates spans for HTTP requests/responses
- Exports traces to Jaeger via OTLP

**Jaeger**:
- Receives traces via OTLP HTTP (port 4318)
- Stores traces in memory/database
- Provides UI for visualization (port 16686)

**Logger Integration**:
- Injects `trace_id` and `span_id` into logs
- Enables log-trace correlation
- Searchable in Loki/Grafana

**Result**:
- Full request visibility
- Log-trace correlation
- Performance insights
- Error debugging
