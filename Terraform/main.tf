terraform {
    required_version = "0.12.24"
}

provider "aws" {
  region = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

##################################################
# DATA                                           #
##################################################

data "aws_availability_zones" "available" {}

data "aws_region" "current" {
}

##################################################
# LOCALS                                         #
##################################################

locals {
  cluster_name = "${var.name}-cluster"
}

locals {
    public_key_filename  = "${path.root}/keys/${var.keypair_name}.pub"
    private_key_filename = "${path.root}/keys/${var.keypair_name}.pem"
    additional_nics_count = 3
}

##################################################
# KEY                                            #                               
##################################################

resource "tls_private_key" "generated" {
    algorithm = "RSA"
}
resource "aws_key_pair" "generated" {
    key_name   = var.keypair_name
    public_key = tls_private_key.generated.public_key_openssh
}
resource "local_file" "public_key_openssh" {
    content  = tls_private_key.generated.public_key_openssh
    filename = local.public_key_filename
}
resource "local_file" "private_key_pem" {
    content  = tls_private_key.generated.private_key_pem
    filename = local.private_key_filename
}

############################################################
# SECURTIY GROUP                                           # 
############################################################

resource "aws_security_group" "rabbit-lb" {
  name = "${var.name}-lb"
  vpc_id = var.vpc_id
  description = "Security Group for the rabbitmq elb"
  
  ingress {
    protocol        = "tcp"
    from_port       = 5672
    to_port         = 5672
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 15672
    to_port         = 15672
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 25672
    to_port         = 25672
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-lb"
  }
  
}

resource "aws_security_group" "rabbit-nodes" {
  name        = "${local.cluster_name}-nodes"
  vpc_id = var.vpc_id
  description = "Security Group for the rabbitmq nodes"

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  ingress {
    protocol        = "TCP"
    from_port       = 5672
    to_port         = 5672
    security_groups = ["${aws_security_group.rabbit-lb.id}"]
  }

  ingress {
    protocol        = "TCP"
    from_port       = 15672
    to_port         = 15672
    security_groups = ["${aws_security_group.rabbit-lb.id}"]
  }

  ingress {
    protocol        = "TCP"
    from_port       = 25672
    to_port         = 25672
    security_groups = ["${aws_security_group.rabbit-lb.id}"]
  }

  ingress {
    protocol        = "TCP"
    from_port       = 4369
    to_port         = 4369
    security_groups = ["${aws_security_group.rabbit-lb.id}"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = ["${aws_security_group.rabbit-lb.id}"]
  }  

  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = {
    Name = "${local.cluster_name}-nodes"
  }
}

##############################################################
# LOAD-BALANCER                                              #
##############################################################

resource "aws_lb" "rabbit_lb" {
  name = "${local.cluster_name}-lb"
  load_balancer_type = "network"
  internal = "false"
  subnets = var.subnet_id
  enable_cross_zone_load_balancing = "true"
  tags = {
    Name = "${local.cluster_name}-lb"
  }
}

resource "aws_lb_listener" "http1" {
    load_balancer_arn = aws_lb.rabbit_lb.arn
    protocol = "TCP"
    port = "80"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.TCP80.arn
    }
}

resource "aws_lb_listener" "http2" {
    load_balancer_arn = aws_lb.rabbit_lb.arn
    protocol = "TCP"
    port = "5672"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.TCP5672.arn
    }
}


resource "aws_lb_listener" "http3" {
    load_balancer_arn = aws_lb.rabbit_lb.arn
    protocol = "TCP"
    port = "15672"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.TCP15672.arn
    }
}

##############################################################
# TARGET GROUP                                               #
##############################################################

resource "aws_lb_target_group" "TCP80" {
  name = "${local.cluster_name}-TCP80"
  vpc_id = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port = "80"

  health_check {
    protocol = "TCP"
    port     = 80

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }
}


resource "aws_lb_target_group" "TCP5672" {
  name        = "${local.cluster_name}-TCP5672"
  vpc_id = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = 5672

  # TCP health check for apiserver
  health_check {
    protocol = "TCP"
    port     = 5672

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }
}


resource "aws_lb_target_group" "TCP15672" {
  name        = "${local.cluster_name}-TCP15672"
  vpc_id = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = 15672
  # TCP health check for apiserver
  health_check {
    protocol = "TCP"
    port     = 15672

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }
}


##################################################
# AUTO SCALING GROUP                             #                               
##################################################

resource "aws_launch_configuration" "rabbit" {
  name = "${var.environment_tag}-rabbit"
  image_id    = var.aws_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.generated.key_name

  security_groups = [
      aws_security_group.rabbit-nodes.id,
      aws_security_group.rabbit-lb.id,
  ]

  associate_public_ip_address = "true"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "rabbit-node" {
  name ="rabbit-asg"
  launch_configuration = "${aws_launch_configuration.rabbit.name}"
  vpc_zone_identifier  = var.subnet_id
  min_size             = var.min_size
  max_size             = var.max_size
  desired_capacity     = var.desired_size
  termination_policies = ["OldestLaunchConfiguration", "Default"]
  target_group_arns    = [aws_lb_target_group.TCP80.arn,
                          aws_lb_target_group.TCP5672.arn,
                          aws_lb_target_group.TCP15672.arn,
  ]

  tag {
    key                 = "Name"
    value               = "prod-rabbit"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "rabbit-node-scale-up" {
  name                   = "${var.name}-${var.environment_tag}-rabbit-node-up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  count                  = var.instance_count
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "rabbit-node-scale-down" {
  name                   = "${var.name}-${var.environment_tag}-rabbit-node-down"
  scaling_adjustment     = -2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  count                  = var.instance_count
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "rabbit-node-upgrade" {
  name                   = "${var.name}-${var.environment_tag}-rabbit-node-upgrade-hook"
  count                  = var.instance_count
  autoscaling_group_name = aws_autoscaling_group.rabbit-node.id
  default_result         = "CONTINUE"
  heartbeat_timeout      = 2000
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}