# Prometheus + Grafana Monitoring Workshop

This module demonstrates comprehensive monitoring with **Prometheus** and **Grafana** using a Flask application. You'll learn how to set up Prometheus metrics collection, create Grafana dashboards, and implement a complete observability stack.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Monitoring Features](#monitoring-features)
- [Workshop Exercises](#workshop-exercises)
  - [Exercise 1: Golden Signals Monitoring with Prometheus Queries](#exercise-1-golden-signals-monitoring-with-prometheus-queries)
  - [Exercise 2: Grafana Dashboard Creation](#exercise-2-grafana-dashboard-creation)
- [Troubleshooting](#troubleshooting)
- [Learning Objectives](#learning-objectives)

## Overview

This workshop module provides a hands-on experience with Prometheus and Grafana monitoring, featuring:

- **Flask Application**: Python web app instrumented with Prometheus metrics
- **Prometheus**: Time-series database for metrics collection
- **Grafana**: Visualization and dashboarding platform
- **Container Monitoring**: cAdvisor for Docker container metrics
- **System Monitoring**: Node exporter for system metrics
- **StatsD Integration**: Custom metrics via StatsD exporter

## Prerequisites

### Software Requirements
- Docker and Docker Compose
- curl (for traffic generation)
- bc (basic calculator, for shell scripts)

### System Requirements
- 6GB RAM minimum (more components than Datadog module)
- 15GB free disk space
- Available ports: 3000 (Grafana), 3001 (App), 8080 (cAdvisor), 9090 (Prometheus)

## Quick Start

1. **Start all services:**
   ```bash
   cd prometheus/
   docker-compose up -d
   # All services start in correct order with health checks (2-3 minutes)
   ```

2. **Generate traffic:**
   ```bash
   ./generate_traffic.sh quick
   ```

3. **View monitoring:**
   - **Prometheus**: http://localhost:9090
   - **Grafana**: http://localhost:3000 (admin/foobar)
   - **App Metrics**: http://localhost:3001/metrics 

## Monitoring Features

### Golden Signals Monitoring

This Flask application demonstrates monitoring of the **Four Golden Signals**:

1. **Latency**: `/delay?seconds=X` - Test response time monitoring
2. **Traffic**: Automatic HTTP request counting via prometheus-flask-exporter
3. **Errors**: `/error?rate=X` - Generate 400/404/500 errors for error rate monitoring
4. **Saturation**: `/cpu-intensive` and `/memory-usage` - Test resource monitoring

### Custom Business Metrics

The application includes custom business metrics to demonstrate how to track business-specific events:

- **`webapp_custom_requests_total`**: Counts requests per endpoint
- **`webapp_business_operations_total`**: Counts business operations by type (user_login, payment, etc.)

### How Python Decorators Work for Metrics

Understanding how the custom metrics work is crucial for implementing your own business metrics. Here's how Python decorators enable automatic metrics collection:

#### Decorator Basics

When you see this code:
```python
@app.route("/business-metrics")
@request_counter
@business_operations
def business_metrics():
    request.operation_type = "payment"  # Set label value
    return {"status": "success"}
```

Python processes decorators from bottom to top, wrapping your function:
```python
# Equivalent to:
business_metrics = app.route("/business-metrics")(business_metrics)
business_metrics = request_counter(business_metrics)
business_metrics = business_operations(business_operations)
```

#### Execution Flow

When a request comes in, here's what happens:

1. **Request arrives**: `GET /business-metrics?operation=payment`
2. **Flask routes to function**
3. **Decorator wrappers start executing** (in reverse order)
4. **Your function runs**:
   ```python
   operation = request.args.get("operation", "payment")
   request.operation_type = operation  # ← Key: Set the label value
   ```
5. **Decorator wrappers finish** (prometheus-flask-exporter magic):
   ```python
   # business_operations decorator reads the label:
   operation_type = getattr(request, 'operation_type', 'unknown')
   # Increments: webapp_business_operations_total{operation_type="payment"}
   
   # request_counter decorator reads the endpoint:
   endpoint = request.endpoint  # "business_metrics"
   # Increments: webapp_custom_requests_total{endpoint="business_metrics"}
   ```

#### The Lambda Pattern

The key to dynamic labels is using lambda functions in metric definitions:

```python
business_operations = metrics.counter(
    'webapp_business_operations_total', 'Total business operations',
    labels={'operation_type': lambda: getattr(request, 'operation_type', 'unknown')}
)
```

- The `lambda:` function executes **after** your route function completes
- It reads values from the `request` object that you set in your function
- This creates dynamic labels based on business logic

#### Why This Pattern Works

✅ **Separation of Concerns**: Business logic and metrics collection are separate  
✅ **Dynamic Labels**: Label values determined at runtime  
✅ **Clean Code**: No manual metric.inc() calls scattered throughout code  
✅ **Prometheus Best Practices**: Proper time series with meaningful labels  

#### Testing Custom Metrics

```bash
# Generate business operations
curl "http://localhost:3001/business-metrics?operation=user_login"
curl "http://localhost:3001/business-metrics?operation=payment"

# Check the metrics
curl http://localhost:3001/metrics | grep webapp_business_operations_total
# Output:
# webapp_business_operations_total{operation_type="user_login"} 1.0
# webapp_business_operations_total{operation_type="payment"} 1.0
```

### Available Endpoints

| Endpoint | Purpose | Parameters | Example |
|----------|---------|------------|---------|
| `/` | Basic hello world | None | `curl http://localhost:3001/` |
| `/health` | Health check | None | `curl http://localhost:3001/health` |
| `/business-metrics` | **Custom metrics demo** | `operation` | `curl "http://localhost:3001/business-metrics?operation=payment"` |
| `/delay` | Latency testing | `seconds` | `curl "http://localhost:3001/delay?seconds=2"` |
| `/error` | Error rate testing | `rate` (%) | `curl "http://localhost:3001/error?rate=80"` |
| `/cpu-intensive` | CPU saturation | `iterations` | `curl "http://localhost:3001/cpu-intensive?iterations=50000"` |
| `/memory-usage` | Memory saturation | `size` (MB) | `curl "http://localhost:3001/memory-usage?size=10"` |
| `/metrics` | **Prometheus metrics** | None | `curl http://localhost:3001/metrics` |

## Workshop Exercises

### Exercise 1: Golden Signals Monitoring with Prometheus Queries

This exercise teaches you how to use **PromQL** (Prometheus Query Language) to monitor the Four Golden Signals. You'll learn to write queries, understand metrics, and analyze application performance.

#### Prerequisites
1. Ensure all services are running: `docker-compose up -d`
2. Generate some traffic: `./generate_traffic.sh quick`
3. Open Prometheus: http://localhost:9090

#### Part A: Traffic (Request Rate)

**Goal**: Monitor how many requests per second your application is handling.

1. **Open Prometheus Console** at http://localhost:9090
2. **Click the "Graph" tab** at the top
3. **Basic Request Count Query**:
   ```promql
   flask_http_request_duration_seconds_count
   ```
   - Click **Execute** button
   - Switch to **Table** view to see all metrics
   - **What you see**: Total request count since startup, broken down by endpoint, method, and status code
   - **Note**: This is the `_count` from the duration histogram, which tracks total requests

4. **Request Rate Query** (requests per second):
   ```promql
   rate(flask_http_request_duration_seconds_count[5m])
   ```
   - **Explanation**: `rate()` calculates per-second rate over a 5-minute window using the histogram count
   - Switch to **Graph** view to see the rate over time
   - **What you see**: How many requests/second each endpoint is receiving

5. **Total Application Request Rate**:
   ```promql
   sum(rate(flask_http_request_duration_seconds_count[5m]))
   ```
   - **Explanation**: `sum()` adds up all endpoints to get total app traffic
   - **Key Insight**: This is your application's overall throughput

#### Part B: Latency (Response Time)

**Goal**: Monitor how long requests take to complete (p95, p99 percentiles).

1. **Response Time Histogram**:
   ```promql
   flask_http_request_duration_seconds_bucket
   ```
   - **What you see**: Histogram buckets showing response time distribution
   - **Explanation**: Histograms group response times into buckets (0.005s, 0.01s, 0.025s, etc.)

2. **95th Percentile Latency** (95% of requests are faster than this):
   ```promql
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
   ```
   - **Explanation**: 
     - `histogram_quantile(0.95, ...)` calculates 95th percentile
     - Uses the rate of histogram buckets over 5 minutes
   - **Key Insight**: If this shows 2 seconds, 95% of requests complete in under 2 seconds

3. **99th Percentile Latency** (slowest 1% of requests):
   ```promql
   histogram_quantile(0.99, rate(flask_http_request_duration_seconds_bucket[5m]))
   ```
   - **Why important**: Shows worst-case user experience

4. **Latency by Endpoint**:
   ```promql
   histogram_quantile(0.95, sum by (le, path) (rate(flask_http_request_duration_seconds_bucket[5m])))
   ```
   - **Explanation**: `sum by (le, path)` groups histogram buckets by endpoint while preserving bucket boundaries
   - **What you see**: 95th percentile latency for each endpoint separately
   - **Note**: The `by` clause must be inside `sum()` and include both `le` and `path` labels

#### Part C: Errors (Error Rate)

**Goal**: Monitor what percentage of requests are failing.

1. **Error Requests Only**:
   ```promql
   flask_http_request_duration_seconds_count{status=~"4..|5.."}
   ```
   - **Explanation**: `status=~"4..|5.."` matches HTTP 4xx and 5xx status codes using regex
   - **What you see**: Total count of error responses

2. **Error Rate**:
   ```promql
   rate(flask_http_request_duration_seconds_count{status=~"4..|5.."}[5m])
   ```
   - **What you see**: Errors per second

3. **Error Percentage**:
   ```promql
   (
     sum(rate(flask_http_request_duration_seconds_count{status=~"4..|5.."}[5m])) 
     / 
     sum(rate(flask_http_request_duration_seconds_count[5m]))
   ) * 100
   ```
   - **Explanation**: 
     - Top: Error rate
     - Bottom: Total request rate  
     - Result: Percentage of requests that fail
   - **Key Insight**: If this shows 5, then 5% of requests are failing

4. **Error Rate by Status Code**:
   ```promql
   sum(rate(flask_http_request_duration_seconds_count{status=~"4..|5.."}[5m])) by (status)
   ```
   - **What you see**: Which error types are most common (404s vs 500s)

#### Part D: Saturation (Resource Usage)

**Goal**: Monitor CPU and memory usage to detect resource bottlenecks.

1. **Container CPU Usage** (from cAdvisor):
   ```promql
   rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m]) * 100
   ```
   - **Explanation**: 
     - `container_cpu_usage_seconds_total` tracks CPU time used
     - `rate(...) * 100` converts to CPU percentage
     - `id=~"/docker/.*"` filters to Docker containers (excludes system containers)
   - **What you see**: CPU percentage used by all Docker containers

2. **Container Memory Usage**:
   ```promql
   container_memory_usage_bytes{id=~"/docker/.*"} / 1024 / 1024
   ```
   - **Explanation**: Converts bytes to megabytes (/ 1024 / 1024)
   - **What you see**: Memory usage in MB for Docker containers

3. **Flask App Container Specifically** (if you want to filter to just the webapp):
   ```promql
   rate(container_cpu_usage_seconds_total{id=~".*prometheus-webapp.*"}[5m]) * 100
   ```
   - **Explanation**: Filters to containers with "prometheus-webapp" in the container ID
   - **What you see**: CPU usage for just your Flask application container

#### Part E: Advanced Queries

1. **Alert Condition - High Error Rate**:
   ```promql
   (
     sum(rate(flask_http_request_duration_seconds_count{status=~"5.."}[5m])) 
     / 
     sum(rate(flask_http_request_duration_seconds_count[5m]))
   ) > 0.05
   ```
   - **Purpose**: Returns 1 when error rate > 5%, used for alerting

2. **SLA Monitoring - 95% of requests under 1 second**:
   ```promql
   histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m])) < 1.0
   ```
   - **Purpose**: Returns 1 when SLA is met, 0 when violated

### Exercise 2: Grafana Dashboard Creation

This exercise teaches you to create Grafana dashboards for the same Golden Signals, with visual charts and alerts.

#### Prerequisites
1. Open Grafana: http://localhost:3000
2. Login: `admin` / `foobar`
3. Generate traffic: `./generate_traffic.sh demo` (run this in background during the exercise)

#### Part A: Configure Prometheus Data Source

**IMPORTANT**: Before creating dashboards, you must connect Grafana to Prometheus.

1. **Add Data Source**:
   - In Grafana, click **"Connections"** in left sidebar
   - Click **"Data sources"**
   - Click **"Add data source"**
   - Select **"Prometheus"**

2. **Configure Prometheus Connection**:
   - **Name**: `Prometheus`
   - **URL**: `http://prometheus:9090` (internal Docker network)
   - **Access**: Server (default)
   - **Scrape interval**: `15s`
   - Leave all other settings as default

3. **Test Connection**:
   - Scroll to bottom and click **"Save & test"**
   - Should show: **"Data source is working"** ✅
   - If it fails, verify services are running: `docker-compose ps`

#### Part B: Creating Your First Dashboard

1. **Create New Dashboard**:
   - Click **"+"** in left sidebar → **"Dashboard"**
   - Click **"+ Create dashboard"**
   - Click **"+ Add visualization"**
   - Select **"Prometheus"** as data source

2. **Traffic Panel - Request Rate**:
   - **Panel Title**: Change to "Request Rate (req/s)" (Top right)
   - **Query**: (Use Code mode)
     ```promql
     sum(rate(flask_http_request_duration_seconds_count[5m])) by (path)
     ```
   - **Legend**: `{{path}}`
   - **Unit**: Set to "requests/sec" (under Standard Options → Unit in the right side bar)
   - **Visualization**: Time series (line chart)
   - Click **Back to dashboard** to see the added panel

#### Part C: Latency Monitoring

3. **Add Second Panel**:
   - Click **"Add"** → **"Visualization"**
   - **Panel Title**: "Response Time Percentiles"
   - **Query A**: 
     ```promql
     histogram_quantile(0.50, rate(flask_http_request_duration_seconds_bucket[5m]))
     ```
   - **Legend A**: "p50 - {{path}}"
   - **Query B** (click + Add query):
     ```promql
     histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
     ```
   - **Legend B**: "p95 - {{path}}"
   - **Query C**:
     ```promql
     histogram_quantile(0.99, rate(flask_http_request_duration_seconds_bucket[5m]))
     ```
   - **Legend C**: "p99 - {{path}}"
   - **Unit**: Set to "seconds (s)"
   - Click **Back to dashboard** to see the added panel

#### Part D: Error Rate Monitoring

4. **Add Error Rate Panel**:
   - **Panel Title**: "Error Rate %"
   - **Query**: 
     ```promql
     (sum(rate(flask_http_request_duration_seconds_count{status=~"4..|5.."}[5m])) / sum(rate(flask_http_request_duration_seconds_count[5m]))) * 100
     ```
   - **Legend**: "Error Rate"
   - **Unit**: "percent (0-100)"
   - **Visualization**: Stat (single number)
   - **Thresholds**: 
     - Yellow: 1  
     - Red: 5
   - **Show Thresholds mode** As lines (dashed)
   -Click **Back to dashboard** to see the added panel

#### Part F: Resource Usage

6. **Add Resource Panel**:
   - **Panel Title**: "Docker Container Resources"
   - **Query A** (CPU): 
     ```promql
     rate(container_cpu_usage_seconds_total{id=~"/docker/.*"}[5m]) * 100
     ```
   - **Legend A**: "CPU % - {{id}}"
   - **Query B** (Memory):
     ```promql
     container_memory_usage_bytes{id=~"/docker/.*"} / 1024 / 1024
     ```
   - **Legend B**: "Memory MB - {{id}}"
   - **Unit**: For mixed units, leave as "Short" or create separate panels
   - **Note**: This shows ALL Docker containers. Use Table view to see which container IDs correspond to which services.
   - Click **Back to dashboard** to see the added panel

#### Part G: Dashboard Configuration

7. **Save Dashboard**:
   - Click **"Save"** (disk icon) at top
   - **Name**: "Golden Signals Workshop"
   - **Description**: "Four Golden Signals monitoring for Flask app"
   - Click **Save**

8. **Time Range**:
   - Top right corner: Set to **"Last 15 minutes"**
   - Enable **auto-refresh**: Set to **"5s"**

9. **Test Your Dashboard**:
   - Run `./generate_traffic.sh demo` to generate varied traffic
   - Watch your panels update in real-time
   - Notice how different endpoints show different patterns

#### Part H: Creating Alerts (Bonus)

10. **Add Alert to Error Rate Panel**:
    - Edit the Error Rate panel
    - Go to **Alert** tab
    - Click **"Create Alert Rule"**
    - **Condition**: `IS ABOVE 5`
    - **Evaluation**: Every `1m` for `2m`
    - **Alert Name**: "High Error Rate"
    - **Message**: "Error rate is above 5% for 2 minutes"
    - **Save Rule**

### Common Grafana Issues & Solutions

#### **Data Source Connection Problems:**
- **Error**: "HTTP Error Bad Gateway"
  - **Solution**: Use `http://prometheus:9090` (Docker internal network), not `http://localhost:9090`
  - **Check**: `docker-compose ps` - ensure all services are "Up" and "healthy"

#### **No Data in Panels:**
- **Cause**: No traffic generated yet
  - **Solution**: Run `./generate_traffic.sh demo` first, wait 1-2 minutes
- **Cause**: Wrong time range
  - **Solution**: Set time range to "Last 15 minutes" and enable auto-refresh

#### **Container Metrics Not Showing:**
- **Issue**: cAdvisor container IDs are long hashes
  - **Solution**: Use Table view to see which `id` corresponds to which service
  - **Alternative**: Use `{id=~"/docker/.*"}` to see all Docker containers

#### **Query Errors:**
- **"No data"**: Check if metrics exist at `/metrics` endpoint first
- **"Parse error"**: Verify PromQL syntax in Prometheus console first
- **"Too many samples"**: Add more specific label filters

### Key Learning Outcomes

After completing these exercises, you'll understand:

✅ **PromQL Fundamentals**:
- `rate()` for calculating per-second rates
- `sum()` for aggregating metrics  
- `histogram_quantile()` for percentiles
- Label filtering with `{status=~"4..|5.."}`
- Grouping with `by (label)`

✅ **Golden Signals Monitoring**:
- Traffic: Request rate and volume
- Latency: Response time percentiles (p95, p99)
- Errors: Error rate and error types
- Saturation: Resource usage and capacity

✅ **Grafana Skills**:
- Creating dashboards and panels
- Using different visualization types
- Setting up alerts and thresholds
- Configuring legends and units

✅ **Practical Monitoring**:
- Which metrics matter for application health
- How to detect performance problems
- Setting meaningful alert thresholds
- Interpreting monitoring data

## Troubleshooting

### Common Issues

#### Services Not Starting
If services fail to start or have dependency errors:
```bash
# Check logs for specific service
docker-compose logs <service_name>

# Restart all services
docker-compose down
docker-compose up -d

# Check status (all should show "Up")
docker-compose ps
```

#### Prometheus Not Scraping Targets
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.'

# Check if application metrics endpoint is accessible
curl http://localhost:3001/metrics

# Verify network connectivity
docker network inspect prometheus_default
```

#### Application Health Check
```bash
# Check application logs
docker-compose logs webapp

# Verify all services are running
docker-compose ps

# Check container metrics
curl http://localhost:8080/metrics

# Test application endpoints
curl http://localhost:3001/health
curl http://localhost:3001/metrics
```

#### Clean Restart
For a complete reset:
```bash
docker-compose down -v
# Wait a moment, then restart:
docker-compose up -d
# Wait 2-3 minutes for all services to be healthy
``` 
