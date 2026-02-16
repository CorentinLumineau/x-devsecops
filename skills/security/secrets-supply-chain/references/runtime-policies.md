---
title: Container Runtime Security Reference
category: security
type: reference
version: "1.0.0"
---

# Container Runtime Security Policies

> Part of the security/container-security knowledge skill

## Overview

Runtime security monitors container behavior and enforces policies during execution. This reference covers Falco rules, seccomp profiles, AppArmor policies, and runtime threat detection patterns.

## 80/20 Quick Reference

**Runtime security layers:**

| Layer | Tool | Protects Against |
|-------|------|------------------|
| Syscall filtering | Seccomp | Kernel exploits |
| MAC | AppArmor/SELinux | File/network access |
| Behavioral | Falco | Anomalous behavior |
| Network | Cilium/Calico | Lateral movement |

**High-value detections:**
- Shell spawned in container
- Binary modification
- Sensitive file access
- Network connection to unusual destination
- Privilege escalation attempts

## Patterns

### Pattern 1: Falco Rules

**When to Use**: Runtime threat detection

**Implementation**:
```yaml
# Custom Falco rules
- rule: Shell Spawned in Container
  desc: Detect shell execution in a container
  condition: >
    spawned_process
    and container
    and shell_procs
    and not user_known_shell_spawn_container
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, shell]

- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: >
    open_read
    and container
    and sensitive_files
    and not user_known_sensitive_file_access
  output: >
    Sensitive file opened for reading
    (user=%user.name file=%fd.name
    container=%container.name image=%container.image.repository)
  priority: WARNING
  tags: [container, filesystem]

- rule: Package Management in Container
  desc: Detect package management commands in container
  condition: >
    spawned_process
    and container
    and package_mgmt_procs
    and not user_known_package_manager_in_container
  output: >
    Package management in container
    (user=%user.name command=%proc.cmdline
    container=%container.name image=%container.image.repository)
  priority: ERROR
  tags: [container, package_management]

- rule: Container Drift Detected
  desc: Executable written or modified in container
  condition: >
    container
    and open_write
    and (fd.filename endswith ".sh"
         or fd.filename endswith ".py"
         or fd.filename contains "/bin/"
         or fd.filename contains "/sbin/")
  output: >
    Drift detected - executable modified in container
    (file=%fd.name container=%container.name image=%container.image.repository)
  priority: ERROR
  tags: [container, drift]

- rule: Outbound Connection to Unusual Port
  desc: Detect outbound connections to unusual ports
  condition: >
    outbound
    and container
    and not (fd.sport in (80, 443, 8080, 8443, 5432, 3306, 6379))
  output: >
    Outbound connection to unusual port
    (container=%container.name destination=%fd.sip:%fd.sport
    image=%container.image.repository)
  priority: NOTICE
  tags: [container, network]

# Macros for rule conditions
- macro: shell_procs
  condition: (proc.name in (bash, sh, zsh, dash, ash, csh, tcsh, ksh))

- macro: package_mgmt_procs
  condition: (proc.name in (apt, apt-get, yum, dnf, apk, pip, npm, gem))

- macro: sensitive_files
  condition: >
    (fd.name startswith /etc/shadow or
     fd.name startswith /etc/passwd or
     fd.name startswith /etc/kubernetes/ or
     fd.name startswith /var/run/secrets/)

# Allow lists
- list: user_known_shell_spawn_container
  items: []

- list: user_known_sensitive_file_access
  items: []
```

**Falco deployment**:
```yaml
# Helm values for Falco
falco:
  jsonOutput: true
  jsonIncludeOutputProperty: true

  # Alerting
  httpOutput:
    enabled: true
    url: "http://falco-sidekick:2801"

  # Custom rules
  rulesFile:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/custom_rules.yaml

falcosidekick:
  enabled: true
  config:
    slack:
      webhookurl: "https://hooks.slack.com/services/xxx"
      minimumpriority: "warning"
    elasticsearch:
      hostport: "https://elasticsearch:9200"
      minimumpriority: "notice"
```

