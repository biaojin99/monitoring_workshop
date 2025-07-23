#!/bin/bash

# Traffic generation script for Prometheus monitoring demo
# This script generates various types of traffic to test monitoring capabilities

echo "Starting traffic generation for Prometheus monitoring demo..."

BASE_URL="http://localhost:3001"

# Function to generate different types of requests
generate_requests() {
    local count=${1:-100}
    echo "Generating ${count} mixed requests for Prometheus monitoring..."
    echo "📊 Monitor metrics at: http://localhost:9090 (Prometheus) and http://localhost:3000 (Grafana)"
    
    for i in $(seq 1 $count); do
        # Mix of different endpoints with weighted distribution for realistic scenarios
        case $((i % 9)) in
            0|1)
                # Health check (most common - 22%)
                curl -s "${BASE_URL}/health" > /dev/null
                echo -n "."
                ;;
            2|3)
                # Root endpoint (common - 22%)
                curl -s "${BASE_URL}/" > /dev/null
                echo -n "/"
                ;;
            4)
                # Business metrics endpoint (11%)
                operations=("user_login" "product_view" "cart_add" "checkout" "payment")
                operation=${operations[$((RANDOM % ${#operations[@]}))]}
                curl -s "${BASE_URL}/business-metrics?operation=${operation}" > /dev/null
                echo -n "📊"
                ;;
            5)
                # Delay endpoint with realistic delay (11%)
                delay_int=$((RANDOM % 20 + 5))
                delay_frac=$((RANDOM % 10))
                delay="${delay_int}.${delay_frac}"
                curl -s "${BASE_URL}/delay?seconds=${delay}" > /dev/null
                echo -n "⏱"
                ;;
            6)
                # Error endpoint with moderate error rate (11%)
                rate=$((RANDOM % 60 + 20))  # 20-80% error rate
                curl -s "${BASE_URL}/error?rate=${rate}" > /dev/null
                echo -n "❌"
                ;;
            7)
                # CPU intensive with reasonable load (11%)
                iterations=$((RANDOM % 30000 + 20000))
                curl -s "${BASE_URL}/cpu-intensive?iterations=${iterations}" > /dev/null
                echo -n "🔥"
                ;;
            8)
                # Memory usage with reasonable size (12%)
                size=$((RANDOM % 15 + 5))  # 5-20MB
                curl -s "${BASE_URL}/memory-usage?size=${size}" > /dev/null
                echo -n "💾"
                ;;
        esac
        
        # Shorter, more realistic delay between requests
        sleep_ms=$((RANDOM % 800 + 200))  # 200-1000ms
        sleep_seconds=$(echo "scale=3; $sleep_ms/1000" | bc -l 2>/dev/null || echo "0.5")
        sleep $sleep_seconds
        
        if [ $((i % 10)) -eq 0 ]; then
            echo ""
            echo "✅ Completed ${i}/${count} requests"
            echo "   📈 Check metrics: webapp_endpoint_counter, http_request_duration_seconds"
        fi
    done
    echo ""
    echo "🎯 Generated realistic traffic pattern with:"
    echo "   • 44% normal operations (health/root checks)"
    echo "   • 11% business metrics (custom metrics demo)"
    echo "   • 22% latency tests (performance monitoring)"
    echo "   • 23% resource/error tests (resource/error monitoring)"
}

