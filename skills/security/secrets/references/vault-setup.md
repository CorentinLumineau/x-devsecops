---
title: HashiCorp Vault Setup Reference
category: security
type: reference
version: "1.0.0"
---

# HashiCorp Vault Setup Patterns

> Part of the security/secrets knowledge skill

## Overview

HashiCorp Vault provides secure secret storage, dynamic secrets, encryption as a service, and identity-based access. This reference covers deployment patterns, authentication methods, and application integration.

## 80/20 Quick Reference

**Vault core features:**

| Feature | Use Case | Priority |
|---------|----------|----------|
| KV Secrets Engine | Static secrets | Critical |
| Dynamic Secrets | Database credentials | High |
| Transit Engine | Encryption as a service | High |
| PKI Engine | Certificate management | Medium |
| Auth Methods | Application identity | Critical |

**Authentication methods ranked by security:**
1. Kubernetes auth (for K8s workloads)
2. AppRole (for automated systems)
3. AWS/GCP/Azure auth (for cloud workloads)
4. Token auth (for development)

## Patterns

### Pattern 1: Development Setup

**When to Use**: Local development and testing

**Implementation**:
```bash
# Start Vault in development mode
vault server -dev

# Set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='hvs.xxxxx'  # Dev root token

# Enable KV secrets engine v2
vault secrets enable -path=secret kv-v2

# Store secrets
vault kv put secret/myapp/database \
  username="admin" \
  password="secure-password" \
  host="localhost" \
  port="5432"

# Retrieve secrets
vault kv get secret/myapp/database
vault kv get -format=json secret/myapp/database | jq -r '.data.data.password'
```

**Docker Compose for Development**:
```yaml
version: '3.8'
services:
  vault:
    image: hashicorp/vault:latest
    cap_add:
      - IPC_LOCK
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: dev-token
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports:
      - "8200:8200"
    volumes:
      - vault-data:/vault/data
      - ./vault-config:/vault/config

volumes:
  vault-data:
```

### Pattern 2: Production Deployment

**When to Use**: Production environments

**Implementation**:
```hcl
# vault-config.hcl
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/server.crt"
  tls_key_file  = "/vault/tls/server.key"
}

api_addr = "https://vault.example.com:8200"
cluster_addr = "https://vault-1.internal:8201"

ui = true

# Auto-unseal with AWS KMS
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}

# Telemetry
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
```

**Kubernetes Deployment with Helm**:
```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com

# Install Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3 \
  --set server.ha.raft.enabled=true \
  --set server.auditStorage.enabled=true \
  --set injector.enabled=true
```

### Pattern 3: AppRole Authentication

**When to Use**: Automated systems, CI/CD pipelines

**Implementation**:
```bash
# Enable AppRole auth method
vault auth enable approle

# Create policy
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}
path "database/creds/myapp-db" {
  capabilities = ["read"]
}
EOF

# Create AppRole
vault write auth/approle/role/myapp \
  secret_id_ttl=24h \
  token_ttl=1h \
  token_max_ttl=4h \
  token_policies="myapp-policy"

# Get Role ID (deploy with application)
vault read auth/approle/role/myapp/role-id

# Generate Secret ID (separate channel, rotate frequently)
vault write -f auth/approle/role/myapp/secret-id
```

**Application Authentication**:
```typescript
import Vault from 'node-vault';

class VaultClient {
  private client: any;
  private token: string | null = null;
  private tokenExpiry: Date | null = null;

  constructor() {
    this.client = Vault({
      apiVersion: 'v1',
      endpoint: process.env.VAULT_ADDR
    });
  }

  async authenticate(): Promise<void> {
    // Check if current token is valid
    if (this.token && this.tokenExpiry && this.tokenExpiry > new Date()) {
      return;
    }

    // AppRole login
    const result = await this.client.approleLogin({
      role_id: process.env.VAULT_ROLE_ID,
      secret_id: process.env.VAULT_SECRET_ID
    });

    this.token = result.auth.client_token;
    this.client.token = this.token;

    // Set expiry with buffer
    const ttl = result.auth.lease_duration;
    this.tokenExpiry = new Date(Date.now() + (ttl - 60) * 1000);
  }

  async getSecret(path: string): Promise<Record<string, any>> {
    await this.authenticate();
    const result = await this.client.read(`secret/data/${path}`);
    return result.data.data;
  }
}

// Usage
const vault = new VaultClient();
const dbConfig = await vault.getSecret('myapp/database');
```

### Pattern 4: Kubernetes Authentication

**When to Use**: Applications running in Kubernetes

**Implementation**:
```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for application
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=production \
  policies=myapp-policy \
  ttl=1h
```

