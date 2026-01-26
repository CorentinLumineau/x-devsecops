---
title: API Error Responses Reference
category: code
type: reference
version: "1.0.0"
---

# API Error Responses

> Part of the code/error-handling knowledge skill

## Overview

Consistent, informative API error responses improve developer experience and debugging. This reference covers error response formats, HTTP status codes, and error handling middleware patterns.

## Quick Reference (80/20)

| Status Code | Meaning | When to Use |
|-------------|---------|-------------|
| 400 | Bad Request | Invalid input, validation errors |
| 401 | Unauthorized | Missing/invalid authentication |
| 403 | Forbidden | Valid auth, insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource state conflict |
| 422 | Unprocessable Entity | Semantic validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server errors |
| 502 | Bad Gateway | Upstream service failure |
| 503 | Service Unavailable | Temporary unavailability |

## Patterns

### Pattern 1: Standard Error Response Format

**When to Use**: All API error responses

**Example**:
```typescript
// Standard error response structure
interface ApiErrorResponse {
  error: {
    code: string;           // Machine-readable error code
    message: string;        // Human-readable message
    details?: ErrorDetail[]; // Additional context
    requestId: string;      // For support/debugging
    timestamp: string;      // ISO 8601
    path: string;           // Request path
    documentation?: string;  // Link to error docs
  };
}

interface ErrorDetail {
  field?: string;          // Field that caused error
  code: string;            // Specific error code
  message: string;         // Detailed message
  value?: any;             // Invalid value (sanitized)
}

// Error codes enum
enum ErrorCode {
  // Validation errors (400)
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INVALID_FORMAT = 'INVALID_FORMAT',
  MISSING_FIELD = 'MISSING_FIELD',
  INVALID_VALUE = 'INVALID_VALUE',

  // Authentication errors (401)
  AUTHENTICATION_REQUIRED = 'AUTHENTICATION_REQUIRED',
  INVALID_TOKEN = 'INVALID_TOKEN',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',

  // Authorization errors (403)
  INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS',
  RESOURCE_ACCESS_DENIED = 'RESOURCE_ACCESS_DENIED',

  // Not found errors (404)
  RESOURCE_NOT_FOUND = 'RESOURCE_NOT_FOUND',
  ENDPOINT_NOT_FOUND = 'ENDPOINT_NOT_FOUND',

  // Conflict errors (409)
  RESOURCE_ALREADY_EXISTS = 'RESOURCE_ALREADY_EXISTS',
  RESOURCE_CONFLICT = 'RESOURCE_CONFLICT',
  OPTIMISTIC_LOCK_FAILURE = 'OPTIMISTIC_LOCK_FAILURE',

  // Rate limiting (429)
  RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED',

  // Server errors (500)
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  DATABASE_ERROR = 'DATABASE_ERROR',
  EXTERNAL_SERVICE_ERROR = 'EXTERNAL_SERVICE_ERROR'
}

// Example responses
const validationErrorResponse: ApiErrorResponse = {
  error: {
    code: 'VALIDATION_ERROR',
    message: 'Request validation failed',
    details: [
      {
        field: 'email',
        code: 'INVALID_FORMAT',
        message: 'Must be a valid email address',
        value: 'not-an-email'
      },
      {
        field: 'age',
        code: 'INVALID_VALUE',
        message: 'Must be between 18 and 120',
        value: 15
      }
    ],
    requestId: 'req_abc123def456',
    timestamp: '2024-01-15T10:30:00.000Z',
    path: '/api/v1/users',
    documentation: 'https://api.example.com/docs/errors#VALIDATION_ERROR'
  }
};

const notFoundResponse: ApiErrorResponse = {
  error: {
    code: 'RESOURCE_NOT_FOUND',
    message: 'User not found',
    requestId: 'req_xyz789',
    timestamp: '2024-01-15T10:31:00.000Z',
    path: '/api/v1/users/nonexistent-id'
  }
};
```

**Anti-Pattern**: Different error formats across endpoints.

### Pattern 2: Error Classes Hierarchy

**When to Use**: Type-safe error handling in application