# Function to generate sustained load with varying patterns
generate_sustained_load() {
    local duration=${1:-300}  # Default 5 minutes
    echo "Generating sustained load for ${duration} seconds (monitor in Grafana at http://localhost:3000)..."
    
    local end_time=$(($(date +%s) + duration))
    local phase=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Change load pattern every 30 seconds
        if [ $(($(date +%s) % 30)) -eq 0 ]; then
            phase=$(((phase + 1) % 3))
            case $phase in
                0) echo "Phase 1: Normal load pattern" ;;
                1) echo "Phase 2: High CPU load pattern" ;;
                2) echo "Phase 3: High error rate pattern" ;;
            esac
        fi
        
        # Generate different load patterns
        case $phase in
            0)
                # Normal load
                curl -s "${BASE_URL}/health" > /dev/null
                ;;
            1)
                # High CPU load
                iterations=$((RANDOM % 50000 + 50000))
                curl -s "${BASE_URL}/cpu-intensive?iterations=${iterations}" > /dev/null
                ;;
            2)
                # High error rate
                curl -s "${BASE_URL}/error?rate=80" > /dev/null
                ;;
        esac
        
        sleep 0.5
    done
    
    echo "✅ Sustained load test completed"
}

# Function to test specific Prometheus metrics
test_prometheus_metrics() {
    echo "Testing specific Prometheus metrics..."
    
    echo "1. Testing request counters..."
    for i in $(seq 1 10); do
        curl -s "${BASE_URL}/" > /dev/null
        curl -s "${BASE_URL}/health" > /dev/null
    done
    
    echo "2. Testing latency histograms..."
    for delay in 0.5 1.0 1.5 2.0; do
        curl -s "${BASE_URL}/delay?seconds=${delay}" > /dev/null
    done
    
    echo "3. Testing error rates..."
    for rate in 10 30 50 80; do
        curl -s "${BASE_URL}/error?rate=${rate}" > /dev/null
    done
    
    echo "4. Testing custom metrics..."
    curl -s "${BASE_URL}/cpu-intensive?iterations=50000" > /dev/null
    curl -s "${BASE_URL}/memory-usage?size=15" > /dev/null
    
    echo "Check metrics at: ${BASE_URL}/metrics"
}

# Function to generate error scenarios
generate_errors() {
    echo "Generating error scenarios for alerting tests..."
    
    for i in $(seq 1 25); do
        # High error rate
        curl -s "${BASE_URL}/error?rate=90" > /dev/null
        sleep 0.2
    done
    
    # Generate some 404s (non-existent endpoints)
    for i in $(seq 1 15); do
        curl -s "${BASE_URL}/nonexistent" > /dev/null
        sleep 0.1
    done
    
    echo "Generated error scenarios - check Prometheus alerts!"
}

# Individual endpoint test functions
test_cpu_intensive() {
    local count=${1:-10}
    echo "Testing CPU-intensive endpoint (${count} requests)..."
    echo "Monitor CPU metrics in Prometheus (http://localhost:9090) and Grafana (http://localhost:3000)..."
    
    for i in $(seq 1 $count); do
        iterations=$((RANDOM % 100000 + 50000))
        echo "Starting CPU test ${i}/${count} (${iterations} iterations)..."
        curl -s "${BASE_URL}/cpu-intensive?iterations=${iterations}" > /dev/null
        echo "CPU test ${i}/${count} completed - check cpu_usage_seconds metric"
        sleep 2
    done
}

test_memory_usage() {
    local count=${1:-10}
    echo "Testing memory usage endpoint (${count} requests)..."
    echo "Monitor memory metrics in Prometheus and Grafana during this test..."
    
    for i in $(seq 1 $count); do
        size=$((RANDOM % 50 + 10))
        echo "Starting memory test ${i}/${count} (${size}MB allocation)..."
        curl -s "${BASE_URL}/memory-usage?size=${size}" > /dev/null
        echo "Memory test ${i}/${count} completed - check memory_usage_bytes metric"
        sleep 1
    done
}

# Database functionality removed - no longer available

test_delay() {
    local count=${1:-10}
    echo "Testing delay endpoint (${count} requests)..."
    echo "Monitor response time histograms in Prometheus and Grafana during this test..."
    
    for i in $(seq 1 $count); do
        delay=$(echo "scale=2; $RANDOM/32767*5+0.5" | bc)
        echo "Starting delay test ${i}/${count} (${delay}s delay)..."
        curl -s "${BASE_URL}/delay?seconds=${delay}" > /dev/null
        echo "Delay test ${i}/${count} completed - check http_request_duration_seconds histogram"
        sleep 0.3
    done
}

