# Architecture

## Architecture Overview

This project deploys a containerised Python application on AWS using a production-style architecture.

The application runs on private EC2 instances managed by an Auto Scaling Group. Incoming user traffic is handled by an internet-facing Application Load Balancer.

Application deployments are automated through GitHub Actions using GitHub OIDC, Amazon ECR, AWS Systems Manager Parameter Store, and Auto Scaling Instance Refresh.

---

## Runtime Request Flow

```text
User
 |
 v
Internet
 |
 v
Application Load Balancer
 |
 v
Target Group
 |
 v
Healthy EC2 Instance
 |
 v
Docker Container
 |
 v
Gunicorn
 |
 v
Flask Application
```

When a user sends a request, it first reaches the internet-facing Application Load Balancer.

The ALB forwards the request to the Target Group.

The Target Group continuously checks the health of registered EC2 instances using the `/health` endpoint.

Traffic is forwarded only to healthy application instances.

Each EC2 instance runs the application inside a Docker container using Gunicorn as the application server.

The EC2 instances are located in private subnets and are not directly accessible from the public internet.

---

# Network Architecture

The project uses a custom VPC:

```text
10.0.0.0/16
```

The VPC contains:

```text
VPC
|
|-- Public Subnet 1
|      |
|      |-- Application Load Balancer
|      `-- NAT Gateway
|
|-- Public Subnet 2
|      |
|      `-- Application Load Balancer
|
|-- Private Subnet 1
|      |
|      `-- EC2 Application Instance
|
`-- Private Subnet 2
       |
       `-- EC2 Application Instance
```

The subnets are distributed across two Availability Zones.

---

## Public Subnets

The public subnets are associated with a route table containing:

```text
0.0.0.0/0
    |
    v
Internet Gateway
```

This allows internet-facing infrastructure such as the Application Load Balancer and NAT Gateway to communicate with the internet.

---

## Private Subnets

The application EC2 instances run in private subnets.

The private route table contains:

```text
0.0.0.0/0
    |
    v
NAT Gateway
```

This allows the EC2 instances to make outbound internet connections while preventing direct inbound internet access.

Typical outbound operations include:

- Downloading operating system packages
- Installing Docker dependencies
- Communicating with required AWS endpoints
- Pulling Docker images from Amazon ECR

---

## Internet Gateway

The Internet Gateway provides internet connectivity for resources in the public subnets.

The public route table directs internet-bound traffic to the Internet Gateway.

---

## NAT Gateway

A NAT Gateway provides outbound internet access for EC2 instances located in private subnets.

The application instances can initiate outbound connections without requiring public IP addresses.

A single NAT Gateway is used in this project to reduce portfolio-environment cost.

A higher-availability production design could use one NAT Gateway per Availability Zone.

---

# Load Balancing Architecture

## Application Load Balancer

The Application Load Balancer is deployed across the two public subnets.

It accepts incoming HTTP traffic on:

```text
Port 80
```

The listener forwards requests to the application Target Group.

```text
Internet
   |
   v
ALB :80
   |
   v
Target Group
   |
   v
EC2 :5000
```

The project currently uses HTTP rather than HTTPS.

HTTPS using AWS Certificate Manager could be added as a future improvement.

---

## Target Group

The Target Group contains the EC2 application instances.

Traffic is forwarded to:

```text
Protocol: HTTP
Port: 5000
```

The health check uses:

```text
Path: /health
Protocol: HTTP
Port: traffic-port
```

Only healthy targets receive application traffic.

---

# Compute Architecture

## Launch Template

The EC2 Launch Template defines how application instances are created.

It includes:

- Amazon Machine Image
- EC2 instance type
- EC2 Security Group
- IAM instance profile
- Bootstrap User Data

The bootstrap script prepares each new instance automatically.

---

## Auto Scaling Group

The Launch Template is used by an Auto Scaling Group.

Current capacity configuration:

```text
Minimum: 2
Desired: 2
Maximum: 4
```

The instances are distributed across the two private subnets.

The Auto Scaling Group registers the instances with the Application Load Balancer Target Group.

---

## CPU Target Tracking

The Auto Scaling Group includes a target tracking policy using:

```text
ASGAverageCPUUtilization
```

Target value:

```text
50%
```

Conceptually:

```text
CPU demand increases
        |
        v
Average CPU rises above target
        |
        v
Auto Scaling adjusts desired capacity
        |
        v
Additional EC2 capacity can be launched
```

The Auto Scaling Group operates within the configured minimum and maximum limits.

---

# Application Runtime

The application is written using Python and Flask.

The application is packaged inside a Docker image.

Gunicorn is used as the application server.

Container startup:

```text
gunicorn --bind 0.0.0.0:5000 app:app
```

The runtime flow inside an instance is:

```text
EC2
 |
 v
