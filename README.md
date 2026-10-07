# AWS DevOps Production Deployment

## Project Overview

This project demonstrates an end-to-end deployment of a containerised Python web application on AWS using modern Cloud and DevOps practices.

The infrastructure is provisioned using Terraform and the application is deployed automatically through GitHub Actions.

The project was designed as a production-style portfolio project to demonstrate practical experience with:

- Infrastructure as Code
- AWS networking
- Docker containerisation
- CI/CD automation
- IAM and secure authentication
- Auto Scaling
- Load balancing
- Monitoring
- Immutable deployments
- Deployment verification
- Cloud troubleshooting

The application runs on private EC2 instances inside an Auto Scaling Group and is accessed through an internet-facing Application Load Balancer.

---

## Architecture

The high-level application architecture is:

```text
                         Internet
                            |
                            v
                 Application Load Balancer
                      Public Subnets
                            |
                            v
                       Target Group
                            |
                  ---------------------
                  |                   |
                  v                   v
                EC2                 EC2
            Private Subnet      Private Subnet
                  |                   |
                  ------- Auto Scaling -------
                            |
                            v
                     Docker Container
                            |
                            v
                         Gunicorn
                            |
                            v
                       Flask App
```

The EC2 application instances are deployed inside private subnets and do not require public IP addresses.

Outbound internet access for the private instances is provided through a NAT Gateway.

---

## CI/CD Deployment Architecture

Application deployments are automated using GitHub Actions.

```text
Developer pushes application change to main
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
       Push image to Amazon ECR
                    |
                    v
Update image SHA in SSM Parameter Store
                    |
                    v
   Start Auto Scaling Instance Refresh
                    |
                    v
      Replace existing EC2 instances
                    |
                    v
New EC2 instances start from Launch Template
                    |
                    v
      Bootstrap script executes
                    |
                    v
Read required image SHA from SSM
                    |
                    v
Authenticate and pull image from ECR
                    |
                    v
      Start Gunicorn container
                    |
                    v
    ALB checks application /health
                    |
                    v
  Instance Refresh completes successfully
```

The GitHub Actions workflow does not mark the deployment as successful immediately after starting the Auto Scaling Instance Refresh.

Instead, it polls AWS until the Instance Refresh reaches a successful state.

This provides stronger deployment verification because the CI/CD pipeline confirms that the replacement instances were actually deployed successfully.

---

## Technologies Used

### Cloud

- Amazon Web Services
- Amazon VPC
- Amazon EC2
- EC2 Auto Scaling
- Application Load Balancer
- Amazon ECR
- AWS Systems Manager Parameter Store
- AWS IAM
- Amazon CloudWatch
- Internet Gateway
- NAT Gateway

### Infrastructure as Code

- Terraform

### Containerisation

- Docker

### Application

- Python
- Flask
- Gunicorn

### CI/CD and Version Control

- Git
- GitHub
- GitHub Actions
- GitHub OpenID Connect

### Operating System

- Linux

---

## AWS Infrastructure

Terraform provisions the AWS infrastructure required to run the application.

The environment includes:

- Custom VPC
- Two public subnets
- Two private subnets
- Internet Gateway
- NAT Gateway
- Public route tables
- Private route tables
- Application Load Balancer
- Target Group
- ALB health checks
- EC2 Launch Template
- Auto Scaling Group
- CPU target tracking scaling policy
- Security Groups
- IAM roles and policies
- Amazon ECR repository
- Systems Manager Parameter Store parameter
- CloudWatch unhealthy-target alarm
- GitHub Actions OIDC integration

---

## Networking Design

The application uses a segmented VPC design.

```text
VPC
|
|-- Public Subnet - Availability Zone 1
|      |
|      `-- Application Load Balancer
|
|-- Public Subnet - Availability Zone 2
|      |
|      `-- Application Load Balancer
|
|-- Private Subnet - Availability Zone 1
|      |
|      `-- EC2 Application Instance
|
`-- Private Subnet - Availability Zone 2
       |
       `-- EC2 Application Instance
