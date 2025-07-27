# Application Logging to ELK Stack

This tutorial demonstrates how to configure your Flask application to send structured logs to the ELK stack. You'll learn to integrate the datadog workshop application with ELK for centralized log management and analysis.

## 🎯 Learning Objectives

After completing this tutorial, you will understand:

1. **ELK Integration**: How to connect applications to ELK stack
2. **Log Routing**: Sending logs to both Datadog and ELK simultaneously
3. **Log Standardization**: Maintaining consistent log formats across different systems
4. **Multi-destination Logging**: Managing logs for multiple observability platforms
5. **Practical Implementation**: Real-world application logging strategies

## 📋 Prerequisites

- Completed [datadog workshop](../../datadog/README.md) with running services
- Completed [ELK stack setup](../elk-stack/README.md) with running ELK services
- Understanding of Python logging configuration
- Basic knowledge of Docker networking

## 🔍 Integration Architecture

### Logging Strategy Overview

Our approach supports **dual logging** to both Datadog and ELK:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flask App     │────│  Structured     │────│   Datadog       │
│                 │    │     Logs        │    │   Platform      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Socket Handler │────│   Logstash      │────│ Elasticsearch   │
│  (TCP to ELK)   │    │ (ELK Stack)     │    │   (ELK Stack)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Benefits of Dual Logging

| Aspect | Datadog | ELK Stack |
|--------|---------|-----------|
| **APM Integration** | ✅ Excellent | ❌ Limited |
| **Cost** | 💰 Commercial | 💰 Free (self-hosted) |
| **Customization** | ❌ Limited | ✅ Highly customizable |
| **Learning Value** | ✅ Industry standard | ✅ Open source skills |
| **Data Retention** | 💰 Subscription-based | ✅ Self-managed |

## 🚀 Implementation Approach

We'll provide **two integration options**:

1. **Option A: Minimal Integration** - Simple README-based approach
2. **Option B: Full Implementation** - Complete code modification

### Option A: Minimal Integration (Recommended for Workshop)

This approach uses the existing structured logging from the Datadog workshop and routes it to ELK via Docker logging drivers.

#### Step 1: Update Docker Compose Configuration

Modify the datadog workshop's `docker-compose.yml` to include log routing:

```bash
# Navigate to datadog workshop
cd ../../datadog/

# Backup original docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
```

Add the following to your `docker-compose.yml`:

```yaml
version: '3.8'

services:
  webapp:
    # ... existing configuration ...
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,version,env"
    labels:
      service: "flask-webapp"
      version: "1.0.0"
      env: "development"
    networks:
      - default
      - elk_elk-network  # Connect to ELK network

  # ... other services ...

networks:
  default:
    driver: bridge
  elk_elk-network:
    external: true  # Reference to ELK stack network
```

#### Step 2: Configure Filebeat for Application Logs

Create `filebeat-app.yml` in the datadog workshop folder:

```yaml
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  include_lines: ['.*flask-webapp.*']
  fields:
    log_source: flask_application
    log_type: application
  fields_under_root: true
  
processors:
- add_docker_metadata:
    host: "unix:///var/run/docker.sock"

- decode_json_fields:
    fields: ["message"]
    target: ""
    overwrite_keys: true

output.logstash:
  hosts: ["localhost:5044"]

logging.level: info
```

#### Step 3: Test the Integration

```bash
# Ensure ELK stack is running
cd ../observability/elk-stack/
docker-compose ps

# Start datadog workshop with logging
cd ../../datadog/
docker-compose up -d

# Generate test traffic
curl http://localhost:3001/health
curl http://localhost:3001/users

# Check logs in Kibana (wait 2-3 minutes)
# Go to http://localhost:5601 and search for service:flask-webapp
```

### Option B: Full Implementation

For a complete integration, we'll create a new application in the observability folder that sends logs to both systems.

#### Step 1: Create Application Structure

```bash
# Navigate to observability folder
cd ../observability/elk-logging/

# Create application structure
mkdir -p flask-app/src
mkdir -p flask-app/config
```

#### Step 2: Create Dual-Logging Flask Application

**File**: `flask-app/src/flask_app.py`