# User endpoints removed - no longer available

test_errors() {
    local count=${1:-30}  # Increased default from 10 to 30 for better random distribution
    echo "Testing error endpoint (${count} requests)..."
    echo "Monitor error rate metrics and alerts in Prometheus and Grafana during this test..."
    echo "The /error endpoint randomly generates 400, 404, or 500 errors with equal probability"
    
    for i in $(seq 1 $count); do
        rate=$((RANDOM % 80 + 20))  # 20-100% error rate
        echo "Testing random errors ${i}/${count} (${rate}% error rate)..."
        curl -s "${BASE_URL}/error?rate=${rate}" > /dev/null
        sleep 0.3
    done
    
    echo ""
    echo "✅ Generated ${count} requests with random error types (400, 404, 500)"
    echo "📊 Check Prometheus/Grafana for error distribution by status code:"
    echo "   • http_requests_total{status=\"400\"}"
    echo "   • http_requests_total{status=\"404\"}"
    echo "   • http_requests_total{status=\"500\"}"
    echo "🔍 If you still only see 500s, try running again with more requests:"
    echo "    $0 error-test 50"
}

# New function for demonstrating monitoring scenarios
demo_monitoring_scenarios() {
    echo "🎯 Demonstrating key monitoring scenarios..."
    echo "📊 Monitor in real-time: http://localhost:9090 (Prometheus) | http://localhost:3000 (Grafana)"
    echo ""
    
    echo "📈 Scenario 1: Normal baseline traffic (30 seconds)..."
    for i in $(seq 1 30); do
        curl -s "${BASE_URL}/health" > /dev/null &
        curl -s "${BASE_URL}/" > /dev/null &
        sleep 1
    done
    wait
    echo "   ✅ Baseline established - check request rate metrics"
    echo ""
    
    echo "⏱ Scenario 2: Latency spike simulation (20 requests)..."
    for i in $(seq 1 20); do
        delay=$(echo "scale=1; 2+$i*0.1" | bc)  # Gradually increasing delay 2.1s to 4.0s
        echo "   Request $i: ${delay}s delay"
        curl -s "${BASE_URL}/delay?seconds=${delay}" > /dev/null
        sleep 0.5
    done
    echo "   ✅ Latency spike complete - check http_request_duration_seconds p95/p99"
    echo ""
    
    echo "❌ Scenario 3: Error rate spike (30 requests)..."
    for i in $(seq 1 30); do
        if [ $i -le 10 ]; then
            rate=90  # High error rate
        elif [ $i -le 20 ]; then
            rate=50  # Medium error rate
        else
            rate=10  # Low error rate
        fi
        echo "   Request $i: ${rate}% error rate"
        curl -s "${BASE_URL}/error?rate=${rate}" > /dev/null
        sleep 0.3
    done
    echo "   ✅ Error spike complete - check error rate: rate(http_requests_total{status=~\"4..|5..\"}[5m])"
    echo ""
    
    echo "🔥 Scenario 4: Resource consumption spike..."
    for i in $(seq 1 5); do
        echo "   CPU spike $i/5..."
        curl -s "${BASE_URL}/cpu-intensive?iterations=80000" > /dev/null &
        echo "   Memory spike $i/5..."
        curl -s "${BASE_URL}/memory-usage?size=25" > /dev/null &
    done
    wait
    echo "   ✅ Resource spike complete - check system resource metrics"
    echo ""
    
    echo "🔄 Scenario 5: Return to normal (recovery verification)..."
    for i in $(seq 1 20); do
        curl -s "${BASE_URL}/health" > /dev/null &
        curl -s "${BASE_URL}/users" > /dev/null &
        sleep 0.8
    done
    wait
    echo "   ✅ Recovery complete - verify metrics return to baseline"
    echo ""
    
    echo "🎉 All monitoring scenarios complete!"
    echo "📋 Key metrics to check:"
    echo "   • webapp_endpoint_counter - Request counts by endpoint"
    echo "   • http_request_duration_seconds - Response time percentiles"
    echo "   • http_requests_total - Success/error rates by status code"
    echo "   • up - Service availability"
    echo ""
    echo "🚨 Suggested alerts to test:"
    echo "   • High latency: http_request_duration_seconds{quantile=\"0.95\"} > 2"
    echo "   • High error rate: rate(http_requests_total{status=~\"5..\"}[5m]) > 0.1"
    echo "   • Service down: up == 0"
}

