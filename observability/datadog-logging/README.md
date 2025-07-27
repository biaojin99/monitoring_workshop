# Structured Logging with Datadog

This tutorial demonstrates how to implement **structured logging** with Datadog for the Flask application. You'll learn to add proper logging instrumentation, configure log aggregation, and correlate logs with traces and metrics for comprehensive observability.

## 🎯 Learning Objectives

After completing this tutorial, you will understand:

1. **Structured Logging Principles**: Best practices for log structure and content
2. **Datadog Log Integration**: Sending application logs to Datadog
3. **Log Correlation**: Connecting logs with traces and metrics
4. **Log-based Alerting**: Creating alerts based on log patterns
5. **Debugging Workflows**: Using logs for troubleshooting and root cause analysis

## 📋 Prerequisites

- Completed [datadog workshop](../../datadog/README.md) with running services
- Understanding of Python logging module
- Datadog account with Logs enabled (may require upgrading from free tier)

## 🔍 Understanding Structured Logging

### Why Structured Logging Matters

Traditional logging:
```python
logger.info("User login failed for user123 from IP 192.168.1.100")
```

Structured logging:
```python
logger.info("User login failed", extra={
    "event": "login_failure",
    "user_id": "user123",
    "ip_address": "192.168.1.100",
    "severity": "warning"
})
```

### Benefits of Structured Logging

| Benefit | Description | Business Impact |
|---------|-------------|-----------------|
| **Searchable** | Query by specific fields | Faster incident resolution |
| **Aggregatable** | Count errors by type | Better error rate tracking |
| **Correlatable** | Link with traces/metrics | Complete request visibility |
| **Alertable** | Threshold-based alerts | Proactive issue detection |

## 🚀 Implementation Guide

### Step 1: Add Logging Dependencies

First, let's add the required packages to the datadog application:

```bash
# Navigate to datadog workshop
cd ../../datadog/

# Add to requirements.txt
echo "python-json-logger==2.0.7" >> src/requirements.txt
```

### Step 2: Create Logging Configuration

Create a new file `src/logging_config.py`:

```python
import logging
import json
import os
from pythonjsonlogger import jsonlogger
from ddtrace import tracer

class DatadogLogFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter that includes Datadog trace correlation"""
    
    def add_fields(self, log_record, record, message_dict):
        super(DatadogLogFormatter, self).add_fields(log_record, record, message_dict)
        
        # Add standard fields
        log_record['timestamp'] = record.created
        log_record['level'] = record.levelname
        log_record['logger'] = record.name
        log_record['service'] = os.getenv('DD_SERVICE', 'flask-webapp')
        log_record['version'] = os.getenv('DD_VERSION', '1.0.0')
        log_record['env'] = os.getenv('DD_ENV', 'development')
        
        # Add Datadog trace correlation
        span = tracer.current_span()
        if span:
            log_record['dd.trace_id'] = str(span.trace_id)
            log_record['dd.span_id'] = str(span.span_id)
            log_record['dd.service'] = span.service
        
        # Ensure message is always present
        if 'message' not in log_record:
            log_record['message'] = record.getMessage()

def setup_logging():
    """Configure structured logging for the application"""
    
    # Get log level from environment variable (default to INFO)
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    numeric_level = getattr(logging, log_level, logging.INFO)
    
    # Create logger
    logger = logging.getLogger()
    logger.setLevel(numeric_level)
    
    # Remove default handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create console handler with JSON formatting
    console_handler = logging.StreamHandler()
    console_handler.setLevel(numeric_level)
    
    # Use custom formatter
    formatter = DatadogLogFormatter(
        '%(timestamp)s %(level)s %(logger)s %(message)s'
    )
    console_handler.setFormatter(formatter)
    
    logger.addHandler(console_handler)
    
    return logger

class StructuredLogger:
    """Simple wrapper around Python logger with one structured example"""
    
    def __init__(self, logger_name):
        self.logger = logging.getLogger(logger_name)
    
    def info(self, message, **kwargs):
        """Standard info logging"""
        self.logger.info(message, extra=kwargs)
    
    def debug(self, message, **kwargs):
        """Standard debug logging"""
        self.logger.debug(message, extra=kwargs)
    
    def warning(self, message, **kwargs):
        """Standard warning logging"""
        self.logger.warning(message, extra=kwargs)
    
    def error(self, message, **kwargs):
        """Standard error logging"""
        self.logger.error(message, extra=kwargs)
    
    def log_business_event(self, event_type, **kwargs):
        """Example of structured logging for important business events"""
        self.logger.info("Business event", extra={
            "event": "business_event",
            "event_type": event_type,
            **kwargs
        })
```