### Pattern 2: Seccomp Profiles

**When to Use**: Restricting system calls

**Implementation**:
```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_AARCH64"],
  "syscalls": [
    {
      "names": [
        "accept4", "access", "arch_prctl", "bind", "brk",
        "capget", "capset", "chdir", "clone", "close",
        "connect", "dup", "dup2", "epoll_create1", "epoll_ctl",
        "epoll_pwait", "execve", "exit", "exit_group", "faccessat",
        "fchown", "fcntl", "fstat", "fstatfs", "futex",
        "getcwd", "getdents64", "getegid", "geteuid", "getgid",
        "getpeername", "getpid", "getppid", "getrandom", "getsockname",
        "getsockopt", "getuid", "ioctl", "listen", "lseek",
        "madvise", "memfd_create", "mmap", "mprotect", "munmap",
        "nanosleep", "newfstatat", "openat", "pipe2", "poll",
        "prctl", "pread64", "prlimit64", "pwrite64", "read",
        "readlink", "recvfrom", "recvmsg", "rt_sigaction",
        "rt_sigprocmask", "rt_sigreturn", "sched_getaffinity",
        "sched_yield", "sendmsg", "sendto", "set_robust_list",
        "set_tid_address", "setgid", "setsockopt", "setuid",
        "sigaltstack", "socket", "stat", "statfs", "tgkill",
        "uname", "unlink", "wait4", "write", "writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    },
    {
      "names": ["clone"],
      "action": "SCMP_ACT_ALLOW",
      "args": [
        {
          "index": 0,
          "value": 2114060288,
          "op": "SCMP_CMP_MASKED_EQ"
        }
      ]
    }
  ]
}
```

**Using in Kubernetes**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  annotations:
    seccomp.security.alpha.kubernetes.io/pod: "localhost/custom-profile.json"
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom-profile.json
  containers:
    - name: app
      image: myapp:latest
```

**RuntimeDefault (recommended minimum)**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
```

### Pattern 3: AppArmor Profiles

**When to Use**: Mandatory access control for file and network

**Implementation**:
```
# /etc/apparmor.d/containers/myapp
#include <tunables/global>

profile myapp flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Network access
  network inet stream,
  network inet6 stream,

  # Allow reading application files
  /app/** r,
  /app/node_modules/** r,

  # Allow writing to specific directories only
  /tmp/** rw,
  /app/logs/** rw,

  # Deny write to sensitive locations
  deny /etc/** w,
  deny /usr/** w,
  deny /bin/** w,
  deny /sbin/** w,

  # Deny shell execution
  deny /bin/sh x,
  deny /bin/bash x,
  deny /bin/dash x,

  # Deny network tools
  deny /usr/bin/curl x,
  deny /usr/bin/wget x,
  deny /usr/bin/nc x,

  # Allow specific capabilities
  capability net_bind_service,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_ptrace,
  deny capability sys_module,
}
```

**Load and use profile**:
```bash
# Load profile
apparmor_parser -r /etc/apparmor.d/containers/myapp

# Verify
aa-status | grep myapp
```

```yaml
# Kubernetes pod with AppArmor
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: localhost/myapp
spec:
  containers:
    - name: app
      image: myapp:latest
```

### Pattern 4: Runtime Network Policies

**When to Use**: Dynamic network security

**Implementation**:
```yaml
# Cilium Network Policy with L7 filtering
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/public/.*"
              - method: "POST"
                path: "/api/public/.*"
                headers:
                  - 'Content-Type: application/json'
  egress:
    - toEndpoints:
        - matchLabels:
            app: database
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
    - toFQDNs:
        - matchName: "api.external-service.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

**Calico with threat feeds**:
```yaml
# Block known malicious IPs
apiVersion: projectcalico.org/v3
kind: GlobalThreatFeed
metadata:
  name: malicious-ips
spec:
  content: IPSet
  mode: Enabled
  description: "Known malicious IPs"
  feedType: Builtin
  globalNetworkSet:
    labels:
      threat-feed: malicious
