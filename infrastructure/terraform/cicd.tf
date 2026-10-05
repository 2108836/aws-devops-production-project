############################################
# GitHub OIDC Provider
# Allows AWS IAM to trust identity tokens
# issued by GitHub Actions.
############################################

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}


############################################
# GitHub Actions Trust Policy
# Defines WHO is allowed to assume the
# GitHub Actions IAM role.
#
# Access is restricted to:
# - Repository: 2108836/aws-devops-production-project
# - Branch: main
############################################

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    # Trust the GitHub OIDC provider.
    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    # Ensure the token is intended for AWS STS.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    # Restrict role assumption to the main branch
    # of this specific GitHub repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:2108836/aws-devops-production-project:ref:refs/heads/main"
      ]
    }
  }
}


############################################
# GitHub Actions IAM Role
# GitHub Actions assumes this role through
# OIDC and receives temporary AWS credentials.
############################################

resource "aws_iam_role" "github_actions" {
  name = "devops-prod-github-actions-role"

  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}


############################################
# GitHub Actions Permissions
# Defines WHAT the GitHub Actions role is
# allowed to do after assuming the role.
############################################

data "aws_iam_policy_document" "github_permissions" {

  ##########################################
  # Allow authentication with Amazon ECR.
  # GetAuthorizationToken requires "*"
  # rather than a repository-specific ARN.
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }


  ##########################################
  # Allow Docker image uploads only to the
  # application's specific ECR repository.
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.app.arn
    ]
  }


  ##########################################
  # Allow GitHub Actions to update the
  # desired application image SHA stored
  # in SSM Parameter Store.
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "ssm:PutParameter"
    ]

    resources = [
      aws_ssm_parameter.image_tag.arn
    ]
  }


  ##########################################
  # Allow GitHub Actions to start an
  # Auto Scaling Group instance refresh.
  #
  # New EC2 instances will read the updated
  # image SHA from Parameter Store and pull
  # that exact image from ECR.
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:StartInstanceRefresh"
    ]

    resources = [
      aws_autoscaling_group.app.arn
    ]
  }
}


############################################
# Attach the permissions above directly
# to the GitHub Actions IAM role.
############################################

resource "aws_iam_role_policy" "github_permissions" {
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.github_permissions.json
}