---
title: OpenAPI Specification Reference
category: code
type: reference
version: "1.0.0"
---

# OpenAPI Specification

> Part of the code/api-design knowledge skill

## Overview

OpenAPI Specification (OAS) is the industry standard for describing RESTful APIs. This reference covers OpenAPI 3.x specification patterns, best practices for API documentation, and code generation strategies.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| Path parameters | Resource identification (`/users/{id}`) |
| Query parameters | Filtering, pagination, sorting |
| Request body | Complex data submission (POST/PUT/PATCH) |
| Components/schemas | Reusable data models |
| Security schemes | Authentication documentation |
| Tags | API organization and grouping |

## Patterns

### Pattern 1: Basic API Structure

**When to Use**: Starting a new API specification

**Example**:
```yaml
openapi: 3.1.0
info:
  title: User Management API
  version: 1.0.0
  description: |
    API for managing user accounts and authentication.

    ## Authentication
    All endpoints require Bearer token authentication.
  contact:
    name: API Support
    email: api-support@example.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: https://staging-api.example.com/v1
    description: Staging server
  - url: http://localhost:3000/v1
    description: Development server

tags:
  - name: users
    description: User management operations
  - name: authentication
    description: Authentication and authorization

paths:
  /users:
    get:
      tags:
        - users
      summary: List all users
      description: Retrieve a paginated list of users with optional filtering
      operationId: listUsers
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/LimitParam'
        - name: status
          in: query
          schema:
            type: string
            enum: [active, inactive, pending]
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '500':
          $ref: '#/components/responses/InternalError'

components:
  schemas: {}
  parameters: {}
  responses: {}
  securitySchemes: {}
```

**Anti-Pattern**: Missing server definitions or incomplete contact information.

### Pattern 2: Schema Definitions

**When to Use**: Defining reusable data models

**Example**:
```yaml
components:
  schemas:
    # Base user schema
    User:
      type: object
      required:
        - id
        - email
        - createdAt
      properties:
        id:
          type: string
          format: uuid
          readOnly: true
          description: Unique identifier for the user
          example: 550e8400-e29b-41d4-a716-446655440000
        email:
          type: string
          format: email
          description: User's email address
          example: user@example.com
        name:
          type: string
          minLength: 1
          maxLength: 100
          description: User's full name
          example: John Doe
        status:
          type: string
          enum: [active, inactive, pending]
          default: pending
          description: Account status
        role:
          $ref: '#/components/schemas/UserRole'
        createdAt:
          type: string
          format: date-time
          readOnly: true
        updatedAt:
          type: string
          format: date-time
          readOnly: true

    # Enum as separate schema
    UserRole:
      type: string
      enum: [admin, user, viewer]
      description: |
        User role determining permissions:
        - admin: Full access
        - user: Standard access
        - viewer: Read-only access

    # Request schema (subset of User)
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
          format: password
          minLength: 8
          writeOnly: true
        name:
          type: string
          minLength: 1
          maxLength: 100

    # Response with pagination
    UserListResponse:
      type: object
      required:
        - data
        - pagination
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/User'
        pagination:
          $ref: '#/components/schemas/Pagination'

    # Reusable pagination schema
    Pagination:
      type: object
      required:
        - page
        - limit
        - total
        - totalPages
      properties:
        page:
          type: integer
          minimum: 1
          example: 1
        limit:
          type: integer
          minimum: 1
          maximum: 100
          example: 20
        total:
          type: integer
          minimum: 0
          example: 150
        totalPages:
          type: integer
          minimum: 0
          example: 8

    # Polymorphic schema with discriminator
    Notification:
      type: object
      required:
        - type
        - recipient
      discriminator:
        propertyName: type
        mapping:
          email: '#/components/schemas/EmailNotification'
          sms: '#/components/schemas/SMSNotification'
          push: '#/components/schemas/PushNotification'
      properties:
        type:
          type: string
        recipient:
          type: string

    EmailNotification:
      allOf:
        - $ref: '#/components/schemas/Notification'
        - type: object
          required:
            - subject
            - body
          properties:
            subject:
              type: string
            body:
              type: string
              format: html
```

**Anti-Pattern**: Duplicating schema properties instead of using `$ref`.

### Pattern 3: Path Operations

**When to Use**: Defining CRUD operations

**Example**:
```yaml
paths:
  /users:
    get:
      tags: [users]
      summary: List users
      operationId: listUsers
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/LimitParam'
        - name: search
          in: query
          description: Search users by name or email
          schema:
            type: string
        - name: sort
          in: query
          description: Sort field and direction
          schema:
            type: string
            pattern: '^[a-zA-Z]+:(asc|desc)$'
            example: 'createdAt:desc'
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
              examples:
                default:
                  $ref: '#/components/examples/UserListExample'

    post:
      tags: [users]
      summary: Create user
      operationId: createUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
            examples:
              minimal:
                summary: Minimal user creation
                value:
                  email: user@example.com
                  password: securePassword123
              complete:
                summary: Complete user creation
                value:
                  email: user@example.com
                  password: securePassword123
                  name: John Doe
      responses:
        '201':
          description: User created
          headers:
            Location:
              description: URL of the created resource
              schema:
                type: string
                format: uri
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '400':
          $ref: '#/components/responses/BadRequest'
        '409':
          description: Email already exists
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'

  /users/{userId}:
    parameters:
      - name: userId
        in: path
        required: true
        description: User identifier
        schema:
          type: string
          format: uuid

    get:
      tags: [users]
      summary: Get user by ID
      operationId: getUser
      responses:
        '200':
          description: User found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFound'

    patch:
      tags: [users]
      summary: Update user
      operationId: updateUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UpdateUserRequest'
      responses:
        '200':
          description: User updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFound'

    delete:
      tags: [users]
      summary: Delete user
      operationId: deleteUser
      responses:
        '204':
          description: User deleted
        '404':
          $ref: '#/components/responses/NotFound'
```