**Example**:
```typescript
// Base API error
abstract class ApiError extends Error {
  abstract readonly statusCode: number;
  abstract readonly code: string;
  readonly details: ErrorDetail[] = [];
  readonly timestamp: Date = new Date();

  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }

  addDetail(detail: ErrorDetail): this {
    this.details.push(detail);
    return this;
  }

  toResponse(requestId: string, path: string): ApiErrorResponse {
    return {
      error: {
        code: this.code,
        message: this.message,
        details: this.details.length > 0 ? this.details : undefined,
        requestId,
        timestamp: this.timestamp.toISOString(),
        path
      }
    };
  }
}

// Client errors (4xx)
class ValidationError extends ApiError {
  readonly statusCode = 400;
  readonly code = 'VALIDATION_ERROR';
}

class AuthenticationError extends ApiError {
  readonly statusCode = 401;
  readonly code: string;

  constructor(code: 'AUTHENTICATION_REQUIRED' | 'INVALID_TOKEN' | 'TOKEN_EXPIRED', message: string) {
    super(message);
    this.code = code;
  }
}

class AuthorizationError extends ApiError {
  readonly statusCode = 403;
  readonly code = 'INSUFFICIENT_PERMISSIONS';

  constructor(
    message: string,
    public readonly requiredPermissions: string[]
  ) {
    super(message);
  }
}

class NotFoundError extends ApiError {
  readonly statusCode = 404;
  readonly code = 'RESOURCE_NOT_FOUND';

  constructor(
    public readonly resourceType: string,
    public readonly resourceId: string
  ) {
    super(`${resourceType} with id '${resourceId}' not found`);
  }
}

class ConflictError extends ApiError {
  readonly statusCode = 409;
  readonly code: string;

  constructor(
    code: 'RESOURCE_ALREADY_EXISTS' | 'RESOURCE_CONFLICT' | 'OPTIMISTIC_LOCK_FAILURE',
    message: string
  ) {
    super(message);
    this.code = code;
  }
}

class RateLimitError extends ApiError {
  readonly statusCode = 429;
  readonly code = 'RATE_LIMIT_EXCEEDED';

  constructor(
    public readonly retryAfter: number,
    public readonly limit: number,
    public readonly remaining: number
  ) {
    super(`Rate limit exceeded. Retry after ${retryAfter} seconds`);
  }
}

// Server errors (5xx)
class InternalError extends ApiError {
  readonly statusCode = 500;
  readonly code = 'INTERNAL_ERROR';

  constructor(message: string = 'An unexpected error occurred') {
    super(message);
  }
}

class ExternalServiceError extends ApiError {
  readonly statusCode = 502;
  readonly code = 'EXTERNAL_SERVICE_ERROR';

  constructor(
    public readonly serviceName: string,
    message: string
  ) {
    super(`External service '${serviceName}' error: ${message}`);
  }
}

// Usage
function validateUserInput(input: any): void {
  const error = new ValidationError('Request validation failed');

  if (!input.email) {
    error.addDetail({
      field: 'email',
      code: 'MISSING_FIELD',
      message: 'Email is required'
    });
  } else if (!isValidEmail(input.email)) {
    error.addDetail({
      field: 'email',
      code: 'INVALID_FORMAT',
      message: 'Must be a valid email address',
      value: input.email
    });
  }

  if (error.details.length > 0) {
    throw error;
  }
}
```

**Anti-Pattern**: Using generic Error class for all API errors.

### Pattern 3: Error Handling Middleware

**When to Use**: Centralized error handling in Express/Fastify

**Example**:
```typescript
// Express error handling middleware
import { Request, Response, NextFunction } from 'express';

function errorHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const requestId = req.headers['x-request-id'] as string || generateRequestId();

  // Log error with context
  logger.error({
    requestId,
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
    userId: req.user?.id
  });

  // Handle known API errors
  if (error instanceof ApiError) {
    const response = error.toResponse(requestId, req.path);

    // Add headers for specific error types
    if (error instanceof RateLimitError) {
      res.setHeader('Retry-After', error.retryAfter);
      res.setHeader('X-RateLimit-Limit', error.limit);
      res.setHeader('X-RateLimit-Remaining', error.remaining);
    }

    res.status(error.statusCode).json(response);
    return;
  }

  // Handle validation libraries (Joi, Zod, etc.)
  if (error.name === 'ZodError') {
    const zodError = error as ZodError;
    const apiError = new ValidationError('Request validation failed');

    zodError.errors.forEach(e => {
      apiError.addDetail({
        field: e.path.join('.'),
        code: 'INVALID_VALUE',
        message: e.message
      });
    });

    res.status(400).json(apiError.toResponse(requestId, req.path));
    return;
  }

  // Handle database errors
  if (error.name === 'SequelizeUniqueConstraintError') {
    const conflictError = new ConflictError(
      'RESOURCE_ALREADY_EXISTS',
      'A resource with this identifier already exists'
    );
    res.status(409).json(conflictError.toResponse(requestId, req.path));
    return;
  }

  // Handle unknown errors (don't expose internal details)
  const internalError = new InternalError();

  // In development, include more details
  if (process.env.NODE_ENV === 'development') {
    internalError.addDetail({
      code: 'DEBUG_INFO',
      message: error.message
    });
  }

  res.status(500).json(internalError.toResponse(requestId, req.path));
}

// Async wrapper to catch async errors
function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Usage
app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await userService.findById(req.params.id);

  if (!user) {
    throw new NotFoundError('User', req.params.id);
  }

  res.json({ data: user });
}));

app.use(errorHandler);
```

