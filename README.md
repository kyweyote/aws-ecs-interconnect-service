# AWS ECS Service Discovery Demo

This project provisions a AWS ECS Fargate environment with private DNS service discovery.
Ref link: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html

## Architecture Overview


## What this deploys

- 1 ECS cluster: `services-cluster`
- 2 ECS services:
  - `dashboard-service` on port `9002` (publicly reachable)
  - `counting-service` on port `9003` (internal service)
- Cloud Map private namespace: `services.local`
- ECR repositories and Docker image push flow
- Security group rules allowing:
  - Internet -> dashboard on `9002`
  - Dashboard/tasks -> counting on `9003`

## Service-to-service connection

`dashboard-service` uses this environment variable:

`COUNTING_SERVICE_URL=http://counting-service.services.local:9003`

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with profile `master-user`
- Docker running locally
- `jq` installed (used by `outputs.tf` external data lookups)

## Deploy

```bash
terraform init
terraform validate
terraform apply -auto-approve
```

## Hands-on test (inside dashboard container)

1. Open shell in dashboard task:

```bash
aws ecs execute-command --cluster services-cluster \
    --task arn:aws:ecs:ap-southeast-1:886436964547:task/services-cluster/233b213e05134ceab7ab934da47d65ca \
    --container dashboard-service --region ap-southeast-1 --profile master-user \
    --interactive \
    --command "/bin/sh"
```

2. Resolve counting service DNS from inside container:

```bash
nslookup counting-service.services.local
#output
Server:         10.0.0.2
Address:        10.0.0.2:53

Non-authoritative answer:
Name:   counting-service.services.local
Address: 10.0.1.91
Name:   counting-service.services.local
Address: 10.0.2.106
Name:   counting-service.services.local
Address: 10.0.1.63
```

