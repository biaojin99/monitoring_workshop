# ELK Stack Setup for Log Aggregation

This tutorial demonstrates how to set up the **ELK Stack** (Elasticsearch, Logstash, Kibana) for centralized log aggregation and analysis. This is a simplified, educational setup designed to showcase how logs can be collected, processed, and visualized in a production-like environment.

## 🎯 Learning Objectives

After completing this tutorial, you will understand:

1. **ELK Stack Architecture**: How Elasticsearch, Logstash, and Kibana work together
2. **Log Aggregation**: Centralized collection and processing of logs
3. **Log Parsing**: Transforming unstructured logs into structured data
4. **Log Visualization**: Creating dashboards and queries in Kibana
5. **Log Management**: Best practices for log retention and search

## 📋 Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for ELK stack
- Basic understanding of JSON and log formats
- 10GB free disk space

## 🏗️ ELK Stack Components

### Component Overview

| Component | Purpose | Port | Description |
|-----------|---------|------|-------------|
| **Elasticsearch** | Search & Storage | 9200 | Distributed search and analytics engine |
| **Logstash** | Log Processing | 5044, 5000 | Data processing pipeline |
| **Kibana** | Visualization | 5601 | Web interface for exploring and visualizing data |
| **Filebeat** | Log Shipping | N/A | Lightweight log shipper |

### Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │────│    Filebeat     │────│    Logstash     │
│   (Logs)        │    │  (Log Shipper)  │    │ (Log Processor) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Kibana      │────│  Elasticsearch  │◄───│    Logstash     │
│ (Visualization) │    │   (Storage)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Setup

### Step 1: Create ELK Configuration Files

Create the docker-compose configuration:

**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elk-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
      - xpack.license.self_generated.type=basic
      - cluster.routing.allocation.disk.threshold_enabled=false
    volumes:
      - elk_elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - elk-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: elk-logstash
    volumes:
      - ./config/logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
      - ./config/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
    ports:
      - "5044:5044"  # Beats input
      - "5000:5000"  # TCP input
      - "9600:9600"  # Logstash monitoring
    networks:
      - elk-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9600 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: elk-kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - SERVER_NAME=kibana
      - SERVER_HOST=0.0.0.0
    ports:
      - "5601:5601"
    networks:
      - elk-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    container_name: elk-filebeat
    user: root
    volumes:
      - ./config/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - elk-network
    depends_on:
      logstash:
        condition: service_healthy
    command: filebeat -e -strict.perms=false

volumes:
  elk_elasticsearch_data:

networks:
  elk-network:
    driver: bridge
```

### Step 2: Create Logstash Configuration

**File**: `config/logstash/logstash.yml`

```yaml
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: ["http://elasticsearch:9200"]
pipeline.workers: 2
pipeline.batch.size: 125
pipeline.batch.delay: 50
```

**File**: `config/logstash/logstash.conf`

```ruby
input {
  # Accept logs from Filebeat
  beats {
    port => 5044
  }
  
  # Accept logs via TCP (for direct application logging)
  tcp {
    port => 5000
    codec => json_lines
  }
}

filter {
  # Parse container logs from Docker
  if [fields][log_type] == "docker" {
    # Extract container information
    grok {
      match => { 
        "[log][file][path]" => "/var/lib/docker/containers/%{DATA:container_id}/%{GREEDYDATA}"
      }
    }
    
    # Parse JSON logs if they exist
    if [message] =~ /^\{.*\}$/ {
      json {
        source => "message"
        target => "parsed_json"
      }
      
      # Promote parsed fields to top level
      if [parsed_json] {
        ruby {
          code => "
            parsed = event.get('parsed_json')
            if parsed.is_a?(Hash)
              parsed.each do |key, value|
                event.set(key, value)
              end
            end
          "
        }
        
        # Remove the raw parsed_json field
        mutate {
          remove_field => ["parsed_json"]
        }
      }
    }
  }
  
  # Parse Flask application logs
  if [container][name] =~ /webapp|flask/ {
    # Add application-specific tags
    mutate {
      add_tag => ["flask_application"]
      add_field => { "log_source" => "flask" }
    }
    
    # Parse log levels
    if [level] {
      mutate {
        lowercase => ["level"]
      }
    }
  }
  
  # Add timestamp processing
  if [timestamp] {
    date {
      match => ["timestamp", "UNIX", "ISO8601"]
      target => "@timestamp"
    }
  }
  
  # Add geo-location for IP addresses (if present)
  if [remote_addr] and [remote_addr] != "127.0.0.1" {
    geoip {
      source => "remote_addr"
      target => "geoip"
    }
  }
  
  # Clean up fields
  mutate {
    remove_field => ["agent", "ecs", "host", "input"]
  }
}

