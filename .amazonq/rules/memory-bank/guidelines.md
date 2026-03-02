# TaskFlow - Development Guidelines

## Code Quality Standards

### Code Formatting
- **Indentation**: 2 spaces (consistent across JavaScript files)
- **Semicolons**: Required at end of statements
- **Quotes**: Single quotes for strings (backend), mixed in frontend
- **Line Length**: Keep reasonable, typically under 100 characters
- **Trailing Commas**: Used in multi-line objects and arrays

### Naming Conventions
- **Variables/Functions**: camelCase (`fetchTasks`, `handleCreateTask`, `httpRequestsTotal`)
- **Constants**: UPPER_SNAKE_CASE for configuration (`MAX_TITLE_LENGTH`, `API_URL`, `SERVICE_NAME`)
- **Components**: PascalCase for React components (`TaskForm`, `TaskList`, `TaskFilter`)
- **Files**: kebab-case for scripts, camelCase for modules (`app.js`, `validate-observability.sh`)
- **Metrics**: snake_case with service prefix (`taskflow_http_requests_total`, `taskflow_tasks_total`)
- **Environment Variables**: UPPER_SNAKE_CASE (`NODE_ENV`, `OTEL_SERVICE_NAME`, `REACT_APP_API_URL`)

### Documentation Standards
- **Inline Comments**: Used sparingly, only for complex logic or observability features
- **Function Comments**: Not required for self-documenting code
- **User Story References**: Comment with US-XXX format in frontend (`// US-001: Create new task`)
- **Error Context**: Descriptive error messages in structured logs

## Structural Conventions

### Module Organization
- **Single Responsibility**: Each module has one clear purpose
  - `app.js` - Express routes and middleware
  - `metrics.js` - Prometheus metrics definitions
  - `telemetry.js` - OpenTelemetry configuration
  - `logger.js` - Structured logging
  - `server.js` - HTTP server entrypoint

### Dependency Management
- **Explicit Imports**: Import only what's needed
  ```javascript
  const { context, trace } = require('@opentelemetry/api');
  const { v4: uuidv4 } = require('uuid');
  ```
- **Destructuring**: Use destructuring for cleaner imports
- **Module Exports**: Export only public API
  ```javascript
  module.exports = {
    app,
    resetInMemoryData
  };
  ```

### Error Handling Patterns
- **Try-Catch Blocks**: Wrap all async operations and route handlers
  ```javascript
  try {
    // Operation
    return res.status(200).json(result);
  } catch (error) {
    logger.error('operation_failed', {
      ...extractErrorFields(error)
    });
    return res.status(500).json({ error: 'Internal server error' });
  }
  ```
- **Early Returns**: Use early returns for validation failures
  ```javascript
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }
  ```
