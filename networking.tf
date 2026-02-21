# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "service-discovery-vpc"
  }
}

resource "aws_subnet" "main" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "rt"
  }
}

resource "aws_route_table_association" "main" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "ecs-tasks-sg"
  }
}

# ECS Tasks Security Group - Ingress from internet to dashboard
resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_dashboard_public" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow public access to dashboard service"

  from_port   = var.dashboard_service_port
  to_port     = var.dashboard_service_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "ecs-dashboard-public"
  }
}

# ECS Tasks Security Group - Ingress between tasks for counting
resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_counting_internal" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow dashboard to call counting service"

  from_port                    = var.counting_service_port
  to_port                      = var.counting_service_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_tasks.id

  tags = {
    Name = "ecs-counting-internal"
  }
}

# ECS Tasks Security Group - Egress to all
resource "aws_vpc_security_group_egress_rule" "ecs_tasks_all" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = {
    Name = "ecs-all-egress"
  }
}
