# OpenAPI Code Generation Reference

Patterns for generating API clients from OpenAPI specifications.

## OpenAPI Generator Setup

### Installation

```bash
# NPM
npm install @openapitools/openapi-generator-cli -g

# Docker
docker pull openapitools/openapi-generator-cli

# Homebrew
brew install openapi-generator
```

### Basic Generation

```bash
# TypeScript Axios
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g typescript-axios \
  -o ./generated/client

# Python
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g python \
  -o ./generated/client

# Go
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g go \
  -o ./generated/client
```

## Configuration

### TypeScript Axios Config

```yaml
# codegen-config.yaml
npmName: "@company/api-client"
npmVersion: "1.0.0"
supportsES6: true
withSeparateModelsAndApi: true
modelPackage: models
apiPackage: api
withInterfaces: true
useSingleRequestParameter: true
```

### Template Customization

```bash
# Extract templates
openapi-generator-cli author template \
  -g typescript-axios \
  -o ./templates

# Use custom templates
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g typescript-axios \
  -t ./templates \
  -o ./generated/client
```

## OpenAPI Best Practices

### Request/Response Models

```yaml
# Good: Separate request and response models
paths:
  /users:
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
      responses:
        '201':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

components:
  schemas:
    CreateUserRequest:
      type: object
      required:
        - email
        - password
      properties:
        email:
          type: string
          format: email
        password:
          type: string
          minLength: 8

    User:
      type: object
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
        createdAt:
          type: string
          format: date-time
```

### Error Responses

```yaml
components:
  schemas:
    Error:
      type: object
      required:
        - code
        - message
      properties:
        code:
          type: string
          enum:
            - VALIDATION_ERROR
            - NOT_FOUND
            - UNAUTHORIZED
            - FORBIDDEN
            - SERVER_ERROR
        message:
          type: string
        details:
          type: array
          items:
            $ref: '#/components/schemas/ErrorDetail'

    ErrorDetail:
      type: object
      properties:
        field:
          type: string
        message:
          type: string

  responses:
    BadRequest:
      description: Validation error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

### Pagination

```yaml
components:
  schemas:
    PageInfo:
      type: object
      properties:
        page:
          type: integer
        limit:
          type: integer
        total:
          type: integer
        hasNext:
          type: boolean
        hasPrevious:
          type: boolean

    UserList:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/User'
        pagination:
          $ref: '#/components/schemas/PageInfo'
```

## Post-Generation Customization

### Wrapper Class

```typescript
// src/client.ts
import { Configuration, UsersApi, OrdersApi } from './generated';

export class APIClient {
  public readonly users: UsersApi;
  public readonly orders: OrdersApi;

  constructor(private config: ClientConfig) {
    const configuration = new Configuration({
      basePath: config.baseUrl,
      accessToken: config.apiKey,
    });

    this.users = new UsersApi(configuration);
    this.orders = new OrdersApi(configuration);
  }
}
```

### Interceptors

```typescript
import axios from 'axios';

const axiosInstance = axios.create();

// Request interceptor
axiosInstance.interceptors.request.use((config) => {
  config.headers['X-Request-ID'] = crypto.randomUUID();
  return config;
});

// Response interceptor
axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Handle auth error
      return Promise.reject(new UnauthorizedError());
    }
    return Promise.reject(error);
  }
);

// Use with generated client
const configuration = new Configuration({
  basePath: 'https://api.example.com',
});
const usersApi = new UsersApi(configuration, '', axiosInstance);
```

## CI Integration

### GitHub Actions

```yaml
name: Generate Client

on:
  push:
    paths:
      - 'openapi.yaml'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate client
        uses: openapi-generators/openapitools-generator-action@v1
        with:
          generator: typescript-axios
          openapi-file: openapi.yaml
          config-file: codegen-config.yaml
          output-dir: generated/

      - name: Commit changes
        run: |
          git add generated/
          git commit -m "chore: regenerate client" || exit 0
          git push
```

### Validation

```bash
# Validate OpenAPI spec
openapi-generator-cli validate -i openapi.yaml

# Lint with spectral
npm install -g @stoplight/spectral
spectral lint openapi.yaml
```
