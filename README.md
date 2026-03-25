# AWS Homelab Infrastructure with Terraform

## Overview

Secure, cost-optimized AWS environment built with Terraform. The architecture uses a bastion host (jump box) for SSH access, a NAT instance instead of NAT Gateway for cost savings, defense-in-depth security with Security Groups and NACLs, and centralized log collection via CloudWatch Logs. It also includes private S3 storage accessed via a VPC Gateway Endpoint.

**Stack:** Terraform · VPC (1 public + 2 private subnets) · 3 EC2 instances (Amazon Linux 2023) · S3 (encrypted, versioned) · VPC Gateway Endpoint (S3) · Security Groups + NACLs · IAM least-privilege roles · KMS (single key for EBS, S3, and CloudWatch) · CloudWatch Logs (KMS-encrypted) · VPC Flow Logs · SSH ProxyJump automation

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                      INTERNET                                        │
└────────────────────────────────────────┬─────────────────────────────────────────────┘
                                         │
                      SSH (Port 22), only from my IP
                      ICMP (ping), only from my IP
                                         │
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               VPC (10.0.0.0/16)                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         PUBLIC SUBNET (10.0.1.0/24)                            │  │
│  │                                                                                │  │
│  │  ┌──────────────────┐               ┌──────────────────┐                       │  │
│  │  │    JUMP BOX      │               │   NAT INSTANCE   │                       │  │
│  │  │   (t3.micro)     │               │   (t3.micro)     │                       │  │
│  │  │                  │               │                  │                       │  │
│  │  │ ┌──────────────┐ │               │ ┌──────────────┐ │                       │  │
│  │  │ │Security Group│ │               │ │Security Group│ │                       │  │
│  │  │ │- SSH from IP │ │               │ │- HTTP/S from │ │                       │  │
│  │  │ └──────────────┘ │               │ │  private sub │ │                       │  │
│  │  │                  │               │ │- SSH from JB │ │                       │  │
│  │  │ Elastic IP ──────┼─────────►     │ └──────────────┘ │                       │  │
│  │  │                  │               │                  │                       │  │
│  │  │ IAM Role:        │               │ Elastic IP ──────┼──►                    │  │
│  │  │ - CloudWatch     │               │                  │                       │  │
│  │  │ - KMS Usage      │               │ IAM Role:        │                       │  │
│  │  └──────────────────┘               │ - CloudWatch     │                       │  │
│  │           │                         │ - KMS Usage      │                       │  │
│  │           │ SSH                     │                  │                       │  │
│  │           │ ProxyJump               │ IP Forwarding +  │                       │  │
│  │           │                         │ iptables         │                       │  │
│  │           │                         │ MASQUERADE       │                       │  │
│  │           │                         └────────┬─────────┘                       │  │
│  │           │                                  │                                 │  │
│  └───────────┼──────────────────────────────────┼─────────────────────────────────┘  │
│              │                                  │ Outbound via NAT                   │
│              │       ┌──────────────────────────┘                                    │
│              │       ▼                                                               │
│  ┌───────────┼─────────────────────────────────────────────────────────────────────┐ │
│  │           │       PRIVATE SUBNET 1 (10.0.2.0/24)                                │ │
│  │           │                                                                     │ │
│  │           ▼                                      ┌──────────────────────┐       │ │
│  │  ┌──────────────────────┐                        │ VPC Gateway Endpoint │       │ │
│  │  │       MAIN VM        │                        │      (S3)            │       │ │
│  │  │      (t3.micro)      │                        └──────────┬───────────┘       │ │
│  │  │                      │                                   │                   │ │
│  │  │ ┌──────────────────┐ │          HTTPS (Private)          │                   │ │
│  │  │ │  Security Group  │ ├───────────────────────────────────┘                   │ │
│  │  │ │ - SSH from JB    │ │                                                       │ │
│  │  │ │ - ICMP from JB   │ │                                                       │ │
│  │  │ └──────────────────┘ │                                                       │ │
│  │  │  NO Public IP        │                                                       │ │
│  │  │  IAM Role:           │                                                       │ │
│  │  │  - CloudWatch        │                                                       │ │
│  │  │  - KMS Usage         │                                                       │ │
│  │  │  - S3 Access         │                                                       │ │
│  │  └──────────────────────┘                                                       │ │
│  │                                                                                 │ │
│  │  PRIVATE SUBNET 2 (10.0.3.0/24)                                                 │ │
│  │  (Empty - for future expansion)                                                 │ │
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

