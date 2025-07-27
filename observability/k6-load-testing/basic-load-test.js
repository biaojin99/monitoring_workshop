import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 5 },   // Ramp up to 5 users
    { duration: '1m', target: 5 },    // Stay at 5 users  
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // Error rate under 1%
  },
};

export default function () {
  const response = http.get('http://localhost:3001/health');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'has correct content': (r) => r.body.includes('healthy'),
    'response time OK': (r) => r.timings.duration < 500,
  });
  
  sleep(1); // 1 second think time
}

// Setup function (runs once before test)
export function setup() {
  console.log('Starting basic load test against Flask application...');
  
  // Verify target application is running
  const healthCheck = http.get('http://localhost:3001/health');
  if (healthCheck.status !== 200) {
    throw new Error('Target application is not healthy!');
  }
  
  return { timestamp: new Date().toISOString() };
}

// Teardown function (runs once after test)
export function teardown(data) {
  console.log(`Basic load test completed at ${data.timestamp}`);
} 