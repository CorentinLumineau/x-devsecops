---
title: SQL Injection Prevention Reference
category: security
type: reference
version: "1.0.0"
---

# SQL Injection Prevention Patterns

> Part of the security/input-validation knowledge skill

## Overview

SQL Injection (SQLi) occurs when untrusted data is concatenated into SQL queries. Attackers can read, modify, or delete data, bypass authentication, or execute administrative operations. This reference covers comprehensive prevention patterns.

## 80/20 Quick Reference

**Prevention hierarchy (most to least effective):**

| Method | Effectiveness | Complexity |
|--------|--------------|------------|
| Parameterized Queries | 100% | Low |
| Stored Procedures | 99% | Medium |
| ORM/Query Builders | 98% | Low |
| Input Validation | 80% (supplementary) | Low |
| Escaping | 70% (last resort) | Medium |

**Golden Rule**: Always use parameterized queries. Never concatenate user input.

## Patterns

### Pattern 1: Parameterized Queries

**When to Use**: Every SQL query with external input

**Implementation**:
```typescript
// Node.js with mysql2
import mysql from 'mysql2/promise';

// VULNERABLE - string concatenation
async function getUserVulnerable(userId: string) {
  const query = `SELECT * FROM users WHERE id = '${userId}'`;
  return db.query(query);
  // Attack: userId = "' OR '1'='1"
  // Attack: userId = "'; DROP TABLE users; --"
}

// SECURE - positional parameters
async function getUser(userId: string) {
  const query = 'SELECT * FROM users WHERE id = ?';
  const [rows] = await db.execute(query, [userId]);
  return rows[0];
}

// SECURE - multiple parameters
async function getUsers(status: string, role: string, limit: number) {
  const query = 'SELECT * FROM users WHERE status = ? AND role = ? LIMIT ?';
  const [rows] = await db.execute(query, [status, role, limit]);
  return rows;
}

// SECURE - named parameters (some drivers support)
async function getUserByEmail(email: string) {
  const query = 'SELECT * FROM users WHERE email = :email AND active = :active';
  const [rows] = await db.execute(query, { email, active: true });
  return rows[0];
}

// PostgreSQL with node-postgres
import { Pool } from 'pg';

async function getUserPg(userId: string) {
  const query = 'SELECT * FROM users WHERE id = $1';
  const result = await pool.query(query, [userId]);
  return result.rows[0];
}

// Python with psycopg2
# cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

// Go with database/sql
# db.Query("SELECT * FROM users WHERE id = ?", userId)

// Java with PreparedStatement
# PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
# ps.setString(1, userId);
```

**Anti-Pattern**: Template literals that look safe but aren't
```typescript
// VULNERABLE - Prisma raw query with template
const user = await prisma.$queryRawUnsafe(
  `SELECT * FROM users WHERE id = '${userId}'`
);

// SECURE - Prisma tagged template (parameterized)
const user = await prisma.$queryRaw`
  SELECT * FROM users WHERE id = ${userId}
`;
```

### Pattern 2: ORM and Query Builders

**When to Use**: Standard CRUD operations

**Implementation**:
```typescript
// Prisma - inherently safe
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function getUser(userId: string) {
  return prisma.user.findUnique({
    where: { id: userId }
  });
}

async function searchUsers(name: string, status: string) {
  return prisma.user.findMany({
    where: {
      name: { contains: name },
      status: status
    }
  });
}

// TypeORM - query builder is safe
import { getRepository } from 'typeorm';

async function searchUsers(name: string, role: string) {
  return getRepository(User)
    .createQueryBuilder('user')
    .where('user.name LIKE :name', { name: `%${name}%` })
    .andWhere('user.role = :role', { role })
    .orderBy('user.createdAt', 'DESC')
    .getMany();
}

// Knex.js - chainable query builder
async function getActiveUsers(status: string) {
  return knex('users')
    .where({ status })
    .whereNotNull('email_verified_at')
    .select('id', 'name', 'email');
}

// Sequelize
async function findUser(email: string) {
  return User.findOne({
    where: { email }
  });
}
```

**Warning**: Raw queries in ORMs can still be vulnerable
```typescript
// VULNERABLE - raw query with concatenation
const users = await sequelize.query(
  `SELECT * FROM users WHERE name = '${name}'`
);

// SECURE - raw query with replacements
const users = await sequelize.query(
  'SELECT * FROM users WHERE name = ?',
  { replacements: [name], type: QueryTypes.SELECT }
);
```

### Pattern 3: Dynamic Table/Column Names

**When to Use**: User-controlled sorting, table selection

