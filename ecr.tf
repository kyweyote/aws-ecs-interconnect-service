# ECR Repository for counting-service
resource "aws_ecr_repository" "counting_service" {
  name                 = "counting-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "counting-service"
    Service = "counting-service"
  }
}

# ECR Repository for dashboard-service
resource "aws_ecr_repository" "dashboard_service" {
  name                 = "dashboard-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "dashboard-service"
    Service = "dashboard-service"
  }
}

data "aws_ecr_authorization_token" "this" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"

  registry_auth {
    address  = replace(data.aws_ecr_authorization_token.this.proxy_endpoint, "https://", "")
    username = split(":", base64decode(data.aws_ecr_authorization_token.this.authorization_token))[0]
    password = split(":", base64decode(data.aws_ecr_authorization_token.this.authorization_token))[1]
  }
}

# Build and push counting-service image
resource "docker_image" "counting_service" {
  name = "${aws_ecr_repository.counting_service.repository_url}:latest"

  build {
    context    = "${path.module}/counting-service"
    dockerfile = "${path.module}/counting-service/Dockerfile"
  }

  depends_on = [aws_ecr_repository.counting_service]
}

resource "docker_registry_image" "counting_service_push" {
  name = docker_image.counting_service.name

  depends_on = [docker_image.counting_service]
}

# Build and push dashboard-service image
resource "docker_image" "dashboard_service" {
  name = "${aws_ecr_repository.dashboard_service.repository_url}:latest"

  build {
    context    = "${path.module}/dashboard-service"
    dockerfile = "${path.module}/dashboard-service/Dockerfile"
  }

  depends_on = [aws_ecr_repository.dashboard_service]
}

resource "docker_registry_image" "dashboard_service_push" {
  name = docker_image.dashboard_service.name

  depends_on = [docker_image.dashboard_service]
}

# ECR Lifecycle Policy to keep only last 10 images
# resource "aws_ecr_lifecycle_policy" "counting_service_policy" {
#   repository = aws_ecr_repository.counting_service.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 images"
#         selection = {
#           tagStatus   = "any"
#           countType   = "imageCountMoreThan"
#           countNumber = 10
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }

# resource "aws_ecr_lifecycle_policy" "dashboard_service_policy" {
#   repository = aws_ecr_repository.dashboard_service.name

#   policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 images"
#         selection = {
#           tagStatus   = "any"
#           countType   = "imageCountMoreThan"
#           countNumber = 10
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }
