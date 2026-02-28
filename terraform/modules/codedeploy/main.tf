resource "aws_lb" "taskflow" {
  name               = "taskflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  tags = {
    Name = "taskflow-alb"
  }
}

resource "aws_lb_target_group" "blue" {
  name     = "taskflow-blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "5000"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_target_group" "green" {
  name     = "taskflow-green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "5000"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "taskflow" {
  load_balancer_arn = aws_lb.taskflow.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

resource "aws_launch_template" "taskflow" {
  name_prefix   = "taskflow-"
  image_id      = var.ami_id
  instance_type = "t3.micro"
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [var.security_group_id]
  user_data              = base64encode(var.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "taskflow-app"
    }
  }
}

resource "aws_autoscaling_group" "taskflow" {
  name                = "taskflow-asg"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.blue.arn]
  health_check_type   = "ELB"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.taskflow.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "taskflow-app"
    propagate_at_launch = true
  }
}

resource "aws_codedeploy_app" "taskflow" {
  name             = "taskflow-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "taskflow" {
  app_name               = aws_codedeploy_app.taskflow.name
  deployment_group_name  = "taskflow-blue-green"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "KEEP_ALIVE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  autoscaling_groups = [aws_autoscaling_group.taskflow.name]

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.blue.name
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name = "taskflow-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_role_policy" "codedeploy_autoscaling" {
  name = "codedeploy-autoscaling-policy"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:DeleteLifecycleHook",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:PutLifecycleHook",
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:EnableMetricsCollection",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribePolicies",
          "autoscaling:DescribeScheduledActions",
          "autoscaling:DescribeNotificationConfigurations",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:SuspendProcesses",
          "autoscaling:ResumeProcesses",
          "autoscaling:AttachLoadBalancers",
          "autoscaling:AttachLoadBalancerTargetGroups",
          "autoscaling:PutScalingPolicy",
          "autoscaling:PutScheduledUpdateGroupAction",
          "autoscaling:PutNotificationConfiguration",
          "autoscaling:PutLifecycleHook",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DeleteAutoScalingGroup",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:TerminateInstances",
          "tag:GetResources",
          "sns:Publish",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeInstanceHealth",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "codedeploy" {
  bucket = "taskflow-codedeploy-${var.aws_account_id}"
}
