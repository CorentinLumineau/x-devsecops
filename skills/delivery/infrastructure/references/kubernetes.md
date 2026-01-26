---
title: Kubernetes Reference
category: delivery
type: reference
version: "1.0.0"
---

# Kubernetes

> Part of the delivery/infrastructure knowledge skill

## Overview

Kubernetes orchestrates containerized applications across clusters. This reference covers deployment patterns, resource management, and production best practices.

## Quick Reference (80/20)

| Resource | Purpose |
|----------|---------|
| Deployment | Manage stateless apps |
| StatefulSet | Manage stateful apps |
| Service | Network access to pods |
| ConfigMap | Configuration data |
| Secret | Sensitive data |
| Ingress | External HTTP access |

## Patterns

### Pattern 1: Production Deployment

**When to Use**: Deploying production applications

**Example**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: api
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000

      containers:
        - name: api
          image: myapp/api:1.2.3
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: api-secrets
                  key: database-url

          envFrom:
            - configMapRef:
                name: api-config

          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"

          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3

          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3

          startupProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 30

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache

      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir:
            sizeLimit: 100Mi

      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: api
                topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: api

      terminationGracePeriodSeconds: 30
```

**Anti-Pattern**: Missing resource limits and health checks.

### Pattern 2: Service and Ingress

**When to Use**: Exposing applications

**Example**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  labels:
    app: api
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  name: http
---
# Internal service for service mesh
apiVersion: v1
kind: Service
metadata:
  name: api-internal
  labels:
    app: api
spec:
  type: ClusterIP
  clusterIP: None  # Headless service
  selector:
    app: api
  ports:
    - name: grpc
      port: 9090
      targetPort: grpc
```

**Anti-Pattern**: Exposing services directly without ingress controller.

### Pattern 3: Configuration Management

**When to Use**: Managing application configuration

**Example**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  LOG_LEVEL: "info"
  LOG_FORMAT: "json"
  CACHE_TTL: "300"
  FEATURE_FLAGS: |
    {
      "newUI": true,
      "betaFeatures": false
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
type: Opaque
stringData:
  database-url: "postgres://user:pass@db:5432/app"
  api-key: "super-secret-key"
---
# External secrets with External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-external-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: api-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: prod/api/database
        property: url
    - secretKey: api-key
      remoteRef:
        key: prod/api/credentials
        property: api-key
---
# Sealed secrets for GitOps
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: api-sealed-secrets
spec:
  encryptedData:
    database-url: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq...
  template:
    metadata:
      name: api-secrets
```

**Anti-Pattern**: Hardcoding secrets in manifests.

### Pattern 4: Horizontal Pod Autoscaler

**When to Use**: Auto-scaling based on metrics

**Example**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 3
  maxReplicas: 20

  metrics:
    # CPU-based scaling
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # Memory-based scaling
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    # Custom metrics (Prometheus)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"

    # External metrics
    - type: External
      external:
        metric:
          name: sqs_queue_length
          selector:
            matchLabels:
              queue: orders
        target:
          type: AverageValue
          averageValue: "30"

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
        - type: Pods
          value: 4
          periodSeconds: 60
      selectPolicy: Max

    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 60
      selectPolicy: Min
---
# Vertical Pod Autoscaler
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  updatePolicy:
    updateMode: Auto
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 2Gi
```

**Anti-Pattern**: Fixed replicas without autoscaling.

### Pattern 5: Network Policies

**When to Use**: Securing pod-to-pod communication

**Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080

    # Allow from other services in same namespace
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080

    # Allow Prometheus scraping
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
        - podSelector:
            matchLabels:
              app: prometheus
      ports:
        - protocol: TCP
          port: 8080

  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53

    # Allow database access
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432

    # Allow external HTTPS
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
---
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

**Anti-Pattern**: No network policies, all pods can communicate.

### Pattern 6: Pod Disruption Budget

**When to Use**: Ensuring availability during disruptions

**Example**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  selector:
    matchLabels:
      app: api
  # At least 2 pods must be available
  minAvailable: 2
  # OR max 1 pod can be unavailable
  # maxUnavailable: 1
---
# For stateful workloads
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgres-pdb
spec:
  selector:
    matchLabels:
      app: postgres
  maxUnavailable: 0  # No disruption allowed
---
# Percentage-based
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: workers-pdb
spec:
  selector:
    matchLabels:
      app: workers
  minAvailable: 80%
```

**Anti-Pattern**: No PDB during node maintenance.

## Checklist

- [ ] Resource requests and limits set
- [ ] Liveness and readiness probes configured
- [ ] Pod anti-affinity for high availability
- [ ] Network policies restrict traffic
- [ ] Secrets not stored in plain text
- [ ] HPA configured for autoscaling
- [ ] PDB prevents mass pod eviction
- [ ] Security context restricts privileges
- [ ] Service accounts with minimal permissions
- [ ] Ingress with TLS configured

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Production Best Practices](https://learnk8s.io/production-best-practices)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Kubernetes Patterns](https://k8spatterns.io/)
