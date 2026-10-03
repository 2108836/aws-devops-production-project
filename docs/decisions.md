# Architecture Decisions

## Decision 1: Use Terraform for Infrastructure as Code

**Reason:**

Terraform allows the AWS infrastructure to be defined as code instead of creating resources manually through the AWS Console. This makes the infrastructure repeatable, consistent, and easier to manage.

Using Infrastructure as Code also reduces the risk of manual configuration mistakes and allows infrastructure changes to be tracked through Git version control.

Before applying changes, `terraform plan` can be used to review what Terraform intends to create, modify, or destroy.

## Decision 2: Keep EC2 Instances in Private Subnets

**Reason:**

Keeping EC2 instances in private subnets reduces direct exposure to the public internet.

Users access the application through the public Application Load Balancer instead of connecting directly to the EC2 instances.

The EC2 Security Group can allow application traffic only from the ALB Security Group, which reduces the attack surface.

Administrative access can be handled through AWS Systems Manager instead of exposing SSH port 22 to the internet.

## Decision 3: Use Amazon ECR for Container Images

**Reason:**

Amazon ECR provides a private AWS-native container registry for storing Docker images securely.

Because ECR integrates with IAM, access to push and pull images can be controlled using AWS roles and permissions instead of sharing long-lived registry credentials.

It also integrates well with EC2 and GitHub Actions, which makes automated image deployment simpler and easier to manage.

## Decision 4: Use GitHub OIDC with IAM Roles

**Reason:**

GitHub OIDC allows GitHub Actions to authenticate with AWS using short-lived temporary credentials instead of storing permanent AWS access keys.

This improves security because long-lived credentials do not need to be saved in the GitHub repository or GitHub Secrets.

OIDC also integrates well with GitHub Actions and AWS IAM, making automated deployments more secure and easier to manage.

## Decision 5: Use Commit-Based Docker Image Tags

**Reason:**

Using commit-based Docker image tags makes each image version uniquely identifiable and traceable back to a specific Git commit.

This makes deployments easier to audit and helps us identify the exact image version that is currently running.

If a deployment fails, the previous known-good image tag can be used for a fast and reliable rollback instead of relying only on the ambiguous `latest` tag.


## Private EC2 Behind an Application Load Balancer

The application EC2 instances are placed in private subnets so they are not directly exposed to the internet. Public user traffic enters through the internet-facing Application Load Balancer, which forwards only the required application traffic to the private EC2 instances.

The private subnets use a private route table with a NAT Gateway for outbound internet access, allowing the instances to reach services such as ECR and Systems Manager without receiving public IP addresses. This reduces the attack surface and keeps the application servers isolated from direct public access.