data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############# Launch template ############

resource "aws_launch_template" "app" {
  name_prefix   = "devops-prod-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  user_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
    aws_region               = var.aws_region
    ecr_repository_url       = aws_ecr_repository.app.repository_url
    image_tag_parameter_name = aws_ssm_parameter.image_tag.name
  }))

  depends_on = [
    aws_iam_role_policy.parameter_read,
    aws_iam_role_policy_attachment.ecr,
    aws_iam_role_policy_attachment.ssm
  ]

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
}


############ Auto scalling ####################

resource "aws_autoscaling_group" "app" {
  name                      = "devops-prod-app-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  health_check_type         = "ELB"
  health_check_grace_period = 180

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  vpc_zone_identifier = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}