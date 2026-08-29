# 8Byte DevOps Assignment

This repo is my solution for the 8Byte.ai DevOps assignment.

The AWS setup is in `ap-south-1`. I used Terraform for the infrastructure and ECS Fargate for running the application. ECR is used for Docker images and GitHub Actions is used for CI and the staging deployment.

The application is intentionally small. It just gives me something to build, test and deploy.

## Structure

```text
.
├── app
│   ├── app.py
│   ├── Dockerfile
│   └── tests
│
├── terraform
│   ├── modules
│   │   ├── alb
│   │   ├── ecs
│   │   ├── ecr
│   │   ├── monitoring
│   │   ├── rds
│   │   ├── security_groups
│   │   └── vpc
│   │
│   └── environments
│       ├── staging
│       └── production
│
├── .github
│   └── workflows
│       ├── ci.yml
│       └── deploy-staging.yml
│
├── README.md
└── challenges.md
```

There are separate staging and production environment directories so the same Terraform modules can be used for both.

Only **staging has been provisioned for this assignment**. The production configuration is present in the repository, but I did not deploy it to AWS.

I kept it this way mainly to avoid creating unnecessary AWS resources and cost while working on the assignment.

## AWS layout

The basic setup is:

```text
                         Internet
                            |
                            v
                           ALB
                            |
                            v
                       ECS Fargate
                       private subnet
                         /       \
                        /         \
                       v           v
                     RDS       Secrets Manager


                       ECR
                        ^
                        |
                  GitHub Actions
```

The ALB is public. ECS and RDS are in private subnets.

The RDS security group only accepts PostgreSQL traffic from the ECS security group. ECS traffic comes through the ALB.

## Terraform

I used modules because there are two environments in the repository.

The modules contain the actual AWS resources. The environment directories provide the values for them.

For example:

```text
terraform/modules/vpc
terraform/modules/ecs
terraform/modules/rds
```

are reused by:

```text
terraform/environments/staging
terraform/environments/production
```

The staging environment is the one I used while developing and testing the assignment.

### State

The staging Terraform state is stored remotely in S3:

```text
s3://8byte-assignment-terraform-state/staging/terraform.tfstate
```

The bucket has versioning and encryption enabled.

The backend configuration is in:

```text
terraform/environments/staging/backend.tf
```

The production environment has its own backend configuration/key so it can have separate state from staging.

I created the state bucket separately because Terraform needs the backend before it can manage the resources in the environment.

## Running staging

I used an AWS CLI profile called `ninja`.

Set it in PowerShell:

```powershell
$env:AWS_PROFILE="ninja"
$env:AWS_REGION="ap-south-1"
```

Check the account before running Terraform:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
cd terraform/environments/staging

terraform init
terraform plan
terraform apply
```

Terraform prints the ALB URL, ECR repository, ECS service and RDS endpoint after the apply.

## Production

The production environment is included but is **not provisioned**.

The idea is to keep the resource definitions in the modules and change the environment values rather than copying the Terraform resources again.

For example, production can have different values for:

```text
ECS desired count
RDS instance size
Multi-AZ
backup retention
NAT Gateway setup
```

I would also use a separate AWS account for production in a real setup.

I didn't create that production infrastructure as part of this assignment because the staging environment was enough to verify the complete Terraform → ECR → ECS path.

## Application

The application listens on port `8080`.

The endpoints currently used are:

```text
/
 /health
```

The `/health` endpoint is used by the ALB health check.

The application reads the environment from an environment variable so the same image can be used in different environments.

## Docker

Build the image from the repository root:

```powershell
docker build -t 8byte-assignment:bootstrap ./app
```

The image is stored in the staging ECR repository.

The ECS task definition refers to the image in ECR.

## CI/CD

I kept CI and deployment as two separate workflows.

The flow is:

```text
Pull Request
     |
     v
    CI
     |
     +---- tests
     |
     +---- docker build


Merge to master
     |
     v
    CI
     |
     +---- tests
     +---- docker build
     +---- push image to ECR
                         |
                         v
                  Deploy staging
                         |
                         v
                        ECS
```

The deployment workflow updates the ECS task definition with the image that was built by the pipeline.

GitHub Actions uses AWS OIDC to assume the deployment IAM role. There are no long-lived AWS access keys in the workflow.

Terraform creates the ECS service and initial task definition. The deployment workflow is responsible for changing the application version.

## Monitoring

I created two CloudWatch dashboards.

`8byte-assignment-staging-application`

This has the metrics I would normally look at first when checking the application:

* ALB request count
* HTTP errors
* target response time
* ECS CPU
* ECS memory

`8byte-assignment-staging-platform`

This is more focused on the resources underneath the application:

* ECS CPU/memory
* RDS CPU
* RDS connections
* RDS storage
* ALB target health

ECS application logs go to:

```text
/ecs/8byte-assignment-staging
```

using the CloudWatch logs driver.

## Database

RDS PostgreSQL is private and is not reachable directly from the internet.

The current staging values are intentionally small:

```text
Publicly accessible : false
Storage encrypted   : true
Multi-AZ             : false
Backup retention     : 1 day
```

The database credentials are obtained through Secrets Manager.

For production, I would review the database size, Multi-AZ and backup retention based on the actual application requirements.

## Security

A few things I kept out of the public path:

* RDS is private.
* ECS tasks are private.
* Only the ALB is public.
* RDS only accepts traffic from ECS.
* Database credentials are in Secrets Manager.
* RDS storage is encrypted.
* Terraform state is encrypted in S3.
* GitHub Actions uses OIDC.
* ECS task and execution roles are separate.

The IAM permissions can be made more restrictive when the exact production resources are known.

## Cost

This is a staging setup, so I didn't use production-sized resources.

The main cost decisions were:

* one ECS task
* small RDS instance
* no RDS Multi-AZ
* one NAT Gateway
* short RDS backup retention

The single NAT Gateway is cheaper than having one in every AZ, but it is also a trade-off in terms of availability.

For production I would make that decision based on the required availability rather than simply copying the staging configuration.

## Things not implemented

There are a few assignment requirements that I have left as the next step rather than pretending they are already part of the working deployment.

These include:

* production deployment
* manual approval before production
* container vulnerability scanning
* dependency scanning
* Slack/email failure notifications
* CloudWatch alarms
* ALB access logs

The production Terraform configuration is present, but I have not provisioned it.

## Verification

Once staging is deployed, the ALB URL can be tested with:

```powershell
curl.exe http://<alb-dns-name>/
```

and:

```powershell
curl.exe http://<alb-dns-name>/health
```

ECS can be checked with:

```powershell
aws ecs describe-services `
  --cluster 8byte-assignment-staging-cluster `
  --services 8byte-assignment-staging-service `
  --profile ninja `
  --region ap-south-1
```

The expected result is that the ECS service has its desired number of tasks running and the ALB reports the target as healthy.

## Cleanup

From the staging directory:

```powershell
terraform destroy
```

The S3 state bucket is separate from the staging infrastructure, so it is not removed by this command.