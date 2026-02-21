# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  tags = {
    Name = "ecs-cluster"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_logs" {
  name = "ecs-task-execution-logs"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cloud Map Namespace for Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = var.service_discovery_namespace
  vpc  = aws_vpc.main.id

  tags = {
    Name = "service-discovery-namespace"
  }
}

# Task Definition for Counting Service
resource "aws_ecs_task_definition" "counting_service" {
  family                   = "counting-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "counting-service"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/counting-service:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.counting_service_port
          hostPort      = var.counting_service_port
          protocol      = "tcp"
        }
      ]
    }
  ])

  tags = {
    Name = "counting-service-task-definition"
  }
}

# Task Definition for Dashboard Service
resource "aws_ecs_task_definition" "dashboard_service" {
  family                   = "dashboard-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "dashboard-service"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/dashboard-service:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.dashboard_service_port
          hostPort      = var.dashboard_service_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "COUNTING_SERVICE_URL"
          value = "http://counting-service.${var.service_discovery_namespace}:${var.counting_service_port}"
        }
      ]
    }
  ])

  tags = {
    Name = "dashboard-service-task-definition"
  }
}

# Service Discovery Service for Counting Service
resource "aws_service_discovery_service" "counting_service" {
  name = "counting-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "counting-service-discovery"
  }
}

# Service Discovery Service for Dashboard Service
resource "aws_service_discovery_service" "dashboard_service" {
  name = "dashboard-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "dashboard-service-discovery"
  }
}

# ECS Service for Counting Service
resource "aws_ecs_service" "counting_service" {
  name            = "counting-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.counting_service.arn
  desired_count   = var.counting_service_desired_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.counting_service.arn
  }

  tags = {
    Name = "counting-service"
  }

  depends_on = [aws_ecs_task_definition.counting_service]
}

# ECS Service for Dashboard Service
resource "aws_ecs_service" "dashboard_service" {
  name            = "dashboard-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dashboard_service.arn
  desired_count   = var.dashboard_service_desired_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.main[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.dashboard_service.arn
  }

  tags = {
    Name = "dashboard-service"
  }

  depends_on = [aws_ecs_task_definition.dashboard_service]
}

# Auto Scaling Target for Counting Service
# resource "aws_appautoscaling_target" "counting_service_target" {
#   max_capacity       = var.counting_service_max_capacity
#   min_capacity       = var.counting_service_desired_count
#   resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.counting_service.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# Auto Scaling Policy for Counting Service
# resource "aws_appautoscaling_policy" "counting_service_policy" {
#   name               = "counting-service-scaling"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.counting_service_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.counting_service_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.counting_service_target.service_namespace
#
#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#     target_value = 70.0
#   }
# }

# Auto Scaling Target for Dashboard Service
# resource "aws_appautoscaling_target" "dashboard_service_target" {
#   max_capacity       = var.dashboard_service_max_capacity
#   min_capacity       = var.dashboard_service_desired_count
#   resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.dashboard_service.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# Auto Scaling Policy for Dashboard Service
# resource "aws_appautoscaling_policy" "dashboard_service_policy" {
#   name               = "dashboard-service-scaling"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.dashboard_service_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.dashboard_service_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.dashboard_service_target.service_namespace
#
#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }
#     target_value = 70.0
#   }
# }
