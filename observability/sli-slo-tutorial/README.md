# SLI/SLO Tutorial with Datadog

This tutorial demonstrates how to implement **Service Level Indicators (SLIs)** and **Service Level Objectives (SLOs)** using Datadog monitoring. You'll learn to define, measure, and alert on service reliability metrics using the Flask application from the datadog workshop.

## 🎯 Learning Objectives

After completing this tutorial, you will understand:

1. **SLI/SLO/SLA Concepts**: The difference and relationship between these key reliability metrics
2. **Practical SLI Definition**: How to identify and measure meaningful service indicators
3. **SLO Implementation**: Setting realistic and business-aligned service objectives
4. **Datadog Alerting**: Configuring alerts for SLO violations
5. **Error Budget Management**: Understanding and managing error budgets

## 📋 Prerequisites

- Completed [datadog workshop](../../datadog/README.md) with running services
- Datadog account with admin access
- Basic understanding of percentiles and error rates

## 🔍 Understanding SLI/SLO/SLA

### Definitions

| Concept | Definition | Example |
|---------|------------|---------|
| **SLI** | Service Level Indicator - A quantitative measure of service performance | "99% of requests complete within 200ms" |
| **SLO** | Service Level Objective - Target value for SLIs | "Maintain 99.9% availability over 30 days" |
| **SLA** | Service Level Agreement - Customer-facing commitment with consequences | "99.9% uptime or 10% service credit" |

### Why They Matter for New Engineers

1. **Business Impact**: Directly connects technical performance to business outcomes
2. **Career Growth**: Essential skill for DevOps/SRE roles
3. **Decision Making**: Provides data-driven approach to reliability investments
4. **Customer Trust**: Ensures predictable service quality

## 🚀 Tutorial Setup

### Step 1: Verify Datadog Workshop is Running

```bash
# Navigate to datadog workshop
cd ../../datadog/

# Start all services
docker compose up -d

# Check all services are healthy
docker compose ps

# Expected output: all services show "Up" status
# datadog-agent     Up
# datadog-webapp    Up  
# datadog-postgres  Up

# Test application endpoints
curl http://localhost:3001/health
curl http://localhost:3001/users
```

### Step 2: Generate Baseline Traffic

```bash
# Generate mixed traffic for 5 minutes to establish baseline
./generate_traffic.sh sustained 300

# This creates realistic patterns for SLI measurement
```

### Step 3: Verify Metrics in Datadog

1. Go to [Datadog APM](https://app.datadoghq.com/apm/services)
2. Find the `flask-webapp` service
3. Verify you see:
   - Request volume
   - Latency percentiles (p50, p95, p99)
   - Error rates

## 📊 Defining SLIs for Our Flask Application

### Core SLIs for Web Applications

Based on Google's **Four Golden Signals**, we'll implement:

#### 1. Availability SLI
**Definition**: Percentage of successful HTTP requests
```
SLI = (Successful Requests / Total Requests) × 100%
```
**Success Criteria**: HTTP status codes 2xx and 3xx

#### 2. Latency SLI  
**Definition**: Percentage of requests completing within threshold
```
SLI = (Requests < 500ms / Total Requests) × 100%
```
**Measurement**: 95th percentile response time

#### 3. (Optional) Error Rate SLI
**Definition**: Percentage of requests without errors
```
SLI = ((Total Requests - Error Requests) / Total Requests) × 100%
```
**Error Criteria**: HTTP status codes 4xx and 5xx

#### 4. (Optional) Throughput SLI
**Definition**: Requests processed per second
```
SLI = Average requests per second over time window
```

## 🎯 Setting SLOs

### Realistic SLO Targets

Based on our Flask application characteristics:

| SLI | SLO Target | Time Window | Rationale |
|-----|------------|-------------|-----------|
| **Availability** | 99.5% | 30 days | Allows ~3.6 hours downtime/month |
| **Latency** | 95% < 500ms | 30 days | Reasonable for web app with DB queries |
| **Error Rate** | < 1% | 30 days | 1 error per 100 requests acceptable |
| **Throughput** | > 10 RPS | 1 hour | Minimum viable traffic handling |

### Error Budget Calculation

```
Error Budget = (100% - SLO Target) × Time Window

Examples:
- Availability SLO 99.5% → 0.5% error budget = ~3.6 hours/month
- Latency SLO 95% → 5% error budget = ~1.5 days/month for slow requests
```

## ⚠️ Implementing Datadog Alerts

### Alert 1: Availability SLO Violation

**Purpose**: Alert when error rate exceeds SLO threshold

1. **Navigate to Datadog SLOs**
   - Go to [Service Mgmt → SLOs](https://app.datadoghq.com/slo/manage)
   - Select "Availability SLO"
   - Go to settings -> Set up alerts


2. **Set Alert Conditions**
   ```
   Alert Type: "Error Budget"
   Alert threshold: > 100% of budget for 30days is consumed
   Warning threshold: > 70% budget for 30days is consumed
   ```

4. **Configure Notifications**
   ```
   Alert message:
   🚨 SLO VIOLATION: Avaliability {{value}}% 
   Availability SLO breaching!

   Runbook for Investigating Long-Term Availability SLO Breach:
   1. Examine historical application logs to identify recurring or persistent error patterns.
   2. Review deployment history and configuration changes over the SLO time window (e.g., last 30 days) for potential causes.
   3. Analyze uptime and incident reports to correlate outages or degradations with SLO breaches.
   4. Check infrastructure health metrics (CPU, memory, network, disk) for sustained resource issues.
   5. Investigate dependencies (databases, external APIs, cloud services) for chronic failures or instability.
   6. Summarize findings and document root causes and mitigation steps for future prevention.
   ```

### Alert 2: Latency SLO Violation

**Purpose**: Alert when latency SLO is breached (p95 > 500ms)

1. **Navigate to Datadog SLOs**
   - Go to [Service Mgmt → SLOs](https://app.datadoghq.com/slo/manage)
   - Select "Latency SLO"
   - Go to settings -> Set up alerts

2. **Set Alert Conditions**
   ```
   Alert Type: "Error Budget"
   Alert threshold: > 100% of latency budget for 30 days is consumed
   Warning threshold: > 70% of latency budget for 30 days is consumed
   ```

3. **Configure Notifications**
   ```
   Alert message:
   🚨 LATENCY SLO VIOLATION: Latency budget {{value}}%
   Latency SLO breaching! 

   Runbook for Investigating Latency SLO Breach:
   1. Review recent application logs for slow request traces and timeouts.
   2. Analyze request traces to identify endpoints or user flows with high latency.
   3. Check deployment and code change history for recent changes that may have impacted performance.
   4. Investigate external dependencies (APIs, databases) for slow responses or bottlenecks.
   5. Examine infrastructure health (CPU, memory, network, disk I/O) for resource saturation.
   6. Summarize findings and document root causes and mitigation steps for future prevention.
   ```

## 🎓 Business Impact Scenarios

### Scenario 1: Product Launch
**Situation**: Marketing announces 50% traffic increase expected
**SLO Response**: 
- Review current error budget (should be >50% remaining)
- Temporarily tighten alert thresholds  
- Pre-scale infrastructure
- Update SLOs if sustained traffic increase

### Scenario 2: Cost Optimization
**Situation**: Management asks to reduce infrastructure costs by 30%
**SLO Response**:
- Model impact on latency SLI (database queries may slow)
- Propose relaxed latency SLO (500ms → 800ms) with business approval
- Use error budget data to justify minimum infrastructure needs

### Scenario 3: Customer Escalation
**Situation**: Customer reports "slow application"
**SLO Response**:
- Check latency SLI vs complaint timeframe
- If SLO met: investigate customer-specific issues
- If SLO violated: acknowledge, fix, improve SLO
- Use data to set realistic expectations

## ✅ Validation Checklist

Confirm your implementation by checking:

- [ ] All four SLIs are defined and measured
- [ ] SLO targets are realistic and business-aligned
- [ ] Alerts are configured with appropriate thresholds
- [ ] Error budget calculations are correct
- [ ] Dashboard provides clear SLO status visibility
- [ ] Test scenarios successfully trigger alerts
- [ ] Alert messages include actionable information
- [ ] Recovery scenarios work as expected

## 📚 Key Takeaways

1. **Start Simple**: Begin with the four golden signals
2. **Be Realistic**: Set achievable SLO targets based on current performance
3. **Iterate**: Adjust SLOs based on business needs and technical constraints  
4. **Communicate**: Share SLO status regularly with stakeholders
5. **Learn from Violations**: Each incident is an opportunity to improve SLOs

## 🔗 Next Steps

1. **Advanced SLOs**: Explore composite SLOs and user journey monitoring
2. **Error Budget Policies**: Define how teams respond to budget exhaustion
3. **SLO Automation**: Implement automated SLO reporting and analysis
4. **Load Testing**: Use [k6 tutorial](../k6-load-testing/) to validate SLO assumptions

## 📖 Additional Resources

- [Google SRE Book - Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [Datadog SLO Documentation](https://docs.datadoghq.com/monitors/service_level_objectives/)
- [SLI/SLO Best Practices](https://cloud.google.com/blog/products/management-tools/practical-guide-to-setting-slos)

---

**💡 Pro Tip**: SLOs are not just technical metrics—they're communication tools that help engineering teams align with business priorities and customer expectations. 