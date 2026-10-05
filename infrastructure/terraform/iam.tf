######### IAM Trust Policy ############


data "aws_iam_policy_document" "ec2_trust" {

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}


#########  assume IAM Role #################

resource "aws_iam_role" "ec2_role" {
  name = "devops-prod-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}


######### SSM permission ###############

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}

########### ECR pull permission ##################

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


################ Instance Profile ###############

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devops-prod-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


###### IAM role policy #################

resource "aws_iam_role_policy" "parameter_read" {
  role = aws_iam_role.ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = aws_ssm_parameter.image_tag.arn
      }
    ]
  })
}