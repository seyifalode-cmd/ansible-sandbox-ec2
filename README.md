# **Ansible Sandbox EC2**

Minimal Terraform configuration that provisions a single AWS EC2 instance with Ansible pre-installed via user data — a clean, reproducible sandbox environment for learning and testing Ansible automation.

---

## Project at a Glance

| | |
|---|---|
| **Tools Used** | Terraform, Ansible, AWS EC2, AWS SSM Parameter Store |
| **Platform** | Amazon Web Services (us-east-1) |
| **Languages** | HCL (Terraform) |
| **What It Does** | Launches an Amazon Linux 2 EC2 instance and installs Ansible automatically on first boot via user data |

---

## The Problem This Project Solves

Getting started with Ansible requires a working Linux environment with Ansible installed. Setting this up manually — choosing an AMI, creating a security group, uploading an SSH key pair, SSHing in, installing Ansible, and enabling the right repositories — takes time and introduces variables that make it hard to share reproducibly with a team or revisit reliably after an environment is torn down.

This project reduces that setup to a single command. Terraform provisions an EC2 instance using the latest Amazon Linux 2 AMI (fetched dynamically from SSM Parameter Store), attaches a security group, associates an SSH key pair, and uses a user data script to install Ansible on first boot without any additional interaction. The instance is ready for Ansible experiments as soon as the user data script completes.

This sandbox is intentionally minimal. It is designed as a starting point — a proof-of-concept node where Ansible commands can be executed against localhost or used as the basis for building more complex control-plane configurations. It is the foundational pattern that the more advanced projects in this series expand upon.

---

## Architecture

```
Local Machine
     |
     | terraform apply
     v
+----------------------------+
|   Terraform (HCL)          |
|   - AWS Provider           |
|   - aws_ssm_parameter      |   <-- resolves latest Amazon Linux 2 AMI
|   - aws_key_pair           |
|   - aws_security_group     |
|   - aws_instance           |
+----------------------------+
     |
     | Provisions
     v
+----------------------------------------------+
|  EC2 Instance: "ansible-sandbox"             |
|  AMI: Amazon Linux 2 (latest, via SSM)       |
|  Instance Type: t3.micro                     |
|  Region: us-east-1                           |
|                                              |
|  Security Group:                             |
|    Inbound  TCP/22  (SSH)                    |
|    Inbound  TCP/80  (HTTP)                   |
|    Outbound All                              |
|                                              |
|  User Data (runs on first boot):             |
|    sudo yum update -y                        |
|    sudo amazon-linux-extras install ansible2 |
+----------------------------------------------+
     |
     | Terraform output
     v
  Ansible-Sandbox-PublicIP
```

---

## Repository Structure

```
ansible-sandbox-ec2/
├── main.tf         # EC2 instance, security group, key pair, user data, AMI lookup
├── variables.tf    # SSH key path variables
├── outputs.tf      # Exports the sandbox EC2 public IP
└── .gitignore
```

---

## How It Works

**AMI resolution via SSM.** Rather than hardcoding an AMI ID that becomes stale or region-specific, the configuration uses an `aws_ssm_parameter` data source to fetch the current latest Amazon Linux 2 HVM x86_64 AMI ID at plan time. This ensures the instance always launches with a supported, up-to-date image.

**SSH key pair.** Terraform reads a local public key file and registers it as an AWS key pair named `ansible`. The path defaults to `~/.ssh/id_ed25519.pub` and can be overridden via a variable. This key is the only authorized method of SSH access.

**Security group.** A minimal security group allows inbound SSH (TCP 22) and HTTP (TCP 80), with unrestricted outbound traffic. No broad CIDR restrictions are applied to SSH in this sandbox context — this is expected for a development environment and should be tightened for any production use.

**User data bootstrap.** The `user_data` block runs a two-command shell script on the instance's first boot:
1. `sudo yum update -y` — patches all installed packages
2. `sudo amazon-linux-extras install ansible2 -y` — installs Ansible 2 from the Amazon Linux Extras repository

No Terraform provisioners are used in this project. The bootstrap is entirely cloud-init-driven, which means `terraform apply` returns as soon as the instance is running, and the user data continues asynchronously in the background.

---

## Walkthrough

```bash
# 1. Initialize Terraform
terraform init

# 2. Review the execution plan
terraform plan

# 3. Provision the sandbox instance
terraform apply \
  -var="ssh_key_public=~/.ssh/id_ed25519.pub" \
  -var="ssh_key_private=~/.ssh/id_ed25519" \
  -auto-approve

# 4. Get the public IP
terraform output Ansible-Sandbox-PublicIP

# 5. SSH into the instance
#    Wait ~2-3 minutes for user data to complete before checking Ansible
ssh -i ~/.ssh/id_ed25519 ec2-user@<public-ip>

# 6. Verify Ansible is installed
ansible --version

# 7. Test Ansible against localhost
ansible localhost -m ping

# 8. Tear down the instance
terraform destroy -auto-approve
```

---

## How to Reproduce

**Prerequisites**

- Terraform >= 1.0.0
- AWS account with credentials configured (`aws configure` or environment variables)
- SSH key pair on your local machine

```bash
# Clone the repository
git clone https://github.com/Seyifunmi0604/ansible-sandbox-ec2.git
cd ansible-sandbox-ec2

# Initialize and apply
terraform init
terraform apply \
  -var="ssh_key_public=${HOME}/.ssh/id_ed25519.pub" \
  -var="ssh_key_private=${HOME}/.ssh/id_ed25519" \
  -auto-approve

# Retrieve the IP and SSH in
terraform output Ansible-Sandbox-PublicIP
ssh -i ~/.ssh/id_ed25519 ec2-user@$(terraform output -raw Ansible-Sandbox-PublicIP)
```

Allow 2-3 minutes after `apply` for the user data script to complete before SSHing in and running `ansible --version`.

---

## Notes on Progression

This project intentionally omits file provisioners, remote-exec provisioners, and playbook execution. Those capabilities are layered in across the companion projects in this series:

- `ansible-control-node-provisioner` extends this pattern with provisioners that install Ansible, copy a playbook, and generate an SSH key pair
- `ansible-managed-nodes-provisioner` adds VPC isolation and a multi-instance fleet using Terraform modules
- `ansible-control-node-setup` provides the Ansible playbooks that configure those managed nodes end-to-end

---

## Related Projects

- `ansible-sandbox-ec2` — **This project** — Minimal single-node sandbox
- `ansible-control-node-provisioner` — Full control node with SSH key generation
- `ansible-managed-nodes-provisioner` — Four managed nodes in a custom VPC
- `ansible-control-node-setup` — Playbooks for configuring the managed node fleet
- `mariadb-ansible-setup` — Self-contained MariaDB provisioning via Terraform + Ansible

---

*Oluwaseyi Michael Falode · Cybersecurity & Cloud Security Engineer · Toronto, ON*