```python
from flask import Flask, request, g, jsonify
import json
import time
import logging
import socket
import threading
from datetime import datetime
from contextlib import contextmanager

# Import existing structured logging helpers
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'datadog', 'src'))

from logging_config import setup_logging, StructuredLogger

app = Flask(__name__)

class ELKLogHandler(logging.Handler):
    """Custom logging handler that sends logs to ELK stack via TCP"""
    
    def __init__(self, host='elk-logstash', port=5000):
        super().__init__()
        self.host = host
        self.port = port
        self.socket = None
        self._lock = threading.Lock()
    
    def _connect(self):
        """Create connection to Logstash"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            return True
        except Exception as e:
            print(f"Failed to connect to ELK: {e}")
            return False
    
    def emit(self, record):
        """Send log record to ELK"""
        try:
            with self._lock:
                if not self.socket:
                    if not self._connect():
                        return
                
                # Format the log record
                log_entry = self.format(record)
                
                # Send to ELK
                message = log_entry + '\n'
                self.socket.send(message.encode('utf-8'))
                
        except Exception as e:
            print(f"Error sending log to ELK: {e}")
            # Reset connection for retry
            if self.socket:
                self.socket.close()
                self.socket = None

class DualLogger(StructuredLogger):
    """Extended logger that sends to both Datadog and ELK"""
    
    def __init__(self, logger_name):
        super().__init__(logger_name)
        
        # Add ELK handler
        elk_handler = ELKLogHandler()
        elk_formatter = logging.Formatter('%(message)s')
        elk_handler.setFormatter(elk_formatter)
        
        # Add handler to logger
        self.logger.addHandler(elk_handler)
    
    def _create_log_entry(self, level, message, **kwargs):
        """Create standardized log entry for both systems"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": level,
            "service": "flask-webapp-elk",
            "version": "1.0.0",
            "message": message,
            **kwargs
        }
        
        # Add trace context if available (for Datadog compatibility)
        if hasattr(g, 'trace_id'):
            log_entry["trace_id"] = g.trace_id
        
        return log_entry
    
    def log_to_both_systems(self, level, message, **kwargs):
        """Send log to both Datadog and ELK with consistent format"""
        log_entry = self._create_log_entry(level, message, **kwargs)
        
        # Send to both systems
        if level.upper() == "ERROR":
            self.logger.error(json.dumps(log_entry))
        elif level.upper() == "WARN":
            self.logger.warning(json.dumps(log_entry))
        else:
            self.logger.info(json.dumps(log_entry))

# Initialize logging
setup_logging()
dual_logger = DualLogger('flask_webapp_elk')

@app.before_request
def before_request():
    """Log request start and set up request context"""
    g.start_time = time.time()
    g.request_id = f"{int(time.time())}-{request.remote_addr}"
    
    dual_logger.log_to_both_systems(
        level="INFO",
        message="Request started",
        event="request_start",
        http_method=request.method,
        http_path=request.path,
        request_id=g.request_id,
        remote_addr=request.remote_addr,
        user_agent=request.headers.get('User-Agent', 'unknown')
    )

@app.after_request
def after_request(response):
    """Log request completion"""
    duration_ms = (time.time() - g.start_time) * 1000
    
    dual_logger.log_to_both_systems(
        level="INFO",
        message="Request completed",
        event="request_end",
        http_method=request.method,
        http_path=request.path,
        http_status=response.status_code,
        duration_ms=round(duration_ms, 2),
        request_id=g.request_id
    )
    
    return response

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    try:
        dual_logger.log_to_both_systems(
            level="INFO",
            message="Health check performed",
            event="health_check",
            status="healthy"
        )
        
        return jsonify({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "service": "flask-webapp-elk"
        })
        
    except Exception as e:
        dual_logger.log_to_both_systems(
            level="ERROR",
            message="Health check failed",
            event="health_check_error",
            error_message=str(e),
            error_type="health_check_failure"
        )
        
        return jsonify({
            "status": "unhealthy",
            "error": str(e)
        }), 503

@app.route("/test-logging", methods=["GET"])
def test_logging():
    """Test endpoint to generate different types of logs"""
    
    # Generate various log types
    dual_logger.log_to_both_systems(
        level="INFO",
        message="Test logging endpoint called",
        event="test_logging",
        test_type="info_log"
    )
    
    dual_logger.log_to_both_systems(
        level="WARN",
        message="This is a warning log for testing",
        event="test_logging",
        test_type="warning_log",
        warning_code="W001"
    )
    
    dual_logger.log_to_both_systems(
        level="ERROR",
        message="This is an error log for testing",
        event="test_logging",
        test_type="error_log",
        error_code="E001",
        error_details="Simulated error for testing purposes"
    )
    
    return jsonify({
        "message": "Test logs generated successfully",
        "logs_sent_to": ["datadog", "elk"],
        "log_types": ["INFO", "WARN", "ERROR"]
    })

@app.route("/business-event", methods=["POST"])
def business_event():
    """Simulate business event logging"""
    try:
        data = request.get_json() or {}
        event_type = data.get('event_type', 'unknown')
        
        dual_logger.log_to_both_systems(
            level="INFO",
            message="Business event occurred",
            event="business_event",
            business_event_type=event_type,
            event_data=data,
            user_id=data.get('user_id'),
            transaction_id=data.get('transaction_id')
        )
        
        return jsonify({
            "message": "Business event logged",
            "event_type": event_type
        })
        
    except Exception as e:
        dual_logger.log_to_both_systems(
            level="ERROR",
            message="Failed to process business event",
            event="business_event_error",
            error_message=str(e),
            error_type="business_event_processing"
        )
        
        return jsonify({"error": "Failed to process business event"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3002, debug=False)
```