```

The Application Load Balancer is internet-facing.

The EC2 application instances remain private.

Public traffic therefore follows this path:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
EC2 Security Group
   |
   v
Application port 5000
```

Private EC2 instances use the NAT Gateway for outbound internet access when required.

---

## Security Design

Security was an important part of the architecture.

### Private EC2 Instances

Application servers run inside private subnets.

They do not require public IP addresses.

---

### Restricted Application Traffic

The EC2 Security Group allows application traffic on port `5000` only from the Application Load Balancer Security Group.

The application instances are therefore not directly exposed to the internet.

---

### No Static AWS Credentials in GitHub

GitHub Actions authenticates with AWS using OpenID Connect.

```text
GitHub Actions
      |
      v
GitHub OIDC Token
      |
      v
AWS STS
      |
      v
Temporary AWS Credentials
```

No long-lived AWS access key or secret key is stored in GitHub.

---

### Separate IAM Roles

Different IAM roles are used for different responsibilities.

```text
GitHub Actions Role
        |
        |-- Push Docker image to ECR
        |-- Update SSM Parameter
        |-- Start Instance Refresh
        `-- Check Instance Refresh status


EC2 Instance Role
        |
        |-- Read deployment value from SSM
        |-- Authenticate with ECR
        |-- Pull Docker image
        `-- Communicate with Systems Manager
```

This separates deployment permissions from application-instance permissions.

---

## Application Runtime

The web application is written using Flask.

For production-style execution, the application runs using Gunicorn rather than Flask's built-in development server.

The Docker container starts using:

```text
gunicorn --bind 0.0.0.0:5000 app:app
```

The application listens on:

```text
Port 5000
```

The Application Load Balancer forwards traffic to this port.

---

## Docker

The application is packaged as a Docker image.

The image contains:

- Python runtime
- Flask
- Gunicorn
- Application source code

A simplified container flow is:

```text
Dockerfile
   |
   v
Install Python dependencies
   |
   v
Copy application
   |
   v
Start Gunicorn
   |
   v
Flask application
```

---

## Immutable Image Versioning

Docker images are not deployed using a mutable `latest` tag.

Each deployment uses the Git commit SHA.

Example:

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

The deployment can therefore be traced directly back to the Git commit that produced it.

```text
Git Commit SHA
      =
Docker Image Tag
      =
SSM Deployment Value
      =
Application Version
```

This improves deployment traceability and removes ambiguity about which application version should be running.

---

## Amazon ECR

Amazon Elastic Container Registry stores the application Docker images.

The CI/CD workflow:

```text
Build image
   |
   v
Tag with Git SHA
   |
   v
Authenticate to ECR
   |
   v
Push image
```

Example deployment image:

```text
devops-prod-app:3552949e4dd15854bb3f7559ed184a648156c53a
```

---

## Systems Manager Parameter Store

AWS Systems Manager Parameter Store is used as the deployment pointer.

The parameter is:

```text
/devops-prod/image-tag
```

Terraform creates and manages the parameter resource.

GitHub Actions updates its value whenever a new application version is deployed.

Example:

```text
/devops-prod/image-tag
        |
        v
3552949e4dd15854bb3f7559ed184a648156c53a
```

New EC2 instances read this value during bootstrap to determine which Docker image should be pulled from ECR.

---

## Terraform and Application Deployment Separation

Infrastructure lifecycle and application deployment lifecycle are intentionally separated.

Terraform manages:

```text
AWS infrastructure
IAM resources
Networking
Load Balancer
Auto Scaling
ECR repository
SSM parameter resource
Monitoring
```

GitHub Actions manages:

```text
Docker image build
Docker image push
Deployment SHA
SSM parameter value
Auto Scaling Instance Refresh
Deployment verification
```

The SSM parameter uses Terraform lifecycle configuration so future Terraform operations do not overwrite the application version deployed by GitHub Actions.

---

## EC2 Bootstrap Process

When an EC2 instance starts, its bootstrap process performs the application deployment.

The process is approximately:

```text
EC2 starts
   |
   v
Install/start Docker
   |
   v
Read image SHA from SSM
   |
   v
Identify ECR registry
   |
   v
Authenticate to ECR
   |
   v
Pull exact SHA-tagged image
   |
   v
Start Docker container
   |
   v
Gunicorn starts Flask application
```