**VPC:** 10.0.0.0/16 with three subnets, public (10.0.1.0/24), private 1 (10.0.2.0/24), and private 2 (10.0.3.0/24). VPC Flow Logs capture ALL traffic and ship to CloudWatch Logs. A VPC Gateway Endpoint provides private access to S3.

**Compute:** Three t3.micro instances using Amazon Linux 2023. All root volumes are KMS-encrypted and IMDSv2 is enforced. The jump box is the sole SSH entry point via its Elastic IP. The NAT instance routes outbound traffic from private subnets. The main VM has no public IP and is reached via ProxyJump.

**Security:** Three-layer defense using stateful security groups, stateless NACLs, and IAM roles. Each instance is assigned a least-privilege role with scoped KMS permissions. The Main VM has a specific IAM policy for S3 access.

**Logging:** All instances ship system and setup logs to CloudWatch Logs via the CloudWatch Agent. VPC Flow Logs provide full network visibility. All log groups are encrypted with the project KMS key.

**KMS:** A single shared KMS key (`alias/cloud-homelab`) handles EBS volume encryption, S3 bucket-key encryption, and CloudWatch log group encryption. Key rotation is enabled.

## Project Structure

```
homelab/
├── README.md
├── .gitignore
└── terraform/
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    ├── network.tf         (VPC, 3 subnets, IGW, route tables, VPC Flow Log)
    ├── security.tf        (Security Groups for all instances)
    ├── nacl.tf            (Public and Private NACLs)
    ├── compute.tf         (EC2: jump box, NAT, main VM; SSH key + local config)
    ├── s3.tf              (S3 bucket, versioning, policies, VPC Endpoint)
    ├── iam_instances.tf   (IAM roles and policies for EC2 instances)
    ├── iam_vpc.tf         (IAM role and policy for VPC Flow Logs)
    ├── kms.tf             (KMS key + alias for EBS, S3 and CloudWatch)
    ├── cloudwatch.tf      (CloudWatch log groups for instances and VPC flow logs)
    ├── data.tf            (Data sources: AMI, AZs, External IP, IAM policies)
    ├── moved.tf           (Terraform state move blocks for refactoring)
    ├── templates/
    │   ├── userdata.tpl           (NAT setup + CloudWatch Agent)
    │   ├── userdata-jump-box.tpl  (Jump box init + CloudWatch Agent)
    │   └── userdata-main-vm.tpl   (Main VM init + CloudWatch Agent)
    └── scripts/
        └── my_ip_json.sh  (Retrieves local IP for SG whitelisting)
```

## Implementation Notes

### Network Architecture

The VPC is segmented into one public and two private subnets. The public route table directs traffic to the Internet Gateway, while the private route table uses the NAT instance's network interface as the default gateway (0.0.0.0/0) and includes a route for the S3 VPC Gateway Endpoint.

### S3 Storage & Private Connectivity

A secure S3 bucket is provisioned for data storage, featuring:

- **Encryption:** Server-side encryption using the project's KMS key (SSE-KMS) with Bucket Keys enabled.
- **Versioning:** Enabled to protect against accidental deletions.
- **Access Control:** Public access is strictly blocked. Access is restricted via IAM roles and a Bucket Policy.
- **VPC Endpoint:** A Gateway Endpoint allows the Main VM to communicate with S3 over the AWS internal network, avoiding the internet and NAT instance.

### NAT Instance

To avoid the cost of a managed NAT Gateway (~$33/month), a t3.micro instance is used as a NAT engine. A user data script enables IP forwarding and configures `iptables` MASQUERADE rules for both private subnets. A systemd service ensures rules persist across reboots.

### SSH Access & Automation

The project automates SSH configuration. Terraform generates a `.ssh/config` file in the `terraform/` directory with `ProxyJump` and `IdentityFile` entries pre-configured.