#### Controlling Log Levels

You can control what gets logged using the `LOG_LEVEL` environment variable:

**Available log levels:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

```bash
# Show all logs (including debug)
export LOG_LEVEL=DEBUG

# Show only warnings and errors (production)
export LOG_LEVEL=WARNING

# Default level (recommended)
export LOG_LEVEL=INFO
```

**Example with different log levels:**

```python
# In your endpoints, you can now use standard log levels:
logger.debug("Processing user request", user_id=123)           # Only shows if DEBUG
logger.info("User created successfully", user_id=123)          # Shows at INFO+  
logger.warning("Slow database query", duration_ms=1500)       # Shows at WARNING+
logger.error("Database connection failed", timeout=30)        # Always shows
```

**Quick test:**
```bash
# Set log level in docker-compose.yml:
# webapp:
#   environment:
#     - LOG_LEVEL=DEBUG

# Or test immediately:
docker-compose up -d --build

# Change log level for testing  
docker exec datadog-webapp env LOG_LEVEL=WARNING python -c "
from logging_config import setup_logging, StructuredLogger
setup_logging()
logger = StructuredLogger('test')
logger.info('This will NOT show (INFO < WARNING)', test=True)
logger.warning('This WILL show', test=True)
"
```

### Step 3: Add Simple Logging to Flask Application

Add basic structured logging to your Flask application with simple decorators.

#### Add imports to flask_app.py

Add these imports to `src/flask_app.py`:

```python
from flask import g
from logging_config import setup_logging, StructuredLogger
import time

# Initialize logging
setup_logging()
logger = StructuredLogger('flask_webapp')
```

#### Add logging middleware

Add this after `app = Flask(__name__)` in `src/flask_app.py`:

```python
@app.before_request
def log_request_start():
    """Log the start of each request"""
    g.start_time = time.time()
    logger.info("Request started", 
        method=request.method,
        path=request.path,
        remote_addr=request.remote_addr
    )

@app.after_request
def log_request_end(response):
    """Log the end of each request"""
    if hasattr(g, 'start_time'):
        duration_ms = (time.time() - g.start_time) * 1000
        
        logger.info("Request completed",
            method=request.method,
            path=request.path,
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2)
        )
    
    return response
```

> **Note**: This runs alongside your existing `app_helper.py` metrics. No conflicts!

### Step 4: Add Business Logic Logging

Update your endpoints to include structured logging using the `logger` object:

#### Enhanced Health Endpoint

```python
@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint with simple logging"""
    try:
        # Test database connectivity
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
        conn.close()
        
        logger.info("Health check passed", 
            endpoint="health",
            database_status="healthy"
        )
        
        return {
            "status": "healthy",
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error("Health check failed", 
            endpoint="health",
            error=str(e),
            database_status="unhealthy"
        )
        
        return {
            "status": "unhealthy", 
            "database": "disconnected",
            "error": str(e)
        }, 503
```

#### Enhanced User Operations

