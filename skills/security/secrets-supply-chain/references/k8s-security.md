---
title: Kubernetes Security Reference
category: security
type: reference
version: "1.0.0"
---

# Kubernetes Security Best Practices

> Part of the security/container-security knowledge skill

## Overview

Kubernetes security spans cluster configuration, workload hardening, network policies, and secrets management. This reference covers critical security controls following the principle of defense in depth.

## 80/20 Quick Reference

**Security priorities (highest impact):**

| Priority | Control | Risk Mitigated |
|----------|---------|----------------|
| 1 | Pod Security Standards | Privilege escalation |
| 2 | Network Policies | Lateral movement |
| 3 | RBAC | Unauthorized access |
| 4 | Secrets encryption | Data exposure |
| 5 | Image scanning | Vulnerable workloads |

## Patterns

### Pattern 1: Pod Security Standards

**When to Use**: All workloads

**Implementation**:
```yaml
# Namespace with restricted pod security
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
# Compliant deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      # Non-root user
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
        - name: app
          image: myregistry/app:v1.2.3@sha256:abc123...  # Use digest
          imagePullPolicy: Always

          # Container security context
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          # Resource limits (prevent DoS)
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"

          # Health checks
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10

          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5

          # Writable directories via emptyDir
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache

      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}

      # Service account with minimal permissions
      serviceAccountName: app-sa
      automountServiceAccountToken: false
```

**Anti-Pattern**: Privileged containers
```yaml
# NEVER do this in production
securityContext:
  privileged: true  # Full host access
  runAsUser: 0      # Running as root
```

### Pattern 2: Network Policies

**When to Use**: All clusters to implement microsegmentation

**Implementation**:
```yaml
# Default deny all ingress and egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Applies to all pods
  policyTypes:
    - Ingress
    - Egress
---
# Allow specific ingress to web app
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        # From ingress controller namespace
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
---
# Allow app to database egress only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
    - Egress
  egress:
    # To database
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
    # DNS resolution
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

### Pattern 3: RBAC Configuration

**When to Use**: All clusters for access control

**Implementation**:
```yaml
# Service account for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["app-config"]  # Specific resources
    verbs: ["get", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["app-secrets"]
    verbs: ["get"]
---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-role-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: production
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
---
# Developer access (read-only to production)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-readonly
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
---
# Bind to developer group
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-readonly
subjects:
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: developer-readonly
  apiGroup: rbac.authorization.k8s.io
```

### Pattern 4: Secrets Management

**When to Use**: Protecting sensitive configuration

**Implementation**:
```yaml
# External Secrets Operator with HashiCorp Vault
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app-role"
          serviceAccountRef:
            name: "app-sa"
---
# External Secret that syncs from Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: myapp/database
        property: username
    - secretKey: password
      remoteRef:
        key: myapp/database
        property: password
---
# Use in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: password
```

**Sealed Secrets for GitOps**:
```bash
# Encrypt secret for GitOps
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
```

```yaml
# Sealed Secret (safe to commit to git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  encryptedData:
    username: AgA1234...encrypted...
    password: AgB5678...encrypted...
```

### Pattern 5: Admission Controllers

**When to Use**: Enforcing policies at deployment time

**Implementation**:
```yaml
# Kyverno policy - require labels
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-labels
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Labels 'app' and 'owner' are required"
        pattern:
          metadata:
            labels:
              app: "?*"
              owner: "?*"
---
# Kyverno policy - disallow privileged containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  rules:
    - name: deny-privileged
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "false"
---
# Kyverno policy - require image digest
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digest
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-digest
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Images must use digest (sha256:...)"
        pattern:
          spec:
            containers:
              - image: "*@sha256:*"
```

### Pattern 6: Audit Logging

**When to Use**: Compliance and incident investigation

**Implementation**:
```yaml
# Audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all requests to secrets
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]

  # Log all authentication decisions
  - level: Metadata
    users: ["system:anonymous"]
    verbs: ["get", "list", "watch"]

  # Log all changes to RBAC
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

  # Log all privileged pod creations
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods"]
    verbs: ["create", "update", "patch"]

  # Don't log reads of configmaps in kube-system
  - level: None
    resources:
      - group: ""
        resources: ["configmaps"]
    namespaces: ["kube-system"]
    verbs: ["get", "list", "watch"]

  # Default: log metadata for everything else
  - level: Metadata
    omitStages:
      - RequestReceived
```

## Checklist

- [ ] Pod Security Standards enforced at namespace level
- [ ] Network policies implement default deny
- [ ] RBAC follows least privilege principle
- [ ] Service accounts have minimal permissions
- [ ] Secrets encrypted at rest (etcd encryption)
- [ ] External secrets manager integrated
- [ ] Image scanning in CI/CD pipeline
- [ ] Images use digests, not tags
- [ ] Admission controllers enforce policies
- [ ] Audit logging enabled and shipped to SIEM
- [ ] Resource quotas prevent DoS
- [ ] Regular CIS benchmark scans

## References

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
