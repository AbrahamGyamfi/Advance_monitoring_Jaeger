# TaskFlow - Development Guidelines

## Code Quality Standards

### Formatting and Structure
- **Indentation**: 2 spaces (no tabs) across all JavaScript files
- **Line Length**: Keep lines under 100 characters where practical
- **Semicolons**: Always use semicolons to terminate statements
- **Quotes**: Single quotes for strings in backend, standard JSX conventions in frontend
- **Trailing Commas**: Use trailing commas in multi-line objects and arrays
- **Blank Lines**: Single blank line between function definitions, two blank lines between major sections

### Naming Conventions
- **Variables/Functions**: camelCase (e.g., `fetchTasks`, `handleCreateTask`, `tasksTotal`)
- **Constants**: UPPER_SNAKE_CASE for true constants (e.g., `MAX_TITLE_LENGTH`, `API_URL`, `SERVICE_NAME`)
- **React Components**: PascalCase (e.g., `TaskForm`, `TaskList`, `TaskFilter`)
- **Files**: kebab-case for scripts, camelCase for modules (e.g., `app.js`, `metrics.js`, `server-userdata.sh`)
- **Routes**: kebab-case with version prefix (e.g., `/api/tasks`, `/api/system/overview`)
- **Metrics**: snake_case with service prefix (e.g., `taskflow_http_requests_total`, `taskflow_tasks_total`)

### Documentation Standards
- **Inline Comments**: Use sparingly, only for complex logic or non-obvious behavior
- **Function Comments**: Not required if function name and parameters are self-explanatory
- **User Story References**: Include US-XXX comments in frontend for feature traceability (e.g., `// US-001: Create new task`)
- **TODO Comments**: Avoid in production code; use issue tracker instead

## Backend Development Patterns

### Express.js Application Structure
```javascript
// Standard module imports at top
const express = require('express');
const cors = require('cors');

// Local module imports after external
const logger = require('./logger');
const { getMetrics } = require('./metrics');

// Constants after imports
const MAX_TITLE_LENGTH = 100;
const API_URL = '/api';

// Application state
let tasks = [];

// Helper functions before route handlers
function validateTaskPayload(title, description) {
  // validation logic
}

// Express app initialization
const app = express();

// Middleware registration
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Custom middleware for observability
app.use((req, res, next) => {
  // metrics collection logic
});

// Route handlers (health/metrics first, then API routes)
app.get('/metrics', async (req, res) => { /* ... */ });
app.get('/health', (req, res) => { /* ... */ });
app.post('/api/tasks', (req, res) => { /* ... */ });

// 404 handler before error handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler last
app.use((err, req, res, _next) => {
  logger.error('unhandled_error', { /* ... */ });
  res.status(500).json({ error: 'Something went wrong!' });
});

// Export for testing
module.exports = { app, resetInMemoryData };
```

### Error Handling Pattern
```javascript
// Always use try-catch in route handlers
app.post('/api/tasks', (req, res) => {
  try {
    // business logic
    return res.status(201).json(newTask);
  } catch (error) {
    logger.error('task_create_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Extract error fields consistently
function extractErrorFields(error) {
  if (!(error instanceof Error)) {
    return { error };
  }
  return {
    error_name: error.name,
    error_message: error.message,
    error_stack: error.stack
  };
}
```

### Validation Pattern
```javascript
// Validate early, return early
function validateTaskPayload(title, description) {
  if (typeof title !== 'string' || title.trim().length === 0) {
    return 'Title is required';
  }
  
  if (title.trim().length > MAX_TITLE_LENGTH) {
    return `Title must be ${MAX_TITLE_LENGTH} characters or less`;
  }
  
  // Return null for valid input
  return null;
}

// Use in route handler
const validationError = validateTaskPayload(title, description);
if (validationError) {
  return res.status(400).json({ error: validationError });
}
```

### Observability Integration
```javascript
// Middleware for automatic metrics collection
app.use((req, res, next) => {
  const startTime = process.hrtime.bigint();
  const spanContext = trace.getSpan(context.active())?.spanContext();
  
  res.on('finish', () => {
    const elapsed = process.hrtime.bigint() - startTime;
    const durationSeconds = Number(elapsed) / 1e9;
    const route = normalizePath(req.path);
    
    // Record metrics
    observeHttpRequest({
      method: req.method,
      route,
      statusCode: res.statusCode,
      durationSeconds
    });
    
    // Log with trace context
    logger.info('http_request_completed', {
      method: req.method,
      route,
      status_code: res.statusCode,
      duration_ms: Number((durationSeconds * 1000).toFixed(2)),
      trace_id: spanContext?.traceId,
      span_id: spanContext?.spanId
    });
  });
  
  next();
});
```

