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