**Implementation**:
```typescript
// Cannot parameterize identifiers - use whitelist

// VULNERABLE - dynamic column name
async function sortUsersVulnerable(sortBy: string) {
  const query = `SELECT * FROM users ORDER BY ${sortBy}`;
  return db.query(query);
  // Attack: sortBy = "id; DELETE FROM users; --"
}

// SECURE - whitelist validation
const ALLOWED_SORT_COLUMNS = ['id', 'name', 'email', 'created_at'] as const;
const ALLOWED_SORT_ORDERS = ['ASC', 'DESC'] as const;

type SortColumn = typeof ALLOWED_SORT_COLUMNS[number];
type SortOrder = typeof ALLOWED_SORT_ORDERS[number];

async function sortUsers(sortBy: string, order: string = 'ASC') {
  // Validate against whitelist
  if (!ALLOWED_SORT_COLUMNS.includes(sortBy as SortColumn)) {
    throw new ValidationError(`Invalid sort column: ${sortBy}`);
  }
  if (!ALLOWED_SORT_ORDERS.includes(order.toUpperCase() as SortOrder)) {
    throw new ValidationError(`Invalid sort order: ${order}`);
  }

  // Safe after whitelist validation
  const query = `SELECT * FROM users ORDER BY ${sortBy} ${order}`;
  return db.query(query);
}

// SECURE - dynamic table name with whitelist
const ALLOWED_TABLES = ['users', 'orders', 'products'];

async function getRecords(tableName: string, limit: number) {
  if (!ALLOWED_TABLES.includes(tableName)) {
    throw new ValidationError(`Invalid table: ${tableName}`);
  }

  // Parameterize what we can
  const query = `SELECT * FROM ${tableName} LIMIT ?`;
  return db.execute(query, [limit]);
}
```

### Pattern 4: IN Clause Handling

**When to Use**: Filtering by multiple values

**Implementation**:
```typescript
// VULNERABLE - string joining
async function getUsersVulnerable(ids: string[]) {
  const query = `SELECT * FROM users WHERE id IN (${ids.join(',')})`;
  return db.query(query);
}

// SECURE - parameterized IN clause
async function getUsers(ids: string[]) {
  if (ids.length === 0) return [];

  // Validate IDs
  ids.forEach(id => {
    if (!/^[0-9a-f-]+$/i.test(id)) {
      throw new ValidationError('Invalid ID format');
    }
  });

  // Create placeholder string
  const placeholders = ids.map(() => '?').join(',');
  const query = `SELECT * FROM users WHERE id IN (${placeholders})`;

  const [rows] = await db.execute(query, ids);
  return rows;
}

// SECURE - with PostgreSQL (array parameter)
async function getUsersPg(ids: string[]) {
  const query = 'SELECT * FROM users WHERE id = ANY($1)';
  const result = await pool.query(query, [ids]);
  return result.rows;
}

// SECURE - with ORM
async function getUsersPrisma(ids: string[]) {
  return prisma.user.findMany({
    where: {
      id: { in: ids }
    }
  });
}
```

### Pattern 5: LIKE Clause Escaping

**When to Use**: Search functionality with wildcards

**Implementation**:
```typescript
// LIKE special characters: % _ [ ] ^
function escapeLikePattern(pattern: string): string {
  return pattern
    .replace(/\\/g, '\\\\')
    .replace(/%/g, '\\%')
    .replace(/_/g, '\\_');
}

// SECURE - escaped LIKE pattern
async function searchUsers(searchTerm: string) {
  const escapedTerm = escapeLikePattern(searchTerm);
  const query = 'SELECT * FROM users WHERE name LIKE ? ESCAPE \'\\\'';
  const [rows] = await db.execute(query, [`%${escapedTerm}%`]);
  return rows;
}

// SECURE - with ORM (handles escaping)
async function searchUsersPrisma(searchTerm: string) {
  return prisma.user.findMany({
    where: {
      name: { contains: searchTerm }  // Prisma escapes automatically
    }
  });
}
```

### Pattern 6: Stored Procedures

**When to Use**: Complex operations, additional security layer

**Implementation**:
```sql
-- Create stored procedure
CREATE PROCEDURE GetUserById(IN userId VARCHAR(36))
BEGIN
  SELECT id, name, email, created_at
  FROM users
  WHERE id = userId AND status = 'active';
END;

-- Create procedure for search
CREATE PROCEDURE SearchUsers(
  IN searchName VARCHAR(100),
  IN searchStatus VARCHAR(20),
  IN pageSize INT,
  IN pageOffset INT
)
BEGIN
  SELECT id, name, email, status
  FROM users
  WHERE name LIKE CONCAT('%', searchName, '%')
    AND (searchStatus IS NULL OR status = searchStatus)
  LIMIT pageSize OFFSET pageOffset;
END;
```

```typescript
// Call stored procedure
async function getUserById(userId: string) {
  const [rows] = await db.execute('CALL GetUserById(?)', [userId]);
  return rows[0]?.[0];
}

async function searchUsers(name: string, status: string | null, page: number) {
  const pageSize = 20;
  const offset = (page - 1) * pageSize;

  const [rows] = await db.execute(
    'CALL SearchUsers(?, ?, ?, ?)',
    [name, status, pageSize, offset]
  );
  return rows[0];
}
```

## Checklist

- [ ] All queries use parameterized statements
- [ ] ORM/query builder used for standard operations
- [ ] Dynamic identifiers validated against whitelist
- [ ] IN clauses use parameterized placeholders
- [ ] LIKE patterns escape special characters
- [ ] Raw queries audited for injection vectors
- [ ] Database user has minimal permissions
- [ ] Error messages don't reveal SQL details
- [ ] Query logging doesn't include sensitive data
- [ ] Regular code review for SQL patterns

## References

- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [Bobby Tables](https://bobby-tables.com/)
- [OWASP Testing Guide - SQL Injection](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/05-Testing_for_SQL_Injection)