output {
  # Send to Elasticsearch
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
    
    # Use document_type based on log source
    template_name => "logs"
    template_pattern => "logs-*"
    template => {
      "index_patterns" => ["logs-*"],
      "settings" => {
        "number_of_shards" => 1,
        "number_of_replicas" => 0
      },
      "mappings" => {
        "properties" => {
          "@timestamp" => { "type" => "date" },
          "level" => { "type" => "keyword" },
          "message" => { "type" => "text" },
          "service" => { "type" => "keyword" },
          "container" => {
            "properties" => {
              "name" => { "type" => "keyword" },
              "id" => { "type" => "keyword" }
            }
          }
        }
      }
    }
  }
  
  # Debug output (optional - remove in production)
  stdout {
    codec => rubydebug
  }
}
```

### Step 3: Create Filebeat Configuration

**File**: `config/filebeat/filebeat.yml`

```yaml
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  fields:
    log_type: docker
  fields_under_root: true

processors:
- add_docker_metadata:
    host: "unix:///var/run/docker.sock"

- drop_event:
    when:
      or:
        - contains:
            container.name: "elk-"
        - contains:
            container.name: "filebeat"

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
```

## 🔧 Starting the ELK Stack

### Step 1: Create Configuration Directories

```bash
# Create the configuration directory structure
mkdir -p config/logstash
mkdir -p config/filebeat

# Create the configuration files as described above
```

### Step 2: Start the ELK Stack

```bash
# Start all ELK services
docker-compose up -d

# Check service status
docker-compose ps

# Expected output: All services should show "Up" and healthy
```

### Step 3: Verify ELK Stack is Running

```bash
# Check Elasticsearch
curl http://localhost:9200/_cluster/health
# Expected: {"status":"green" or "yellow"}

# Check Logstash
curl http://localhost:9600
# Expected: JSON response with Logstash info

# Check Kibana
curl http://localhost:5601/api/status
# Expected: JSON response with Kibana status
```

## 📊 Using Kibana for Log Analysis

### Step 1: Access Kibana

1. Open your browser and go to http://localhost:5601
2. Wait for Kibana to fully load (may take 2-3 minutes)

### Step 2: Create Index Pattern

1. **Go to Stack Management**:
   - Click on the hamburger menu (☰) in the top left
   - Navigate to "Stack Management" → "Index Patterns"

2. **Create Index Pattern**:
   - Click "Create index pattern"
   - Index pattern name: `logs-*`
   - Click "Next step"
   - Time field: `@timestamp`
   - Click "Create index pattern"

### Step 3: Explore Logs in Discover

1. **Navigate to Discover**:
   - Click on the hamburger menu (☰)
   - Select "Analytics" → "Discover"

2. **View Recent Logs**:
   - Select time range (last 24 hours)
   - You should see logs from your containers

## 🧪 Testing Log Collection

### Generate Test Logs

Create a simple log generator to test the ELK stack:

**File**: `test-log-generator.py`

```python
import json
import time
import random
import socket
from datetime import datetime

def send_log_to_logstash(host='localhost', port=5000):
    """Send JSON logs directly to Logstash TCP input"""
    
    # Sample log events
    events = [
        {"event": "user_login", "user_id": "user123", "success": True},
        {"event": "api_request", "endpoint": "/users", "method": "GET", "status": 200},
        {"event": "database_query", "table": "users", "duration_ms": 45},
        {"event": "error", "error_type": "connection_timeout", "service": "payment"},
        {"event": "purchase", "amount": 29.99, "currency": "USD", "user_id": "user456"}
    ]
    
    try:
        # Create socket connection
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((host, port))
        
        for _ in range(10):  # Send 10 test logs
            # Select random event
            event = random.choice(events).copy()
            
            # Add common fields
            event.update({
                "timestamp": datetime.utcnow().isoformat(),
                "level": random.choice(["INFO", "WARN", "ERROR"]),
                "service": "test_application",
                "version": "1.0.0",
                "hostname": "test-host"
            })
            
            # Send JSON log
            log_line = json.dumps(event) + '\n'
            sock.send(log_line.encode('utf-8'))
            
            print(f"Sent log: {event['event']}")
            time.sleep(1)
        
        sock.close()
        print("Test logs sent successfully!")
        
    except Exception as e:
        print(f"Error sending logs: {e}")

if __name__ == "__main__":
    send_log_to_logstash()
```

### Run the Test

```bash
# Generate test logs
python3 test-log-generator.py

# Check logs in Kibana Discover
# You should see the test events appear within 1-2 minutes
```

## 🔍 Kibana Queries and Visualizations

### Useful Kibana Queries

#### Basic Queries

```bash
# Show only ERROR level logs
level:ERROR

# Show logs from specific service
service:flask

# Show logs in time range with specific event
event:user_login AND @timestamp:[now-1h TO now]

# Show database operations that took longer than 100ms
event:database_operation AND duration_ms:>100
```

#### Advanced Queries

```bash
# Complex query: Show errors from flask service in last hour
level:ERROR AND service:flask AND @timestamp:[now-1h TO now]

