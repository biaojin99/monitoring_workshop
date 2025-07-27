# k6 Load Testing for Observability

This tutorial demonstrates how to use **k6** for performance testing and traffic generation. You'll start with basic load testing to generate traffic and observe your application's response, then learn how to integrate with Datadog for unified observability.

## 🎯 Learning Objectives

After completing this tutorial, you will understand:

1. **k6 Fundamentals**: How to write and execute simple load tests
2. **Traffic Generation**: Creating realistic load patterns to test your application
3. **Load Pattern Recognition**: Understanding how different load patterns affect performance
4. **Performance Baseline**: Establishing basic performance expectations through simple tests
5. **Advanced Integration**: Sending k6 metrics directly to Datadog for unified observability

## 📋 Prerequisites

- Completed [datadog workshop](../../datadog/README.md) with running services
- Basic understanding of JavaScript (k6 uses JavaScript for test scripts)
- Docker Compose knowledge (optional, for advanced scenarios)

## 🚀 Installing k6

### Option 1: Using Package Managers (Recommended)

#### macOS (using Homebrew)
```bash
brew install k6
```

```bash
# Install brew if command not found
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Restart terminal after installation
```

#### Ubuntu/Debian
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

#### Windows (using Chocolatey)
```bash
choco install k6
```

### Option 2: Using Docker
```bash
# Test installation with docker
docker run --rm -i --network="host" grafana/k6:latest run - <basic-load-test.js
```

### Option 3: Download Binary
```bash
# Download from https://k6.io/docs/get-started/installation/
# Extract and add to PATH
```

### Verify Installation
```bash
k6 version
# Expected output: k6 v0.47.0 (or later version)
```

## ✅ Prerequisites Check

Before running load tests, ensure your application is running:

```bash
# Navigate to datadog directory and check services
cd ../../datadog/
docker-compose ps

# Should show datadog-agent, datadog-postgres, and datadog-webapp as running
# If not running, start them:
# docker-compose up -d

# Navigate back to k6 directory
cd ../observability/k6-load-testing/

# Quick test to verify your application is responding
curl http://localhost:3001/health
# Expected: {"status": "healthy"}
```

## 🏗️ Test Structure and Components

### Basic k6 Test Structure

Every k6 test follows this structure:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp up
    { duration: '1m', target: 20 },   // Stay at 20 users
    { duration: '30s', target: 0 },   // Ramp down
  ],
};

// Main test function (executes for each virtual user)
export default function () {
  const response = http.get('http://localhost:3001/health');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);  // Think time between requests
}
```

### Key k6 Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **Virtual Users (VUs)** | Simulated concurrent users | `target: 50` = 50 concurrent users |
| **Iterations** | Number of test function executions | Each VU runs the test function multiple times |
| **Stages** | Test phases with different load levels | Ramp up → sustain → ramp down |
| **Checks** | Assertions for response validation | Status codes, response times |
| **Thresholds** | Pass/fail criteria for the test | `http_req_duration: ['p(95)<500']` |

## 📊 Simple Load Test Scenarios (Short Duration)

These test scenarios are designed to be simple and run quickly (2-3 minutes) while demonstrating load testing patterns and Datadog integration.

### Scenario 1: Basic Health Check Load Test

**File**: `basic-load-test.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // Ramp up to 5 users
    { duration: '1m', target: 5 },    // Stay at 5 users  
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // Error rate under 1%
  },
};

export default function () {
  const response = http.get('http://localhost:3001/health');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'has correct content': (r) => r.body.includes('healthy'),
    'response time OK': (r) => r.timings.duration < 500,
  });
  
  sleep(1); // 1 second think time
}

// Setup function (runs once before test)
export function setup() {
  console.log('Starting basic load test against Flask application...');
  
  // Verify target application is running
  const healthCheck = http.get('http://localhost:3001/health');
  if (healthCheck.status !== 200) {
    throw new Error('Target application is not healthy!');
  }
  
  return { timestamp: new Date().toISOString() };
}

// Teardown function (runs once after test)
export function teardown(data) {
  console.log(`Basic load test completed at ${data.timestamp}`);
}
```

### Scenario 2: Simple Multi-Endpoint Test

**File**: `simple-multi-endpoint-test.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 8 },   // Ramp up
    { duration: '1m', target: 8 },    // Sustained load
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.02'],
    'http_req_duration{endpoint:users}': ['p(95)<600'],
    'http_req_duration{endpoint:health}': ['p(95)<200'],
  },
};

