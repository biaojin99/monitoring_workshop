# Observability Workshop

This workshop module provides comprehensive hands-on experience with **observability concepts** including SLI/SLO monitoring, load testing, and centralized logging. It builds upon the existing Datadog and Prometheus workshops to demonstrate advanced observability practices.

## 🎯 Learning Objectives

By completing this workshop, you will understand:

1. **SLI/SLO/SLA Concepts**: How to define and monitor Service Level Indicators and Objectives
2. **Load Testing**: Using k6 to generate realistic traffic and validate system performance
3. **Structured Logging**: Implementing proper logging practices with Datadog
4. **Log Aggregation**: Setting up ELK stack for centralized log management
5. **Observability Strategy**: Combining metrics, traces, and logs for comprehensive system visibility

## 📁 Workshop Components

| Component | Purpose | Prerequisites |
|-----------|---------|---------------|
| **[sli-slo-tutorial/](./sli-slo-tutorial/)** | SLI/SLO monitoring with Datadog alerts | Running datadog workshop |
| **[k6-load-testing/](./k6-load-testing/)** | Load testing with k6 for traffic generation | k6 installation |
| **[datadog-logging/](./datadog-logging/)** | Structured logging with Datadog | Running datadog workshop |
| **[elk-stack/](./elk-stack/)** | ELK setup for log aggregation | Docker Compose |
| **[elk-logging/](./elk-logging/)** | Application logging to ELK | ELK stack running |

## 🚀 Quick Start

### Prerequisites
- Completed the [datadog workshop](../datadog/README.md)
- Docker and Docker Compose installed
- k6 installed (for load testing)
- Datadog account with API key

### Recommended Workshop Flow

1. **Start with SLI/SLO Tutorial**
   ```bash
   cd sli-slo-tutorial/
   # Follow README to set up Datadog alerts
   ```

2. **Add Load Testing**
   ```bash
   cd ../k6-load-testing/
   # Install k6 and run load tests
   ```

3. **Implement Structured Logging**
   ```bash
   cd ../datadog-logging/
   # Follow guide to add logging to datadog app
   ```

4. **Set up ELK Stack**
   ```bash
   cd ../elk-stack/
   # Deploy ELK for log aggregation
   ```

5. **Configure Application Logging to ELK**
   ```bash
   cd ../elk-logging/
   # Connect application logs to ELK
   ```

## 🔍 Observability Concepts

### The Three Pillars of Observability

1. **Metrics** (covered in datadog/prometheus workshops)
   - Time-series data for system performance
   - Business KPIs and operational metrics

2. **Traces** (covered in datadog workshop)
   - Request flow through distributed systems
   - Performance bottleneck identification

3. **Logs** (covered in this workshop)
   - Detailed event records for debugging
   - Business transaction logs

### SLI/SLO/SLA Framework

- **SLI (Service Level Indicator)**: A quantitative measure of service quality
- **SLO (Service Level Objective)**: Target values for SLIs
- **SLA (Service Level Agreement)**: Customer-facing commitments based on SLOs

## 🎓 Learning Path

For new engineers entering the market, we recommend following this learning path:

1. **Understand Monitoring Basics** → Complete datadog/prometheus workshops
2. **Learn Observability Strategy** → Complete this observability workshop
3. **Practice Real-world Scenarios** → Use provided load testing and alerting examples
4. **Business Context** → Understand how observability drives business decisions

## 🔧 Troubleshooting

Common issues and solutions:

### Docker Issues
```bash
# Clean up containers
docker system prune -f

# Check available ports
netstat -an | grep LISTEN
```

### Service Dependencies
- Ensure datadog workshop is running before SLI/SLO tutorial
- Start ELK stack before configuring application logging
- Verify k6 installation before load testing

## 📚 Additional Resources

- [Datadog SLI/SLO Documentation](https://docs.datadoghq.com/monitors/service_level_objectives/)
- [k6 Load Testing Guide](https://k6.io/docs/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Observability Best Practices](https://sre.google/workbook/implementing-slos/)

---

**Note**: This workshop is designed for educational purposes to demonstrate observability concepts to new engineers entering the DevOps/SRE market. 