ACCOUNT_ID=$(terraform output -raw aws_account_id)
REGION=$(terraform output -raw aws_region)

aws ecr get-login-password --profile master-user --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

COUNTING_REPO=$(terraform output -raw counting_service_repository_url)
DASHBOARD_REPO=$(terraform output -raw dashboard_service_repository_url)

docker build -t "${COUNTING_REPO}:latest" counting-service
docker push "${COUNTING_REPO}:latest"

docker build -t "${DASHBOARD_REPO}:latest" dashboard-service
docker push "${DASHBOARD_REPO}:latest"

###
TOKEN=$(aws ecr get-login-password --profile master-user --region "$REGION")
echo "Got token length: ${#TOKEN}"
unset TOKEN
cat ~/.docker/config.json

###

aws ecr-public get-login-password --profile master-user --region us-east-1 \
| docker login --username AWS --password-stdin public.ecr.aws

docker build -t public.ecr.aws/j6k7m6l0/counting-service counting-service
docker push public.ecr.aws/j6k7m6l0/counting-service:latest

docker build -t public.ecr.aws/j6k7m6l0/dashboard-service dashboard-service
docker push public.ecr.aws/j6k7m6l0/dashboard-service:latest

### 
aws ecs execute-command --cluster services-cluster \
    --task arn:aws:ecs:ap-southeast-1:886436964547:task/services-cluster/233b213e05134ceab7ab934da47d65ca \
    --container dashboard-service --region ap-southeast-1 --profile master-user \
    --interactive \
    --command "/bin/sh"

nslookup counting-service.services.local

apk update && apk add curl
curl -iv http://counting-dns:9003

apk add openssl

openssl s_client -connect 172.31.26.124:9003 < /dev/null 2> /dev/null | openssl x509 -noout -text