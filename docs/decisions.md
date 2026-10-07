# Architecture Decisions

This document records the main engineering decisions made while designing and implementing the AWS DevOps Production Deployment project.

The purpose is to explain not only what was built, but why particular approaches were selected and what trade-offs were considered.

---

## Decision 1: Use Terraform for Infrastructure as Code

### Decision

Use Terraform to provision and manage the AWS infrastructure.

### Reason

Terraform allows infrastructure to be defined as code rather than manually created through the AWS Console.

This makes infrastructure:

- Repeatable
- Reviewable
- Version controlled
- Easier to reproduce
- Less dependent on manual configuration

Before infrastructure changes are applied, `terraform plan` can be used to inspect the expected changes.

The project therefore keeps infrastructure configuration alongside the application repository rather than relying on undocumented manual AWS configuration.

### Trade-Off

Terraform introduces state management and requires developers to understand resource dependencies and lifecycle behaviour.

For this portfolio project, local Terraform state is used. A larger team environment should normally use remote state and state locking.

---

## Decision 2: Keep EC2 Instances in Private Subnets

### Decision

Run application EC2 instances inside private subnets instead of assigning them public IP addresses.

### Reason

The EC2 instances do not need to be directly accessible from the internet.

Public users should access the application through the Application Load Balancer.

The traffic flow is:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Private EC2 Instances
```

The EC2 Security Group permits application traffic on port `5000` only from the ALB Security Group.

This reduces the public attack surface.

Administrative management can be performed using AWS Systems Manager rather than exposing SSH port `22`.

### Trade-Off

Private instances still require outbound connectivity for operations such as package installation and image retrieval.

This requires additional networking infrastructure such as a NAT Gateway, which introduces cost.

---

## Decision 3: Use an Application Load Balancer

### Decision

Expose the application through an internet-facing Application Load Balancer rather than exposing individual EC2 instances.

### Reason

The ALB provides a single public application entry point and distributes requests across healthy backend instances.

It also provides health checking through:

```text
/health
```

Only healthy targets receive user traffic.

This separates the public access layer from the private application compute layer.

### Trade-Off

The Application Load Balancer creates an ongoing AWS cost even when application traffic is low.

For a temporary portfolio environment, the infrastructure is destroyed after testing.

---

## Decision 4: Use an Auto Scaling Group

### Decision

Manage application EC2 instances through an Auto Scaling Group instead of creating independent EC2 instances manually.

### Reason

The Auto Scaling Group maintains the required number of application instances and can replace unhealthy instances automatically.

The project uses:

```text
Minimum capacity: 2
Desired capacity: 2
Maximum capacity: 4
```

Instances are distributed across private subnets in two Availability Zones.

This provides better resilience than running a single standalone EC2 instance.

---

## Decision 5: Use a Launch Template

### Decision

Define EC2 configuration through an AWS Launch Template.

### Reason

The Launch Template provides a consistent definition for new application instances, including:

- AMI
- Instance type
- Security Group
- IAM instance profile
- User Data bootstrap configuration

Whenever the Auto Scaling Group launches a replacement instance, it can reproduce the required configuration consistently.

---

## Decision 6: Use Amazon ECR for Container Images

### Decision

Store application Docker images in a private Amazon ECR repository.

### Reason

Amazon ECR integrates directly with AWS IAM.

GitHub Actions can push application images using temporary AWS credentials, while EC2 instances can pull images using their IAM instance role.

This removes the need to maintain separate long-lived container registry credentials.

---

## Decision 7: Use Git Commit SHA Docker Image Tags

### Decision

Tag deployment images using the Git commit SHA instead of using the mutable `latest` tag.

Example:

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

### Reason

A Git SHA uniquely identifies the source code used to produce an image.

This creates a traceable relationship:

```text
Git Commit
    =
Docker Image Tag
    =
Application Version
```

Using immutable image identifiers avoids ambiguity about which version of the application is being deployed.

It also makes it possible to identify and redeploy a previous known-good image if required.

### Trade-Off

Each deployment creates another image version in ECR, so image lifecycle management becomes important over time.

---

## Decision 8: Use SSM Parameter Store as the Deployment Pointer

### Decision

Store the currently required Docker image SHA in AWS Systems Manager Parameter Store.

Parameter:

```text
/devops-prod/image-tag
```

### Reason

The Launch Template should not need to be modified every time a new application image is released.

Instead, each new EC2 instance retrieves the required image version from Parameter Store during bootstrap.

The deployment relationship becomes:

```text
GitHub Actions
      |
      v