```python
@app.route("/users", methods=["GET"])
def get_users():
    """Get all users with simple logging"""
    try:
        logger.debug("Fetching users from database")
        
        conn = get_db_connection()
        with conn.cursor() as cursor:
            start_time = time.time()
            cursor.execute("SELECT id, username, email FROM users")
            users = cursor.fetchall()
            query_duration = (time.time() - start_time) * 1000
        conn.close()
        
        logger.info("Users retrieved successfully", 
            user_count=len(users),
            query_duration_ms=round(query_duration, 2)
        )
        
        user_list = [{"id": u[0], "username": u[1], "email": u[2]} for u in users]
        return {"users": user_list}
        
    except Exception as e:
        logger.error("Failed to retrieve users", 
            endpoint="get_users",
            error=str(e)
        )
        return {"error": "Failed to retrieve users"}, 500

@app.route("/users", methods=["POST"])
def create_user():
    """Create user with simple logging"""
    try:
        data = request.get_json()
        
        # Validate input
        if not data or not data.get('username') or not data.get('email'):
            logger.warning("User creation failed - invalid input", 
                provided_fields=list(data.keys()) if data else []
            )
            return {"error": "Username and email are required"}, 400
        
        username = data['username']
        email = data['email']
        
        logger.debug("Creating new user", username=username, email=email)
        
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id",
                (username, email)
            )
            user_id = cursor.fetchone()[0]
            conn.commit()
        conn.close()
        
        # Use the structured logging example for important business events
        logger.log_business_event("user_created", 
            user_id=user_id,
            username=username
        )
        
        return {
            "message": "User created successfully",
            "user": {"id": user_id, "username": username, "email": email}
        }, 201
        
    except Exception as e:
        logger.error("Failed to create user", 
            endpoint="create_user",
            username=data.get('username') if 'data' in locals() else None,
            error=str(e)
        )
        return {"error": "Failed to create user"}, 500
```

#### Simple vs Structured Logging

**Most of the time, use simple logging:**
```python
logger.debug("Processing request", user_id=123)
logger.info("Operation completed", duration_ms=45)
logger.warning("Slow query detected", query_time=1500)
logger.error("Database connection failed", timeout=30)
```

**Use structured logging for important business events:**
```python
logger.log_business_event("user_created", user_id=123, username="john")
logger.log_business_event("payment_processed", amount=99.99, currency="USD")
```

This keeps your code simple while still providing rich, searchable logs in Datadog!

### Step 5: Test Logging Locally

Before configuring Datadog, let's test that our logging works correctly by running the Flask app locally.

#### Setup local environment

```bash
# Navigate to the datadog workshop
cd ../../datadog/

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r src/requirements.txt
```

#### Create the logging config file

Create `src/logging_config.py` with the complete logging configuration from Step 2 above:

```bash
# Copy the complete DatadogLogFormatter and StructuredLogger classes
# from Step 2 into src/logging_config.py
```

#### Run Flask app locally

```bash
# Set environment variables
export LOG_LEVEL=INFO
export DB_HOST=localhost  # We'll skip DB for this test
export DD_AGENT_HOST=localhost

# Run the Flask app (will show some DB connection errors, that's expected)
cd src/
python flask_app.py
```

#### Test with curl commands

Open a new terminal and test the logging:

```bash
# Test basic endpoint (no DB required)
curl http://localhost:3001/

# Test health check (will show DB connection error logging)
curl http://localhost:3001/health
```

#### Expected log output

You should see JSON logs like this:

```json
{"timestamp": 1634567890.123, "level": "INFO", "logger": "flask_webapp", "message": "Request started", "method": "GET", "path": "/", "remote_addr": "127.0.0.1"}
{"timestamp": 1634567890.125, "level": "INFO", "logger": "flask_webapp", "message": "Request completed", "method": "GET", "path": "/", "status_code": 200, "duration_ms": 2.1}
```

#### Test different log levels

```bash
# Test with DEBUG level (shows more logs)
export LOG_LEVEL=DEBUG
python flask_app.py

### Step 6: Configure Datadog Log Collection

Add these log collection settings to your existing `datadog` service in `docker-compose.yml`:

  ```yaml
  datadog:
    # ... existing configuration ...
    environment:
      # Keep all your existing DD_ variables
      - DD_LOGS_ENABLED=true                        # ← Add this
      # REMOVE: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true  (causes all container logs to mix)
      # REMOVE: DD_CONTAINER_EXCLUDE_LOGS="name:datadog-agent" (not needed anymore)
    volumes:
      # Keep all your existing volume mounts
      - /var/lib/docker/containers:/var/lib/docker/containers:ro  # ← Add this

  webapp:
    # ... existing configuration ...
    labels:
      - "com.datadoghq.ad.logs=[{\"source\": \"python\", \"service\": \"flask-webapp\"}]"  # ← Add this
  ```

#### Troubleshooting Log Collection

If logs don't appear in Datadog, check these steps:

**Step 1: Verify Datadog Agent Log Collection**
```bash
# Check if agent is collecting logs
docker exec datadog-agent agent status | grep -A 20 "Logs Agent"