### Prometheus Metrics Pattern
```javascript
// Define metrics with clear naming and labels
const httpRequestsTotal = new client.Counter({
  name: 'taskflow_http_requests_total',
  help: 'Total number of HTTP requests handled by the backend',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Sanitize label values to prevent cardinality explosion
function sanitizeRoute(route) {
  if (!route) return 'unknown';
  return route
    .replace(UUID_PATTERN, ':id')
    .replace(/\/\d+(?=\/|$)/g, '/:id');
}

// Record metrics with sanitized labels
function observeHttpRequest({ method, route, statusCode, durationSeconds }) {
  const labels = {
    method: sanitizeMethod(method),
    route: sanitizeRoute(route),
    status_code: sanitizeStatusCode(statusCode)
  };
  
  httpRequestsTotal.inc(labels);
  httpRequestDurationSeconds.observe(labels, durationSeconds);
  
  if (statusCode >= 400) {
    httpErrorsTotal.inc(labels);
  }
}
```

### OpenTelemetry Configuration
```javascript
// Initialize SDK with environment-based configuration
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'production'
  }),
  traceExporter: new OTLPTraceExporter({
    url: OTEL_ENDPOINT
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

// Start telemetry with error handling
async function startTelemetry() {
  if (telemetryStarted || process.env.OTEL_SDK_DISABLED === 'true') {
    return;
  }
  
  try {
    await sdk.start();
    telemetryStarted = true;
    // Log success as structured JSON
  } catch (error) {
    // Log failure as structured JSON
  }
}
```

### Structured Logging Pattern
```javascript
// Always log as structured JSON
logger.info('http_request_completed', {
  method: req.method,
  route: route,
  status_code: statusCode,
  duration_ms: durationMs,
  trace_id: traceId,
  span_id: spanId
});

// Use snake_case for log field names
logger.error('task_create_failed', {
  error_name: error.name,
  error_message: error.message,
  error_stack: error.stack
});
```

## Frontend Development Patterns

### React Component Structure
```javascript
// Imports: React first, then components, then styles
import React, { useState, useEffect } from 'react';
import './App.css';
import TaskForm from './components/TaskForm';
import TaskList from './components/TaskList';

// Constants after imports
const API_URL = process.env.REACT_APP_API_URL || '/api';

// Functional component with hooks
function App() {
  // State declarations grouped by purpose
  const [tasks, setTasks] = useState([]);
  const [filter, setFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Effects after state
  useEffect(() => {
    const controller = new AbortController();
    fetchTasks(controller.signal);
    
    return () => {
      controller.abort();
    };
  }, []);
  
  // Helper functions
  const fetchTasks = async (signal) => { /* ... */ };
  const handleCreateTask = async (taskData) => { /* ... */ };
  
  // Render
  return (
    <div className="App">
      {/* JSX */}
    </div>
  );
}

export default App;
```

### Async API Call Pattern
```javascript
// Always use try-catch with proper error handling
const handleCreateTask = async (taskData) => {
  try {
    const response = await fetch(`${API_URL}/tasks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(taskData),
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to create task');
    }
    
    const newTask = await response.json();
    setTasks((prevTasks) => [newTask, ...prevTasks]);
    showNotification('Task created successfully!', 'success');
    return true;
  } catch (err) {
    console.error('Error creating task:', err);
    setError(err.message);
    showNotification(err.message, 'error');
    return false;
  }
};
```

### State Update Pattern
```javascript
// Use functional updates for state that depends on previous state
setTasks((prevTasks) => [newTask, ...prevTasks]);

setTasks((prevTasks) =>
  prevTasks.map((task) => (task.id === taskId ? updatedTask : task))
);

setTasks((prevTasks) => prevTasks.filter((task) => task.id !== taskId));
```

### Abort Controller Pattern
```javascript
// Always provide cleanup for async operations in useEffect
useEffect(() => {
  const controller = new AbortController();
  fetchTasks(controller.signal);
  
  return () => {
    controller.abort();
  };
}, []);