---
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: block-malicious
spec:
  selector: all()
  types:
    - Egress
  egress:
    - action: Deny
      destination:
        selector: threat-feed == "malicious"
```

### Pattern 5: Runtime Anomaly Detection

**When to Use**: ML-based behavioral monitoring

**Implementation**:
```yaml
# Sysdig Secure runtime policy
apiVersion: v1
kind: Policy
metadata:
  name: production-runtime
spec:
  rules:
    - name: Container Drift
      description: Detect modification of executables
      condition:
        condition_type: container_drift
        condition_params:
          allow_list: []
      actions:
        - type: kill
        - type: alert
          params:
            severity: critical

    - name: Crypto Mining Detection
      description: Detect cryptocurrency mining
      condition:
        condition_type: process
        condition_params:
          process_names:
            - xmrig
            - minerd
            - cgminer
          parent_process_names: []
      actions:
        - type: kill
        - type: alert

    - name: Reverse Shell
      description: Detect reverse shell attempts
      condition:
        condition_type: command_contains
        condition_params:
          commands:
            - "bash -i"
            - "/dev/tcp/"
            - "nc -e"
            - "python -c 'import socket'"
      actions:
        - type: kill
        - type: alert
          params:
            severity: critical
```

### Pattern 6: Response Automation

**When to Use**: Automated incident response

**Implementation**:
```typescript
// Automated response to Falco alerts
interface FalcoAlert {
  rule: string;
  priority: string;
  output: string;
  outputFields: {
    'container.id': string;
    'container.name': string;
    'k8s.pod.name': string;
    'k8s.ns.name': string;
  };
}

class RuntimeResponseHandler {
  async handleAlert(alert: FalcoAlert): Promise<void> {
    switch (alert.priority) {
      case 'Critical':
        await this.criticalResponse(alert);
        break;
      case 'Error':
        await this.errorResponse(alert);
        break;
      default:
        await this.logAndNotify(alert);
    }
  }

  private async criticalResponse(alert: FalcoAlert): Promise<void> {
    const { 'k8s.pod.name': podName, 'k8s.ns.name': namespace } = alert.outputFields;

    // Isolate pod by adding network policy
    await this.isolatePod(namespace, podName);

    // Capture forensic data
    await this.captureForensics(namespace, podName);

    // Scale down to contain
    await this.scalePodDown(namespace, podName);

    // Alert security team
    await this.alertSecurityTeam(alert);
  }

  private async isolatePod(namespace: string, podName: string): Promise<void> {
    const networkPolicy = {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: {
        name: `isolate-${podName}`,
        namespace
      },
      spec: {
        podSelector: {
          matchLabels: {
            'app.kubernetes.io/instance': podName
          }
        },
        policyTypes: ['Ingress', 'Egress']
        // Empty ingress/egress = deny all
      }
    };

    await k8s.createNamespacedNetworkPolicy(namespace, networkPolicy);
  }

  private async captureForensics(namespace: string, podName: string): Promise<void> {
    // Capture process list
    await k8s.exec(namespace, podName, 'ps aux');

    // Capture network connections
    await k8s.exec(namespace, podName, 'netstat -tulpn');

    // Save to incident storage
  }
}
```

## Checklist

- [ ] Falco deployed with custom rules
- [ ] Seccomp profile applied (minimum: RuntimeDefault)
- [ ] AppArmor/SELinux profiles for sensitive workloads
- [ ] Network policies enforce microsegmentation
- [ ] Alert routing configured (Slack, PagerDuty)
- [ ] Automated response for critical alerts
- [ ] Forensic data capture automated
- [ ] Regular rule tuning to reduce noise
- [ ] Incident response playbooks documented
- [ ] Runtime security testing in CI/CD

## References

- [Falco Documentation](https://falco.org/docs/)
- [Seccomp Security Profiles](https://kubernetes.io/docs/tutorials/security/seccomp/)
- [AppArmor for Containers](https://kubernetes.io/docs/tutorials/security/apparmor/)
- [Cilium Network Policies](https://docs.cilium.io/en/stable/security/)