Docker
 |
 v
Gunicorn
 |
 v
Flask
 |
 v
Port 5000
```

---

# EC2 Bootstrap Architecture

When a new EC2 instance starts, Terraform-provided User Data executes the bootstrap script.

The deployment flow is:

```text
EC2 starts
 |
 v
Bootstrap script executes
 |
 v
Docker is prepared
 |
 v
Read image tag from SSM Parameter Store
 |
 v
Determine ECR registry
 |
 v
Authenticate to Amazon ECR
 |
 v
Pull exact SHA-tagged image
 |
 v
Start Docker container
 |
 v
Gunicorn starts Flask application
 |
 v
ALB health check
```

The application image version is therefore not permanently hard-coded into the Launch Template.

The instance retrieves the currently required image version from Systems Manager Parameter Store when it starts.

---

# Container Registry Architecture

Amazon Elastic Container Registry stores the application Docker images.

Each deployment image is tagged with the Git commit SHA.

Example:

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

This provides an immutable relationship between source code and deployed container image:

```text
Git Commit SHA
      =
ECR Image Tag
```

---

# Deployment Pointer

AWS Systems Manager Parameter Store stores the application image version that new EC2 instances should deploy.

Parameter:

```text
/devops-prod/image-tag
```

Example value:

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

The complete relationship is:

```text
Git Commit
    =
Docker Image Tag
    =
SSM Parameter Value
    =
