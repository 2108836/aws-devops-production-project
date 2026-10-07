############################################
# GitHub OIDC Provider
# Reuse the existing GitHub OIDC provider
# already configured in this AWS account.
############################################

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}


############################################
# GitHub Actions Trust Policy
#
# Defines WHO can assume the GitHub Actions
# IAM role through GitHub OIDC.
############################################

data "aws_iam_policy_document" "github_trust" {

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }

    # Token must be intended for AWS STS.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    # Restrict access to this repository's
    # main branch using GitHub's immutable subject.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:2108836@237055730/aws-devops-production-project@1405436461:ref:refs/heads/main"
      ]
    }
  }
}


############################################
# GitHub Actions IAM Role
#
# GitHub Actions assumes this role through
# OIDC and receives temporary AWS credentials.
############################################

resource "aws_iam_role" "github_actions" {
  name = "devops-prod-github-actions-role"

  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}


############################################
# GitHub Actions Permission Policy
#
# Defines WHAT GitHub Actions can do
# after assuming the IAM role.
############################################

data "aws_iam_policy_document" "github_permissions" {

  ##########################################
  # ECR authentication
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }


  ##########################################
  # Push Docker images only to this
  # project's ECR repository.
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
  # Update the desired image SHA stored
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
  # Start deployment by refreshing the ASG.
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


  ##########################################
  # Read instance refresh status.
  #
  # The CI/CD pipeline will use this to
  # check whether the deployment actually
  # completed successfully.
  ##########################################

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeInstanceRefreshes"
    ]

    resources = ["*"]
  }
}


############################################
# Attach GitHub deployment permissions
# directly to the GitHub Actions IAM role.
############################################

resource "aws_iam_role_policy" "github_permissions" {
  role   = aws_iam_role.github_actions.name
  policy = data.aws_iam_policy_document.github_permissions.json
}