import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 8 },   // Ramp up
    { duration: '1m', target: 8 },    // Sustained load
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.02'],
    'http_req_duration{endpoint:users}': ['p(95)<600'],
    'http_req_duration{endpoint:health}': ['p(95)<200'],
  },
};

export default function () {
  // Simple behavior: 70% health checks, 30% user operations
  const behavior = Math.random();
  
  if (behavior < 0.7) {
    // 70% - Health checks (fast)
    healthCheck();
  } else {
    // 30% - User operations (slower)
    userOperations();
  }
}

function healthCheck() {
  const response = http.get('http://localhost:3001/health', {
    tags: { endpoint: 'health' },
  });
  
  check(response, {
    'health status 200': (r) => r.status === 200,
    'health response fast': (r) => r.timings.duration < 200,
  });
  
  sleep(0.5); // Quick health checks
}

function userOperations() {
  const response = http.get('http://localhost:3001/users', {
    tags: { endpoint: 'users' },
  });
  
  check(response, {
    'users endpoint status 200': (r) => r.status === 200,
    'users response time < 600ms': (r) => r.timings.duration < 600,
  });
  
  sleep(1.5); // Consistent think time
} 