export default function () {
  // Simple behavior: 70% health checks, 30% user operations
  const behavior = Math.random();
  
  if (behavior < 0.7) {
    // 70% - Health checks (fast)
    healthCheck();
  } else {
    // 30% - User operations (slower)
    userOperations();
  }
}

function healthCheck() {
  const response = http.get('http://localhost:3001/health', {
    tags: { endpoint: 'health' },
  });
  
  check(response, {
    'health status 200': (r) => r.status === 200,
    'health response fast': (r) => r.timings.duration < 200,
  });
  
  sleep(0.5); // Quick health checks
}

function userOperations() {
  const response = http.get('http://localhost:3001/users', {
    tags: { endpoint: 'users' },
  });
  
  check(response, {
    'users endpoint status 200': (r) => r.status === 200,
    'users response time < 600ms': (r) => r.timings.duration < 600,
  });
  
  sleep(1.5); // Consistent think time
}
```

### Scenario 3: Simple Ramp-Up Test

**File**: `simple-ramp-test.js`

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '20s', target: 2 },   // Start small
    { duration: '20s', target: 5 },   // Ramp to 5 users
    { duration: '20s', target: 10 },  // Ramp to 10 users
    { duration: '1m', target: 10 },   // Hold at 10 users
    { duration: '20s', target: 0 },   // Wind down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // More lenient for ramp test
    http_req_failed: ['rate<0.02'],
  },
};

export default function () {
  // Alternate between health checks and user operations
  const endpoints = ['health', 'users'];
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const response = http.get(`http://localhost:3001/${endpoint}`, {
    tags: { endpoint: endpoint },
  });
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time acceptable': (r) => r.timings.duration < 1000,
  });
  
  sleep(1); // Consistent think time
}
```

## 🎮 Running Basic Load Tests

### Quick Start - Running Your First Load Test

```bash
# Navigate to the k6 folder
cd observability/k6-load-testing/

# Run basic load test (2 minutes) - watch your application respond!
k6 run basic-load-test.js

# Run multi-endpoint test (2 minutes) - compare endpoint performance
k6 run simple-multi-endpoint-test.js

# Run ramp-up test (3 minutes) - see how your app handles increasing load
k6 run simple-ramp-test.js
```

### What to Observe During Tests

While k6 tests run, you can monitor your application's response in real-time:

#### 1. k6 Console Output
Watch the live metrics in your terminal:
- **Virtual Users (VUs)**: Current load level
- **Response Times**: How fast your app responds
- **Error Rate**: Any failed requests
- **Checks**: Whether your assertions pass

#### 2. Datadog APM Dashboard
Open [Datadog APM Services](https://app.datadoghq.com/apm/services) in another tab:
- **flask-webapp Service**: Watch latency increase during load
- **Request Rate**: See traffic spikes from your load test
- **Error Rate**: Monitor application errors under load

#### 3. Infrastructure Monitoring
Check [Datadog Infrastructure](https://app.datadoghq.com/infrastructure):
- **CPU Usage**: How hard your containers work under load
- **Memory Usage**: Resource consumption during tests
- **Network I/O**: Data transfer patterns

### Using Docker for k6 Tests

If you prefer using Docker k6:

```bash
# Basic test with Docker
docker run --rm -i --network="host" \
  grafana/k6:latest run - <basic-load-test.js

# Multi-endpoint test with Docker
docker run --rm -i --network="host" \
  grafana/k6:latest run - <simple-multi-endpoint-test.js

# Ramp test with Docker
docker run --rm -i --network="host" \
  grafana/k6:latest run - <simple-ramp-test.js
