# 8Byte DevOps Assignment

This repository contains my implementation of the 8Byte DevOps assignment.

I used AWS for the infrastructure. The application is running on ECS Fargate and the container image is stored in ECR. Terraform is used for the infrastructure and GitHub Actions handles the CI and staging deployment.

The application itself is kept simple since the main part of the assignment is around infrastructure and deployment.

## Repository

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
├── best-practices.md
└── challenges.md
```

I kept the Terraform resources in modules and the environment-specific values under `environments`.

So the staging and production folders use the same basic Terraform modules instead of having two copies of the infrastructure code.

At the moment, I have provisioned staging. The production Terraform configuration is present but I have not applied it.

## Infrastructure

The AWS setup looks like this:

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
                 RDS     Secrets Manager

                  ECR
                   ^
                   |
             GitHub Actions
```

The ALB is the public entry point.

ECS runs in private subnets and the RDS instance is also private. The database security group only allows PostgreSQL traffic from the ECS security group.

This keeps the database out of the public path instead of exposing it directly to the internet.

## Terraform

I used reusable Terraform modules for the AWS resources.

The main modules are:

```text
vpc
alb
ecs
ecr
rds
security_groups
monitoring
```

The staging environment passes values into these modules. Production has the same structure but can use different values.

This also makes it easier to change things like ECS count or RDS size without changing the module itself.

### Terraform state

I moved the Terraform state to S3 instead of keeping `terraform.tfstate` in the repository.

The staging state uses:

```text
8byte-assignment-terraform-state
└── staging/
    └── terraform.tfstate
```

The S3 bucket has encryption and versioning enabled.

Staging and production use separate state paths so changes in one environment do not affect the other state.

## Application

The application listens on port `8080`.

There are two endpoints currently used by the deployment:

```text
/
 /health
```

`/health` is used by the load balancer health check.

The application also reads the environment from an environment variable. This allows the same container image to be used for different environments.

## Container

The application is packaged into a Docker image.

CI builds the image and pushes it to the staging ECR repository when code is merged to `master`.

I used the Git commit SHA as the image tag instead of `latest`.

For example:

```text
8byte-assignment-staging:<commit-sha>
```

This gives me a direct link between a running ECS task and the commit that produced the image.

## CI/CD

I kept CI and deployment as two workflows.

The CI workflow runs for pull requests and for pushes to `master`.

The current flow is:

```text
Pull Request
    |
    v
   CI
    |
    +-- tests
    +-- dependency scan
    +-- Docker build
    +-- container scan


Merge to master
    |
    v
   CI
    |
    +-- tests
    +-- dependency scan
    +-- Docker build
    +-- container scan
    +-- push image to ECR
                         |
                         v
                    Deploy staging
                         |
                         v
                        ECS
```

The deployment workflow takes the image built by CI and updates the ECS service to use that image.

GitHub Actions uses OIDC to assume the AWS IAM role. I did not store an AWS access key in GitHub.

I also added an SES notification to the CI workflow. If the workflow fails, an email is sent with the repository, branch, commit and workflow run information.

## Monitoring

I created two CloudWatch dashboards rather than putting everything into one dashboard.

### Application

`8byte-assignment-staging-application`

This dashboard has the metrics I would check first when looking at the application:

* ALB requests
* HTTP errors
* response time
* ECS CPU
* ECS memory

### Platform

`8byte-assignment-staging-platform`

This one is more focused on the AWS resources:

* ECS CPU and memory
* RDS CPU
* RDS connections
* RDS storage
* ALB target health

ECS container logs are sent to CloudWatch Logs.

The log group is:

```text
/ecs/8byte-assignment-staging
```

## Database

PostgreSQL is running on RDS.

For staging, I used a small instance and kept Multi-AZ disabled. The database is not publicly accessible.

The important staging settings are:

```text
Public access       : false
Storage encryption  : enabled
Multi-AZ             : false
Backup retention     : 1 day
```

The database credentials are stored in Secrets Manager and passed to the ECS task as secrets.

The application does not need the database password inside the Docker image or Git repository.

## Security

I kept the public access limited to the ALB.

The request path is:

```text
Internet -> ALB -> ECS -> RDS
```

RDS does not accept connections from the internet. Its security group allows PostgreSQL traffic from the ECS security group.

The ECS execution role and task role are separate.

GitHub Actions uses OIDC rather than long-lived AWS credentials.

RDS and the Terraform state are encrypted.

The database credentials are stored in Secrets Manager.

Trivy is also used in CI to check the application files and Docker image for HIGH and CRITICAL vulnerabilities.

## Cost decisions

Since this is a staging environment, I did not use production-sized resources.

The main choices were:

* one ECS task
* small RDS instance
* no RDS Multi-AZ
* one NAT Gateway
* short backup retention

I used one NAT Gateway instead of one per Availability Zone. This saves cost for staging, although it is not as highly available.

I would change these settings for production depending on the availability and traffic requirements.

## Production

The production environment is included in the Terraform repository but has not been provisioned.

The same modules can be used for production with different environment values.

For example, production would normally need a higher ECS task count, a larger RDS configuration, longer backup retention and Multi-AZ where required.

I would also keep production in a separate AWS account rather than running staging and production in the same account.

The production deployment would also have a manual approval step before the ECS service is changed.

## Things I would change for a real production setup

The current implementation is focused on the assignment and the staging environment.

Before using the same setup for a real production workload, I would add:

* CloudWatch alarms
* deployment rollback checks
* manual production approval
* ALB access logging
* separate AWS account for production
* tighter IAM policies

These are intentionally not mixed into the staging setup just to make the assignment larger.

##Approach & Challenges

Some of the implementation problems I ran into and how I fixed them are documented in `approach-and-challenges.md`.

## Best practices

The reasoning behind the Terraform structure, state management, IAM, networking, secrets, CI/CD and cost decisions is in `best-practices.md`.
