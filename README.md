# Deploy Sample Python Application on AWS EC2 using GitHub Actions

A production-grade CI/CD automation implementation for deploying a Python Web Application (Flask + Gunicorn + Systemd) to AWS EC2 instances across both **Public** and **Private Subnet** network topologies.

---

## 📋 Table of Contents
1. [Overview & Requirements](#-overview--requirements)
2. [Architectural Topologies](#-architectural-topologies)
   - [Scenario 1: EC2 with Public IP (Direct SSH)](#scenario-1-ec2-with-public-ip-direct-ssh)
   - [Scenario 2A: EC2 with Private IP via Bastion Host](#scenario-2a-ec2-with-private-ip-via-bastion-host)
   - [Scenario 2B: EC2 with Private IP via AWS Systems Manager (SSM)](#scenario-2b-ec2-with-private-ip-via-aws-systems-manager-ssm)
3. [Project Directory Structure](#-project-directory-structure)
4. [GitHub Actions Workflows](#-github-actions-workflows)
5. [GitHub Secrets Reference](#-github-secrets-reference)
6. [Step-by-Step Deployment Guide](#-step-by-step-deployment-guide)
7. [Terraform Infrastructure Provisioning](#-terraform-infrastructure-provisioning)
8. [AWS IAM & SSM Setup](#-aws-iam--ssm-setup)
9. [Troubleshooting & Verification](#-troubleshooting--verification)

---

## 🎯 Overview & Requirements

This repository solves the requirement:
> **"Deploy sample python application on ec2 using GitHub actions. Try server with public IP and private IP:"**
> 1. **Bastion Host (Jump Box ProxyJump)**
> 2. **AWS Systems Manager (SSM Run Command)**

| Requirement | Implementation | Security Profile |
| :--- | :--- | :--- |
| **Python Web App** | Flask REST API (`app/app.py`) + Gunicorn WSGI + Systemd service | Non-root `appuser`, auto-restart, health check |
| **CI / Quality Gate** | GitHub Actions (`ci-test.yml`) with flake8 linting and pytest unit tests | Pre-deployment verification |
| **Public EC2** | Direct SSH deployment via GitHub Actions (`deploy-public-ip.yml`) | Port 22 SSH + Port 5000 HTTP |
| **Private EC2 (Bastion)** | SSH Tunneling using OpenSSH `ProxyJump` (`deploy-private-bastion.yml`) | Private EC2 only accepts SSH from Bastion SG |
| **Private EC2 (SSM)** | Zero open inbound ports via AWS Systems Manager (`deploy-private-ssm.yml`) | Port 22 closed; communicates outbound to SSM API |

---

## 🏗 Architectural Topologies

### Scenario 1: EC2 with Public IP (Direct SSH)
The runner directly connects to the EC2 instance using its Public IP address / Elastic IP over SSH (port 22).

```mermaid
flowchart LR
    Dev([Developer]) -->|git push| GHA[GitHub Actions Runner]
    subgraph AWS VPC
        subgraph Public Subnet
            EC2_PUB["Public EC2 (54.x.x.x)<br/>• Port 22 (SSH)<br/>• Port 5000 (Flask App)"]
        end
    end
    GHA -->|1. Run Pytest| GHA
    GHA -->|2. SCP Code & Scripts| EC2_PUB
    GHA -->|3. SSH Deploy & Restart| EC2_PUB
    GHA -->|4. HTTP Healthcheck| EC2_PUB
```

---

### Scenario 2A: EC2 with Private IP via Bastion Host
The private EC2 instance resides in a private subnet with NO public IP. An intermediary Bastion Jump Host in the public subnet forwards SSH commands using OpenSSH `ProxyJump`.

```mermaid
flowchart LR
    GHA[GitHub Actions Runner]
    subgraph AWS VPC (10.0.0.0/16)
        subgraph Public Subnet (10.0.1.0/24)
            Bastion["Bastion Host<br/>Public IP: 54.x.x.x<br/>Security Group: Allow Port 22"]
        end
        subgraph Private Subnet (10.0.2.0/24)
            EC2_PRIV["Private EC2<br/>Private IP: 10.0.2.x<br/>SG: Inbound 22/5000 ONLY from Bastion"]
        end
    end
    GHA -->|SSH ProxyJump through Bastion| EC2_PRIV
    Bastion -.->|Tunnel SSH Stream| EC2_PRIV
```

**OpenSSH ProxyJump Configuration (`~/.ssh/config`):**
```ssh-config
Host bastion
    HostName ${{ secrets.BASTION_HOST }}
    User ec2-user
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no

Host private-ec2
    HostName ${{ secrets.PRIVATE_EC2_IP }}
    User ec2-user
    IdentityFile ~/.ssh/private_key
    ProxyJump bastion
    StrictHostKeyChecking no
```

---

### Scenario 2B: EC2 with Private IP via AWS Systems Manager (SSM)
**The most secure, modern AWS cloud architecture.**
The private EC2 instance has:
- **NO Public IP**
- **NO Open Inbound Ports** (Port 22 SSH is completely blocked!)
- Communicates securely to AWS SSM Agent via NAT Gateway or SSM VPC Endpoints
- GitHub Actions triggers `aws ssm send-command` (`AWS-RunShellScript`) and streams execution logs.

```mermaid
flowchart TD
    GHA[GitHub Actions Runner] -->|1. Assume IAM Role / Auth| AWS_API[AWS SSM API]
    AWS_API -->|2. Send-Command AWS-RunShellScript| SSM_AGENT[SSM Agent on Private EC2]
    subgraph AWS VPC
        subgraph Private Subnet (No Inbound Ports Open)
            SSM_AGENT -->|3. Pull Repo / Update Files| LOCAL_FS[/opt/python-app]
            LOCAL_FS -->|4. Restart Service & Verify| SYSTEMD[Systemd: python-app.service]
        end
    end
    SSM_AGENT -->|5. Execution Output| AWS_API
    AWS_API -->|6. Polled Command Status: Success| GHA
```

---

## 📁 Project Directory Structure

```text
├── .github/
│   └── workflows/
│       ├── ci-test.yml                 # Pytest & Flake8 CI test automation
│       ├── deploy-public-ip.yml        # Scenario 1: Direct SSH deployment
│       ├── deploy-private-bastion.yml  # Scenario 2A: Bastion ProxyJump deployment
│       └── deploy-private-ssm.yml      # Scenario 2B: AWS SSM Run Command deployment
├── app/
│   ├── __init__.py
│   ├── app.py                         # Production Flask REST API (/health, /api/info)
│   ├── requirements.txt               # Flask, Gunicorn, pytest, requests
│   └── tests/
│       ├── __init__.py
│       └── test_app.py                # Automated Pytest suite
├── scripts/
│   ├── install_prereqs.sh             # EC2 OS bootstrap (Python 3, venv, user, systemd)
│   ├── deploy.sh                      # Zero-downtime venv update, restart & healthcheck
│   ├── python-app.service             # Systemd service unit template
│   └── ssm_deploy_script.sh           # Remote execution script used by AWS SSM
├── terraform/                         # Complete Infrastructure as Code
│   ├── main.tf                        # VPC, Subnets, NAT Gateway, IAM SSM Role, EC2s
│   ├── variables.tf                   # Region, CIDRs, instance type variables
│   ├── outputs.tf                     # IPs, Instance IDs, and GitHub secrets map
│   └── terraform.tfvars.example       # Example variable values
└── README.md                          # Comprehensive documentation
```

---

## ⚙️ GitHub Secrets Reference

Configure these in your GitHub Repository under **Settings** > **Secrets and variables** > **Actions**:

### Secrets for Scenario 1 (Public IP)
| Secret Name | Description | Example |
| :--- | :--- | :--- |
| `EC2_PUBLIC_IP` | Public IPv4 or Elastic IP of the target EC2 | `54.210.12.34` |
| `EC2_USER` | SSH username (e.g. `ec2-user` for Amazon Linux, `ubuntu` for Ubuntu) | `ec2-user` |
| `EC2_SSH_KEY` | Private SSH Key (`.pem`) matching the EC2 Key Pair | `-----BEGIN RSA PRIVATE KEY-----...` |

### Secrets for Scenario 2A (Private IP via Bastion)
| Secret Name | Description | Example |
| :--- | :--- | :--- |
| `BASTION_HOST` | Public IP of the Bastion jump host | `3.85.120.45` |
| `BASTION_USER` | SSH username for the Bastion | `ec2-user` |
| `BASTION_SSH_KEY` | Private SSH Key for the Bastion | `-----BEGIN RSA PRIVATE KEY-----...` |
| `PRIVATE_EC2_IP` | Private Subnet IP address of target EC2 | `10.0.2.145` |
| `PRIVATE_EC2_USER` | SSH username for the target EC2 | `ec2-user` |
| `PRIVATE_EC2_SSH_KEY`| Private SSH Key for the target EC2 (if different from Bastion) | `-----BEGIN RSA PRIVATE KEY-----...` |

### Secrets for Scenario 2B (Private IP via SSM)
| Secret Name | Description | Example |
| :--- | :--- | :--- |
| `AWS_REGION` | AWS Region hosting the EC2 instance | `us-east-1` |
| `EC2_INSTANCE_ID` | EC2 Instance ID managed by SSM | `i-0abcdef1234567890` |
| `AWS_ACCESS_KEY_ID` | IAM User access key with SSM Run Command permissions | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM User secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_ROLE_ARN` *(Optional OIDC)* | IAM Role ARN for passwordless GitHub OIDC authentication | `arn:aws:iam::123456789012:role/GitHubSSMDeployRole` |
| `DEPLOY_S3_BUCKET` *(Optional)* | S3 bucket for staging packaged tarball release artifacts | `my-ec2-deployment-artifacts` |

---

## 🚀 Step-by-Step Deployment Guide

### 1. Setting up the Target EC2 Instance (Manual or Cloud-Init)
Run the prerequisite installer once on your EC2 instance (or pass it in User Data):
```bash
chmod +x scripts/install_prereqs.sh
./scripts/install_prereqs.sh
```
This script:
1. Installs Python 3, Pip, and Git.
2. Creates an unprivileged system user `appuser`.
3. Sets up `/opt/python-app` with permissions.
4. Registers and enables `python-app.service` in systemd.

---

### 2. Testing Application Locally
To test the Flask application and unit tests on your machine:
```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # Or `.\venv\Scripts\activate` on Windows

# Install requirements
pip install -r app/requirements.txt

# Run pytest unit tests
pytest app/tests/ -v

# Start development server
python app/app.py
```

Test endpoints:
```bash
curl http://localhost:5000/
curl http://localhost:5000/health
curl http://localhost:5000/api/info
curl -X POST http://localhost:5000/api/items -H "Content-Type: application/json" -d '{"name": "Test Deployment"}'
```

---

## 🛠 Terraform Infrastructure Provisioning

The included `terraform/` directory provisions the entire architecture in minutes:
- 1 Custom VPC with DNS hostnames enabled
- 1 Public Subnet (with Internet Gateway)
- 1 Private Subnet (with NAT Gateway)
- 1 Public EC2 Server
- 1 Bastion Host
- 1 Private EC2 Server (with SSM IAM role & profile attached)
- Interconnected Security Groups

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your key_name and preferences
terraform init
terraform plan
terraform apply
```

After apply, Terraform prints all IPs, Instance IDs, and formatted GitHub secrets:
```bash
Outputs:
bastion_public_ip       = "54.198.50.21"
private_ec2_instance_id = "i-09ab7c1e34df8921a"
private_ec2_private_ip  = "10.0.2.45"
public_ec2_public_ip    = "54.210.98.12"
```

---

## 🔐 AWS IAM & SSM Setup

### 1. EC2 Instance IAM Role (Required for SSM)
The private EC2 instance must have an IAM instance profile attached containing:
- AWS Managed Policy: **`AmazonSSMManagedInstanceCore`**

### 2. GitHub Actions IAM Policy (For `deploy-private-ssm.yml`)
Attach this policy to the IAM user or OIDC role used by GitHub Actions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:DescribeInstanceInformation",
        "ssm:ListCommands"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 🔍 Troubleshooting & Verification

### Verifying Systemd Service Status on EC2
```bash
sudo systemctl status python-app.service
sudo journalctl -u python-app.service -f --no-pager
```

### Checking SSM Agent Status on Private EC2
```bash
sudo systemctl status amazon-ssm-agent
```

### Testing Bastion ProxyJump manually from your terminal
```bash
ssh -J ec2-user@<BASTION_PUBLIC_IP> ec2-user@<PRIVATE_EC2_IP>
```