# Main execution
case "${1}" in
    "quick")
        echo "Running quick test (50 requests)..."
        generate_requests 50
        ;;
    "sustained")
        duration=${2:-300}
        echo "Running sustained load test for ${duration} seconds..."
        generate_sustained_load $duration
        ;;
    "errors")
        echo "Running error generation test..."
        generate_errors
        ;;
    "metrics")
        echo "Testing Prometheus metrics..."
        test_prometheus_metrics
        ;;
    "cpu")
        count=${2:-10}
        test_cpu_intensive $count
        ;;
    "memory")
        count=${2:-10}
        test_memory_usage $count
        ;;
    "database"|"db")
        count=${2:-10}
        test_database $count
        ;;
    "delay")
        count=${2:-10}
        test_delay $count
        ;;
    "users")
        count=${2:-10}
        test_users $count
        ;;
    "error-test")
        count=${2:-30}
        test_errors $count
        ;;
    "demo"|"scenarios")
        echo "Running monitoring scenarios demo..."
        demo_monitoring_scenarios
        ;;
    "full")
        echo "Running full Prometheus test suite..."
        echo "1. Testing metrics..."
        test_prometheus_metrics
        echo "2. Quick requests..."
        generate_requests 30
        echo "3. Error scenarios..."
        generate_errors
        echo "4. Sustained load (2 minutes)..."
        generate_sustained_load 120
        ;;
    *)
        echo "Usage: $0 {quick|sustained|errors|metrics|demo|cpu|memory|delay|error-test|full} [count]"
        echo ""
        echo "🚀 Recommended tests:"
        echo "  demo|scenarios     - 🎯 Complete monitoring demo with 5 realistic scenarios"
        echo "  quick              - Generate 50 mixed requests with realistic patterns"
        echo "  full               - Run complete test suite"
        echo ""
        echo "📊 General tests:"
        echo "  sustained [duration] - Generate sustained load (default: 300 seconds)"
        echo "  errors             - Generate error scenarios for alerting"
        echo "  metrics            - Test specific Prometheus metrics"
        echo ""
        echo "🔧 Specific endpoint tests:"
        echo "  cpu [count]        - Test CPU-intensive endpoint (default: 10)"
        echo "  memory [count]     - Test memory usage endpoint (default: 10)"
        echo "  delay [count]      - Test delay endpoint (default: 10)"
        echo "  error-test [count] - Test random error codes (400/404/500) (default: 30)"
        echo ""
        echo "Monitoring URLs:"
        echo "  Prometheus: http://localhost:9090"
        echo "  Grafana:    http://localhost:3000 (admin/foobar)"
        echo "  App metrics: http://localhost:3001/metrics"
        echo ""
        echo "💡 Examples:"
        echo "  $0 demo            - 🌟 Best demo: Complete monitoring scenarios"
        echo "  $0 quick           - Quick mixed test with realistic patterns"
        echo "  $0 cpu 20          - Run 20 CPU-intensive tests"
        echo "  $0 memory 15       - Run 15 memory tests"
        echo "  $0 sustained 600   - 10-minute sustained load test"
        echo "  $0 error-test 50   - Generate 50 error scenarios"
        exit 1
        ;;
esac

echo "Traffic generation completed! Check your monitoring dashboards." 