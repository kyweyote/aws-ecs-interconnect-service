data "external" "dashboard_runtime" {
	program = ["bash", "-lc", <<-EOT
		set -euo pipefail
		query_json=$(cat)

		cluster=$(echo "$query_json" | jq -r '.cluster')
		service=$(echo "$query_json" | jq -r '.service')
		region=$(echo "$query_json" | jq -r '.region')
		profile=$(echo "$query_json" | jq -r '.profile')
		container=$(echo "$query_json" | jq -r '.container')

		task_arn=$(aws ecs list-tasks \
			--cluster "$cluster" \
			--service-name "$service" \
			--desired-status RUNNING \
			--region "$region" \
			--profile "$profile" \
			--query 'taskArns[0]' \
			--output text)

		if [ "$task_arn" = "None" ] || [ -z "$task_arn" ]; then
			jq -n '{task_arn:"", private_ip:"", public_ip:"", execute_command:"No running dashboard task found yet."}'
			exit 0
		fi

		eni_id=$(aws ecs describe-tasks \
			--cluster "$cluster" \
			--tasks "$task_arn" \
			--region "$region" \
			--profile "$profile" \
			--query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' \
			--output text)

		private_ip=$(aws ec2 describe-network-interfaces \
			--network-interface-ids "$eni_id" \
			--region "$region" \
			--profile "$profile" \
			--query 'NetworkInterfaces[0].PrivateIpAddress' \
			--output text)

		public_ip=$(aws ec2 describe-network-interfaces \
			--network-interface-ids "$eni_id" \
			--region "$region" \
			--profile "$profile" \
			--query 'NetworkInterfaces[0].Association.PublicIp' \
			--output text)

		if [ "$public_ip" = "None" ]; then
			public_ip=""
		fi

		execute_command="aws ecs execute-command --cluster $cluster --task $task_arn --container $container --region $region --profile $profile --interactive --command \"/bin/sh\""

		jq -n \
			--arg task_arn "$task_arn" \
			--arg private_ip "$private_ip" \
			--arg public_ip "$public_ip" \
			--arg execute_command "$execute_command" \
			'{task_arn:$task_arn, private_ip:$private_ip, public_ip:$public_ip, execute_command:$execute_command}'
	EOT
	]

	query = {
		cluster   = aws_ecs_cluster.main.name
		service   = aws_ecs_service.dashboard_service.name
		region    = var.aws_region
		profile   = var.aws_profile
		container = "dashboard-service"
	}
}

data "external" "counting_runtime" {
	program = ["bash", "-lc", <<-EOT
		set -euo pipefail
		query_json=$(cat)

		cluster=$(echo "$query_json" | jq -r '.cluster')
		service=$(echo "$query_json" | jq -r '.service')
		region=$(echo "$query_json" | jq -r '.region')
		profile=$(echo "$query_json" | jq -r '.profile')

		task_arn=$(aws ecs list-tasks \
			--cluster "$cluster" \
			--service-name "$service" \
			--desired-status RUNNING \
			--region "$region" \
			--profile "$profile" \
			--query 'taskArns[0]' \
			--output text)

		if [ "$task_arn" = "None" ] || [ -z "$task_arn" ]; then
			jq -n '{private_ip:""}'
			exit 0
		fi

		eni_id=$(aws ecs describe-tasks \
			--cluster "$cluster" \
			--tasks "$task_arn" \
			--region "$region" \
			--profile "$profile" \
			--query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' \
			--output text)

		private_ip=$(aws ec2 describe-network-interfaces \
			--network-interface-ids "$eni_id" \
			--region "$region" \
			--profile "$profile" \
			--query 'NetworkInterfaces[0].PrivateIpAddress' \
			--output text)

		jq -n --arg private_ip "$private_ip" '{private_ip:$private_ip}'
	EOT
	]

	query = {
		cluster = aws_ecs_cluster.main.name
		service = aws_ecs_service.counting_service.name
		region  = var.aws_region
		profile = var.aws_profile
	}
}

output "dashboard_service_public_ip" {
	value       = data.external.dashboard_runtime.result.public_ip
	description = "Dashboard service public IP"
}

output "dashboard_service_private_ip" {
	value       = data.external.dashboard_runtime.result.private_ip
	description = "Dashboard service private IP"
}

output "counting_service_private_ip" {
	value       = data.external.counting_runtime.result.private_ip
	description = "Counting service private IP"
}

output "dashboard_execute_command" {
	value       = data.external.dashboard_runtime.result.execute_command
	description = "Ready-to-run ECS execute-command for dashboard-service"
}