**Anti-Pattern**: Using POST for all operations instead of proper HTTP methods.

### Pattern 4: Security Schemes

**When to Use**: Documenting authentication requirements

**Example**:
```yaml
components:
  securitySchemes:
    # Bearer token authentication
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: |
        JWT token obtained from /auth/login endpoint.
        Include in Authorization header: `Bearer <token>`

    # API key authentication
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
      description: API key for service-to-service communication

    # OAuth 2.0
    OAuth2:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://auth.example.com/authorize
          tokenUrl: https://auth.example.com/token
          refreshUrl: https://auth.example.com/refresh
          scopes:
            read:users: Read user information
            write:users: Modify user information
            admin: Full administrative access
        clientCredentials:
          tokenUrl: https://auth.example.com/token
          scopes:
            service: Service-to-service access

# Global security (applies to all operations)
security:
  - BearerAuth: []

# Per-operation security override
paths:
  /auth/login:
    post:
      security: []  # No authentication required
      summary: Authenticate user
      responses:
        '200':
          description: Authentication successful

  /admin/users:
    get:
      security:
        - BearerAuth: []
        - OAuth2: [admin]  # Requires admin scope
      summary: List all users (admin)
```

**Anti-Pattern**: Missing security definitions for protected endpoints.

### Pattern 5: Error Responses

**When to Use**: Standardizing error handling

**Example**:
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
          description: Machine-readable error code
          example: VALIDATION_ERROR
        message:
          type: string
          description: Human-readable error message
          example: Invalid email format
        details:
          type: array
          items:
            $ref: '#/components/schemas/ErrorDetail'
        requestId:
          type: string
          description: Request identifier for support
          example: req_abc123

    ErrorDetail:
      type: object
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
                code: VALIDATION_ERROR
                message: Request validation failed
                details:
                  - field: email
                    code: INVALID_FORMAT
                    message: Must be a valid email address
                requestId: req_abc123

    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: UNAUTHORIZED
            message: Authentication token is missing or invalid
            requestId: req_abc123

    Forbidden:
      description: Insufficient permissions
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
          example:
            code: NOT_FOUND
            message: User not found
            requestId: req_abc123

    Conflict:
      description: Resource conflict
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    TooManyRequests:
      description: Rate limit exceeded
      headers:
        X-RateLimit-Limit:
          schema:
            type: integer
          description: Request limit per window
        X-RateLimit-Remaining:
          schema:
            type: integer
          description: Remaining requests in window
        X-RateLimit-Reset:
          schema:
            type: integer
          description: Unix timestamp when limit resets
        Retry-After:
          schema:
            type: integer
          description: Seconds to wait before retrying
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    InternalError:
      description: Internal server error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
          example:
            code: INTERNAL_ERROR
            message: An unexpected error occurred
            requestId: req_abc123
```

**Anti-Pattern**: Inconsistent error response formats across endpoints.

### Pattern 6: Code Generation

**When to Use**: Generating client/server code from spec

**Example**:
```yaml
# Add x-* extensions for code generators
paths:
  /users:
    get:
      operationId: listUsers
      x-codegen-request-body-name: filter
      x-openapi-router-controller: controllers.users

components:
  schemas:
    User:
      x-typescript-type: UserEntity
      x-go-type: models.User
      properties:
        id:
          x-go-name: ID
          x-typescript-optional: false
```

```bash
# Generate TypeScript client
npx openapi-typescript-codegen \
  --input ./openapi.yaml \
  --output ./src/api \
  --client axios

# Generate Go server
oapi-codegen \
  -package api \
  -generate types,server,spec \
  openapi.yaml > api/api.gen.go

# Validate specification
npx @stoplight/spectral-cli lint openapi.yaml
```

**Anti-Pattern**: Not validating spec before code generation.

## Checklist

- [ ] OpenAPI version 3.0+ used
- [ ] All endpoints have operationId
- [ ] Schemas use $ref for reusability
- [ ] Security schemes documented
- [ ] Error responses standardized
- [ ] Examples provided for complex schemas
- [ ] Pagination documented for list endpoints
- [ ] Spec validates without errors
- [ ] Code generation tested
- [ ] API versioning strategy defined

## References

- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [OpenAPI Tools](https://openapi.tools/)
- [Swagger Editor](https://editor.swagger.io/)
- [Spectral Linting](https://stoplight.io/open-source/spectral)