Update SSM image SHA
      |
      v
New EC2 instance
      |
      v
Read image SHA
      |
      v
Pull exact image from ECR
```

This separates infrastructure configuration from application deployment state.

---

## Decision 9: Separate Terraform Ownership from CI/CD Deployment Ownership

### Decision

Terraform owns the SSM parameter resource, while GitHub Actions owns its deployment value.

### Reason

Terraform is responsible for creating infrastructure.

GitHub Actions is responsible for deploying application versions.

If Terraform continuously controlled the value of the SSM parameter, a later Terraform operation could accidentally replace the image SHA deployed by CI/CD.

A Terraform lifecycle rule therefore ignores application deployment value changes:

```hcl
lifecycle {
  ignore_changes = [value]
}
```

This creates a clear ownership boundary:

```text
Terraform
   |
   `-- Infrastructure lifecycle


GitHub Actions
   |
   `-- Application deployment lifecycle
```

---

## Decision 10: Use GitHub OIDC Instead of Static AWS Access Keys

### Decision

Authenticate GitHub Actions to AWS using OpenID Connect and an IAM role.

### Reason

GitHub Actions does not need permanent AWS access keys stored in GitHub Secrets.

The authentication flow is:

```text
GitHub Actions
      |
      v
OIDC Token
      |
      v
AWS STS
      |
      v
Temporary AWS Credentials
```

The IAM trust policy restricts which GitHub identity can assume the deployment role.

This is safer than storing long-lived AWS access keys.

### Trade-Off

OIDC trust policies must be configured correctly.

During implementation, the workflow initially failed because the GitHub OIDC subject claim did not match the IAM trust policy.

The actual immutable subject was identified and the trust policy was corrected.

---

## Decision 11: Use Separate IAM Roles for EC2 and GitHub Actions

### Decision

Use different IAM roles for runtime instances and the CI/CD pipeline.

### Reason

The EC2 instances and GitHub Actions perform different jobs.

The EC2 role needs permissions such as:

```text
Read deployment value from SSM
Pull images from ECR
Communicate with Systems Manager
```

The GitHub Actions role needs permissions such as:

```text
Push images to ECR
Update SSM deployment value
Start Instance Refresh
Read Instance Refresh status
```

Separating the roles supports least privilege and avoids giving one identity unnecessary permissions.

---

## Decision 12: Use Security Group Referencing

### Decision

Allow EC2 application traffic based on the ALB Security Group rather than allowing port `5000` from the entire internet.

### Reason

The EC2 inbound rule conceptually becomes:

```text
Source:
ALB Security Group

Port:
5000
```

This means application traffic can reach the EC2 instances only through the approved load balancer path.

The EC2 instances remain private implementation details rather than public application endpoints.

---

## Decision 13: Use Systems Manager Instead of Public SSH

### Decision

Do not expose SSH port `22` publicly for normal instance administration.

### Reason

The EC2 instances use the Systems Manager Agent and an IAM instance role.

This allows AWS-managed instance access without requiring:

- Public IP addresses
- Public SSH
- Shared SSH keys
- Bastion hosts for this project

Interactive Session Manager access still depends on the human operator having the appropriate IAM permissions.

---

## Decision 14: Use Gunicorn Instead of the Flask Development Server

### Decision

Run the Flask application using Gunicorn inside the Docker container.

### Reason

Flask's built-in server is intended primarily for development.

The production-style container command is:

```text
gunicorn --bind 0.0.0.0:5000 app:app
```

Gunicorn provides a more appropriate WSGI application runtime for the deployed environment.

---

## Decision 15: Use Auto Scaling Instance Refresh for Deployments

### Decision

After publishing a new application version, use an Auto Scaling Instance Refresh to replace existing EC2 instances.

### Reason

Updating the SSM image parameter does not automatically restart existing EC2 instances.

Existing instances would continue running their old Docker image.

The deployment process therefore becomes:

```text
New image pushed to ECR
        |
        v
SSM updated with new SHA
        |
        v
Instance Refresh starts
        |
        v
New EC2 instances launch
        |
        v
New instances read new SHA
        |
        v
New image runs
```

This allows application deployments to use the existing Auto Scaling infrastructure rather than manually modifying individual EC2 instances.

---

## Decision 16: Make CI/CD Wait for Deployment Completion

### Decision

Do not mark the GitHub Actions workflow successful immediately after calling `StartInstanceRefresh`.

### Reason

An accepted AWS API request only proves that the refresh started.

It does not prove that replacement EC2 instances:

- Launched successfully
- Started the application
- Became healthy
- Completed the refresh

The workflow therefore captures the Instance Refresh ID and polls its status using `DescribeInstanceRefreshes`.

```text
Start refresh
    |
    v
