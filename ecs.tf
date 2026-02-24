# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.main.arn
  }

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

resource "aws_iam_role_policy_attachment" "ecs_task_service_connect_tls_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForServiceConnectTransportLayerSecurity"
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

resource "aws_iam_role" "ecs_service_connect_tls_role" {
  name = "ecs-service-connect-tls-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSServiceAssume"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_service_connect_tls_role_policy" {
  role       = aws_iam_role.ecs_service_connect_tls_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForServiceConnectTransportLayerSecurity"
}

resource "aws_iam_role_policy" "ecs_service_connect_tls_pca_policy" {
  name = "ecs-service-connect-tls-pca-policy"
  role = aws_iam_role.ecs_service_connect_tls_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm-pca:DescribeCertificateAuthority",
          "acm-pca:IssueCertificate",
          "acm-pca:GetCertificate"
        ]
        Resource = var.service_connect_tls_pca_arn
      }
    ]
  })
}

# Cloud Map namespace for ECS Service Connect
resource "aws_service_discovery_http_namespace" "main" {
  name = var.service_discovery_namespace

  tags = {
    Name = "service-connect-namespace"
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
          name          = "counting-service"
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
          name          = "dashboard-service"
          containerPort = var.dashboard_service_port
          hostPort      = var.dashboard_service_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "COUNTING_SERVICE_URL"
          value = "http://counting-dns"
        }
      ]
    }
  ])

  tags = {
    Name = "dashboard-service-task-definition"
  }
}

# ECS Service for Counting Service
resource "aws_ecs_service" "counting_service" {
  name                   = "counting-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.counting_service.arn
  desired_count          = var.counting_service_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "counting-service"
      discovery_name = "counting-dns"

      client_alias {
        dns_name = "counting-dns"
        port     = 80
      }

      dynamic "tls" {
        for_each = var.service_connect_tls_enabled ? [1] : []
        content {
          issuer_cert_authority {
            aws_pca_authority_arn = var.service_connect_tls_pca_arn
          }
          role_arn = aws_iam_role.ecs_service_connect_tls_role.arn
        }
      }
    }
  }

  tags = {
    Name = "counting-service"
  }

  depends_on = [
    aws_ecs_task_definition.counting_service,
    aws_iam_role_policy_attachment.ecs_task_service_connect_tls_role_policy,
    aws_iam_role_policy_attachment.ecs_service_connect_tls_role_policy,
    aws_iam_role_policy.ecs_service_connect_tls_pca_policy
  ]
}

# ECS Service for Dashboard Service
resource "aws_ecs_service" "dashboard_service" {
  name                   = "dashboard-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.dashboard_service.arn
  desired_count          = var.dashboard_service_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.main[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "dashboard-service"
      discovery_name = "dashboard-dns"

      client_alias {
        dns_name = "dashboard-dns"
        port     = 80
      }

      dynamic "tls" {
        for_each = var.service_connect_tls_enabled ? [1] : []
        content {
          issuer_cert_authority {
            aws_pca_authority_arn = var.service_connect_tls_pca_arn
          }
          role_arn = aws_iam_role.ecs_service_connect_tls_role.arn
        }
      }
    }
  }

  tags = {
    Name = "dashboard-service"
  }

  depends_on = [
    aws_ecs_task_definition.dashboard_service,
    aws_iam_role_policy_attachment.ecs_task_service_connect_tls_role_policy,
    aws_iam_role_policy_attachment.ecs_service_connect_tls_role_policy,
    aws_iam_role_policy.ecs_service_connect_tls_pca_policy
  ]
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
