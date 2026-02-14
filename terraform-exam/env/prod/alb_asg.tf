################################
# ALB Security Group
################################
resource "aws_security_group" "alb_sg" {
  name   = "exam-alb-sg"
  vpc_id = module.base.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################
# Target Group
################################
resource "aws_lb_target_group" "tg" {
  name     = "exam-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.base.vpc_id

  health_check {
    path = "/"
  }
}

################################
# ALB
################################
resource "aws_lb" "alb" {
  name               = "exam-alb"
  load_balancer_type = "application"
  subnets            = module.base.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
}

################################
# Listener: 80 -> Target Group
################################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

################################
# Ubuntu 22.04 AMI (auto)
################################
data "aws_ami" "ubuntu_2204_alb" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################
# Launch Template for Auto Scaling
################################
resource "aws_launch_template" "lt" {
  name_prefix   = "exam-lt-"
  image_id      = data.aws_ami.ubuntu_2204_alb.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [module.base.ec2_sg_id]

  # התקנת nginx כדי שה-ALB health check יעבור
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
  EOF
  )
}

################################
# Auto Scaling Group (min 1, max 3)
################################
resource "aws_autoscaling_group" "asg" {
  name                = "exam-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = module.base.public_subnet_ids

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  tag {
    key                 = "Name"
    value               = "exam-asg-instance"
    propagate_at_launch = true
  }
}