# Should show "Logs Agent" running and log collection enabled
```

**Step 2: Check Container Log Labels**
```bash
# Verify webapp container has correct labels
docker inspect datadog-webapp | grep -A 5 "Labels"

# Should show the com.datadoghq.ad.logs label
```

**Step 3: Restart with Log Collection**
```bash
# Restart to apply log collection changes
docker-compose down
docker-compose up -d

# Wait 2-3 minutes for logs to appear in Datadog
```

**Step 4: Generate Test Traffic**
```bash
# Generate logs to ensure they're being created
curl http://localhost:3001/
curl "http://localhost:3001/delay?seconds=1"
curl http://localhost:3001/health

# Check logs are being generated
docker logs datadog-webapp --tail 10
```

**Step 5: Check Datadog Agent Logs**
```bash
# Check for any log collection errors
docker logs datadog-agent | grep -i "log\|error"

# Look for "Started processing logs" or similar messages
```

**Step 6: Manual Agent Check**
```bash
# Force agent to check log configuration
docker exec datadog-agent agent configcheck

# Should show log configuration for webapp container
```

**Common Issues:**

1. **Missing DD_API_KEY**: Ensure your `.env` file has the correct API key
2. **Wrong DD_SITE**: Ensure you're using the correct Datadog site (us1.datadoghq.com, eu1.datadoghq.com, etc.)
3. **Log Delay**: Logs can take 2-5 minutes to appear in Datadog initially
4. **Container Labels**: The webapp container needs the log collection label
5. **All Container Logs Mixed**: If you see Datadog agent logs in your flask-webapp service, remove `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true`

**Fix for Mixed Container Logs:**

If you're seeing Datadog agent logs or other container logs appearing under your flask-webapp service:

```yaml
# In your docker-compose.yml, UPDATE the datadog service:
datadog:
  environment:
    - DD_LOGS_ENABLED=true
    # REMOVE these two lines:
    # - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true   
    # - DD_CONTAINER_EXCLUDE_LOGS="name:datadog-agent"

# Keep only the webapp label for specific log collection:
webapp:
  labels:
    - "com.datadoghq.ad.logs=[{\"source\": \"python\", \"service\": \"flask-webapp\"}]"
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

This ensures only your Flask app logs are collected with the `flask-webapp` service tag.

## 🔧 Testing Your Logging Setup

### Step 7: Rebuild and Restart

```bash
# Navigate to datadog workshop
cd ../../datadog/

# Add the new logging files to src/ directory
# (Create the files as described above)

# Rebuild the application
docker-compose down
docker-compose up -d --build

# Wait for services to start
sleep 30
```

### Step 8: Generate Test Traffic with Logging

```bash
# Test normal operations
curl http://localhost:3001/health
curl http://localhost:3001/users

# Create test users
curl -X POST http://localhost:3001/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test_user","email":"test@example.com"}'

### Step 9: Verify Logs in Docker

```bash
# Check application logs
docker logs datadog-webapp | head -20

