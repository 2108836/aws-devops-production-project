####### ECR repository ############

resource "aws_ecr_repository" "app" {
  name                 = "devops-prod-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}