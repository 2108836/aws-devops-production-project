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


## Day 2

### Objective
Build and deploy the AWS networking foundation using Terraform.

### Completed
- Configured the AWS Terraform provider and region variable.
- Initialised and validated the Terraform project.
- Created a custom VPC with DNS support enabled.
- Created two public and two private subnets across two Availability Zones.
- Created and attached an Internet Gateway.
- Created public and private route tables.
- Associated the correct subnets with their route tables.
- Created an Elastic IP and NAT Gateway for private subnet outbound connectivity.
- Reviewed the Terraform plan before deployment.
- Deployed 14 AWS resources using Terraform.
- Verified the VPC, subnets, route tables, and NAT Gateway in the AWS Console.
- Verified all managed resources using `terraform state list`.

### Troubleshooting / Mistakes
- Corrected Terraform resource references such as `.id`.
- Fixed exact Terraform argument names and case sensitivity.
- Fixed route table association mistakes between public and private subnets.
- Fixed an incorrectly quoted Terraform reference.
- Resolved an expired AWS authentication session.
- Verified that Terraform state and provider files are excluded from Git.

### Key Learning
Public subnets route internet traffic through an Internet Gateway, while private subnets use a NAT Gateway for outbound internet access without directly exposing backend EC2 instances.

### Next Step
Build the application compute layer, including security groups, IAM access, Launch Template, Auto Scaling Group, Target Group, and Application Load Balancer.

## Day 3 — Secure Compute and Load Balancing Foundation

- Configured separate security groups for the ALB and private EC2 instances so traffic is allowed only where required. The ALB accepts HTTP traffic from the internet, while EC2 accepts application traffic only from the ALB on port 5000.

- Created an EC2 IAM role and instance profile. EC2 can assume this role to communicate with AWS Systems Manager for secure remote management without public SSH, and to read/pull container images from Amazon ECR.

- Configured an internet-facing Application Load Balancer, listener and target group. The ALB receives requests on port 80 and forwards them to application instances on port 5000. The target group uses the `/health` endpoint to determine whether the application is healthy before sending traffic to it.

- Created a Launch Template and Auto Scaling Group for the compute layer. The Launch Template defines the AMI, instance type, EC2 security group, IAM instance profile and bootstrap user data. The Auto Scaling Group maintains the required number of EC2 instances across the private subnets and registers them with the target group. The bootstrap script installs Docker, authenticates to ECR, pulls the specified image tag and starts the application container.


## Day 4 — Containerised Application Deployment

- Created a Flask application with `/` and `/health` endpoints for application traffic and load balancer health checks.
- Built and tested the Docker image locally, verifying both application endpoints on port 5000.
- Tagged the tested Docker image using Git commit SHA `857e0df` to provide a traceable and immutable deployment version.
- Pushed the SHA-tagged Docker image to the private Amazon ECR repository.
- Applied the Terraform configuration to deploy the production-style AWS infrastructure and application workload.
- Verified that the Auto Scaling Group maintained two healthy private EC2 instances and that both targets passed the Application Load Balancer health checks.
- Confirmed the application was publicly reachable through the ALB while the EC2 instances remained private.
- Verified that the EC2 instances were manageable through AWS Systems Manager without exposing SSH port 22.
- Troubleshot Docker/ECR authentication and IAM permission issues during deployment, including Windows Docker credential handling and missing IAM role-management permissions.


## Day 5 — Automated CI/CD Deployment with GitHub Actions and OIDC

- Created a GitHub Actions deployment workflow triggered by pushes to the `main` branch.
- Configured GitHub OIDC authentication so GitHub Actions can assume an AWS IAM role using temporary credentials instead of stored AWS access keys.
- Reused the existing GitHub OIDC provider in the AWS account through a Terraform data source rather than creating a duplicate provider.
- Restricted the GitHub Actions IAM trust policy to this repository and the `main` branch using GitHub's immutable OIDC subject claim.
- Configured least-privilege GitHub Actions permissions for Amazon ECR image uploads, SSM Parameter Store updates and Auto Scaling instance refreshes.
- Created `/devops-prod/image-tag` in SSM Parameter Store to act as the deployment pointer for the currently required Docker image SHA.
- Updated the EC2 bootstrap process so new instances read the image SHA from Parameter Store, authenticate with ECR, pull the matching image and start the application container.
- Seeded ECR with the previously tested bootstrap image `857e0df` so the initial Auto Scaling Group deployment could start successfully.
- Successfully deployed the AWS infrastructure with Terraform and verified two private EC2 instances became healthy behind the Application Load Balancer.
- Pushed the CI/CD configuration to GitHub and successfully deployed image `0c2e331598590795b4102e636782191e9d0a6246` through GitHub Actions.
- Verified that GitHub Actions updated the SSM deployment pointer and started an Auto Scaling Group instance refresh.
- Confirmed replacement EC2 instances pulled and ran the exact Git SHA-tagged image from ECR and that the instance refresh completed successfully at 100%.
- Verified the application remained publicly reachable through the ALB after the automated rolling deployment.
- Troubleshot IAM permissions, Terraform resource tainting and a GitHub OIDC authentication failure caused by GitHub's immutable subject claim format.
- Removed ECR images and destroyed the Terraform-managed AWS infrastructure after testing to avoid unnecessary NAT Gateway, ALB and EC2 costs.