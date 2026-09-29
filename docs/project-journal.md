# Project Journal

## Day 1

### Objective
Define the project requirements, initialise the repository, and design the first version of the AWS architecture.

### Completed
- Created the initial project folder structure.
- Initialised Git and changed the default branch to `main`.
- Created the initial `.gitignore` and `README.md`.
- Created the first Git commit.
- Defined the main technical requirements.
- Designed the runtime request flow.
- Documented the main AWS infrastructure components.
- Documented key architecture and security decisions.

### Key Decisions
- Use Terraform for Infrastructure as Code.
- Keep EC2 instances in private subnets.
- Use an internet-facing Application Load Balancer.
- Use Amazon ECR for Docker images.
- Use GitHub OIDC with IAM roles.
- Use commit-based Docker image tags.
- Use SSM instead of exposing SSH publicly.

### Concepts Reviewed
- ALB and Target Groups
- Auto Scaling Groups
- Launch Templates
- Public and private subnets
- NAT Gateway
- Security Groups
- AWS Systems Manager
- IAM Roles
- Amazon ECR
- Rolling deployments and rollback

### Next Step
Begin building the AWS network infrastructure with Terraform.