```

## 🎯 Simple Performance Validation

### Understanding k6 Output

k6 provides comprehensive metrics in the console:

```bash
# Example k6 output after running a test
     ✓ status is 200
     ✓ users response time < 600ms  
     ✓ health status 200

     checks.........................: 100.00% ✓ 956       ✗ 0
     data_received..................: 312 kB  5.2 kB/s
     data_sent......................: 76 kB   1.3 kB/s
     http_req_duration..............: avg=245.37ms min=101.77ms med=240.35ms max=505.73ms p(90)=321.09ms p(95)=368.11ms
     http_req_failed................: 0.00%   ✓ 0         ✗ 956
     http_reqs......................: 956     15.93/s
     iteration_duration.............: avg=1.24s    min=1.10s    med=1.24s    max=1.51s    p(90)=1.32s    p(95)=1.36s  
     iterations.....................: 956     15.93/s
     vus............................: 5       min=5       max=5
     vus_max........................: 5       min=5       max=5
```

### Key Metrics to Watch

| Metric | What it Measures | Good Threshold |
|--------|------------------|----------------|
| **http_req_duration p(95)** | 95% of requests complete within this time | < 500ms |
| **http_req_failed** | Percentage of failed requests | < 1% |
| **checks** | Percentage of successful checks | 100% |
| **http_reqs** | Requests per second | Depends on capacity |

### Quick Performance Checks

Use these simple tests to validate basic performance expectations:

#### Response Time Check
```bash
# Verify response times stay reasonable under light load
k6 run basic-load-test.js

# Expected: p95 < 500ms in k6 output
```

#### Error Rate Check
```bash
# Verify error rates stay low during multi-endpoint test
k6 run simple-multi-endpoint-test.js

# Expected: http_req_failed should be 0.00%
```

#### Load Tolerance Check
```bash
# Verify application handles gradual load increases
k6 run simple-ramp-test.js

# Expected: Response times increase gradually, no sudden spikes
```

## 🐛 Troubleshooting

### Common Issues

#### "Connection Refused" Errors
```bash
# Check if datadog workshop is running
cd ../../datadog/
docker-compose ps

# Restart if needed
docker-compose down && docker-compose up -d
```

#### High Latency During Tests
```bash
# Check system resources
docker stats

# May need to:
# 1. Reduce VU count
# 2. Increase think time
# 3. Scale application
```

#### k6 Installation Issues
```bash
# Verify installation
k6 version

# Use Docker if binary installation fails
docker run --rm -i --network="host" grafana/k6:latest run - <basic-load-test.js
```

### Performance Tuning

#### Optimizing k6 Performance

```bash
# For high-load tests, tune k6
export K6_NO_USAGE_REPORT=true
export K6_NO_VU_CONNECTION_REUSE=false

# Run with optimizations
k6 run --no-thresholds --no-summary spike-test.js
```

#### System Limits

```bash
# Check system limits for high VU counts
ulimit -n  # File descriptors
ulimit -u  # Processes

# Increase if needed (macOS/Linux)
ulimit -n 65536
```

## ✅ Simple Validation Exercises

### Exercise 1: Basic Load Pattern Recognition
1. Run `k6 run basic-load-test.js` (2 minutes)
2. Watch the k6 console output for response times and virtual user metrics
3. Note how response times change as virtual users ramp up
4. Simultaneously monitor Datadog APM Services to see application impact

### Exercise 2: Multi-Endpoint Comparison
1. Run `k6 run simple-multi-endpoint-test.js` (2 minutes)
2. Compare response times in k6 output for different endpoint behavior
3. Check Datadog APM Resources tab to compare `/health` vs `/users` performance
4. Observe which endpoint handles load better

### Exercise 3: Load Pattern Analysis
1. Run `k6 run simple-ramp-test.js` (3 minutes)
2. Watch k6 metrics change during each ramp stage
3. Monitor Datadog Infrastructure to see CPU/memory changes
4. Identify at what user count performance starts to degrade

## 📚 Key Takeaways

1. **Simple Tests, Real Insights**: Short 2-3 minute tests can reveal important performance patterns
2. **Application Monitoring**: Monitor your application's response to load in Datadog APM and Infrastructure
3. **Pattern Recognition**: Different load patterns (steady, multi-endpoint, ramp-up) reveal different bottlenecks
4. **Baseline Understanding**: Regular simple load tests help establish performance baselines
5. **Real-time Correlation**: Observing application metrics during load tests shows immediate impact

---

## 🚀 Advanced: Datadog Integration with k6 Metrics

Ready to take it further? You can send k6 metrics directly to Datadog for unified observability!

### Prerequisites: Install xk6 (Extension Builder)

First, install `xk6` to build k6 with extensions:

```bash
# Option 1: Using Go (Recommended)
go install go.k6.io/xk6/cmd/xk6@latest

