import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 15 },   // Build up load
    { duration: '3m', target: 15 },   // Maintain load while introducing errors
    { duration: '1m', target: 0 },    // Wind down
  ],
  thresholds: {
    // Expect higher error rates in this test
    http_req_failed: ['rate<0.15'],   // Allow up to 15% errors
    'http_req_failed{expected:false}': ['rate<0.02'], // But unexpected errors should be low
  },
};

export default function () {
  const scenario = Math.random();
  
  if (scenario < 0.7) {
    // 70% normal requests
    normalRequests();
  } else {
    // 30% requests that might generate errors
    errorRequests();
  }
}

function normalRequests() {
  const response = http.get('http://localhost:3001/health', {
    tags: { expected: 'true' },
  });
  
  check(response, {
    'normal request successful': (r) => r.status === 200,
  });
  
  sleep(Math.random() * 2 + 1);
}

function errorRequests() {
  // Deliberately trigger errors to test error handling
  const errorRate = Math.floor(Math.random() * 100); // 0-99
  const response = http.get(`http://localhost:3001/error?rate=${errorRate}`, {
    tags: { expected: 'true' }, // We expect these to sometimes fail
  });
  
  check(response, {
    'error endpoint responded': (r) => r.status !== 0, // Any response is good
  });
  
  sleep(Math.random() * 3 + 1);
} 