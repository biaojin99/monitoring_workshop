# Datadog Monitoring Workshop

This module demonstrates comprehensive monitoring with **Datadog** using a Flask application. You'll learn how to set up Datadog APM (Application Performance Monitoring), StatsD metrics, and infrastructure monitoring.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Components](#components)
- [Setup Instructions](#setup-instructions)
- [Running the Application](#running-the-application)
- [Generating Traffic](#generating-traffic)
- [Monitoring Features](#monitoring-features)
- [Troubleshooting](#troubleshooting)
- [Learning Objectives](#learning-objectives)

## Overview

This workshop module provides a hands-on experience with Datadog monitoring, featuring:

- **Flask Application**: Python web app instrumented with Datadog APM
- **StatsD Metrics**: Custom business and performance metrics
- **Database Monitoring**: PostgreSQL monitoring with Datadog agent
- **Infrastructure Monitoring**: System-level metrics collection

## Prerequisites

### Software Requirements
- Docker and Docker Compose
- Datadog account (free trial available at [datadoghq.com](https://datadoghq.com))
- curl (for traffic generation)
- bc (basic calculator, for shell scripts)

### System Requirements
- 4GB RAM minimum
- 10GB free disk space

## Quick Start

1. **Get your Datadog API key:**
   ```bash
   # Visit https://app.datadoghq.com/organization-settings/api-keys
   # Create a new API key or copy an existing one
   ```

2. **Set up environment:**
   ```bash
   cd datadog/
   cp env.template .env
   # Edit .env and add your DD_API_KEY
   ```

3. **Start all services:**
   ```bash
   docker-compose up -d
   # All services will start in correct order with health checks
   ```

4. **Generate traffic:**
   ```bash
   ./generate_traffic.sh quick
   ```

5. **View in Datadog:**
   - Go to [Datadog APM](https://app.datadoghq.com/apm/home)
   - Check [Infrastructure](https://app.datadoghq.com/infrastructure)

## Components

### Application Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flask App     │────│   Datadog       │────│   Datadog       │
│   (Port 3001)   │    │   Agent         │    │   Platform      │
│                 │    │   (Port 8126)   │    │   (Cloud)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │   StatsD        │
│   (Port 5432)   │    │   (Port 8125)   │
└─────────────────┘    └─────────────────┘
```

### Services Included

| Service | Purpose | Port |
|---------|---------|------|
| **webapp** | Flask application with Datadog instrumentation | 3001 |
| **datadog** | Datadog agent for APM and metrics collection | 8126, 8125 |
| **postgres** | PostgreSQL database with monitoring setup | 5432 |

## Setup Instructions

### Step 1: Environment Configuration

```bash
# Copy environment template
cp env.template .env

# Edit the .env file with your Datadog configuration
DD_API_KEY=your_actual_api_key_here
DD_SITE=datadoghq.com  # or your specific Datadog site
```

### Step 2: Start All Services

```bash
# Start all services (Datadog agent, PostgreSQL, and Flask app)
docker-compose up -d

# Check all services are healthy (may take 2-3 minutes)
docker-compose ps
```

Expected output (all services should show "Up" status):
```
Name                 Command               State                    Ports
datadog-agent        agent run                Up      0.0.0.0:8125->8125/udp, 0.0.0.0:8126->8126/tcp
datadog-postgres     docker-entrypoint.sh     Up      0.0.0.0:5432->5432/tcp
datadog-webapp       python flask_app.py      Up      0.0.0.0:3001->3001/tcp
```

### Step 3: Verify Application

```bash
# Check application health
curl http://localhost:3001/health

# View metrics endpoint (should show Flask metrics)
curl http://localhost:3001/metrics || echo "No Prometheus metrics (this is expected for Datadog module)"
```

## Running the Application

### Manual Testing

Test individual endpoints:

```bash
# Health check
curl http://localhost:3001/health

# Get users
curl http://localhost:3001/users

# Create a user
curl -X POST http://localhost:3001/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test_user","email":"test@example.com"}'

# Test delay endpoint
curl "http://localhost:3001/delay?seconds=2"

# Test error endpoint
curl "http://localhost:3001/error?rate=50"
```

### Application Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Simple hello message |
| `/health` | GET | Health check with database connectivity |
| `/users` | GET | Retrieve all users |
| `/users` | POST | Create a new user |
| `/delay` | GET | Artificial delay for latency testing |
| `/error` | GET | Generate errors for error rate testing |
| `/cpu-intensive` | GET | CPU-heavy operation |
| `/memory-usage` | GET | Memory allocation testing |
| `/database-query` | GET | Database query performance testing |

## Generating Traffic

### Using the Traffic Generator

```bash
# Quick test (50 requests)
./generate_traffic.sh quick

# Sustained load (5 minutes)
./generate_traffic.sh sustained 300

# Error scenarios
./generate_traffic.sh errors

# Complete test suite
./generate_traffic.sh full
```

### Custom Traffic Generation

```bash
# High frequency requests
for i in {1..100}; do
  curl -s http://localhost:3001/health > /dev/null &
  if (( i % 10 == 0 )); then wait; fi
done

# Mixed load testing
while true; do
  curl -s "http://localhost:3001/delay?seconds=1" &
  curl -s "http://localhost:3001/error?rate=30" &
  curl -s "http://localhost:3001/users" &
  sleep 2
done
```

## Monitoring Features

### Datadog APM Features

1. **Request Tracing**
   - End-to-end request traces
   - Database query visibility
   - Performance bottleneck identification

2. **Custom Metrics via StatsD**
   - Request counts by endpoint
   - Response time histograms
   - Error rate tracking
   - Business value metrics

3. **Infrastructure Monitoring**
   - Container resource usage
   - Database performance
   - System-level metrics

### Key Metrics to Monitor

| Metric | Type | Description |
|--------|------|-------------|
| `request_count` | Counter | Total HTTP requests |
| `request_latency_seconds_hist` | Histogram | Request response times |
| `error_count` | Counter | HTTP errors (4xx, 5xx) |
| `business_value` | Gauge | Custom business metrics |
| `database_queries_total` | Counter | Database operations |

### Datadog Dashboards

After generating traffic, check these Datadog sections:

1. **APM Service Overview**
   - Go to APM → Services → flask-webapp
   - View request volume, latency, and errors

2. **Infrastructure**
   - Check container metrics
   - Monitor PostgreSQL performance

3. **Custom Dashboards**
   - Create dashboards using StatsD metrics
   - Build alerts on error rates

## Troubleshooting

### Common Issues

#### Datadog Agent Not Connecting
```bash
# Check agent status
docker exec datadog-agent agent status

# Verify API key
docker logs datadog-agent | grep -i "api key"

# Check agent health
curl http://localhost:8126/info
```

#### Application Not Starting
```bash
# Check logs
docker-compose logs webapp

# Verify database connection
docker exec datadog-postgres pg_isready -U root

# Check network connectivity
docker-compose ps
```

#### Services Not Starting
If services fail to start:
```bash
# Check logs for specific service
docker-compose logs <service_name>

# Restart all services
docker-compose down
docker-compose up -d

# Check status
docker-compose ps
```

#### No Metrics in Datadog
```bash
# Verify StatsD is receiving metrics
docker logs datadog-agent | grep -i statsd

# Check if traces are being sent
docker logs webapp | grep -i datadog

# Test metrics endpoint manually
curl http://localhost:3001/health
# Then check Datadog APM within 1-2 minutes
```

### Debug Commands

```bash
# View all running containers
docker ps

# Check container logs
docker logs datadog-agent
docker logs datadog-webapp
docker logs datadog-postgres

# Restart services
docker-compose restart

# Clean restart
docker-compose down
docker-compose -f docker-compose-infra.yml down
docker-compose -f docker-compose-infra.yml up -d
docker-compose up -d
```

## Hands-On Exercise: Custom Business Metrics with StatsD

This section provides a practical exercise for students to implement their own custom business metrics using Datadog's StatsD push model.

### Understanding StatsD Push Model

StatsD follows a **push model** where your application actively sends metrics to the StatsD server (Datadog Agent). This approach offers several advantages:

- **Non-blocking**: Metrics are sent via UDP, so they won't slow down your application
- **Fire-and-forget**: No waiting for responses from the metrics server
- **Simple protocol**: Easy to integrate with any programming language
- **Efficient**: Minimal overhead on application performance
- **Middleware-friendly**: Perfect for Flask's `after_request` handlers

### Exercise: Adding E-commerce Purchase Metrics

Let's implement a simple e-commerce purchase endpoint where we track business-critical metrics.

#### Step 1: Add Purchase Endpoint

Add this new endpoint to your `flask_app.py` file (append to the end, before the `if __name__ == "__main__":` line):

```python
@app.route("/purchase", methods=["POST"])
def purchase():
    """Simulate a purchase transaction with business metrics"""
    try:
        data = request.get_json() or {}
        user_id = data.get("user_id", 1)
        product_id = data.get("product_id", 1)
        quantity = data.get("quantity", 1)
        price_per_item = data.get("price", 19.99)
        
        # Calculate business metrics
        total_amount = quantity * price_per_item
        processing_time = random.uniform(0.1, 2.0)  # Simulate processing time
        
        # Simulate processing delay
        time.sleep(processing_time)
        
        # Store metrics in request for later use
        request.purchase_amount = total_amount
        request.processing_time = processing_time
        request.quantity = quantity
        request.product_id = product_id
        
        return {
            "message": "Purchase successful",
            "transaction_id": f"txn_{random.randint(10000, 99999)}",
            "amount": total_amount,
            "processing_time": processing_time,
            "product_id": product_id
        }, 201
        
    except Exception as e:
        logger.error(f"Purchase failed: {e}")
        return {"error": "Purchase failed", "details": str(e)}, 500
```

> **🔄 Why Store Data in Request Object?**
> 
> You might wonder: "Why not send metrics directly from the route?" Here's why we use this pattern:
> 
> **Data Flow Timeline:**
> 1. **Route executes** → Calculates `total_amount`, `processing_time`, etc.
> 2. **Route finishes** → Returns response to user
> 3. **After-request handlers run** → Need access to the calculated data for metrics
> 
> **The Request Object Bridge:**
> - Flask's `request` object persists for the entire request lifecycle
> - We store business data in it: `request.purchase_amount = total_amount`
> - Later, metrics handlers retrieve it: `getattr(request, "purchase_amount", 0)`
> 
> **Benefits:**
> - ✅ **Clean separation**: Business logic stays in routes, metrics in handlers
> - ✅ **Team ownership**: Different teams can own different parts
> - ✅ **Centralized observability**: One place handles all metrics
> - ✅ **Testable**: Can test business logic without metrics concerns

#### Step 2: Implement Custom StatsD Metrics

Now add the StatsD metric tracking. This step demonstrates **separation of concerns** by creating a dedicated handler for business metrics.

In your `app_helper.py` file, add these new metric names at the top with the other metric definitions:

```python
# Add these new business metric names
PURCHASE_AMOUNT_METRIC = "ecommerce.purchase_amount"
PURCHASE_COUNT_METRIC = "ecommerce.purchase_count"
PROCESSING_TIME_METRIC = "ecommerce.processing_time"
```

Then, add a **separate after_request handler** for business metrics. Add this new function to `app_helper.py`:

```python
def record_purchase_metrics(response):
    """Dedicated handler for purchase business metrics"""
    # Always return the response, even if None
    if response is None:
        return response
    
    try:
        # Only process purchase requests
        if request.path == "/purchase" and request.method == "POST":
            # Get purchase data from request
            purchase_amount = getattr(request, "purchase_amount", 0)
            processing_time = getattr(request, "processing_time", 0)
            quantity = getattr(request, "quantity", 0)
            product_id = getattr(request, "product_id", "unknown")
            
            # 1. Revenue tracking (gauge for current value)
            statsd.gauge(
                PURCHASE_AMOUNT_METRIC,
                purchase_amount,
                tags=[
                    "service:webapp",
                    "currency:USD",
                    f"amount_range:{get_amount_range(purchase_amount)}",
                    f"product_id:{product_id}"
                ]
            )
            
            # 2. Purchase count (counter automatically calculates rate)
            statsd.increment(
                PURCHASE_COUNT_METRIC,
                value=quantity,  # Can increment by quantity, not just 1
                tags=[
                    "service:webapp",
                    "transaction_type:purchase",
                    f"product_id:{product_id}"
                ]
            )
            
            # 3. Processing time distribution (Datadog distribution for better percentiles)
            statsd.distribution(
                PROCESSING_TIME_METRIC,
                processing_time,
                tags=[
                    "service:webapp",
                    "operation:purchase"
                ]
            )
    
    except Exception as e:
        # Don't let metrics collection break the response
        print(f"Purchase metrics collection error: {e}")
    
    return response

def get_amount_range(amount):
    """Helper function to categorize purchase amounts"""
    if amount < 10:
        return "small"
    elif amount < 50:
        return "medium"
    elif amount < 200:
        return "large"
    else:
        return "premium"
```

Finally, **register your new handler** in the `setup_datadog_metrics` function:

```python
def setup_datadog_metrics(app):
    """Setup Datadog monitoring for the Flask application"""
    # Register functions to be called before and after each request
    app.before_request(start_timer)
    
    # General application metrics
    app.after_request(stop_timer)
    app.after_request(record_request_data)
    
    # Business-specific metrics (separate handler)
    app.after_request(record_purchase_metrics)
```

> **📋 Note**: `app.after_request()` is Flask's built-in method that automatically calls your function after every request completes, making it perfect for metrics collection without cluttering your business logic.

> **🏗️ Architecture Pattern**: Notice how we separated concerns:
> - `record_request_data()`: Handles general application metrics (latency, errors, etc.)
> - `record_purchase_metrics()`: Handles business-specific metrics (revenue, transactions)
> 
> This pattern makes code more maintainable and allows different teams to own different metric handlers!

#### Step 3: Test Your Custom Metrics

Since you've added new code, you need to rebuild the image to include the changes:

> **💡 Important**: When you add new endpoints or modify existing Python files, you need to rebuild the Docker image. The source code volume mount only works for changes to existing files, not for new code additions.

```bash
# Stop the current containers
docker-compose down

# Rebuild and start (this includes your new code)
docker-compose up -d --build

# Wait a moment for all services to start
sleep 10

# Check if all services are healthy
docker-compose ps

# Test purchase endpoint
curl -X POST http://localhost:3001/purchase \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 123,
    "product_id": 456,
    "quantity": 2,
    "price": 29.99
  }'

# Generate test traffic with varied purchase data
for i in {1..20}; do
  # Random purchase amounts and quantities (using shell arithmetic for better compatibility)
  base_amount=$((RANDOM % 100 + 5))  # 5-104
  cents=$((RANDOM % 100))            # 0-99 cents
  amount="$base_amount.$cents"       # Combine for realistic prices like 25.67
  
  quantity=$((RANDOM % 5 + 1))
  product_id=$((RANDOM % 10 + 1))
  user_id=$((RANDOM % 50 + 1))
  
  curl -s -X POST http://localhost:3001/purchase \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":$user_id,\"product_id\":$product_id,\"quantity\":$quantity,\"price\":$amount}" > /dev/null
  
  echo "Purchase $i: Product $product_id, Quantity $quantity, Price \$$amount"
  sleep 1
done
```

#### Step 4: Verify Metrics in Datadog

1. **Go to Datadog Metrics Explorer**: https://app.datadoghq.com/metric/explorer
2. **Search for your custom metrics**:
   - `ecommerce.purchase_amount`
   - `ecommerce.purchase_count`
   - `ecommerce.processing_time`

3. **Create visualizations**:
   - Revenue over time (line graph)
   - Purchase count by amount range (bar chart)
   - Processing time percentiles (p50, p95, p99)

### Key StatsD Concepts Demonstrated

| Metric Type | Use Case | Example |
|-------------|----------|---------|
| **Counter** | Event counting, rates | `purchase_count` |
| **Gauge** | Current value snapshot | `purchase_amount` |
| **Distribution** | Value distribution with accurate percentiles | `processing_time`, `request_latency` |

> **💡 Why Distributions?** Datadog distributions provide more accurate percentiles (p50, p95, p99) than histograms and can be aggregated across multiple hosts for better insights.

### Business Metrics Best Practices

1. **Use meaningful tags**: Group metrics by business dimensions (product_id, amount_range, user segments)
2. **Choose appropriate metric types**: Counters for events, gauges for states, distributions for timing/value analysis
3. **Monitor what matters**: Focus on metrics that drive business decisions (revenue, transaction volume, processing time)
4. **Set up alerts**: Create alerts for critical business thresholds (high processing time, unusual purchase patterns)

### Debugging Your Metrics

```bash
# Check if metrics are being sent
docker logs datadog-agent | grep -i statsd

# Verify application is sending purchase metrics
docker logs datadog-webapp | grep -i purchase

# Check Datadog agent status
docker exec datadog-agent agent status

# If you made code changes, rebuild and restart
docker-compose down
docker-compose up -d --build

# Test the purchase endpoint manually
curl -X POST http://localhost:3001/purchase \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 1, "price": 10.00}'
```

## Learning Objectives

By completing this workshop, you will learn:

1. **Datadog APM Setup**
   - How to instrument a Python application
   - APM agent configuration
   - Trace collection and analysis

2. **Custom Metrics with StatsD**
   - Implementing counters, distributions, and gauges
   - Business metric tracking
   - Performance measurement with accurate percentiles
   - **NEW**: Hands-on implementation of business logic metrics

3. **Infrastructure Monitoring**
   - Container and system monitoring
   - Database performance tracking
   - Resource usage analysis

4. **Observability Best Practices**
   - Monitoring strategy design
   - Alert configuration
   - Dashboard creation
   - **NEW**: Business-driven metrics strategy

### Next Steps

- Explore Datadog's alerting capabilities
- Create custom dashboards for your use case
- Set up log aggregation with Datadog Logs
- Experiment with Datadog Synthetics for uptime monitoring

## Resources

- [Datadog Documentation](https://docs.datadoghq.com/)
- [Python APM Documentation](https://docs.datadoghq.com/tracing/setup_overview/setup/python/)
- [StatsD Documentation](https://docs.datadoghq.com/developers/dogstatsd/)
- [Database Monitoring](https://docs.datadoghq.com/database_monitoring/) 