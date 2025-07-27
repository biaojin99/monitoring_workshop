import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '20s', target: 2 },   // Start small
    { duration: '20s', target: 5 },   // Ramp to 5 users
    { duration: '20s', target: 10 },  // Ramp to 10 users
    { duration: '1m', target: 10 },   // Hold at 10 users
    { duration: '20s', target: 0 },   // Wind down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // More lenient for ramp test
    http_req_failed: ['rate<0.02'],
  },
};

export default function () {
  // Alternate between health checks and user operations
  const endpoints = ['health', 'users'];
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const response = http.get(`http://localhost:3001/${endpoint}`, {
    tags: { endpoint: endpoint },
  });
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time acceptable': (r) => r.timings.duration < 1000,
  });
  
  sleep(1); // Consistent think time
} 