**Anti-Pattern**: Try/catch in every route handler.

### Pattern 4: Problem Details (RFC 7807)

**When to Use**: Standardized error format following RFC 7807

**Example**:
```typescript
// RFC 7807 Problem Details
interface ProblemDetails {
  type: string;       // URI reference identifying problem type
  title: string;      // Short, human-readable summary
  status: number;     // HTTP status code
  detail?: string;    // Detailed explanation
  instance?: string;  // URI reference for specific occurrence
  [key: string]: any; // Extension members
}

// Implementation
class ProblemDetailsError extends Error {
  constructor(
    public readonly type: string,
    public readonly title: string,
    public readonly status: number,
    public readonly detail?: string,
    public readonly extensions: Record<string, any> = {}
  ) {
    super(title);
    this.name = 'ProblemDetailsError';
  }

  toProblemDetails(instance: string): ProblemDetails {
    return {
      type: this.type,
      title: this.title,
      status: this.status,
      detail: this.detail,
      instance,
      ...this.extensions
    };
  }
}

// Predefined problem types
const ProblemTypes = {
  VALIDATION: 'https://api.example.com/problems/validation-error',
  AUTH_REQUIRED: 'https://api.example.com/problems/authentication-required',
  FORBIDDEN: 'https://api.example.com/problems/forbidden',
  NOT_FOUND: 'https://api.example.com/problems/not-found',
  RATE_LIMITED: 'https://api.example.com/problems/rate-limited',
  INTERNAL: 'https://api.example.com/problems/internal-error'
};

// Factory functions
function validationProblem(errors: ValidationError[]): ProblemDetailsError {
  return new ProblemDetailsError(
    ProblemTypes.VALIDATION,
    'Validation Error',
    400,
    'One or more validation errors occurred',
    { errors }
  );
}

function notFoundProblem(resourceType: string, resourceId: string): ProblemDetailsError {
  return new ProblemDetailsError(
    ProblemTypes.NOT_FOUND,
    'Resource Not Found',
    404,
    `The ${resourceType} with identifier '${resourceId}' was not found`,
    { resourceType, resourceId }
  );
}

function rateLimitProblem(retryAfter: number): ProblemDetailsError {
  return new ProblemDetailsError(
    ProblemTypes.RATE_LIMITED,
    'Rate Limit Exceeded',
    429,
    `You have exceeded the rate limit. Please retry after ${retryAfter} seconds`,
    { retryAfter }
  );
}

// Middleware
function problemDetailsHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const instance = `${req.protocol}://${req.host}${req.originalUrl}`;

  if (error instanceof ProblemDetailsError) {
    res
      .status(error.status)
      .type('application/problem+json')
      .json(error.toProblemDetails(instance));
    return;
  }

  // Convert to problem details
  const problem: ProblemDetails = {
    type: ProblemTypes.INTERNAL,
    title: 'Internal Server Error',
    status: 500,
    instance
  };

  if (process.env.NODE_ENV === 'development') {
    problem.detail = error.message;
  }

  res
    .status(500)
    .type('application/problem+json')
    .json(problem);
}
```

**Anti-Pattern**: Non-standard error formats in public APIs.

### Pattern 5: Error Documentation

**When to Use**: API documentation for errors

**Example**:
```yaml
# OpenAPI error documentation
components:
  schemas:
    Error:
      type: object
      required:
        - error
      properties:
        error:
          type: object
          required:
            - code
            - message
            - requestId
            - timestamp
            - path
          properties:
            code:
              type: string
              description: Machine-readable error code
              example: VALIDATION_ERROR
            message:
              type: string
              description: Human-readable error message
              example: Request validation failed
            details:
              type: array
              items:
                $ref: '#/components/schemas/ErrorDetail'
            requestId:
              type: string
              description: Unique request identifier for support
              example: req_abc123
            timestamp:
              type: string
              format: date-time
              description: Error timestamp
            path:
              type: string
              description: Request path
              example: /api/v1/users
            documentation:
              type: string
              format: uri
              description: Link to error documentation

    ErrorDetail:
      type: object
      required:
        - code
        - message
      properties:
        field:
          type: string
          description: Field that caused the error
          example: email
        code:
          type: string
          description: Specific error code
          example: INVALID_FORMAT
        message:
          type: string
          description: Detailed error message
          example: Must be a valid email address

  responses:
    BadRequest:
      description: Invalid request
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          examples:
            validation:
              summary: Validation error
              value:
                error:
                  code: VALIDATION_ERROR
                  message: Request validation failed
                  details:
                    - field: email
                      code: INVALID_FORMAT
                      message: Must be a valid email address
                  requestId: req_abc123
                  timestamp: '2024-01-15T10:30:00.000Z'
                  path: /api/v1/users

    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          examples:
            missing_token:
              summary: Missing authentication
              value:
                error:
                  code: AUTHENTICATION_REQUIRED
                  message: Authentication token is required
                  requestId: req_xyz789
                  timestamp: '2024-01-15T10:30:00.000Z'
                  path: /api/v1/users
