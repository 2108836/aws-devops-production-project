########### Load balancer ###########

resource "aws_lb_target_group" "app" {
  name        = "devops-prod-app-tg"
  vpc_id      = aws_vpc.main.id
  port        = 5000
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

############ Load balancer for subnet #########

resource "aws_lb" "app" {
  name               = "devops-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.alb_sg.id
  ]

  subnets = [
    aws_subnet.public_1.id, aws_subnet.public_2.id
  ]
}


############ Listener ##################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