- **Jump Box:** Accessible via Elastic IP only from the deployer's public IP.
- **Private Instances:** Transparently accessible via `ssh -F .ssh/config <host>`.
- **Security:** `StrictHostKeyChecking` is set to `accept-new` with a local `known_hosts` file to maintain security while avoiding manual fingerprint confirmation.

### Dynamic IP Whitelisting

The `scripts/my_ip_json.sh` script dynamically fetches the current public IP of the workstation running Terraform. This IP is then used to whitelist SSH and ICMP access in both Security Groups and NACLs, ensuring no hardcoded IPs are left in the configuration.

### CloudWatch Logging

Each instance installs and configures the CloudWatch Agent via user data. Logs collected include:

- `/var/log/messages` (all instances)
- `/var/log/nat-setup.log` (NAT instance)
- `/var/log/secure` (Jump box and Main VM)

| Instance     | Log Group                     | Retention |
| ------------ | ----------------------------- | --------- |
| Jump box     | `/cloud-homelab/jump-box`     | 30 days   |
| NAT instance | `/cloud-homelab/nat-instance` | 30 days   |
| Main VM      | `/cloud-homelab/main-vm`      | 30 days   |
| VPC Flow Log | `/cloud-homelab-vpc-flow-log` | 30 days   |

## Security

| Control         | Scope                     | Details                                                                                                                                           |
| --------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Security Groups | Instance-level (stateful) | Jump box: SSH/ICMP from my IP only. NAT: HTTP/S and ICMP from private subnets, SSH/ICMP from jump box. Main VM: SSH/ICMP from jump box only.      |
| NACLs           | Subnet-level (stateless)  | Public NACL: SSH from my IP, HTTP/S egress, ephemeral ports, ICMP. Private NACL: SSH from public subnet, ephemeral return traffic, HTTP/S egress. |
| IAM Roles       | API-level                 | Instances: Scoped KMS usage and CloudWatch logging. Main VM: Scoped S3 access. VPC Flow Logs: Permissions to write to CloudWatch.                 |
| KMS             | Encryption                | Single key covers CloudWatch logs, EBS root volumes, and S3 objects. Key rotation enabled.                                                        |
| IMDSv2          | Instance metadata         | `http_tokens = "required"` enforced on all EC2 instances to prevent SSRF-based metadata theft.                                                    |
| S3 Security     | Data Protection           | Block Public Access enabled, Bucket Policy enforced, SSE-KMS encryption, and versioning enabled.                                                  |
| Bastion Pattern | Access control            | Single SSH entry point via Jump Box. Private instances do not have public IPs and restrict SSH to the Jump Box security group.                    |
| VPC Flow Logs   | Visibility                | ALL traffic logged to CloudWatch for audit and troubleshooting.                                                                                   |

## Cost

| Resource                       | Cost (after Free Tier) |
| ------------------------------ | ---------------------- |
| 3× t3.micro EC2                | ~$22/month             |
| 2× Elastic IPs (attached)      | $0 while running       |
| KMS key                        | ~$1/month              |
| S3 Storage                     | ~$0.023/GB             |
| VPC S3 Endpoint                | FREE (Gateway type)    |
| CloudWatch Logs (minimal data) | <$2/month              |
| NAT Instance (vs. NAT Gateway) | Saves ~$30/month       |
| **Total (24/7)**               | **~$25-30/month**      |

_Note: Costs are significantly reduced if instances are stopped when not in use._

## Deployment

```bash
# 0. Ensure your SSH public key is in terraform/.ssh/
# Default expected name: cloud-homelab-key.pem.pub

# 1. Initialize
terraform -chdir=terraform init

# 2. Preview
terraform -chdir=terraform plan

# 3. Deploy
terraform -chdir=terraform apply

# 4. Connect
ssh -F terraform/.ssh/config jump-box
ssh -F terraform/.ssh/config main-vm
ssh -F terraform/.ssh/config nat-instance
```

Outputs include SSH connection commands, private/public IPs for all instances, and the S3 bucket name.

## License

This project is intended for educational purposes.
