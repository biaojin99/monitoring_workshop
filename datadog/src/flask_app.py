from flask import Flask, request, g
import random
import os
import time
import psycopg2
from app_helper import setup_datadog_metrics
from datetime import datetime
import logging

# Instrumentation for Datadog APM
from ddtrace import tracer, patch_all

patch_all()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

tracer.configure(
    hostname=os.getenv("DD_AGENT_HOST", "datadog"),
    port=int(os.getenv("DD_TRACE_AGENT_PORT", 8126)),
)

DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "changeme")
DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")

# Create Flask application
app = Flask(__name__)

# Setup Datadog StatsD metrics
setup_datadog_metrics(app)

def get_db_connection():
    """Get database connection"""
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )
    return conn

@app.route("/")
def hello():
    """Simple hello endpoint"""
    return {"message": "Hello, World! Monitored by Datadog", "timestamp": datetime.now().isoformat()}

@app.route("/health")
def health():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        return {"status": "healthy", "database": "connected"}, 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}, 500

@app.route("/users")
def get_users():
    """Get users from database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, email FROM users ORDER BY id")
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        user_list = [{"id": user[0], "username": user[1], "email": user[2]} for user in users]
        return {"users": user_list, "count": len(user_list)}
    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        return {"error": "Failed to fetch users", "details": str(e)}, 500

@app.route("/users", methods=["POST"])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json()
        username = data.get("username")
        email = data.get("email")
        
        if not username or not email:
            return {"error": "Username and email are required"}, 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id",
            (username, email)
        )
        user_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        return {"message": "User created", "user_id": user_id, "username": username, "email": email}, 201
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        return {"error": "Failed to create user", "details": str(e)}, 500

@app.route("/delay")
def delay():
    """Endpoint that introduces artificial delay for testing"""
    delay_seconds = request.args.get("seconds", 1, type=float)
    # Simulate processing time
    time.sleep(delay_seconds)
    
    # Add business metric for this operation
    request.business_value = delay_seconds * 10  # Simulate business value calculation
    
    return {"message": f"Delayed response after {delay_seconds} seconds", "business_value": request.business_value}

@app.route("/error")
def error():
    """Endpoint that generates errors for testing monitoring"""
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
    """CPU-intensive endpoint for testing performance monitoring"""
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
    """Endpoint that uses memory for testing resource monitoring"""
    size_mb = request.args.get("size", 10, type=int)
    
    # Allocate memory (size in MB)
    data = bytearray(size_mb * 1024 * 1024)
    
    # Hold the memory for a short time
    time.sleep(1)
    
    return {
        "message": f"Allocated {size_mb} MB of memory",
        "size_bytes": len(data)
    }

@app.route("/database-query")
def database_query():
    """Endpoint that performs database queries for testing DB monitoring"""
    query_type = request.args.get("type", "simple")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if query_type == "complex":
            # Complex query for testing
            cursor.execute("""
                SELECT u.username, COUNT(*) as user_count 
                FROM users u 
                GROUP BY u.username 
                ORDER BY user_count DESC 
                LIMIT 10
            """)
        else:
            # Simple query
            cursor.execute("SELECT COUNT(*) FROM users")
        
        result = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return {"query_type": query_type, "result": result}
    except Exception as e:
        logger.error(f"Database query error: {e}")
        return {"error": "Database query failed", "details": str(e)}, 500

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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3001, debug=True) 