This means EC2 instances do not contain a permanently hard-coded application version.

They retrieve the currently required version when they start.

---

## Auto Scaling

The application runs inside an EC2 Auto Scaling Group.

Current configuration:

```text
Minimum capacity: 2
Desired capacity: 2
Maximum capacity: 4
```

This ensures that the application normally runs across two EC2 instances while allowing additional capacity when required.

---

## CPU Target Tracking

A target tracking Auto Scaling policy monitors average CPU utilisation.

The target is approximately:

```text
50% average CPU utilisation
```

The Auto Scaling Group can adjust desired capacity between the configured minimum and maximum values based on CPU demand.

Conceptually:

```text
CPU load increases
      |
      v
Average CPU exceeds target
      |
      v
ASG increases desired capacity
      |
      v
Additional EC2 instance starts
```

Capacity can also decrease again when demand falls.

---

## Application Load Balancer

An Application Load Balancer distributes requests between the EC2 instances.

```text
                  ALB
                   |
             -------------
             |           |
             v           v
           EC2-1       EC2-2
```

The ALB forwards requests only to healthy registered targets.

---

## Health Checks

The Target Group checks:

```text
/health
```

The application returns a successful HTTP response when healthy.

If an instance becomes unhealthy, the Load Balancer stops routing application traffic to that target.

The Auto Scaling Group also uses ELB health information when managing the instances.

---

## Deployment Using Auto Scaling Instance Refresh

Updating the SSM parameter alone does not restart existing EC2 instances.

Therefore, after publishing a new application version, GitHub Actions starts an Auto Scaling Instance Refresh.

```text
Existing EC2 instances
        |
        v
Instance Refresh starts
        |
        v
New instance launches
        |
        v
Reads new SHA from SSM
        |
        v
Pulls new Docker image
        |
        v
Passes ALB health checks
        |
        v
Old instance removed
```

The process continues until the instances in the Auto Scaling Group have been replaced.

---

## CI/CD Deployment Verification

A key improvement in the project is that the workflow waits for the AWS deployment to complete.

After starting the Instance Refresh, GitHub Actions stores the refresh ID and periodically checks its status.

Conceptually:

```text
StartInstanceRefresh
        |
        v
Receive InstanceRefreshId
        |
        v
DescribeInstanceRefreshes
        |
        v
     InProgress
        |
        v
     InProgress
        |
        v
     Successful
        |
        v
GitHub Actions job succeeds
```

If the deployment fails, is cancelled, rolls back, or exceeds the configured timeout, the CI/CD workflow fails instead of incorrectly reporting success.

---

## Monitoring

Amazon CloudWatch monitors the health of the application targets.

The project includes a CloudWatch alarm for:

```text
Namespace:
AWS/ApplicationELB

Metric:
UnHealthyHostCount
```

The alarm detects unhealthy targets behind the Application Load Balancer.

The implemented monitoring provides health detection.

Automatic notification through services such as Amazon SNS is not currently implemented.

---

## Final Deployment Verification

The final deployment was verified across multiple layers.

### GitHub Actions

The final CI/CD workflow completed successfully.

```text
GitHub Actions: Successful
```

---

### ECR Image Verification

The final Git SHA was successfully stored as an ECR image tag.

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

Image digest:

```text
sha256:0bccb8808974d504ad9575b958bad4fa5940287182421714f23fe487c2cc3dae
```

---

### SSM Verification

Systems Manager Parameter Store contained the same Git SHA:

```text
3552949e4dd15854bb3f7559ed184a648156c53a
```

This confirmed:

```text
Git commit
    =
ECR image
    =
SSM deployment value
```

---

### Auto Scaling Verification

After the deployment, the Auto Scaling Group contained two replacement instances:

```text
i-09295b0987e55fd00   InService   Healthy
i-0ee322de733af464d   InService   Healthy
```

The previous instances had been replaced by the Instance Refresh.

---

### Target Group Verification

Both replacement EC2 instances became healthy ALB targets:

```text
i-09295b0987e55fd00   healthy
i-0ee322de733af464d   healthy
```

---

### Application Verification

The application was accessed through the Application Load Balancer and returned:

```text
Hello from the AWS DevOps production app!
```

This confirmed that traffic successfully travelled through:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Target Group
   |
   v
Private EC2
   |
   v
Docker
   |
   v
Gunicorn
   |
   v
Flask
```

---

## CloudWatch Verification

The unhealthy-target CloudWatch alarm was verified in the:

```text
OK
```

state while the application targets were healthy.

---

## Troubleshooting Experience

This project also involved practical troubleshooting rather than only successful deployments.

Examples included:

### GitHub OIDC Trust Policy

GitHub Actions initially failed to assume the AWS IAM role because the OIDC subject did not match the repository's actual token subject.

The trust policy was corrected to restrict access to the required repository and branch.

This reinforced the difference between:

```text
IAM Trust Policy = WHO can assume the role

IAM Permissions Policy = WHAT the role can do
```

---

### IAM Permission Troubleshooting

Additional AWS API permissions were required when deployment verification was added.

The GitHub Actions role required permission to check Auto Scaling Instance Refresh status.

The final permissions separate resource-specific deployment actions from AWS Describe operations where resource-level restriction is not supported.

---

### Docker / ECR Push Troubleshooting

During the final deployment, Docker image uploads to ECR experienced network/proxy-related timeout and broken-pipe errors.

Docker was configured to reduce concurrent image-layer uploads:

```json
"max-concurrent-uploads": 1
```

The ECR image push then completed successfully.

This provided practical experience troubleshooting Docker Desktop networking and registry uploads rather than treating the issue as an AWS infrastructure failure.

---

### Session Manager IAM Troubleshooting

The EC2 instance itself was successfully managed by Systems Manager:

```text
SSM Agent: Online
EC2 IAM role: Attached
Instance status: Healthy
```

However, the human IAM user did not have sufficient permissions to start an interactive Session Manager session.

This demonstrated the difference between:

```text
EC2 instance IAM role
```

and:

```text
Human/operator IAM permissions
```

The issue was therefore correctly identified as an operator IAM permission problem rather than an EC2 networking or SSM Agent failure.

---

## Key Engineering Decisions

### 1. Private EC2 Instances

Application instances are not directly exposed to the public internet.

Traffic enters through the Application Load Balancer.

---

### 2. Git SHA Image Tags

Immutable Git SHA tags are used instead of `latest`.

This improves traceability and deployment reliability.

---

### 3. SSM as Deployment Pointer

Systems Manager Parameter Store separates the infrastructure configuration from the deployed application version.

---

### 4. GitHub OIDC Authentication

OIDC avoids storing long-lived AWS credentials inside GitHub.

---

### 5. Instance Refresh Deployment

Existing EC2 instances are replaced after each application deployment so that new instances start using the updated application image.

---

### 6. CI/CD Waits for Deployment Completion

The pipeline does not consider the deployment successful until AWS reports that the Instance Refresh completed successfully.

---

### 7. Gunicorn Runtime

Gunicorn is used instead of Flask's development server for a more appropriate production-style runtime.

---

### 8. Single NAT Gateway

The project uses one NAT Gateway to reduce the cost of the portfolio environment.

A highly available production implementation could use one NAT Gateway per Availability Zone.

---

## Key Repository Files

```text
aws-devops-production-project/
|
|-- .github/
|   `-- workflows/
|       `-- deploy.yml
|
|-- app/
|   |-- app.py
|   |-- Dockerfile
|   `-- requirements.txt
|
|-- infrastructure/
|   `-- terraform/
|       |-- compute.tf
|       |-- cicd.tf
|       |-- deployment.tf
|       |-- iam.tf
|       |-- load_balancer.tf
|       |-- monitoring.tf
|       `-- bootstrap.sh.tftpl
|
|-- docs/
|
`-- README.md
```

---

## Application Deployment Flow

The complete application deployment can be summarised as:

```text
Application change
      |
      v
git push main
      |
      v
GitHub Actions
      |
      v
OIDC temporary AWS credentials
      |
      v
