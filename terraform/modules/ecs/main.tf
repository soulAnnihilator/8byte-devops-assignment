resource "aws_ecs_cluster" "ninja" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "ninja" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7

  tags = {
    Name = "/ecs/${var.name}"
  }
}

data "aws_iam_policy_document" "task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json

  tags = {
    Name = "${var.name}-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secret_access" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      var.db_secret_arn
    ]
  }
}

resource "aws_iam_role_policy" "secret_access" {
  name   = "${var.name}-secret-access"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secret_access.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json

  tags = {
    Name = "${var.name}-ecs-task"
  }
}

resource "aws_lb" "ninja" {
  name               = substr("${var.name}-alb", 0, 32)
  load_balancer_type = "application"
  internal           = false

  security_groups = [var.alb_security_group_id]
  subnets         = var.public_subnet_ids

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_lb_target_group" "ninja" {
  name        = substr("${var.name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ninja.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ninja.arn
  }
}

resource "aws_ecs_task_definition" "ninja" {
  family                   = "${var.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = var.container_image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]

    environment = [{
      name  = "APP_ENV"
      value = "staging"
    }]

    secrets = [
      {
        name      = "DB_USERNAME"
        valueFrom = "${var.db_secret_arn}:username::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${var.db_secret_arn}:password::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.ninja.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "app"
      }
    }
  }])

  tags = {
    Name = "${var.name}-task"
  }
}

resource "aws_ecs_service" "ninja" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.ninja.id
  task_definition = aws_ecs_task_definition.ninja.arn

  lifecycle {
  ignore_changes = [task_definition]
}

  desired_count = var.desired_count
  launch_type   = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ninja.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.secret_access
  ]

  tags = {
    Name = "${var.name}-service"
  }
}

resource "aws_appautoscaling_target" "ninja" {
  max_capacity       = var.max_count
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.ninja.name}/${aws_ecs_service.ninja.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ninja.resource_id
  scalable_dimension = aws_appautoscaling_target.ninja.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ninja.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