**Kubernetes Deployment with Vault Agent Injector**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        # Enable Vault Agent injection
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        # Inject database credentials
        vault.hashicorp.com/agent-inject-secret-db: "secret/data/myapp/database"
        vault.hashicorp.com/agent-inject-template-db: |
          {{- with secret "secret/data/myapp/database" -}}
          export DB_HOST="{{ .Data.data.host }}"
          export DB_USER="{{ .Data.data.username }}"
          export DB_PASS="{{ .Data.data.password }}"
          {{- end -}}
    spec:
      serviceAccountName: myapp
      containers:
        - name: app
          image: myapp:latest
          command: ["/bin/sh", "-c"]
          args: ["source /vault/secrets/db && ./start.sh"]
```

### Pattern 5: Dynamic Database Credentials

**When to Use**: Database access with automatic credential rotation

**Implementation**:
```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-db" \
  connection_url="postgresql://{{username}}:{{password}}@db.example.com:5432/myapp" \
  username="vault-admin" \
  password="admin-password"

# Create role for application
vault write database/roles/myapp-db \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

**Application Usage**:
```typescript
class DynamicDatabaseClient {
  private vault: VaultClient;
  private connectionPool: Pool | null = null;
  private credentialExpiry: Date | null = null;

  constructor(vault: VaultClient) {
    this.vault = vault;
  }

  async getConnection(): Promise<Pool> {
    // Check if credentials need refresh
    if (this.connectionPool && this.credentialExpiry &&
        this.credentialExpiry > new Date(Date.now() + 5 * 60 * 1000)) {
      return this.connectionPool;
    }

    // Get new credentials
    const creds = await this.vault.read('database/creds/myapp-db');

    // Close old pool
    if (this.connectionPool) {
      await this.connectionPool.end();
    }

    // Create new pool with fresh credentials
    this.connectionPool = new Pool({
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      user: creds.data.username,
      password: creds.data.password
    });

    // Set expiry
    this.credentialExpiry = new Date(Date.now() + creds.lease_duration * 1000);

    return this.connectionPool;
  }
}
```

### Pattern 6: Transit Encryption

**When to Use**: Encryption as a service, key management

**Implementation**:
```bash
# Enable transit secrets engine
vault secrets enable transit

# Create encryption key
vault write -f transit/keys/myapp-key \
  type=aes256-gcm96 \
  auto_rotate_period=30d

# Encrypt data
vault write transit/encrypt/myapp-key \
  plaintext=$(echo "sensitive data" | base64)

# Decrypt data
vault write transit/decrypt/myapp-key \
  ciphertext="vault:v1:..."
```

**Application Integration**:
```typescript
class EncryptionService {
  private vault: VaultClient;
  private keyName: string;

  constructor(vault: VaultClient, keyName: string = 'myapp-key') {
    this.vault = vault;
    this.keyName = keyName;
  }

  async encrypt(plaintext: string): Promise<string> {
    const encoded = Buffer.from(plaintext).toString('base64');
    const result = await this.vault.write(`transit/encrypt/${this.keyName}`, {
      plaintext: encoded
    });
    return result.data.ciphertext;
  }

  async decrypt(ciphertext: string): Promise<string> {
    const result = await this.vault.write(`transit/decrypt/${this.keyName}`, {
      ciphertext
    });
    return Buffer.from(result.data.plaintext, 'base64').toString();
  }

  async encryptBatch(items: string[]): Promise<string[]> {
    const batch = items.map(item => ({
      plaintext: Buffer.from(item).toString('base64')
    }));

    const result = await this.vault.write(`transit/encrypt/${this.keyName}`, {
      batch_input: batch
    });

    return result.data.batch_results.map((r: any) => r.ciphertext);
  }
}

// Usage
const encryption = new EncryptionService(vault);
const encrypted = await encryption.encrypt('SSN: 123-45-6789');
const decrypted = await encryption.decrypt(encrypted);
```

## Checklist

- [ ] Vault deployed in HA mode for production
- [ ] Auto-unseal configured (AWS KMS, GCP KMS, etc.)
- [ ] TLS enabled for all Vault communication
- [ ] Audit logging enabled and shipped to SIEM
- [ ] AppRole or Kubernetes auth used (not token auth)
- [ ] Policies follow least privilege principle
- [ ] Secret ID rotation automated
- [ ] Dynamic credentials used where possible
- [ ] Transit engine for application encryption
- [ ] Regular backup and recovery testing

## References

- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Production Hardening](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Vault Agent](https://developer.hashicorp.com/vault/docs/agent)
- [Vault on Kubernetes](https://developer.hashicorp.com/vault/tutorials/kubernetes)