Docker build
      |
      v
Git SHA image tag
      |
      v
Amazon ECR
      |
      v
SSM Parameter Store updated
      |
      v
ASG Instance Refresh
      |
      v
New EC2 instance
      |
      v
Bootstrap script
      |
      v
Read SHA from SSM
      |
      v
Pull exact image from ECR
      |
      v
Run Gunicorn container
      |
      v
ALB /health check
      |
      v
Healthy target
      |
      v
Application receives traffic
```

---

## Infrastructure Deployment

Terraform is used to provision the AWS infrastructure.

Typical Terraform workflow:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Infrastructure can later be removed using:

```bash
terraform destroy
```

Terraform configuration should always be reviewed before applying or destroying resources.

---

## Local Application Testing

The application can be built locally using Docker.

```bash
docker build -t devops-prod-app ./app
```

Run the container:

```bash
docker run -d -p 5000:5000 --name devops-prod-app devops-prod-app
```

Test the application:

```bash
curl http://localhost:5000/
```

Test the health endpoint:

```bash
curl http://localhost:5000/health
```

---

## Limitations

This project demonstrates production-style engineering practices, but it is a portfolio environment rather than a complete enterprise production platform.

Current limitations include:

- HTTP rather than HTTPS
- Single NAT Gateway
- No Route 53 custom domain
- No SNS alarm notifications
- No AWS WAF
- No centralised application log aggregation
- No automated post-deployment integration test suite
- No automatic deployment rollback implementation
- Single application environment rather than separate development, staging, and production environments

These limitations are intentionally documented rather than hidden.

---

## Potential Future Improvements

Possible future improvements include:

- HTTPS using AWS Certificate Manager
- Route 53 DNS
- CloudWatch dashboards
- SNS alert notifications
- Centralised application logging
- AWS WAF
- Automated integration testing
- Automated deployment rollback
- Secrets Manager for application secrets
- Multiple NAT Gateways for stronger Availability Zone independence
- Separate development, staging, and production environments
- Remote Terraform state using S3
- Terraform state locking
- Additional security monitoring
- Container vulnerability scanning improvements

---

## Cost Management

This infrastructure includes AWS resources that may generate ongoing charges, particularly:

- NAT Gateway
- Application Load Balancer
- EC2 instances

The environment is intended to be deployed temporarily for development, testing, and portfolio demonstration.

After verification, the AWS resources can be destroyed with Terraform to prevent unnecessary ongoing charges.

---

## What This Project Demonstrates

This project demonstrates practical understanding of how different Cloud and DevOps components work together rather than treating them as isolated tools.

```text
Terraform
    |
    v
AWS Infrastructure
    |
    v
Networking + IAM + Compute
    |
    v
Docker
    |
    v
Amazon ECR
    |
    v
GitHub Actions
    |
    v
Immutable Deployment
    |
    v
Auto Scaling Instance Refresh
    |
    v
Load Balancing
    |
    v
CloudWatch Monitoring
```

Key skills demonstrated include:

- Designing AWS network architecture
- Building infrastructure using Terraform
- Containerising Python applications with Docker
- Using Gunicorn as an application server
- Configuring Application Load Balancers
- Designing Auto Scaling Groups
- Implementing CPU-based target tracking
- Working with AWS IAM roles and policies
- Implementing GitHub Actions CI/CD
- Authenticating through GitHub OIDC
- Publishing immutable Docker images to ECR
- Managing deployment state through SSM
- Performing rolling deployments through Instance Refresh
- Monitoring ALB target health using CloudWatch
- Troubleshooting IAM, Docker, AWS and CI/CD issues
- Verifying deployments across multiple infrastructure layers

---

## Project Status

**Completed**

The project successfully demonstrates the following end-to-end lifecycle:

```text
Infrastructure as Code
        |
        v
Containerisation
        |
        v
Secure CI/CD
        |
        v
Immutable Deployment
        |
        v
Auto Scaling
        |
        v
Load Balancing
        |
        v
Monitoring
        |
        v
Deployment Verification
```

The AWS infrastructure is designed to be destroyed after final testing to minimise portfolio-environment costs.