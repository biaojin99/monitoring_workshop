import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Normal load
    { duration: '30s', target: 100 }, // Sudden spike!
    { duration: '1m', target: 100 },  // Maintain spike
    { duration: '30s', target: 10 },  // Return to normal
    { duration: '2m', target: 10 },   // Observe recovery
    { duration: '30s', target: 0 },   // Wind down
  ],
  thresholds: {
    // More lenient thresholds during spike
    http_req_duration: ['p(95)<2000'], 
    http_req_failed: ['rate<0.1'],
  },
};

export default function () {
  const response = http.get('http://localhost:3001/users');
  
  check(response, {
    'spike test status check': (r) => r.status === 200,
    'spike test timing': (r) => r.timings.duration < 5000, // Very lenient during spike
  });
  
  sleep(Math.random() * 1 + 0.5); // Faster requests during spike
} 