// Handle abort in fetch
const fetchTasks = async (signal) => {
  try {
    const response = await fetch(`${API_URL}/tasks`, { signal });
    // process response
  } catch (err) {
    if (err.name === 'AbortError') {
      return; // Ignore abort errors
    }
    // handle other errors
  }
};
```

## Testing Patterns

### Jest Test Structure
```javascript
// Group tests by endpoint/feature
describe('TaskFlow API Tests', () => {
  // Reset state before each test
  beforeEach(() => {
    resetInMemoryData();
  });
  
  // Nested describe blocks for organization
  describe('POST /api/tasks', () => {
    it('should create a new task', async () => {
      const taskData = {
        title: 'Test Task',
        description: 'Test Description'
      };
      
      const res = await request(app).post('/api/tasks').send(taskData);
      
      expect(res.statusCode).toBe(201);
      expect(res.body).toHaveProperty('id');
      expect(res.body.title).toBe(taskData.title);
    });
    
    it('should reject empty title', async () => {
      const res = await request(app).post('/api/tasks').send({ title: '   ' });
      
      expect(res.statusCode).toBe(400);
      expect(res.body.error).toBe('Title is required');
    });
  });
});
```

### Test Naming Convention
- Use descriptive test names: `should create a new task`, `should reject empty title`
- Test both happy path and error cases
- Include observability testing: `should expose Prometheus RED metrics`
- Test edge cases: `should support response delay injection for latency testing`

## Infrastructure as Code Patterns

### Terraform Module Structure
```hcl
# Root module orchestrates child modules
module "networking" {
  source = "./modules/networking"
  
  security_group_name = "taskflow-sg"
  key_name            = var.key_name
  public_key_path     = var.public_key_path
  admin_cidr_blocks   = var.admin_cidr_blocks
}

module "compute" {
  source = "./modules/compute"
  
  # Reference outputs from other modules
  key_name            = module.networking.key_name
  security_group_name = module.networking.security_group_name
}
```

### Variable Naming
- Use snake_case: `jenkins_instance_type`, `admin_cidr_blocks`
- Provide descriptions for all variables
- Set sensible defaults where appropriate
- Use validation blocks for critical variables

### Resource Tagging
```hcl
tags = {
  Name        = "taskflow-${resource_type}"
  Project     = "TaskFlow"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```

## CI/CD Pipeline Patterns

### Jenkins Pipeline Structure
```groovy
pipeline {
  agent any
  
  environment {
    // Group related variables
    AWS_REGION = credentials('aws-region')
    BACKEND_IMAGE = "${ECR_REGISTRY}/${APP_NAME}-backend"
  }
  
  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }
  
  stages {
    // Use parallel for independent tasks
    stage('Build Docker Images') {
      parallel {
        stage('Build Backend') { /* ... */ }
        stage('Build Frontend') { /* ... */ }
      }
    }
  }
}
```

### Containerized Testing
```bash
# Run tests in containers to avoid Jenkins agent dependencies
docker run --rm -v $(pwd):/app -w /app node:18-alpine sh -c '
  npm ci
  npm test
'
```

### Error Handling in Shell Scripts
```bash
# Always use strict error handling
set -euo pipefail

# Define cleanup functions
cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

# Use trap for cleanup
trap cleanup EXIT
```

## Docker Best Practices

### Multi-Stage Builds
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app .
EXPOSE 5000
CMD ["node", "server.js"]
```

### Build Arguments
```dockerfile
ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_NUMBER

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
```

## Monitoring Configuration Patterns

### Prometheus Scrape Config
```yaml
scrape_configs:
  - job_name: 'taskflow-backend'
    scrape_interval: 15s
    static_configs:
      - targets: ['app-server:5000']
    metrics_path: '/metrics'
```

### Alert Rule Structure
```yaml
groups:
  - name: taskflow_alerts
    interval: 30s
    rules:
      - alert: TaskflowHighErrorRate
        expr: |
          100 * sum(rate(taskflow_http_errors_total{route!="/metrics"}[5m]))
          / clamp_min(sum(rate(taskflow_http_requests_total{route!="/metrics"}[5m])), 0.001)
          > 5
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
```

## Security Best Practices

### Credential Management
- Never hardcode credentials in code or configuration files
- Use Jenkins credentials for sensitive values
- Use IAM roles for AWS service access
- Store secrets in environment variables

### Input Validation
- Always validate and sanitize user input
- Set maximum lengths for string inputs
- Use type checking before processing
- Return specific error messages for validation failures

### CORS Configuration
```javascript
// Enable CORS for frontend communication
app.use(cors());
```

## Performance Optimization

### Response Time Targets
- Health checks: < 50ms
- API endpoints: < 100ms (p95)
- Metrics endpoint: < 200ms

### Resource Limits
```javascript
// Limit request body size
app.use(express.json({ limit: '1mb' }));

// Set maximum string lengths
const MAX_TITLE_LENGTH = 100;
const MAX_DESCRIPTION_LENGTH = 500;
```

### Efficient Data Structures
- Use in-memory arrays for small datasets
- Sort data once, cache results where possible
- Use functional updates to avoid unnecessary re-renders in React