# Option 2: Using Homebrew
brew install xk6

# Option 3: Download binary from GitHub
# Visit: https://github.com/grafana/xk6/releases
# Download for macOS and add to PATH
```

Verify xk6 installation:
```bash
xk6 version
# Expected output: xk6 v0.x.x (go1.x.x)
```

### Build k6 with StatsD Extension

**Note**: The built-in `--out statsd` was removed in k6 v0.55.0. Use the xk6-output-statsd extension:

```bash
# One-time build with xk6-output-statsd extension
xk6 build --with github.com/LeonAdato/xk6-output-statsd

# This creates a custom ./k6 binary with StatsD support
```

### Send k6 Metrics to Datadog

Your Datadog Agent is already configured to receive StatsD metrics on port 8125:

```bash
# Run tests with StatsD output to Datadog Agent
K6_STATSD_ENABLE_TAGS=true ./k6 run -o output-statsd basic-load-test.js

# Environment variables explained:
# K6_STATSD_ENABLE_TAGS=true - enables endpoint tagging
# -o output-statsd - sends metrics to localhost:8125 (Datadog Agent)
```

### View k6 Metrics in Datadog

After running tests with StatsD output, you'll see k6 metrics in Datadog:

#### 1. Datadog Metrics Explorer
- Navigate to [Datadog Metrics Explorer](https://app.datadoghq.com/metric/explorer)
- Search for metrics starting with `k6.` (e.g., `k6.http_req_duration`, `k6.vus`)
- Filter by tags like `endpoint:health` or `endpoint:users`

#### 2. Key k6 Metrics Available
- **`k6.http_req_duration`**: Response times (avg, p95, p99)
- **`k6.http_reqs`**: Request rate (requests/second)
- **`k6.http_req_failed`**: Error rate percentage
- **`k6.vus`**: Number of active virtual users
- **`k6.data_sent/received`**: Network traffic volume

#### 3. Advanced Commands

```bash
# All your previous tests now with Datadog metrics:

# Basic test with StatsD metrics
K6_STATSD_ENABLE_TAGS=true ./k6 run -o output-statsd basic-load-test.js

# Multi-endpoint test with StatsD metrics  
K6_STATSD_ENABLE_TAGS=true ./k6 run -o output-statsd simple-multi-endpoint-test.js

# Ramp-up test with StatsD metrics
K6_STATSD_ENABLE_TAGS=true ./k6 run -o output-statsd simple-ramp-test.js
```

#### 4. Docker Alternative

```bash
# Build and run with Docker in one command
docker run --rm -i --network="host" \
  -e K6_STATSD_ENABLE_TAGS=true \
  -e K6_STATSD_ADDR=localhost:8125 \
  -v "${PWD}:/scripts" \
  --entrypoint="" \
  grafana/xk6:latest \
  sh -c "xk6 build --with github.com/LeonAdato/xk6-output-statsd && ./k6 run -o output-statsd /scripts/basic-load-test.js"
```

### Benefits of k6 + Datadog Integration

1. **Unified Dashboard**: Combine k6 load metrics with application APM and infrastructure
2. **Tagged Metrics**: Filter by endpoint, test type, or custom tags
3. **Historical Trends**: Track performance changes over time
4. **Alerting**: Set up alerts on k6 metrics for automated monitoring
5. **Correlation**: Directly correlate load test results with application behavior

---

## 🔗 Next Steps

1. **Custom Test Scenarios**: Create tests that match your specific application endpoints
2. **Datadog Dashboards**: Build custom dashboards combining k6 and application metrics  
3. **Automated Testing**: Schedule regular load tests to monitor performance trends
4. **Advanced Patterns**: Explore more complex load patterns as you gain confidence

## 📖 Additional Resources

- [k6 Documentation](https://k6.io/docs/)
- [k6 Best Practices](https://k6.io/docs/testing-guides/test-types/)
- [Performance Testing Guide](https://k6.io/docs/testing-guides/running-large-tests/)
- [xk6-output-statsd Extension](https://github.com/LeonAdato/xk6-output-statsd)

---

**💡 Pro Tip**: Start simple with basic k6 load testing to understand your application's behavior, then enhance with Datadog integration for comprehensive observability! 