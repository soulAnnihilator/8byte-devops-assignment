# Approach & Challenges

This document covers some of the decisions I made while building the assignment and a few issues I came across during the implementation.

I focused on getting the staging environment working first and then added the CI, monitoring and other parts around it.

## 1. Terraform and application deployment

One thing I wanted to keep separate was infrastructure changes and application deployments.

Terraform creates the VPC, ALB, ECS service, ECR repository, RDS, IAM roles and CloudWatch resources. It also creates the initial ECS task definition.

After that, GitHub Actions handles application deployments.

```text
Terraform
   |
   +-- VPC
   +-- ALB
   +-- ECS
   +-- ECR
   +-- RDS
   +-- IAM
   +-- CloudWatch

GitHub Actions
   |
   +-- Test
   +-- Build
   +-- Scan
   +-- Push image
   +-- Deploy to ECS
```

This is useful because an application deployment does not need a Terraform change.

I also don't want a normal `terraform apply` to replace the task definition that was updated by the deployment pipeline. The ECS service therefore ignores task definition changes made outside Terraform.

## 2. ECS image

I first used a `bootstrap` image so that the ECS service had an image available when the infrastructure was created.

There was no image in ECR initially, so the ECS tasks were failing with `CannotPullContainerError`.

After building and pushing the image, the tasks started normally and the ALB target became healthy.

For the actual CI deployment, I changed this to use the Git commit SHA as the image tag.

```text
8byte-assignment-staging:<commit-sha>
```

I prefer this over `latest` because I can tell which version of the code is running from the ECS task definition.

The `bootstrap` image was only needed to get the initial environment up.

## 3. Terraform state

The first Terraform runs used local state.

Once the infrastructure was working, I moved the staging state to S3.

```text
8byte-assignment-terraform-state
    |
    +-- staging/
          |
          +-- terraform.tfstate
```

The bucket uses encryption and versioning.

One issue I hit while changing the backend was an S3 `AccessDenied` error. The AWS CLI could see the bucket, but Terraform could not list the objects required during backend migration.

After checking the IAM permissions and the S3 access, I was able to initialize Terraform against the S3 backend.

I kept the backend configuration separate from the infrastructure modules. The state storage should not depend on the infrastructure state that it is storing.

## 4. Network setup and cost

The ALB is in public subnets.

ECS and RDS are in private subnets.

```text
Internet
   |
   v
 ALB
   |
   v
 ECS
   |
   v
 RDS
```

The RDS security group only allows PostgreSQL traffic from ECS.

For NAT, I used one NAT Gateway for staging.

Using one per Availability Zone would give better availability, but for this assignment it would add cost without much benefit. I would use multiple NAT Gateways for production if the availability requirement justified the extra cost.

## 5. RDS configuration

The staging database is configured as:

```text
Publicly accessible : false
Storage encryption   : enabled
Multi-AZ             : false
Backup retention     : 1 day
```

I did not enable Multi-AZ for staging because this environment is only being used to demonstrate the deployment.

For production, I would decide this based on the required RTO/RPO and database availability rather than simply copying the staging settings.

## 6. Secrets

The database username and password are stored in Secrets Manager.

They are not present in the Git repository or Docker image.

The ECS task definition references the individual values from the secret.

The ECS execution role and task role are separate. This gives me a cleaner boundary between permissions needed by ECS itself and permissions needed by the application.

For production, I would also enable secret rotation where appropriate and restrict access to the specific secret rather than giving broader Secrets Manager permissions.

## 7. Monitoring

I created two CloudWatch dashboards.

The first one is focused on the application:

```text
8byte-assignment-staging-application
```

It contains things such as request count, HTTP errors, response time and ECS CPU/memory.

The second one is focused more on the platform:

```text
8byte-assignment-staging-platform
```

It contains ECS, RDS and ALB metrics such as CPU, memory, database connections, storage and target health.

I kept them separate because when troubleshooting an application issue I don't necessarily want to look through all the database and infrastructure metrics at the same time.

## 8. Logging

ECS sends the application container logs to CloudWatch Logs.

The current log group is:

```text
/ecs/8byte-assignment-staging
```

The application doesn't need to maintain log files on the container itself. If the ECS task is replaced, the logs are still available in CloudWatch.

For a larger production setup, I would add structured application logs, request/correlation IDs, log retention settings and ALB access logging.

## 9. CI/CD

I kept CI and deployment as separate workflows.

The CI workflow runs for pull requests and pushes to `master`.

```text
Pull Request
     |
     v
    CI
     |
     +-- Tests
     +-- Dependency scan
     +-- Docker build
     +-- Docker image scan


Merge to master
     |
     v
    CI
     |
     +-- Tests
     +-- Dependency scan
     +-- Docker build
     +-- Docker image scan
     +-- Push image to ECR
                     |
                     v
               Deploy staging
                     |
                     v
                    ECS
```

Trivy is used for the dependency/file scan and for the Docker image scan.

The pipeline fails for HIGH and CRITICAL findings that are not ignored as unfixed.

The CI workflow also sends an email through SES if the workflow fails.

GitHub Actions uses OIDC to assume the AWS IAM role, so there is no AWS access key stored in GitHub.

I kept the pipeline fairly small because it is easier to troubleshoot and there was no need to add extra deployment stages for staging.

## 10. Production environment

The production Terraform configuration is present in the repository but I did not provision it.

The same modules are used for staging and production, with environment-specific values.

Some of the values that I would change for production are:

```text
ECS task count
RDS instance size
RDS Multi-AZ
Backup retention
NAT Gateway setup
```

I would also use a separate AWS account for production.

The production deployment would have a manual approval before changing the ECS service.

## Things I would add before production

The staging flow is working, but I would add a few things before using the same setup for an actual production workload:

* CloudWatch alarms for important failure and capacity conditions
* Manual approval for production deployment
* Deployment rollback verification
* ALB access logging
* Separate AWS account for production
* Tighter IAM policies
* Terraform validation and security checks in CI
* Longer and environment-specific RDS backup settings

The vulnerability scans and CI failure email notification are already part of the current CI workflow, so they are not listed as future work.

## Best practices used

The implementation details and reasoning around state management, IAM, networking, secrets, CI/CD, monitoring and cost are covered in `best-practices.md`.
