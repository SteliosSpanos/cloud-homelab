# AWS Homelab Infrastructure with Terraform

## Overview

Secure, cost-optimized AWS environment built with Terraform. The architecture includes a bastion host (jump box) for SSH access, a NAT instance instead of NAT Gateway for cost savings, a containerized FastAPI web app with a PostgreSQL RDS database, and defense-in-depth security with Security Groups and NACLs. Centralized logging is handled via CloudWatch Logs, with S3 storage for Terraform state.

**Stack:** Terraform · VPC (1 public + 2 private subnets) · 4 EC2 instances (Amazon Linux 2023) · RDS (PostgreSQL) · S3 (encrypted, versioned) · VPC Gateway Endpoint (S3) · Security Groups + NACLs · IAM least-privilege roles · KMS (encryption for EBS, S3, RDS, and CloudWatch) · CloudWatch Logs · Docker Compose (local dev)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                      INTERNET                                        │
└───────────┬────────────────────────────┬─────────────────────────────────┬───────────┘
            │                            │                                 │
     HTTP/S (Port 80/443)          SSH (Port 22)                     ICMP (ping)
        from ANYWHERE              only from my IP                   only from my IP
            │                            │                                 │
            ▼                            ▼                                 ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               VPC (10.0.0.0/16)                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         PUBLIC SUBNET (10.0.1.0/24)                            │  │
│  │                                                                                │  │
│  │  ┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐    │  │
│  │  │    JUMP BOX      │       │   NAT INSTANCE   │       │     WEB APP      │    │  │
│  │  │   (t3.micro)     │       │   (t3.micro)     │       │    (t3.micro)    │    │  │
│  │  │                  │       │                  │       │                  │    │  │
│  │  │ ┌──────────────┐ │       │ ┌──────────────┐ │       │ ┌──────────────┐ │    │  │
│  │  │ │Security Group│ │       │ │Security Group│ │       │ │Security Group│ │    │  │
│  │  │ │- SSH from IP │ │       │ │- HTTP/S from │ │       │ │- HTTP/S from │ │    │  │
│  │  │ └──────────────┘ │       │ │  private sub │ │       │ │  ANYWHERE    │ │    │  │
│  │  │                  │       │ │- SSH from JB │ │       │ │- SSH from JB │ │    │  │
│  │  │ Elastic IP ──────┼──►    │ └──────────────┘ │       │ └──────────────┘ │    │  │
│  │  │                  │       │                  │       │                  │    │  │
│  │  │ IAM Role:        │       │ Elastic IP ──────┼──►    │ Elastic IP ──────┼──► │  │
│  │  │ - CloudWatch     │       │                  │       │                  │    │  │
│  │  │ - KMS Usage      │       │ IAM Role:        │       │ IAM Role:        │    │  │
│  │  └──────────────────┘       │ - CloudWatch     │       │ - Secrets Mgr    │    │  │
│  │           │                 │ - KMS Usage      │       │ - CloudWatch     │    │  │
│  │           │ SSH             └────────┬─────────┘       └────────┬─────────┘    │  │
│  │           │ ProxyJump                │                          │              │  │
│  └───────────┼──────────────────────────┼──────────────────────────┼──────────────┘  │
│              │                          │ Outbound via NAT         │                 │
│              │       ┌──────────────────┘                          │                 │
│              │       ▼                                             │                 │
│  ┌───────────┼─────────────────────────────────────────────────────┼───────────────┐ │
│  │           │       PRIVATE SUBNET 1 (10.0.2.0/24)                │               │ │
│  │           │                                                     │               │ │
│  │           ▼                                                     ▼               │ │
│  │  ┌──────────────────┐                          ┌───────────────────────┐        │ │
│  │  │     MAIN VM      │                          │     RDS DATABASE      │        │ │
│  │  │    (t3.micro)    │                          │     (PostgreSQL)      │        │ │
│  │  │                  │          SQL             │                       │        │ │
│  │  │ ┌──────────────┐ │  ◄───────────────────────┤ ┌───────────────────┐ │        │ │
│  │  │ │Security Group│ │ (future use)             │ │  Security Group   │ │        │ │
│  │  │ │- SSH from JB │ │                          │ │ - 5432 from Web   │ │        │ │
│  │  │ └──────────────┘ │                          │ └───────────────────┘ │        │ │
│  │  └──────────────────┘                          └───────────────────────┘        │ │
│  │                                                                                 │ │
│  │  PRIVATE SUBNET 2 (10.0.3.0/24)                                                 │ │
│  │  (Secondary RDS Subnet)                                                         │ │
│  └───────────────────────────────────────────────────────────────────┬─────────────┘ │
│                                                                      │               │
│  ┌────────────────────────┐         ┌────────────────────────────────▼────────────┐  │
│  │      S3 BUCKET         │◄────────┤         SECURITY LAYERS                     │  │
│  │ (KMS Encrypted,        │         │ Layer 1: Security Groups (Stateful)         │  │
│  │  Private, Versioned)   │         │ Layer 2: Network ACLs (Stateless)           │  │
│  └────────────────────────┘         │ Layer 3: IAM Roles (API Access)             │  │
│                                     └─────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**VPC:** 10.0.0.0/16 with three subnets: one public (10.0.1.0/24) housing the Jump Box, NAT instance, and Web App; and two private subnets for internal workloads and RDS.