# Expected JSON log format:
# {"timestamp": 1634567890.123, "level": "INFO", "logger": "flask_webapp", 
#  "message": "Request started", "event": "request_start", ...}
```

## 📊 Viewing Logs in Datadog

### Step 10: Access Datadog Logs

1. Go to [Datadog Logs](https://app.datadoghq.com/logs)
2. You should see logs from your Flask application
3. Logs will be tagged with `service:flask-webapp`

### Step 11: Create Log Queries

#### Business Event Analysis
```
service:flask-webapp event:business_event
```

#### Error Analysis
```
service:flask-webapp status:error
```

#### Performance Analysis
```
service:flask-webapp event:request_end @duration_ms:>500
```

#### Database Operations
```
service:flask-webapp event:database_operation
```

### Step 12: Create Log-based Metrics

Create custom metrics from logs:

1. **Error Rate Metric**
   ```
   Query: service:flask-webapp status:error
   Metric: error_rate_from_logs
   ```

2. **Slow Request Metric**
   ```
   Query: service:flask-webapp @duration_ms:>1000
   Metric: slow_requests_from_logs
   ```

3. **User Creation Rate**
   ```
   Query: service:flask-webapp business_event_type:user_created
   Metric: user_creation_rate
   ```

## ⚠️ Creating Log-based Alerts

### Alert 1: High Error Rate

Create an alert for excessive errors:

```
Query: service:flask-webapp status:error
Threshold: > 10 errors in 5 minutes
Alert Message: 
🚨 High error rate detected in Flask application
Error count: {{value}} in last 5 minutes
Check logs: https://app.datadoghq.com/logs?query=service:flask-webapp%20status:error
```

### Alert 2: Database Connection Issues

```
Query: service:flask-webapp error_type:database_connection_error
Threshold: > 1 error in 1 minute
Alert Message:
🔌 Database connection issues detected
This may indicate database outage or network issues
```

### Alert 3: Suspicious Activity

```
Query: service:flask-webapp event:security_event
Threshold: > 5 events in 10 minutes
Alert Message:
🛡️ Multiple security events detected
Investigate potential security incident
```

## 🔍 Log Correlation with Traces

### Understanding Trace-Log Correlation

With proper setup, you can:

1. **Navigate from Trace to Logs**: Click on a trace span to see related logs
2. **Navigate from Logs to Traces**: Click on trace_id in logs to see full trace
3. **Unified Timeline**: See traces and logs on the same timeline

### Correlation Query Examples

#### Find logs for a specific trace
```
@dd.trace_id:123456789
```

#### Find all logs for slow requests
```
service:flask-webapp @duration_ms:>1000 @dd.trace_id:*
```

## 🎯 Load Testing with Log Validation

### Generate Traffic and Monitor Logs

```bash
# Start load test
cd ../k6-load-testing/
k6 run mixed-workload-test.js

# Monitor logs in real-time (separate terminal)
docker logs -f datadog-webapp | grep -E "(request_start|request_end|business_event)"
```

### Expected Log Patterns

During load testing, you should see:

1. **Request Flow Logs**:
   ```json
   {"event": "request_start", "http_method": "GET", "http_path": "/users"}
   {"event": "database_operation", "db_operation": "SELECT", "db_table": "users"}
   {"event": "business_event", "business_event_type": "users_retrieved"}
   {"event": "request_end", "http_status": 200, "duration_ms": 45.2}
   ```

2. **Error Scenarios**:
   ```json
   {"event": "application_error", "error_type": "database_query_error"}
   {"event": "request_end", "http_status": 500, "duration_ms": 12.1}
   ```

## ✅ Validation Checklist

Confirm your logging implementation:

- [ ] Logs are in JSON format
- [ ] Each log includes trace correlation (dd.trace_id, dd.span_id)
- [ ] Business events are properly logged
- [ ] Database operations include timing information
- [ ] Errors include sufficient context for debugging
- [ ] Logs appear in Datadog Logs interface
- [ ] Log-based metrics are working
- [ ] Alerts can be created from log queries
- [ ] Trace-log correlation is functional

## 📚 Best Practices Summary

### Do's ✅

1. **Use structured JSON format** for all logs
2. **Include trace correlation** for request flow visibility
3. **Log business events** not just technical events
4. **Add timing information** for performance analysis
5. **Use consistent field names** across all log entries
6. **Include sufficient context** for debugging

### Don'ts ❌

1. **Don't log sensitive data** (passwords, PII, etc.)
2. **Don't create excessive log volume** (avoid debug logs in production)
3. **Don't log inside tight loops** (can impact performance)
4. **Don't forget error context** (always include relevant details)

## 🔗 Next Steps

1. **Advanced Log Processing**: Explore Datadog Log Pipelines for data transformation
2. **Log Archival**: Set up long-term log storage for compliance
3. **Cross-Service Correlation**: Extend logging to microservices
4. **Custom Log Parsers**: Create parsers for third-party service logs

## 📖 Additional Resources

- [Datadog Logging Documentation](https://docs.datadoghq.com/logs/)
- [Python Logging Best Practices](https://docs.python.org/3/howto/logging.html)
- [Structured Logging Guide](https://docs.datadoghq.com/logs/log_configuration/parsing/)

---

**💡 Pro Tip**: Good logging is like good documentation—it should tell the story of what your application is doing and why, not just what happened. 