InProgress
    |
    v
InProgress
    |
    v
Successful
```

The pipeline becomes green only after AWS reports a successful refresh.

Failure, cancellation, rollback-related outcomes, or timeout cause the workflow to fail.

This makes CI/CD status more meaningful.

---

## Decision 17: Trigger Application Deployment Only for Application Changes

### Decision

Configure the GitHub Actions deployment workflow with:

```yaml
paths:
  - "app/**"
```

### Reason

Documentation-only changes should not rebuild the Docker image and replace production EC2 instances.

This reduces:

- Unnecessary deployments
- Unnecessary EC2 replacements
- Deployment time
- AWS activity

Infrastructure changes continue to be managed separately through Terraform.

---

## Decision 18: Add CPU Target Tracking Auto Scaling

### Decision

Use an Auto Scaling target tracking policy based on:

```text
ASGAverageCPUUtilization
```

with a target value of:

```text
50%
```

### Reason

The Auto Scaling Group should be capable of adjusting capacity based on workload rather than operating only at a permanently fixed desired capacity.

The policy operates within:

```text
Minimum: 2
Maximum: 4
```

This demonstrates dynamic scaling while preserving capacity limits.

---

## Decision 19: Monitor ALB Unhealthy Targets with CloudWatch

### Decision

Create a CloudWatch alarm for:

```text
Namespace: AWS/ApplicationELB
Metric: UnHealthyHostCount
```

### Reason

Load balancer target health is an important application availability signal.

The alarm detects when one or more application targets remain unhealthy across the configured evaluation periods.

This provides monitoring independently of deployment automation.

### Current Limitation

The alarm currently provides detection only.

Amazon SNS notifications or other automated alert delivery are not implemented.

---

## Decision 20: Use One NAT Gateway for the Portfolio Environment

### Decision

Use a single NAT Gateway rather than one NAT Gateway in each Availability Zone.

### Reason

NAT Gateways generate ongoing AWS charges.

For a temporary portfolio project, reducing infrastructure cost is more important than implementing full NAT Gateway Availability Zone redundancy.

### Trade-Off

A production architecture with stronger Availability Zone independence would typically consider a NAT Gateway per Availability Zone.

This project deliberately documents the compromise rather than presenting the single-NAT architecture as maximum availability.

---

## Decision 21: Keep Monitoring and Auto Scaling as Separate Responsibilities

### Decision

Use CloudWatch alarms for detecting unhealthy targets while allowing the Auto Scaling Group and ELB health checks to manage instance health and replacement.

### Reason

Monitoring and remediation are related but separate concerns.

```text
CloudWatch
   |
   `-- Detect and report health condition

ALB / ASG
   |
   `-- Evaluate target/instance health and manage capacity
```

Keeping these responsibilities clear makes troubleshooting easier and avoids assuming that every alarm directly performs a replacement action.

---

## Decision 22: Treat the Project as Production-Style, Not Fully Production-Ready

### Decision

Describe the project as a production-style deployment rather than claiming that it represents a complete enterprise production platform.

### Reason

The project implements significant production practices, including:

- Private application instances
- Load balancing
- Auto Scaling
- IAM separation
- OIDC
- Immutable image versions
- CI/CD
- Deployment verification
- CloudWatch monitoring
- Infrastructure as Code

However, some capabilities intentionally remain outside the current scope:

- HTTPS
- Route 53 custom DNS
- AWS WAF
- SNS notifications
- Multiple NAT Gateways
- Centralised application logging
- Automatic deployment rollback
- Separate development, staging and production environments

Documenting these limitations demonstrates awareness of the difference between a strong portfolio architecture and a complete enterprise production environment.

---

# Summary

The major design principle throughout the project was separation of responsibility.

```text
Terraform
   |
   `-- Creates and manages infrastructure


GitHub Actions
   |
   `-- Builds and deploys application versions


Amazon ECR
   |
   `-- Stores immutable application images


SSM Parameter Store
   |
   `-- Stores desired deployment version


Auto Scaling Group
   |
   `-- Maintains and replaces application instances


Application Load Balancer
   |
   `-- Distributes traffic only to healthy targets


CloudWatch
   |
   `-- Observes application target health
```

Together these decisions create a deployment architecture that is reproducible, traceable, security-conscious, automated, and suitable for demonstrating practical Junior/Graduate Cloud and DevOps engineering skills.