Required Application Version
```

Terraform manages the existence and configuration of the parameter.

GitHub Actions manages the deployment value.

Terraform uses a lifecycle rule to prevent later infrastructure operations from overwriting the image version deployed by CI/CD.

---

# CI/CD Architecture

Application deployments are performed using GitHub Actions.

The workflow is triggered when application files under:

```text
app/**
```

are changed on the `main` branch.

This prevents documentation-only changes from unnecessarily triggering an application deployment.

---

## Deployment Flow

```text
Application change pushed to main
              |
              v
       GitHub Actions
              |
              v
Authenticate to AWS using OIDC
              |
              v
      Build Docker image
              |
              v
Tag image with Git commit SHA
              |
              v
     Push image to ECR
              |
              v
Update SSM deployment parameter
              |
              v
Start Auto Scaling Instance Refresh
              |
              v
Replace existing EC2 instances
              |
              v
New instances read SHA from SSM
              |
              v
Pull exact image from ECR
              |
              v
Start application container
              |
              v
Pass ALB health checks
              |
              v
Instance Refresh succeeds
```

---

# GitHub OIDC Authentication

GitHub Actions does not use long-lived AWS access keys.

Instead, GitHub uses OpenID Connect.

```text
GitHub Actions
      |
      v
GitHub OIDC token
      |
      v
AWS STS
      |
      v
Assume GitHub Actions IAM Role
      |
      v
Temporary AWS credentials
```

The IAM trust policy restricts which GitHub identity is allowed to assume the deployment role.

This provides stronger security than storing permanent AWS access keys inside GitHub Secrets.

---

# Deployment Verification

Starting an Auto Scaling Instance Refresh does not mean that the deployment has completed.

The GitHub Actions workflow therefore captures the Instance Refresh ID.

It then repeatedly queries AWS:

```text
StartInstanceRefresh
        |
        v
InstanceRefreshId
        |
        v
DescribeInstanceRefreshes
        |
        v
Pending / InProgress
        |
        v
Successful
```

The workflow succeeds only after AWS reports:

```text
Successful
```

Failure, cancellation, rollback-related outcomes, or deployment timeout cause the workflow to fail.

This ensures that a green CI/CD workflow represents a completed deployment rather than only a successfully accepted AWS API request.

---

# Auto Scaling Instance Refresh

Updating the SSM image tag does not restart existing EC2 instances.

An Instance Refresh is therefore used to replace them.

```text
Existing EC2 instances
        |
        v
Instance Refresh
        |
        v
New EC2 instance starts
        |
        v
Bootstrap reads new SHA
        |
        v
New Docker image pulled
        |
        v
Application starts
        |
        v
ALB health check passes
        |
        v
Old instance removed
```

This process provides a rolling application deployment using the Auto Scaling Group.

---

# IAM Architecture

The project uses separate IAM responsibilities for application instances and CI/CD.

## EC2 IAM Role

The EC2 instances use:

```text
devops-prod-ec2-role
```

The role enables instances to perform required operations such as:

```text
EC2
 |
 |-- Systems Manager communication
 |-- Read deployment parameter from SSM
 `-- Read application image from ECR
```

An instance profile attaches the IAM role to instances created from the Launch Template.

---

## GitHub Actions IAM Role

GitHub Actions assumes:

```text
devops-prod-github-actions-role
```

Its deployment permissions include operations required to:

- Authenticate to ECR
- Upload Docker images
- Update the SSM deployment parameter
- Start Auto Scaling Instance Refresh
- Read Instance Refresh status

The GitHub Actions role and EC2 role are separate because they perform different responsibilities.

---

# Security Group Architecture

## ALB Security Group

The ALB Security Group accepts HTTP traffic from the internet:

```text
Internet
   |
   v
ALB Security Group
Port 80
```

The ALB can send application traffic toward the EC2 instances.

---

## EC2 Security Group

The EC2 Security Group allows application traffic on:

```text
Port 5000
```

but only when the source is the ALB Security Group.

```text
ALB Security Group
        |
        v
EC2 Security Group :5000
```

The backend application instances are therefore not directly exposed to public application traffic.

---

# Systems Manager Architecture

AWS Systems Manager is used for two separate purposes in the project.

## Parameter Store

Parameter Store stores the currently required Docker image SHA.

```text
/devops-prod/image-tag
```

New EC2 instances read this value during bootstrap.

---

## EC2 Management

The EC2 IAM role and SSM Agent allow the private instances to be managed without exposing public SSH access.

The application architecture does not require inbound SSH port `22`.

Interactive Session Manager access also depends on the human/operator IAM identity having the required permissions.

---

# Monitoring Architecture

Amazon CloudWatch monitors Application Load Balancer target health.

The project contains a CloudWatch alarm using:

```text
Namespace: AWS/ApplicationELB

Metric: UnHealthyHostCount

Statistic: Maximum

Threshold: 1

Evaluation periods: 2

Period: 60 seconds
```

The alarm detects unhealthy application targets.

```text
ALB Target Group
       |
       v
UnHealthyHostCount
       |
       v
CloudWatch Alarm
```

The current project implements detection but does not send notifications through SNS.

---

# Infrastructure as Code Architecture

Terraform manages the AWS infrastructure.

Key responsibilities include:

```text
Terraform
 |
 |-- VPC
 |-- Subnets
 |-- Internet Gateway
 |-- NAT Gateway
 |-- Route Tables
 |-- Security Groups
 |-- IAM
 |-- ECR
 |-- SSM parameter resource
 |-- Application Load Balancer
 |-- Target Group
 |-- Launch Template
 |-- Auto Scaling Group
 |-- Auto Scaling policy
 |-- CloudWatch alarm
 `-- GitHub OIDC IAM configuration
```

This makes the infrastructure reproducible and reviewable as code.

---

# Infrastructure vs Deployment Ownership

Infrastructure lifecycle and application deployment lifecycle are deliberately separated.

```text
Terraform
   |
   v
Infrastructure ownership
```

Terraform manages AWS resources.

```text
GitHub Actions
   |
   v
Application deployment ownership
```

GitHub Actions manages application image deployment.

This separation prevents ordinary application deployments from requiring a complete Terraform infrastructure deployment.

---

# Final End-to-End Architecture

```text
                         USER
                           |
                           v
                       INTERNET
                           |
                           v
              APPLICATION LOAD BALANCER
                   PUBLIC SUBNETS
                           |
                           v
                     TARGET GROUP
                           |
              -------------------------
              |                       |
              v                       v
            EC2                     EC2
       PRIVATE SUBNET 1        PRIVATE SUBNET 2
              |                       |
              -------- AUTO SCALING --
                           |
                           v
                        DOCKER
                           |
                           v
                       GUNICORN
                           |
                           v
                         FLASK
```

Application deployment:

```text
Developer
    |
    v
Git Push
    |
    v
GitHub Actions
    |
    v
GitHub OIDC
    |
    v
AWS IAM Role
    |
    v
Docker Build
    |
    v
Git SHA Tag
    |
    v
Amazon ECR
    |
    v
SSM Parameter Store
    |
    v
ASG Instance Refresh
    |
    v
New EC2 Instances
    |
    v
Read SHA from SSM
    |
    v
Pull Image from ECR
    |
    v
Docker + Gunicorn + Flask
    |
    v
ALB Health Check
    |
    v
Deployment Successful
```

---

# Availability and Cost Trade-Offs

The application is distributed across two private subnets and two Availability Zones.

The Application Load Balancer also spans two public subnets.

The Auto Scaling Group maintains multiple application instances for improved availability.

However, only one NAT Gateway is used.

This is a deliberate cost optimisation for a portfolio environment.

A higher-availability production architecture could deploy one NAT Gateway in each Availability Zone.

---

# Current Limitations

The current architecture intentionally does not include:

- HTTPS termination
- Route 53 custom DNS
- AWS WAF
- SNS alarm notifications
- Multiple NAT Gateways
- Centralised application log aggregation
- Automatic deployment rollback
- Separate development, staging and production environments

These are potential future improvements rather than components currently implemented in the project.