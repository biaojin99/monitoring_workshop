import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 20 },   // Ramp up
    { duration: '5m', target: 20 },   // Sustained load
    { duration: '2m', target: 50 },   // Peak load
    { duration: '3m', target: 50 },   // Sustain peak
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    http_req_failed: ['rate<0.05'],
    'http_req_duration{endpoint:users}': ['p(95)<800'],
    'http_req_duration{endpoint:delay}': ['p(95)<1500'],
  },
};

export default function () {
  // Simulate realistic user behavior patterns
  const userBehavior = Math.random();
  
  if (userBehavior < 0.4) {
    // 40% - Browse users
    browseUsers();
  } else if (userBehavior < 0.7) {
    // 30% - Health checks (monitoring/load balancer)
    healthCheck();
  } else if (userBehavior < 0.9) {
    // 20% - Database operations
    databaseOperations();
  } else {
    // 10% - Slow operations
    slowOperations();
  }
}

function browseUsers() {
  const response = http.get('http://localhost:3001/users', {
    tags: { endpoint: 'users' },
  });
  
  check(response, {
    'users endpoint status 200': (r) => r.status === 200,
    'users response time < 800ms': (r) => r.timings.duration < 800,
  });
  
  sleep(Math.random() * 3 + 2); // 2-5 second think time
}

function healthCheck() {
  const response = http.get('http://localhost:3001/health', {
    tags: { endpoint: 'health' },
  });
  
  check(response, {
    'health status 200': (r) => r.status === 200,
  });
  
  sleep(1); // Quick health checks
}

function databaseOperations() {
  // Create a user
  const createUser = http.post('http://localhost:3001/users', 
    JSON.stringify({
      username: `user_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      email: `test_${Math.random().toString(36).substr(2, 9)}@example.com`
    }), 
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'create_user' },
    }
  );
  
  check(createUser, {
    'create user status 201': (r) => r.status === 201,
    'create user response time < 1000ms': (r) => r.timings.duration < 1000,
  });
  
  sleep(Math.random() * 2 + 1); // 1-3 second think time
}

function slowOperations() {
  const delay = Math.random() * 2 + 1; // 1-3 second delay
  const response = http.get(`http://localhost:3001/delay?seconds=${delay}`, {
    tags: { endpoint: 'delay' },
  });
  
  check(response, {
    'delay endpoint status 200': (r) => r.status === 200,
    'delay matches request': (r) => r.timings.duration >= delay * 1000 * 0.9, // Allow 10% tolerance
  });
  
  sleep(Math.random() * 5 + 3); // 3-8 second think time
} 