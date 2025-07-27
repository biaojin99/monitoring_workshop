from flask import Flask, request
from prometheus_flask_exporter import PrometheusMetrics
import random
import time
from datetime import datetime

app = Flask(__name__)

# Initialize Prometheus metrics - this will create both duration and request count metrics
metrics = PrometheusMetrics(app)

# Custom metrics for demonstration - showing how to create business-specific metrics
request_counter = metrics.counter(
    'webapp_custom_requests_total', 'Total custom requests',
    labels={'endpoint': lambda: request.endpoint or 'unknown'}
)

business_operations = metrics.counter(
    'webapp_business_operations_total', 'Total business operations',
    labels={'operation_type': lambda: getattr(request, 'operation_type', 'unknown')}
)

@app.route("/")
@request_counter
def hello():
    return {"message": "Hello, World! Monitored by Prometheus", "timestamp": datetime.now().isoformat()}

@app.route("/health")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}, 200

@app.route("/business-metrics")
@request_counter
@business_operations
def business_metrics():
    """Endpoint that demonstrates custom business metrics"""
    # Simulate different business operations
    operations = ["user_login", "product_view", "cart_add", "checkout", "payment"]
    operation = request.args.get("operation", random.choice(operations))
    
    # Store operation type for the business_operations metric
    request.operation_type = operation
    
    # Simulate processing time based on operation complexity
    processing_times = {
        "user_login": 0.1,
        "product_view": 0.05,
        "cart_add": 0.2,
        "checkout": 0.5,
        "payment": 1.0
    }
    
    processing_time = processing_times.get(operation, 0.1)
    time.sleep(processing_time)
    
    return {
        "message": f"Business operation '{operation}' completed",
        "operation": operation,
        "processing_time": processing_time,
        "timestamp": datetime.now().isoformat()
    }

# Golden Signals Endpoints

@app.route("/delay")
def delay():
    """Latency - Endpoint that introduces artificial delay"""
    delay_seconds = request.args.get("seconds", 1, type=float)
    time.sleep(delay_seconds)
    return {"message": f"Delayed response after {delay_seconds} seconds", "delay": delay_seconds}

@app.route("/error")
def error():
    """Errors - Endpoint that generates errors for testing error rate monitoring"""
    error_rate = request.args.get("rate", 50, type=int)  # Default 50% error rate
    
    if random.randint(1, 100) <= error_rate:
        # Generate different types of errors
        error_type = random.choice(["400", "404", "500"])
        if error_type == "400":
            return {"error": "Bad request simulation"}, 400
        elif error_type == "404":
            return {"error": "Resource not found simulation"}, 404
        else:
            return {"error": "Internal server error simulation"}, 500
    else:
        return {"message": "Success! No error generated this time"}

@app.route("/cpu-intensive")
def cpu_intensive():
    """Saturation - CPU-intensive endpoint for testing performance monitoring"""
    iterations = request.args.get("iterations", 100000, type=int)
    
    # Simulate CPU-intensive work
    start_time = time.time()
    result = 0
    for i in range(iterations):
        result += i ** 2
    
    end_time = time.time()
    execution_time = end_time - start_time
    
    return {
        "message": "CPU-intensive operation completed",
        "iterations": iterations,
        "result": result,
        "execution_time": execution_time
    }

@app.route("/memory-usage")
def memory_usage():
    """Saturation - Endpoint that uses memory for testing resource monitoring"""
    size_mb = request.args.get("size", 10, type=int)
    
    # Allocate memory (size in MB)
    data = bytearray(size_mb * 1024 * 1024)
    
    # Hold the memory for a short time
    time.sleep(1)
    
    return {
        "message": f"Allocated {size_mb} MB of memory",
        "size_bytes": len(data)
    }

if __name__ == "__main__":
    print("Starting Flask app...")
    print("Available routes:")
    for rule in app.url_map.iter_rules():
        print(f"  {rule.rule} -> {rule.endpoint}")
    print("Starting on http://localhost:3001...")
    # Use debug=False to prevent the restart issue that breaks /metrics
    app.run(host="0.0.0.0", port=3001, debug=False) 