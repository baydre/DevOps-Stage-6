# GitHub Actions CI/CD Architecture

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          GITHUB REPOSITORY                               │
│                        baydre/DevOps-Stage-6                            │
└────────────────┬────────────────────────────────────────────────────────┘
                 │
                 │ Push/PR to main
                 │
        ┌────────▼─────────┐
        │  GitHub Actions  │
        │   Orchestrator   │
        └────┬────────┬────┘
             │        │
    ┌────────▼───┐   └──────────┐
    │Infrastructure│             │
    │  Workflow    │             │
    └────┬─────────┘             │
         │                       │
    ┌────▼────────────────┐     │
    │  1. terraform-plan  │     │
    │  ─────────────────  │     │
    │  • Checkout code    │     │
    │  • Setup Terraform  │     │
    │  • Configure AWS    │     │
    │  • terraform init   │     │
    │  • terraform validate│     │
    │  • terraform plan   │     │
    │  • Check changes    │     │
    └────┬────────────────┘     │
         │                       │
         │ If changes detected   │
         │                       │
    ┌────▼─────────────────┐    │
    │  2. terraform-apply   │    │
    │  ─────────────────   │    │
    │  • Manual approval   │    │
    │  • terraform apply   │    │
    │  • Get instance IP   │    │
    │  • Setup SSH         │    │
    │  • Wait for instance │    │
    │  • Run Ansible       │    │
    │  • Verify deployment │    │
    └────┬─────────────────┘    │
         │                       │
         │ Deployment done       │
         │                       │
    ┌────▼──────────────────┐   │
    │   AWS Infrastructure  │   │
    │  ──────────────────── │   │
    │  • VPC (10.0.0.0/16)  │   │
    │  • Public Subnet      │   │
    │  • Internet Gateway   │   │
    │  • Security Group     │   │
    │  • EC2 Instance       │◄──┼─────────────┐
    │  • S3 (TF State)      │   │             │
    │  • DynamoDB (Lock)    │   │             │
    │  • Lambda (Drift)     │   │             │
    └───────────────────────┘   │             │
                                │             │
                   ┌────────────▼──────────┐  │
                   │  Application          │  │
                   │  Workflow             │  │
                   └────┬──────────────────┘  │
                        │                     │
                   ┌────▼─────────────────┐  │
                   │ 1. check-infra       │  │
                   │ ──────────────────   │  │
                   │ • Configure AWS      │  │
                   │ • Query EC2          │  │
                   │ • Get instance IP    │  │
                   └────┬─────────────────┘  │
                        │                     │
                        │ If instance exists  │
                        │                     │
                   ┌────▼──────────────────┐ │
                   │ 2. deploy-application │ │
                   │ ──────────────────    │ │
                   │ • Setup SSH           │ │
                   │ • Git pull on server  │─┤
                   │ • docker-compose down │ │
                   │ • docker-compose up   │ │
                   │ • Health checks       │ │
                   └────┬──────────────────┘ │
                        │                     │
                        │ If deployment fails │
                        │                     │
                   ┌────▼───────────────┐    │
                   │ 3. rollback        │    │
                   │ ────────────────   │    │
                   │ • SSH to server    │    │
                   │ • git reset HEAD~1 │────┘
                   │ • restart containers│
                   └────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                     APPLICATION STACK ON EC2                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │                      TRAEFIK (Reverse Proxy)                  │      │