# Show high-value purchases
event:purchase AND amount:>50

# Show failed login attempts
event:user_login AND success:false
```

### Creating Visualizations

#### 1. Log Level Distribution (Pie Chart)

1. Go to "Analytics" → "Visualize Library"
2. Click "Create visualization"
3. Select "Pie" chart
4. Choose your index pattern (`logs-*`)
5. **Buckets**:
   - Split slices: Terms aggregation
   - Field: `level.keyword`
6. Save as "Log Level Distribution"

#### 2. Logs Over Time (Line Chart)

1. Create new visualization → "Line"
2. **Y-axis**: Count
3. **X-axis**: Date histogram on `@timestamp`
4. **Break down by**: Terms on `service.keyword`
5. Save as "Logs Over Time by Service"

#### 3. Top Error Messages (Data Table)

1. Create new visualization → "Data table"
2. **Metrics**: Count
3. **Buckets**: Terms aggregation on `error_type.keyword`
4. Add filter: `level:ERROR`
5. Save as "Top Error Types"

### Creating a Dashboard

1. Go to "Analytics" → "Dashboard"
2. Click "Create dashboard"
3. Add the visualizations you created
4. Arrange and resize as needed
5. Save as "Application Monitoring Dashboard"

## ⚠️ Monitoring and Alerts

### Setting up Kibana Alerting

1. **Go to Stack Management**:
   - Navigate to "Alerting" → "Rules"

2. **Create Error Rate Alert**:
   - Name: "High Error Rate"
   - Index: `logs-*`
   - Condition: `level:ERROR`
   - Threshold: Count > 10 (in 5 minutes)
   - Action: Log to console (for demo)

### Health Monitoring

```bash
# Monitor Elasticsearch cluster health
curl http://localhost:9200/_cluster/health?pretty

# Monitor Logstash pipeline stats
curl http://localhost:9600/_node/stats/pipelines?pretty

# Check disk usage
curl http://localhost:9200/_cat/allocation?v
```

## 🔧 Troubleshooting

### Common Issues

#### Services Not Starting

```bash
# Check Docker logs
docker-compose logs elasticsearch
docker-compose logs logstash
docker-compose logs kibana

# Check system resources
docker stats

# Restart services
docker-compose restart
```

#### No Logs Appearing in Kibana

```bash
# Check if Logstash is receiving logs
docker logs elk-logstash | grep "pipeline"

# Test Logstash TCP input directly
echo '{"message":"test","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"}' | nc localhost 5000

# Check Elasticsearch indices
curl http://localhost:9200/_cat/indices?v
```

#### Performance Issues

```bash
# Increase Elasticsearch heap size (in docker-compose.yml)
ES_JAVA_OPTS=-Xms2g -Xmx2g

# Optimize Logstash workers
# Edit config/logstash/logstash.yml:
pipeline.workers: 4
pipeline.batch.size: 250
```

## 📚 Key Concepts for Students

### 1. Index Management

- **Index Pattern**: `logs-*` groups daily indices
- **Index Lifecycle**: Automatic rotation and deletion
- **Mapping**: Defines field types and indexing behavior

### 2. Log Processing Pipeline

1. **Collection**: Filebeat ships logs from containers
2. **Processing**: Logstash parses, filters, and enriches logs
3. **Storage**: Elasticsearch indexes and stores logs
4. **Visualization**: Kibana provides search and dashboarding

### 3. Best Practices

- **Structured Logging**: Use JSON format for better parsing
- **Field Naming**: Consistent field names across services
- **Log Levels**: Appropriate use of INFO, WARN, ERROR
- **Resource Management**: Monitor disk usage and set retention policies

## ✅ Validation Checklist

Confirm your ELK setup is working:

- [ ] All ELK services are running and healthy
- [ ] Elasticsearch cluster is green/yellow status
- [ ] Logstash is processing logs (check stats endpoint)
- [ ] Kibana is accessible at http://localhost:5601
- [ ] Index pattern `logs-*` is created
- [ ] Test logs appear in Kibana Discover
- [ ] Visualizations can be created successfully
- [ ] Dashboards display real-time data

## 🔗 Next Steps

1. **Advanced Configuration**: Explore Logstash plugins and filters
2. **Security**: Enable authentication and TLS
3. **Scaling**: Set up multi-node Elasticsearch cluster
4. **Integration**: Connect with monitoring tools like Prometheus

## 📖 Additional Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/)
- [Logstash Documentation](https://www.elastic.co/guide/en/logstash/current/)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/)
- [ELK Best Practices](https://www.elastic.co/guide/en/elasticsearch/guide/current/index.html)

---

**💡 Pro Tip**: Start with simple log forwarding and gradually add more complex parsing and enrichment as you understand your log patterns better. 