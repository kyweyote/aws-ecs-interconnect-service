# CloudWatch Log Group for ECS
# resource "aws_cloudwatch_log_group" "ecs" {
#   name              = "/ecs/services"
#   retention_in_days = 7
#
#   tags = {
#     Name = "ecs-logs"
#   }
# }

# resource "aws_cloudwatch_log_group" "counting_service" {
#   name              = "/ecs/counting-service"
#   retention_in_days = 7
#
#   tags = {
#     Name = "counting-service-logs"
#   }
# }

# resource "aws_cloudwatch_log_group" "dashboard_service" {
#   name              = "/ecs/dashboard-service"
#   retention_in_days = 7
#
#   tags = {
#     Name = "dashboard-service-logs"
#   }
# }