│  │  Ports: 80 (HTTP), 443 (HTTPS), 8080 (Dashboard)            │      │
│  └──────────────────┬───────────────────────────────────────────┘      │
│                     │                                                   │
│     ┌───────────────┼───────────────────────────────┐                  │
│     │               │                               │                  │
│  ┌──▼───────┐  ┌───▼──────┐  ┌──────────┐  ┌──────▼──────┐          │
│  │ Frontend │  │ Auth API │  │ Todos API│  │  Users API  │          │
│  │  (Vue)   │  │   (Go)   │  │  (Node)  │  │   (Java)    │          │
│  └──────────┘  └──────────┘  └──────────┘  └─────────────┘          │
│                                     │                                   │
│                                ┌────▼─────┐                            │
│                                │  Redis   │                            │
│                                └──────────┘                            │
│                                     │                                   │
│                          ┌──────────▼───────────┐                      │
│                          │ Log Message Processor│                      │
│                          │      (Python)        │                      │
│                          └──────────────────────┘                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                       DEPLOYMENT FLOW                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Developer Push                                                          │
│       │                                                                  │
│       ├─► infra/terraform/** ──► Infrastructure Workflow                │
│       │                           │                                      │
│       │                           ├─► terraform plan                     │
│       │                           │   └─► No changes? DONE               │
│       │                           │   └─► Changes? ──► Manual Approval   │
│       │                           │                     │                │
│       │                           └─► terraform apply ◄─┘                │
│       │                               └─► Ansible deploy                 │
│       │                                   └─► Health check               │
│       │                                                                  │
│       └─► auth-api/**          ──► Application Workflow                 │
│           frontend/**              │                                     │
│           todos-api/**             ├─► Check infrastructure exists       │
│           users-api/**             │   └─► No? FAIL                      │
│           docker-compose.yml       │   └─► Yes? ──► Deploy               │
│                                    │                 │                   │
│                                    └─► Git pull ─────┤                   │
│                                        Restart       │                   │
│                                        Health check  │                   │
│                                                      │                   │
│                                        Success? ─────┘                   │
│                                        │                                 │
│                                        └─► Fail? ──► Automatic Rollback  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                     MONITORING & MAINTENANCE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────┐                                                     │
│  │ Drift Detection│                                                     │
│  │  (Scheduled)   │                                                     │
│  └────────┬───────┘                                                     │
│           │                                                              │
│           ├─► terraform plan -detailed-exitcode                         │
│           │                                                              │
│           ├─► Exit 0: No drift ✓                                        │
│           ├─► Exit 2: Drift detected! ✗                                 │
│           └─► Notify team                                               │
│                                                                          │
│  ┌──────────────────┐                                                   │
│  │  CloudWatch      │                                                   │
│  │  Lambda Function │                                                   │
│  └─────────┬────────┘                                                   │
│            │                                                             │
│            └─► Scheduled drift checks                                   │
│                └─► SNS notifications                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                        SECURITY LAYERS                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─ GitHub Secrets (Encrypted) ──────────────────────────────────┐     │
│  │  • AWS_ACCESS_KEY_ID                                           │     │
│  │  • AWS_SECRET_ACCESS_KEY                                       │     │
│  │  • SSH_PRIVATE_KEY                                             │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                          │
│  ┌─ AWS Security ──────────────────────────────────────────────────┐   │
│  │  • IAM policies (least privilege)                              │   │
│  │  • Security Groups (ports 22, 80, 443, 8080)                   │   │
│  │  • VPC isolation                                               │   │
│  │  • S3 encryption at rest                                       │   │
│  │  • DynamoDB state locking                                      │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─ Application Security ──────────────────────────────────────────┐   │
│  │  • JWT authentication (Auth API)                               │   │
│  │  • Docker container isolation                                  │   │
│  │  • Traefik as security gateway                                 │   │
│  │  • Environment variable secrets                                │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Infrastructure Workflow
- **Trigger:** Changes to `infra/terraform/**` or `infra/ansible/**`
- **Purpose:** Provision and configure AWS infrastructure
- **Tools:** Terraform, Ansible, AWS CLI

### 2. Application Workflow
- **Trigger:** Changes to application code or `docker-compose.yml`
- **Purpose:** Deploy application updates
- **Tools:** Docker Compose, SSH, Git

### 3. Drift Detection
- **Trigger:** Scheduled (cron) or manual
- **Purpose:** Detect unauthorized infrastructure changes
- **Tools:** Terraform, Lambda, CloudWatch, SNS

## Deployment Stages

1. **Code Push** → GitHub receives changes
2. **Workflow Trigger** → GitHub Actions starts appropriate workflow
3. **Validation** → Syntax checks, plan generation
4. **Approval** → Manual review for infrastructure changes
5. **Execution** → Terraform/Ansible or Docker deployment
6. **Verification** → Health checks and smoke tests
7. **Notification** → Status updates and alerts

## State Management

- **Terraform State:** S3 bucket with versioning
- **State Locking:** DynamoDB table
- **Inventory:** Dynamically generated from Terraform outputs
- **Secrets:** GitHub Secrets (encrypted at rest)

## Rollback Strategy

- **Infrastructure:** Terraform state rollback + re-apply
- **Application:** Git reset to previous commit + restart
- **Automatic:** Triggers on failed health checks
- **Manual:** SSH access for emergency fixes