- **Consistent Error Responses**: Always return JSON with `error` field
- **Error Field Extraction**: Use helper function to extract error details
  ```javascript
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

## Observability Practices

### Structured Logging
- **JSON Format**: All logs in JSON format for parsing
  ```javascript
  logger.info('http_request_completed', {
    method: req.method,
    route,
    status_code: statusCode,
    duration_ms: Number((durationSeconds * 1000).toFixed(2)),
    trace_id: spanContext.traceId,
    span_id: spanContext.spanId
  });
  ```
- **Log Levels**: Use appropriate levels (info, warn, error)
  - `info` - Normal operations (2xx, 3xx responses)
  - `warn` - Client errors (4xx responses)
  - `error` - Server errors (5xx responses)
- **Trace Context**: Include `trace_id` and `span_id` in all logs
- **Structured Fields**: Use snake_case for log field names

### Metrics Implementation
- **RED Methodology**: Rate, Errors, Duration for all HTTP endpoints
  ```javascript
  const httpRequestsTotal = new client.Counter({
    name: 'taskflow_http_requests_total',
    help: 'Total number of HTTP requests handled by the backend',
    labelNames: ['method', 'route', 'status_code'],
    registers: [register]
  });
  ```
- **Label Consistency**: Use consistent labels across metrics (`method`, `route`, `status_code`)
- **Path Normalization**: Replace IDs with `:id` placeholder
  ```javascript
  function normalizePath(path) {
    return path
      .replace(UUID_PATTERN, ':id')
      .replace(/\/\d+(?=\/|$)/g, '/:id');
  }
  ```
- **Histogram Buckets**: Define appropriate buckets for latency SLOs
  ```javascript
  buckets: [0.01, 0.03, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5]
  ```
- **Gauge for State**: Use Gauge for current state metrics (`taskflow_tasks_total`)

### Distributed Tracing
- **Auto-Instrumentation**: Use OpenTelemetry auto-instrumentation
  ```javascript
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': {
        enabled: false
      },
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => request.url === '/metrics'
      }
    })
  ]
  ```
- **Span Context Extraction**: Extract trace context from active span
  ```javascript
  const spanContext = trace.getSpan(context.active())?.spanContext();
  ```
- **OTLP Export**: Use OTLP HTTP exporter for Jaeger
- **Service Naming**: Set service name via environment variable

### Monitoring Endpoints
- **Health Check**: Simple endpoint returning status and basic metrics
  ```javascript
  app.get('/health', (req, res) => {
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      tasksCount: tasks.length
    });
  });
  ```
- **Metrics Endpoint**: Expose Prometheus metrics at `/metrics`
- **Exclude from Tracing**: Don't trace `/metrics` endpoint to avoid noise

## API Design Patterns

### RESTful Conventions
- **Resource Naming**: Plural nouns (`/api/tasks`)
- **HTTP Methods**: Standard CRUD mapping
  - POST `/api/tasks` - Create
  - GET `/api/tasks` - List
  - GET `/api/tasks/:id` - Read (not implemented, using list)
  - PATCH `/api/tasks/:id` - Partial update (status)
  - PUT `/api/tasks/:id` - Full update (title, description)
  - DELETE `/api/tasks/:id` - Delete
- **Status Codes**: Appropriate HTTP status codes
  - 200 - Success
  - 201 - Created
  - 400 - Bad request (validation)
  - 404 - Not found
  - 500 - Server error
  - 502 - Bad gateway (upstream failure)

### Request/Response Patterns
- **JSON Content-Type**: Always use `application/json`
- **Request Validation**: Validate before processing
  ```javascript
  const validationError = validateTaskPayload(title, description);
  if (validationError) {
    return res.status(400).json({ error: validationError });
  }
  ```
- **Response Consistency**: Always return JSON objects
- **Timestamps**: ISO 8601 format (`new Date().toISOString()`)
- **ID Generation**: Use UUID v4 for unique identifiers

### Middleware Patterns
- **CORS**: Enable CORS for cross-origin requests
  ```javascript
  app.use(cors());
  ```
- **Body Parsing**: Limit request body size
  ```javascript
  app.use(express.json({ limit: '1mb' }));
  ```
- **Request Logging**: Log all requests with timing
  ```javascript
  app.use((req, res, next) => {
    const startTime = process.hrtime.bigint();
    res.on('finish', () => {
      // Log request with duration
    });
    next();
  });
  ```
- **Error Handler**: Global error handler at the end
  ```javascript
  app.use((err, req, res, _next) => {
    logger.error('unhandled_error', { ...extractErrorFields(err) });
    res.status(500).json({ error: 'Something went wrong!' });
  });
  ```

## Frontend Patterns

### React Hooks Usage
- **useState**: For component state management
  ```javascript
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  ```
- **useEffect**: For side effects (data fetching)
  ```javascript
  useEffect(() => {
    const controller = new AbortController();
    fetchTasks(controller.signal);
    return () => {
      controller.abort();
    };
  }, []);
  ```
- **Cleanup**: Always cleanup in useEffect return function

### State Management
- **Immutable Updates**: Use functional updates for state
  ```javascript
  setTasks((prevTasks) => [newTask, ...prevTasks]);
  setTasks((prevTasks) =>
    prevTasks.map((task) => (task.id === taskId ? updatedTask : task))
  );
  ```
- **Derived State**: Calculate filtered data from state
  ```javascript
  const filteredTasks = getFilteredTasks();
  const activeCount = tasks.filter(task => !task.completed).length;
  ```

### API Communication
- **Fetch API**: Use native fetch for HTTP requests
- **Async/Await**: Use async/await for cleaner code
- **Error Handling**: Try-catch for all API calls
- **Abort Controller**: Support request cancellation
  ```javascript
  const controller = new AbortController();
  const response = await fetch(`${API_URL}/tasks`, { signal: controller.signal });
  ```
- **Response Validation**: Check response.ok before parsing
  ```javascript
  if (!response.ok) {
    throw new Error('Failed to fetch tasks');
  }
  ```

### User Feedback
- **Loading States**: Show loading indicator during async operations
- **Error Messages**: Display user-friendly error messages
- **Notifications**: Temporary success/error notifications
  ```javascript
  const showNotification = (message, type) => {
    setNotification({ message, type });
    setTimeout(() => setNotification(null), 3000);
  };
  ```
- **Confirmations**: Confirm destructive actions
  ```javascript
  if (!window.confirm('Are you sure you want to delete this task?')) {
    return;
  }
  ```

## Testing Standards

### Test Organization
- **Describe Blocks**: Group related tests
  ```javascript
  describe('TaskFlow API Tests', () => {
    describe('GET /health', () => {
      it('should return healthy status', async () => {
        // Test implementation
      });
    });
  });
  ```
- **BeforeEach**: Reset state before each test
  ```javascript
  beforeEach(() => {
    resetInMemoryData();
  });
  ```

### Test Patterns
- **Supertest**: Use supertest for API testing
  ```javascript
  const res = await request(app).get('/health');
  expect(res.statusCode).toBe(200);
  ```
- **Assertions**: Use Jest matchers
  - `toBe()` - Strict equality
  - `toEqual()` - Deep equality
  - `toHaveProperty()` - Object property check
  - `toContain()` - String/array contains
  - `toBeGreaterThanOrEqual()` - Numeric comparison
- **Async Tests**: Use async/await in test functions
- **Test Data**: Create minimal test data for each test

### Test Coverage
- **Happy Path**: Test successful operations
- **Error Cases**: Test validation failures, not found, server errors
- **Edge Cases**: Empty data, whitespace, invalid input
- **Performance**: Test delay injection for latency testing
  ```javascript
  it('should support response delay injection for latency testing', async () => {
    const start = Date.now();
    const res = await request(app).get('/api/tasks?delay_ms=120');
    const elapsed = Date.now() - start;
    expect(elapsed).toBeGreaterThanOrEqual(100);
  });
  ```

## Configuration Management

### Environment Variables
- **Defaults**: Provide sensible defaults
  ```javascript
  const PORT = Number(process.env.PORT || 5000);
  const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || 'taskflow-backend';
  ```
- **Type Conversion**: Convert string env vars to appropriate types
- **Validation**: Validate required environment variables
  ```yaml
  environment:
    - NODE_ENV=production
    - OTEL_SERVICE_NAME=taskflow-backend
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://${MONITORING_HOST}:4318
  ```

### Feature Flags
- **Conditional Logic**: Use environment variables for feature toggles
  ```javascript
  if (process.env.OTEL_SDK_DISABLED === 'true') {
    return;
  }
  ```
- **Test Mode**: Special handling for test environment
  ```javascript
  if (process.env.NODE_ENV === 'test') {
    return Promise.resolve(getHealthSnapshot());
  }
  ```

## Security Practices

### Input Validation
- **Length Limits**: Enforce maximum lengths
  ```javascript
  const MAX_TITLE_LENGTH = 100;
  const MAX_DESCRIPTION_LENGTH = 500;
  ```
- **Type Checking**: Validate data types
  ```javascript
  if (typeof title !== 'string' || title.trim().length === 0) {
    return 'Title is required';
  }
  ```
- **Sanitization**: Trim whitespace from user input
  ```javascript
  title: title.trim()
  ```

### Error Information
- **Generic Messages**: Don't expose internal details to clients
  ```javascript
  res.status(500).json({ error: 'Internal server error' });
  ```
- **Detailed Logging**: Log full error details internally
  ```javascript
  logger.error('task_create_failed', {
    error_name: error.name,
    error_message: error.message,
    error_stack: error.stack
  });
  ```

### Resource Limits
- **Request Body Size**: Limit to prevent DoS
  ```javascript
  app.use(express.json({ limit: '1mb' }));
  ```
- **Delay Caps**: Cap artificial delays
  ```javascript
  const MAX_DELAY_MS = 5000;
  return Math.min(parsedDelay, MAX_DELAY_MS);
  ```

## Performance Optimization

### Response Time
- **Early Returns**: Return as soon as possible
- **Minimal Processing**: Only process what's needed
- **Async Operations**: Use async/await for I/O operations

### Memory Management
- **In-Memory Storage**: Simple array for tasks (demo purposes)
- **Metric Reset**: Provide reset function for testing
  ```javascript
  function resetInMemoryData() {
    tasks = [];
    resetMetrics();
    setTasksTotal(0);
  }
  ```

### Monitoring Performance
- **High-Resolution Timing**: Use `process.hrtime.bigint()` for accurate timing
  ```javascript
  const startTime = process.hrtime.bigint();
  const elapsed = process.hrtime.bigint() - startTime;
  const durationSeconds = Number(elapsed) / 1e9;
  ```
- **Latency Testing**: Support artificial delays for testing
  ```javascript
  const delayMs = parseDelayMs(req.query.delay_ms);
  if (delayMs > 0) {
    await delay(delayMs);
  }
  ```

## Code Idioms

### Frequently Used Patterns

#### Sanitization Functions
```javascript
function sanitizeMethod(method) {
  if (!method) {
    return 'UNKNOWN';
  }
  return method.toUpperCase();
}
```

#### Promise-based Delays
```javascript
function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
```

#### Array Sorting
```javascript
const sortedTasks = [...tasks].sort((a, b) => 
  new Date(b.createdAt) - new Date(a.createdAt)
);
```

#### Conditional Rendering (React)
```javascript
{loading ? (
  <div className="loading">Loading tasks...</div>
) : (
  <TaskList tasks={filteredTasks} />
)}
```

#### Ternary for Conditional Values
```javascript
const traceContext = spanContext
  ? {
      trace_id: spanContext.traceId,
      span_id: spanContext.spanId
    }
  : {};
```

## Annotations and Comments

### Observability Comments
- Mark observability-specific code
  ```javascript
  // Test route for error simulation (observability validation)
  ```

### User Story References
- Link code to requirements in frontend
  ```javascript
  // US-001: Create new task
  // US-002: Fetch tasks on component mount
  // US-003: Toggle task completion status
  ```

### Configuration Comments
- Document important configuration decisions
  ```javascript
  // Exclude /metrics from tracing to avoid noise
  ignoreIncomingRequestHook: (request) => request.url === '/metrics'
  ```

### Inline Explanations
- Explain non-obvious logic
  ```javascript
  // Replace UUIDs and numeric IDs with :id placeholder
  return path
    .replace(UUID_PATTERN, ':id')
    .replace(/\/\d+(?=\/|$)/g, '/:id');
  ```