**Compute:** Four t3.micro instances using Amazon Linux 2023.

- **Jump Box:** Sole entry point for SSH.
- **NAT Instance:** Routes outbound traffic for private subnets.
- **Web App:** Hosts the FastAPI application, exposed to the internet.
- **Main VM:** General-purpose private instance.

**Database:** Amazon RDS for PostgreSQL instance deployed across private subnets for high availability (configured for single-AZ to save costs but with subnet groups ready for multi-AZ). Encrypted at rest using KMS.

**Web App:** A FastAPI Python application containerized with Docker. It uses AWS Secrets Manager to securely retrieve database credentials and SQLAlchemy for ORM.

## Project Structure

```
homelab/
├── README.md
├── .gitignore
├── docker-compose.yml     (Local development stack)
├── app/                   (FastAPI application)
│   ├── main.py
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── test_main.py
│   └── templates/
└── terraform/
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    ├── network.tf         (VPC, Subnets, IGW, Route Tables)
    ├── security.tf        (Security Groups for all resources)
    ├── nacl.tf            (Network ACLs)
    ├── compute.tf         (EC2 instances and SSH keys)
    ├── database_rds.tf    (RDS PostgreSQL instance)
    ├── s3.tf              (S3 bucket and VPC Endpoint)
    ├── iam_instances.tf   (IAM roles for EC2)
    ├── iam_vpc.tf         (IAM roles for VPC Flow Logs)
    ├── kms.tf             (KMS encryption keys)
    ├── cloudwatch.tf      (CloudWatch Log Groups)
    ├── data.tf            (Data sources)
    ├── backend.tf         (S3 Remote State configuration)
    ├── moved.tf           (Refactoring history)
    ├── templates/         (User-data scripts)
    └── scripts/           (Utility scripts)
```

## Local Development

You can run the application locally using Docker Compose. This starts a PostgreSQL container and the FastAPI app.

```bash
docker compose up --build
```

The app will be available at `http://localhost:8000`.

## Security

| Control         | Scope                     | Details                                                                                                                                              |
| --------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Security Groups | Instance-level (stateful) | Web App: HTTP/S from anywhere, SSH/ICMP from Jump Box. RDS: Postgres (5432) from Web App only.                                                       |
| NACLs           | Subnet-level (stateless)  | Public NACL: SSH from my IP, HTTP/S ingress/egress, ephemeral ports. Private NACL: Restricts traffic to internal VPC CIDR and specific return ports. |
| IAM Roles       | API-level                 | Web App: Scoped access to Secrets Manager for DB creds. All: KMS usage and CloudWatch logging.                                                       |
| Secrets Manager | Credential Management     | RDS master password is automatically generated and stored in Secrets Manager, retrieved by the Web App at runtime.                                   |
| KMS             | Encryption                | Centralized key management for EBS, RDS, S3, and CloudWatch Logs.                                                                                    |

## Cost

| Resource                       | Cost (after Free Tier) |
| ------------------------------ | ---------------------- |
| 4× t3.micro EC2                | ~$29/month             |
| 1× db.t3.micro RDS             | ~$13/month             |
| 3× Elastic IPs (attached)      | $0 while running       |
| KMS key                        | ~$1/month              |
| S3/CloudWatch (minimal)        | <$3/month              |
| NAT Instance (vs. NAT Gateway) | Saves ~$30/month       |
| **Total (24/7)**               | **~$45-50/month**      |

_Note: Stop instances and delete RDS snapshots when not in use to minimize costs._

## Deployment

1. **Local Setup:** Ensure your SSH public key is in `terraform/.ssh/cloud-homelab-key.pem.pub`.
2. **Terraform Init:** `terraform -chdir=terraform init`
3. **Terraform Apply:** `terraform -chdir=terraform apply`
4. **Access Web App:** Get the public IP from Terraform outputs and visit `http://<web-app-ip>`.
5. **SSH Access:** Use the generated SSH config: `ssh -F terraform/.ssh/config web-app`.
