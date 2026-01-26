---
title: Terraform Reference
category: delivery
type: reference
version: "1.0.0"
---

# Terraform

> Part of the delivery/infrastructure knowledge skill

## Overview

Terraform enables Infrastructure as Code (IaC) for provisioning and managing cloud resources. This reference covers best practices for modules, state management, and production-grade configurations.

## Quick Reference (80/20)

| Concept | Purpose |
|---------|---------|
| Provider | Interface to cloud APIs |
| Resource | Infrastructure component |
| Module | Reusable configuration |
| State | Tracks managed resources |
| Workspace | Isolated state environments |
| Backend | Remote state storage |

## Patterns

### Pattern 1: Project Structure

**When to Use**: Organizing Terraform configurations

**Example**:
```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── eks/
│   │   └── ...
│   └── rds/
│       └── ...
└── shared/
    ├── providers.tf
    └── versions.tf
```

```hcl
# environments/prod/main.tf
terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name             = "${var.project_name}-${var.environment}"
  cidr             = var.vpc_cidr
  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = false  # HA in production
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  node_groups = var.eks_node_groups
}
```

**Anti-Pattern**: Single flat directory with all resources.

### Pattern 2: Reusable Modules

**When to Use**: Standardizing infrastructure patterns

**Example**:
```hcl
# modules/rds/variables.tf
variable "identifier" {
  description = "Database identifier"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Instance type"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Storage in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DB subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access the database"
  type        = list(string)
  default     = []
}

# modules/rds/main.tf
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.identifier}-sg"
  }
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  multi_az               = var.multi_az
  publicly_accessible    = false

  username = var.master_username
  password = var.master_password

  backup_retention_period = var.multi_az ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = var.multi_az
  skip_final_snapshot = !var.multi_az

  performance_insights_enabled = var.multi_az

  tags = {
    Name = var.identifier
  }

  lifecycle {
    prevent_destroy = false
  }
}

# modules/rds/outputs.tf
output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

locals {
  port = var.engine == "postgres" ? 5432 : 3306
}
```

**Anti-Pattern**: Copy-pasting resource blocks instead of using modules.

### Pattern 3: State Management

**When to Use**: Managing Terraform state securely

**Example**:
```hcl
# Remote state backend configuration
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"

    # Assume role for state access
    role_arn = "arn:aws:iam::123456789:role/TerraformStateAccess"
  }
}

# State locking table
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Locks"
  }
}

# Reading remote state from other configurations
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "company-terraform-state"
    key    = "prod/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs from remote state
resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
}
```

```bash
# State management commands

# Import existing resource
terraform import aws_instance.web i-1234567890abcdef0

# Move resource between modules
terraform state mv module.old.aws_instance.web module.new.aws_instance.web

# Remove resource from state (keep in cloud)
terraform state rm aws_instance.web

# List resources in state
terraform state list

# Show specific resource state
terraform state show aws_instance.web

# Force unlock state (use carefully)
terraform force-unlock LOCK_ID
```

**Anti-Pattern**: Local state files or state without locking.

### Pattern 4: Variables and Validation

**When to Use**: Input validation and type safety

**Example**:
```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}

  validation {
    condition     = !contains(keys(var.tags), "Name")
    error_message = "Name tag is set automatically, do not include."
  }
}

# Complex variable types
variable "node_groups" {
  description = "EKS node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 50)
    labels         = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.node_groups : v.min_size <= v.desired_size && v.desired_size <= v.max_size
    ])
    error_message = "Node group sizes must satisfy: min_size <= desired_size <= max_size."
  }
}

# Local values for computed configuration
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  is_production = var.environment == "prod"

  instance_type = local.is_production ? "t3.large" : "t3.small"
}
```

**Anti-Pattern**: No input validation, runtime errors.

### Pattern 5: Sensitive Data Handling

**When to Use**: Managing secrets in Terraform

**Example**:
```hcl
# Mark variables as sensitive
variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# Sensitive outputs
output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

# Generate random passwords
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}/database/credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
  })
}

# Read existing secret
data "aws_secretsmanager_secret_version" "existing" {
  secret_id = "existing-secret-name"
}

locals {
  existing_creds = jsondecode(data.aws_secretsmanager_secret_version.existing.secret_string)
}

# Vault provider for secrets
provider "vault" {
  address = "https://vault.example.com"
}

data "vault_generic_secret" "db" {
  path = "secret/database/prod"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
}
```

**Anti-Pattern**: Hardcoding secrets or storing in state unencrypted.

### Pattern 6: CI/CD Integration

**When to Use**: Automated Terraform pipelines

**Example**:
```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'

env:
  TF_VERSION: '1.6.0'
  AWS_REGION: 'us-east-1'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        working-directory: terraform/environments/prod
        run: terraform init -backend=false

      - name: Terraform Validate
        working-directory: terraform/environments/prod
        run: terraform validate

  plan:
    needs: validate
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: terraform/environments/prod
        run: terraform init

      - name: Terraform Plan
        id: plan
        working-directory: terraform/environments/prod
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📖
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: terraform/environments/prod/tfplan

  apply:
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: terraform/environments/prod

      - name: Terraform Init
        working-directory: terraform/environments/prod
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform/environments/prod
        run: terraform apply -auto-approve tfplan
```

**Anti-Pattern**: Manual applies without review.

## Checklist

- [ ] Remote state with locking configured
- [ ] Modules used for reusable components
- [ ] Variables validated with conditions
- [ ] Sensitive values marked and encrypted
- [ ] Environment-specific configurations
- [ ] CI/CD pipeline with plan review
- [ ] Terraform version pinned
- [ ] Provider versions pinned
- [ ] Documentation for modules
- [ ] State backup configured

## References

- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Module Registry](https://registry.terraform.io/)
