# LLM Integration Patterns Reference

API patterns, error handling, and cost optimization for LLM integrations.

## API Patterns

### Basic Request with Retry

```typescript
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic();

async function callLLM(
  prompt: string,
  options: { maxRetries?: number; model?: string } = {}
): Promise<string> {
  const { maxRetries = 3, model = 'claude-sonnet-4-20250514' } = options;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await client.messages.create({
        model,
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }],
      });

      return response.content[0].type === 'text'
        ? response.content[0].text
        : '';
    } catch (error) {
      if (isRetryable(error) && attempt < maxRetries - 1) {
        await sleep(Math.pow(2, attempt) * 1000);
        continue;
      }
      throw error;
    }
  }

  throw new Error('Max retries exceeded');
}

function isRetryable(error: unknown): boolean {
  if (error instanceof Anthropic.RateLimitError) return true;
  if (error instanceof Anthropic.InternalServerError) return true;
  if (error instanceof Anthropic.APIConnectionError) return true;
  return false;
}
```

### Streaming Responses

```typescript
async function streamLLM(
  prompt: string,
  onChunk: (text: string) => void
): Promise<string> {
  let fullText = '';

  const stream = client.messages.stream({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 4096,
    messages: [{ role: 'user', content: prompt }],
  });

  for await (const event of stream) {
    if (
      event.type === 'content_block_delta' &&
      event.delta.type === 'text_delta'
    ) {
      onChunk(event.delta.text);
      fullText += event.delta.text;
    }
  }

  return fullText;
}

// Usage: real-time UI updates
await streamLLM(prompt, (chunk) => {
  process.stdout.write(chunk);
});
```

### Structured Output

```typescript
async function getStructuredOutput<T>(
  prompt: string,
  schema: z.ZodSchema<T>
): Promise<T> {
  const response = await callLLM(
    `${prompt}\n\nRespond with valid JSON matching this schema:\n${JSON.stringify(zodToJsonSchema(schema))}`
  );

  // Extract JSON from response
  const jsonMatch = response.match(/```json\n?([\s\S]*?)\n?```/) ||
                    response.match(/\{[\s\S]*\}/);

  if (!jsonMatch) throw new Error('No JSON found in response');

  const parsed = JSON.parse(jsonMatch[1] || jsonMatch[0]);
  return schema.parse(parsed);
}
```

## Error Handling

### Error Classification

```typescript
enum LLMErrorType {
  RATE_LIMITED = 'rate_limited',
  CONTEXT_OVERFLOW = 'context_overflow',
  INVALID_RESPONSE = 'invalid_response',
  SERVICE_DOWN = 'service_down',
  TIMEOUT = 'timeout',
}

function classifyError(error: unknown): LLMErrorType {
  if (error instanceof Anthropic.RateLimitError)
    return LLMErrorType.RATE_LIMITED;
  if (error instanceof Anthropic.BadRequestError &&
      error.message.includes('too many tokens'))
    return LLMErrorType.CONTEXT_OVERFLOW;
  if (error instanceof Anthropic.InternalServerError)
    return LLMErrorType.SERVICE_DOWN;
  if (error instanceof Anthropic.APIConnectionError)
    return LLMErrorType.TIMEOUT;
  return LLMErrorType.INVALID_RESPONSE;
}
```

### Graceful Degradation

```typescript
async function llmWithFallback(prompt: string): Promise<string> {
  try {
    // Try primary model
    return await callLLM(prompt, { model: 'claude-sonnet-4-20250514' });
  } catch (error) {
    const errorType = classifyError(error);

    switch (errorType) {
      case LLMErrorType.CONTEXT_OVERFLOW:
        // Reduce context and retry
        const shortened = truncateContext(prompt, 0.5);
        return await callLLM(shortened);

      case LLMErrorType.RATE_LIMITED:
        // Wait and retry
        await sleep(60000);
        return await callLLM(prompt);

      case LLMErrorType.SERVICE_DOWN:
        // Return cached or default response
        return getCachedResponse(prompt) ?? 'Service temporarily unavailable';

      default:
        throw error;
    }
  }
}
```

## Cost Optimization

### Token Usage Tracking

```typescript
interface UsageMetrics {
  inputTokens: number;
  outputTokens: number;
  model: string;
  cost: number;
}

function calculateCost(usage: { input_tokens: number; output_tokens: number }, model: string): number {
  const pricing: Record<string, { input: number; output: number }> = {
    'claude-sonnet-4-20250514': { input: 3.0, output: 15.0 },  // per 1M tokens
    'claude-haiku-35-20241022': { input: 0.25, output: 1.25 },
  };

  const rates = pricing[model];
  if (!rates) return 0;

  return (usage.input_tokens * rates.input + usage.output_tokens * rates.output) / 1_000_000;
}
```

### Cost Reduction Strategies

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Use smaller model for simple tasks | 80-90% | Slightly lower quality |
| Cache identical requests | 50-70% | Stale responses possible |
| Reduce context size | 20-50% | May miss relevant info |
| Batch similar requests | 10-30% | Higher latency |
| Prompt caching (API feature) | 50-90% on input | Requires repeated prefixes |

```typescript
// Route to appropriate model based on task complexity
function selectModel(task: TaskType): string {
  switch (task) {
    case 'code-generation':
    case 'architecture-review':
      return 'claude-sonnet-4-20250514';   // Complex: use capable model
    case 'code-formatting':
    case 'simple-completion':
      return 'claude-haiku-35-20241022';   // Simple: use fast/cheap model
    default:
      return 'claude-sonnet-4-20250514';
  }
}
```

## Rate Limiting

```typescript
class RateLimiter {
  private tokens: number;
  private lastRefill: number;

  constructor(
    private maxTokens: number,
    private refillRate: number // tokens per second
  ) {
    this.tokens = maxTokens;
    this.lastRefill = Date.now();
  }

  async acquire(cost: number = 1): Promise<void> {
    this.refill();

    while (this.tokens < cost) {
      const waitTime = (cost - this.tokens) / this.refillRate * 1000;
      await sleep(waitTime);
      this.refill();
    }

    this.tokens -= cost;
  }

  private refill(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    this.tokens = Math.min(this.maxTokens, this.tokens + elapsed * this.refillRate);
    this.lastRefill = now;
  }
}

// Usage
const limiter = new RateLimiter(60, 1); // 60 requests/min
await limiter.acquire();
const result = await callLLM(prompt);
```

## Response Caching

```typescript
async function cachedLLMCall(
  prompt: string,
  options: { ttl?: number } = {}
): Promise<string> {
  const { ttl = 3600 } = options;
  const cacheKey = `llm:${hashPrompt(prompt)}`;

  const cached = await cache.get(cacheKey);
  if (cached) return cached;

  const response = await callLLM(prompt);
  await cache.set(cacheKey, response, 'EX', ttl);

  return response;
}

function hashPrompt(prompt: string): string {
  return crypto.createHash('sha256').update(prompt).digest('hex').slice(0, 16);
}
```

## Common Pitfalls

- **No timeout**: LLM calls can hang; always set request timeouts (30-120s)
- **Unbounded retries**: Exponential backoff with max retries; avoid retry storms
- **Ignoring token limits**: Estimate input tokens before sending; truncate proactively
- **No cost monitoring**: Track per-request costs; set budget alerts
- **Synchronous blocking**: Use streaming for user-facing requests; batch for background
- **Hardcoded model names**: Abstract model selection for easy switching and A/B testing
