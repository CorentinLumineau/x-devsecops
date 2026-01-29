---
name: Rate Limiting
description: Rate limiting algorithms, implementation patterns, and distributed strategies
category: security/api-security
type: reference
license: Apache-2.0
---

# Rate Limiting

## Algorithm Comparison

### Fixed Window

```
Window: 1 minute, Limit: 100
|------- minute 1 -------||------- minute 2 -------|
[100 requests allowed     ][100 requests allowed     ]

Problem: 100 requests at 0:59 + 100 at 1:01 = 200 in 2 seconds
```

### Sliding Window Log

```python
import time

class SlidingWindowLog:
    def __init__(self, limit, window_seconds):
        self.limit = limit
        self.window = window_seconds
        self.requests = {}  # client_id -> [timestamps]

    def allow(self, client_id):
        now = time.time()
        cutoff = now - self.window

        # Remove expired entries
        self.requests[client_id] = [
            t for t in self.requests.get(client_id, [])
            if t > cutoff
        ]

        if len(self.requests[client_id]) >= self.limit:
            return False

        self.requests[client_id].append(now)
        return True
```

### Token Bucket

```python
import time

class TokenBucket:
    def __init__(self, capacity, refill_rate):
        self.capacity = capacity
        self.tokens = capacity
        self.refill_rate = refill_rate  # tokens per second
        self.last_refill = time.time()

    def allow(self, tokens=1):
        self._refill()
        if self.tokens >= tokens:
            self.tokens -= tokens
            return True
        return False

    def _refill(self):
        now = time.time()
        elapsed = now - self.last_refill
        self.tokens = min(
            self.capacity,
            self.tokens + elapsed * self.refill_rate
        )
        self.last_refill = now
```

### Leaky Bucket

```python
import time
from collections import deque

class LeakyBucket:
    def __init__(self, capacity, leak_rate):
        self.capacity = capacity
        self.leak_rate = leak_rate  # requests per second
        self.queue = deque()
        self.last_leak = time.time()

    def allow(self):
        self._leak()
        if len(self.queue) < self.capacity:
            self.queue.append(time.time())
            return True
        return False

    def _leak(self):
        now = time.time()
        elapsed = now - self.last_leak
        to_remove = int(elapsed * self.leak_rate)
        for _ in range(min(to_remove, len(self.queue))):
            self.queue.popleft()
        self.last_leak = now
```

## Distributed Rate Limiting

### Redis-Based (Sliding Window)

```python
import redis
import time

r = redis.Redis()

def rate_limit(client_id, limit=100, window=60):
    """Sliding window rate limiter using Redis sorted set."""
    key = f"ratelimit:{client_id}"
    now = time.time()
    cutoff = now - window

    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, cutoff)  # Remove expired
    pipe.zadd(key, {f"{now}:{id(now)}": now})  # Add current
    pipe.zcard(key)  # Count
    pipe.expire(key, window)  # TTL cleanup
    results = pipe.execute()

    count = results[2]
    allowed = count <= limit

    return {
        "allowed": allowed,
        "limit": limit,
        "remaining": max(0, limit - count),
        "reset": int(now + window)
    }
```

### Redis Token Bucket (Lua Script)

```lua
-- Atomic token bucket in Redis
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

local data = redis.call('hmget', key, 'tokens', 'last_refill')
local tokens = tonumber(data[1]) or capacity
local last_refill = tonumber(data[2]) or now

-- Refill tokens
local elapsed = now - last_refill
tokens = math.min(capacity, tokens + elapsed * refill_rate)

local allowed = 0
if tokens >= requested then
    tokens = tokens - requested
    allowed = 1
end

redis.call('hmset', key, 'tokens', tokens, 'last_refill', now)
redis.call('expire', key, math.ceil(capacity / refill_rate) * 2)

return {allowed, math.floor(tokens)}
```

## Rate Limit Tiers

```yaml
rate_limits:
  tiers:
    anonymous:
      requests_per_minute: 30
      burst: 10
      identifier: ip_address

    authenticated:
      requests_per_minute: 300
      burst: 50
      identifier: api_key

    premium:
      requests_per_minute: 3000
      burst: 500
      identifier: api_key

  per_endpoint:
    "POST /api/auth/login":
      requests_per_minute: 5
      identifier: ip_address
      note: "Brute force protection"

    "POST /api/orders":
      requests_per_minute: 10
      identifier: user_id
      note: "Abuse prevention"
```

## Response Handling

```python
from flask import jsonify, request

def rate_limit_response(result):
    headers = {
        "X-RateLimit-Limit": str(result["limit"]),
        "X-RateLimit-Remaining": str(result["remaining"]),
        "X-RateLimit-Reset": str(result["reset"]),
    }

    if not result["allowed"]:
        headers["Retry-After"] = str(result["reset"] - int(time.time()))
        return jsonify({
            "error": "rate_limit_exceeded",
            "message": "Too many requests. Please retry later.",
            "retry_after": headers["Retry-After"]
        }), 429, headers

    return None  # Proceed with request
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Rate limit by IP only | Shared IPs (NAT) block legit users | Use API key + IP |
| No burst allowance | Rejects legitimate spikes | Use token bucket |
| Missing Retry-After header | Clients hammer immediately | Always include header |
| Rate limit after processing | Wastes server resources | Check before handler |
| No distributed coordination | Inconsistent across instances | Use Redis/central store |
