
################ Security group #############
resource "aws_security_group" "alb_sg" {
  name        = "devops-prod-alb-sg"
  description = "Security group for public ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "devops-prod-alb-sg"
  }
}



############ Ingress rule ################

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.alb_sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}




############ Security group ###########

resource "aws_security_group" "ec2_sg" {
  name        = "devops-prod-ec2-sg"
  description = "Security group for private application EC2"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "devops-prod-ec2-sg"
  }
}


############ Ingress rule for load balancer ###########

resource "aws_vpc_security_group_ingress_rule" "allow_app_from_alb" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
}



########## Egress Rule for ALB ###########

resource "aws_vpc_security_group_egress_rule" "allow_app_to_ec2" {
  security_group_id            = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.ec2_sg.id

}


### allow Ec2 to access internet ###############

resource "aws_vpc_security_group_egress_rule" "allow_https_outbounds" {
  security_group_id = aws_security_group.ec2_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}