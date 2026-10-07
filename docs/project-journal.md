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

## Day 6 — Production Hardening, Monitoring and Final Deployment Verification

- Replaced the Flask development server with Gunicorn to provide a more appropriate production-style application runtime inside the Docker container.
- Built and tested the updated Docker image locally and verified both the application and `/health` endpoints successfully.
- Added a CPU target tracking Auto Scaling policy configured to maintain approximately 50% average CPU utilisation while scaling between the existing minimum and maximum ASG capacity.
- Added an Amazon CloudWatch alarm monitoring the Application Load Balancer `UnHealthyHostCount` metric to detect unhealthy application targets.
- Extended the GitHub Actions IAM permissions so the deployment workflow can query Auto Scaling Instance Refresh status after starting a deployment.
- Improved the GitHub Actions workflow so it captures the Instance Refresh ID and polls AWS until the refresh completes successfully instead of reporting success immediately after the refresh request is accepted.
- Added deployment failure handling for failed, cancelled and rollback-related Instance Refresh states, together with a deployment timeout.
- Added an `app/**` workflow path filter so documentation-only changes do not unnecessarily trigger application deployments.
- Rebuilt the AWS infrastructure with Terraform and verified two EC2 application instances became `InService` and healthy behind the Application Load Balancer.
- Verified the CPU target tracking policy was configured correctly and the CloudWatch unhealthy-target alarm remained in the `OK` state.
- Completed the final end-to-end CI/CD deployment through GitHub Actions using Git commit SHA `3552949e4dd15854bb3f7559ed184a648156c53a`.
- Verified the same Git SHA was stored as the Amazon ECR image tag and as the deployment value in SSM Parameter Store.
- Confirmed the Auto Scaling Instance Refresh replaced the previous EC2 instances with new healthy instances.
- Verified replacement instances `i-09295b0987e55fd00` and `i-0ee322de733af464d` were both `InService` and healthy.
- Confirmed both replacement instances registered successfully as healthy Application Load Balancer targets.
- Verified the deployed application remained publicly reachable through the Application Load Balancer after the completed rolling deployment.
- Troubleshot Docker Desktop and Amazon ECR image upload failures caused by proxy/network upload behaviour. Reduced Docker concurrent layer uploads to allow the image push to complete successfully.
- Identified a Session Manager console access failure as an IAM permission issue on the human `devops-user` identity rather than an EC2 networking, instance-role or SSM Agent problem. The target EC2 instance remained healthy and its SSM Agent was online.
- Updated the project README to document the final architecture, CI/CD deployment flow, security model, monitoring, Auto Scaling, immutable deployment strategy, troubleshooting experience, limitations and future improvements.

### Key Learning

A successful deployment should be verified across the complete delivery path rather than relying only on a successful CI/CD command.

The final deployment was validated through:

`Git commit → GitHub Actions → ECR image → SSM deployment pointer → Auto Scaling Instance Refresh → replacement EC2 instances → ALB health checks → application response`

The project also reinforced the importance of separating infrastructure management from application deployment, using immutable application versions, monitoring deployment progress, applying least-privilege IAM, and diagnosing problems at the correct layer.

### Next Step

Complete the remaining project documentation, perform final repository checks, remove temporary local deployment credentials and test containers, and destroy the AWS infrastructure to avoid unnecessary NAT Gateway, Application Load Balancer and EC2 costs.