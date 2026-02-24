variable "aws_region" {
  type        = string
  description = "AWS region for ECR."
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile for Terraform."
  default     = "master-user"
}

# VPC and Networking
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# ECS Configuration
variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
  default     = "services-cluster"
}

variable "service_discovery_namespace" {
  type        = string
  description = "Cloud Map namespace used by ECS Service Connect"
  default     = "services.local"
}

variable "service_connect_tls_enabled" {
  type        = bool
  description = "Enable TLS for ECS Service Connect services"
  default     = true
}

variable "service_connect_tls_pca_arn" {
  type        = string
  description = "AWS Private CA ARN used by Service Connect TLS"
  default     = ""
}

# Task Configuration
variable "task_cpu" {
  type        = string
  description = "CPU units for ECS task"
  default     = "256"
}

variable "task_memory" {
  type        = string
  description = "Memory in MB for ECS task"
  default     = "512"
}

# Counting Service Configuration
variable "counting_service_port" {
  type        = number
  description = "Port for counting service"
  default     = 9003
}

variable "counting_service_desired_count" {
  type        = number
  description = "Desired number of counting service tasks"
  default     = 1
}

# variable "counting_service_max_capacity" {
#   type        = number
#   description = "Maximum number of counting service tasks for auto scaling"
#   default     = 3
# }

# Dashboard Service Configuration
variable "dashboard_service_port" {
  type        = number
  description = "Port for dashboard service"
  default     = 9002
}

variable "dashboard_service_desired_count" {
  type        = number
  description = "Desired number of dashboard service tasks"
  default     = 1
}

# variable "dashboard_service_max_capacity" {
#   type        = number
#   description = "Maximum number of dashboard service tasks for auto scaling"
#   default     = 3
# }