#### Step 3: Create Docker Configuration for ELK Integration

**File**: `flask-app/Dockerfile`

```dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app
USER app

EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3002/health || exit 1

CMD ["python", "flask_app.py"]
```

**File**: `flask-app/requirements.txt`

```
Flask==2.3.3
python-json-logger==2.0.7
requests==2.31.0
```

**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  flask-elk-app:
    build: ./flask-app
    container_name: flask-elk-webapp
    ports:
      - "3002:3002"
    environment:
      - APP_ENV=development
      - LOG_LEVEL=INFO
    networks:
      - default
      - elk_elk-network
    depends_on:
      - elk-logstash
    restart: unless-stopped

  # Reference to external ELK stack
  elk-logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: elk-logstash-app
    volumes:
      - ../elk-stack/config/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
      - ../elk-stack/config/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
    ports:
      - "5045:5044"  # Different port to avoid conflicts
      - "5001:5000"  # TCP input for direct application logs
    networks:
      - elk_elk-network
    external_links:
      - elk_elk-network

networks:
  default:
    driver: bridge
  elk_elk-network:
    external: true
```

## 🔧 Testing the Integration

### Step 1: Start All Services

```bash
# Ensure ELK stack is running
cd ../elk-stack/
docker-compose ps

# Start the Flask application with ELK integration
cd ../elk-logging/
docker-compose up -d --build

# Verify services are running
docker-compose ps
```

### Step 2: Generate Test Logs

```bash
# Test health endpoint
curl http://localhost:3002/health

# Test logging endpoint
curl http://localhost:3002/test-logging

# Test business event logging
curl -X POST http://localhost:3002/business-event \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "purchase",
    "user_id": "user123",
    "transaction_id": "txn456",
    "amount": 99.99,
    "currency": "USD"
  }'

# Generate sustained traffic
for i in {1..20}; do
  curl -s http://localhost:3002/health > /dev/null
  curl -s http://localhost:3002/test-logging > /dev/null
  echo "Generated request $i"
  sleep 2
done
```

### Step 3: Verify Logs in Both Systems

#### Check Logs in ELK (Kibana)

1. Go to http://localhost:5601
2. Navigate to "Discover"
3. Search for: `service:flask-webapp-elk`
4. You should see structured logs from the application

#### Check Docker Logs

```bash
# Check application logs
docker logs flask-elk-webapp

# Expected output: JSON-formatted logs
```

## 📊 Log Analysis in ELK

### Business Event Queries

```bash
# In Kibana Discover, use these queries:

# All business events
event:business_event

# Purchase events
business_event_type:purchase

# High-value purchases
business_event_type:purchase AND amount:>50

# Error events
level:ERROR

# Request performance
event:request_end AND duration_ms:>100
```

### Creating ELK Dashboards for Application Logs

#### 1. Application Health Dashboard

Create visualizations for:
- Request volume over time
- Average response time
- Error rate percentage
- Top endpoints by request count

#### 2. Business Events Dashboard

Create visualizations for:
- Business events by type
- Purchase amounts over time
- User activity patterns
- Error breakdown by type

## 🔍 Comparison: Datadog vs ELK

### Log Query Examples

#### Finding the Same Information in Both Systems

**Datadog Query**:
```
service:flask-webapp-elk event:business_event business_event_type:purchase
```

**ELK Query (Kibana)**:
```
service:flask-webapp-elk AND event:business_event AND business_event_type:purchase
```

### Feature Comparison

| Feature | Datadog | ELK |
|---------|---------|-----|
| **Real-time Search** | ✅ Fast | ✅ Fast |
| **Custom Dashboards** | ✅ Good | ✅ Excellent |
| **Alerting** | ✅ Advanced | ✅ Basic |
| **Data Retention** | 💰 Limited by plan | ✅ Unlimited (disk space) |
| **Learning Curve** | ✅ Easy | ❌ Moderate |
| **Cost** | 💰 Per log volume | ✅ Infrastructure only |

## ⚠️ Best Practices for Dual Logging

### 1. Log Volume Management

```python
# Implement sampling for high-volume logs
import random

def should_log_to_elk(sample_rate=0.1):
    """Sample logs to reduce ELK volume"""
    return random.random() < sample_rate

# Usage in application
if should_log_to_elk():
    dual_logger.log_to_both_systems(...)
```

### 2. Error Handling

```python
# Always log errors to both systems
dual_logger.log_to_both_systems(
    level="ERROR",
    message="Critical error occurred",
    event="application_error",
    error_severity="high"
)
```

### 3. Performance Considerations

- Use asynchronous logging for high-throughput applications
- Implement connection pooling for ELK TCP connections
- Monitor log processing latency

## ✅ Validation Checklist

Confirm your ELK logging integration is working:

- [ ] ELK stack is running and healthy
- [ ] Flask application starts successfully
- [ ] Application logs appear in Kibana within 2-3 minutes
- [ ] Structured logs maintain consistent format
- [ ] Both INFO and ERROR logs are visible
- [ ] Business events are properly tagged
- [ ] Search queries work in Kibana
- [ ] Dashboard visualizations display data

## 🎓 Learning Outcomes

After completing this tutorial, students have learned:

1. **Multi-Platform Logging**: How to send logs to multiple observability platforms
2. **Log Standardization**: Maintaining consistent log formats across systems
3. **Open Source Alternative**: Understanding ELK as an alternative to commercial solutions
4. **Trade-off Analysis**: Comparing commercial vs open-source observability tools
5. **Production Considerations**: Real-world logging architecture decisions

## 📚 Key Takeaways

### For New Engineers

1. **Vendor Flexibility**: Don't lock yourself into a single observability vendor
2. **Cost Management**: Understand the cost implications of different logging strategies
3. **Skills Development**: Learning open-source tools (ELK) builds valuable skills
4. **Architecture Decisions**: Consider maintainability, cost, and team skills when choosing tools

### Technical Insights

- **Log Routing**: Multiple destinations can be achieved through various methods
- **Format Consistency**: Structured logging enables multi-platform compatibility
- **Performance Impact**: Multiple logging destinations require careful performance consideration
- **Operational Complexity**: Managing multiple systems requires additional operational overhead

## 🔗 Next Steps

1. **Advanced ELK Configuration**: Explore Elasticsearch clustering and performance tuning
2. **Log Lifecycle Management**: Implement retention policies and archival strategies
3. **Security**: Add authentication and encryption to ELK stack
4. **Monitoring**: Set up monitoring for the ELK stack itself
5. **Integration**: Connect ELK with other tools (Grafana, Prometheus, etc.)

## 📖 Additional Resources

- [ELK Stack Best Practices](https://www.elastic.co/guide/en/elasticsearch/guide/current/index.html)
- [Logstash Configuration Guide](https://www.elastic.co/guide/en/logstash/current/configuration.html)
- [Kibana User Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Docker Logging Drivers](https://docs.docker.com/config/containers/logging/)

---

**💡 Pro Tip**: In production environments, consider using a message queue (like Redis or RabbitMQ) between your application and ELK to handle high log volumes and provide buffering during ELK maintenance windows. 