```

**Anti-Pattern**: Missing error documentation in API specs.

### Pattern 6: Client-Side Error Handling

**When to Use**: SDK/client error handling

**Example**:
```typescript
// API client with error handling
class ApiClient {
  constructor(
    private baseUrl: string,
    private options: ApiClientOptions = {}
  ) {}

  async request<T>(
    method: string,
    path: string,
    options: RequestOptions = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;

    try {
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...this.options.headers,
          ...options.headers
        },
        body: options.body ? JSON.stringify(options.body) : undefined
      });

      if (!response.ok) {
        throw await this.parseError(response);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ApiClientError) {
        throw error;
      }

      // Network or other errors
      throw new NetworkError(`Request failed: ${error.message}`);
    }
  }

  private async parseError(response: Response): Promise<ApiClientError> {
    try {
      const body: ApiErrorResponse = await response.json();

      switch (response.status) {
        case 400:
          return new ValidationClientError(body.error);
        case 401:
          return new AuthenticationClientError(body.error);
        case 403:
          return new AuthorizationClientError(body.error);
        case 404:
          return new NotFoundClientError(body.error);
        case 409:
          return new ConflictClientError(body.error);
        case 429:
          return new RateLimitClientError(body.error, response.headers);
        default:
          return new ApiClientError(response.status, body.error);
      }
    } catch {
      return new ApiClientError(response.status, {
        code: 'UNKNOWN_ERROR',
        message: response.statusText,
        requestId: 'unknown',
        timestamp: new Date().toISOString(),
        path: response.url
      });
    }
  }
}

// Client error classes
class ApiClientError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly error: ApiErrorResponse['error']
  ) {
    super(error.message);
    this.name = 'ApiClientError';
  }

  get code(): string {
    return this.error.code;
  }

  get requestId(): string {
    return this.error.requestId;
  }
}

class ValidationClientError extends ApiClientError {
  constructor(error: ApiErrorResponse['error']) {
    super(400, error);
    this.name = 'ValidationClientError';
  }

  getFieldErrors(): Map<string, string[]> {
    const fieldErrors = new Map<string, string[]>();

    for (const detail of this.error.details || []) {
      if (detail.field) {
        const existing = fieldErrors.get(detail.field) || [];
        existing.push(detail.message);
        fieldErrors.set(detail.field, existing);
      }
    }

    return fieldErrors;
  }
}

class RateLimitClientError extends ApiClientError {
  readonly retryAfter: number;

  constructor(error: ApiErrorResponse['error'], headers: Headers) {
    super(429, error);
    this.name = 'RateLimitClientError';
    this.retryAfter = parseInt(headers.get('Retry-After') || '60');
  }
}

// Usage
const client = new ApiClient('https://api.example.com');

try {
  const user = await client.request<User>('POST', '/users', {
    body: { email: 'invalid', name: 'Test' }
  });
} catch (error) {
  if (error instanceof ValidationClientError) {
    const fieldErrors = error.getFieldErrors();
    fieldErrors.forEach((errors, field) => {
      console.log(`${field}: ${errors.join(', ')}`);
    });
  } else if (error instanceof RateLimitClientError) {
    console.log(`Rate limited. Retry after ${error.retryAfter}s`);
  } else if (error instanceof ApiClientError) {
    console.log(`API error: ${error.code} - ${error.message}`);
  } else {
    console.log(`Unexpected error: ${error.message}`);
  }
}
```

**Anti-Pattern**: Ignoring error codes and only showing generic messages.

## Checklist

- [ ] Consistent error response format across all endpoints
- [ ] Appropriate HTTP status codes used
- [ ] Machine-readable error codes for programmatic handling
- [ ] Human-readable messages for display
- [ ] Request ID included for debugging
- [ ] Validation errors include field-level details
- [ ] Rate limit errors include retry information
- [ ] Internal errors don't expose sensitive details
- [ ] Error documentation in API specs
- [ ] Client SDKs handle errors appropriately

## References

- [HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [RFC 7807 - Problem Details](https://datatracker.ietf.org/doc/html/rfc7807)
- [Google API Error Model](https://cloud.google.com/apis/design/errors)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/Guidelines.md#7102-error-condition-responses)
