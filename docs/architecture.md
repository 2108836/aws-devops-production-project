# Architecture

## Runtime Request Flow

User → Internet → Application Load Balancer (ALB) → Target Group → Healthy EC2 Instance → Docker Container → Python Application

When a user sends a request to the application, the request first reaches the internet-facing Application Load Balancer.

The ALB forwards the request to a Target Group. The Target Group keeps track of the health status of the registered EC2 instances through health checks.

The ALB then sends traffic only to a healthy EC2 instance. The EC2 instance runs the application inside a Docker container, and the Python application processes the request and returns the response back to the user.

The EC2 instances are placed in private subnets so that users cannot access them directly from the internet. Only the ALB is publicly accessible.

## Infrastructure Components

### Application Load Balancer
The Application Load Balancer receives incoming HTTP/HTTPS requests from users and forwards them to healthy backend targets registered in the Target Group.

### Target Group
The Target Group contains the backend EC2 instances and monitors their health using health checks. The ALB sends traffic only to healthy registered targets.

### Auto Scaling Group
The Auto Scaling Group maintains the required number of EC2 instances. If an instance becomes unhealthy or fails, the ASG can automatically replace it with a new instance.

### Launch Template
The Launch Template defines how new EC2 instances should be created, including the AMI, instance type, security groups, IAM role, and User Data startup configuration.

### NAT Gateway
The NAT Gateway provides outbound internet access to EC2 instances running in private subnets, for example to download packages or pull container images, while keeping those instances inaccessible directly from the internet.

### AWS Systems Manager
AWS Systems Manager allows administrators to securely manage and access private EC2 instances without exposing SSH port 22 to the public internet. Session Manager can provide terminal access using IAM-controlled permissions.

### IAM Role
An IAM Role is an AWS identity that contains permissions. AWS services such as EC2 or GitHub Actions can assume the role and receive temporary credentials to access only the AWS resources they are permitted to use.

### Amazon ECR
Amazon Elastic Container Registry (ECR) is AWS's container image registry. Docker images can be stored in ECR and later pulled by EC2 instances during application deployment.