# Approach & Challenges

## 1. Separating Infrastructure Management from Application Deployment

One of the design choices was deciding what Terraform should own and what the deployment pipeline should own.

Terraform provisions the infrastructure and creates the initial ECS task definition. After that GitHub Actions is responsible for deploying application versions.

This avoids having Terraform manage every application image update.

The flow is:

```text
Terraform
    |
    +--> VPC
    +--> ALB
    +--> ECS
    +--> ECR
    +--> RDS
    +--> IAM
    +--> CloudWatch
             |
             v
       Initial ECS setup

GitHub Actions
    |
    +--> Build
    +--> Test
    +--> Push image
    +--> Update ECS task definition
```

This separation also avoids a situation where a normal `terraform apply` unintentionally rolls an ECS service back to an older application version.

For this reason, the ECS service ignores changes to the task definition made by the deployment pipeline.

---

## 2. Making the ECS Deployment Reproducible

I initially used a fixed `bootstrap` image tag to get the ECS service running.

This worked for bootstrapping the environment, but it is not a good deployment strategy because the same tag can point to different image versions.

The CI pipeline therefore uses the Git commit SHA as the image identifier.

For example:

```text
8byte-assignment-staging:<commit-sha>
```

This gives each deployment an immutable reference.

If a deployment needs to be investigated later, the ECS task definition can be traced back to the exact Git commit that produced the image.

The `bootstrap` image is only used to establish the initial working environment.

---

## 3. Remote Terraform State and State Ownership

The infrastructure was initially developed with local Terraform state because it made the first iteration faster.

Once the infrastructure was working, I moved the staging state to an S3 backend.

The state is stored under:

```text
staging/terraform.tfstate
```

The S3 bucket has versioning and encryption enabled.

This was important because Terraform state contains infrastructure information and should not be treated as a normal source-code file.

I also kept the backend separate from the infrastructure modules so that the state storage itself does not depend on the state it is responsible for storing.

For a larger team, I would additionally restrict access to the state bucket through a dedicated IAM policy and use separate state keys/accounts for each environment.

---

## 4. Network Design vs Cost

The ECS tasks and RDS database are kept in private subnets, while the ALB is placed in public subnets.

This gives the application a public entry point without making the containers or database directly reachable from the internet.

There is a cost trade-off with the NAT Gateway.

For a small staging environment, I used a single NAT Gateway instead of one per Availability Zone.

This reduces the cost considerably, but it also means the NAT path is not AZ-independent.

I would use multiple NAT Gateways for a production environment where the additional cost is justified by the availability requirement.

---

## 5. RDS Availability Decision

The RDS instance is configured as:

```text
Multi-AZ: false
Publicly accessible: false
Storage encryption: enabled
```

This was a deliberate staging decision rather than an assumption that Multi-AZ is always required.

The assignment environment does not have a production availability requirement, so paying for Multi-AZ would add cost without providing much value for the demonstration.

For production, I would base the decision on the application's RTO/RPO and database availability requirements.

---

## 6. Secrets Handling

Database credentials are not stored directly in Terraform variables or committed configuration files.

The ECS task definition retrieves the database credentials from AWS Secrets Manager.

This keeps the secret value outside the Git repository and avoids passing the password as a normal environment variable.

The ECS execution/task roles are separated so that permissions can be assigned based on what each role actually needs.

For production, I would also review secret rotation requirements and reduce the scope of Secrets Manager access to the specific secret ARN.

---

## 7. Monitoring Design

I separated the CloudWatch dashboards into two views instead of putting every metric into one dashboard.

### Application dashboard

This is intended to answer:

> Is the application receiving traffic and responding correctly?

It focuses on ALB and ECS metrics such as:

* Request count
* HTTP errors
* Target response time
* ECS CPU
* ECS memory

### Platform dashboard

This is intended to answer:

> Is there an infrastructure or database problem?

It focuses on:

* ECS resource utilization
* RDS CPU
* RDS connections
* RDS storage
* ALB target health

The separation makes the dashboards more useful during troubleshooting instead of having one large dashboard with unrelated metrics.

---

## 8. Logging Strategy

Application logs from ECS are sent directly to CloudWatch Logs using the ECS `awslogs` driver.

This means the container does not need to manage log files locally and operators can inspect logs after a task is replaced.

For a production implementation, I would extend this with:

* CloudWatch alarms
* Log retention policies
* Structured JSON application logs
* Correlation/request IDs
* ALB access logging
* Centralized security/audit logging

These were kept outside the initial implementation to keep the assignment focused on the core infrastructure and deployment path.

---

## 9. CI/CD Boundary

The pipeline was intentionally kept simple:

```text
Pull Request
     |
     v
    CI
     |
     +--> Tests
     +--> Docker build

Merge to master
     |
     v
    CI
     |
     +--> Tests
     +--> Docker build
     +--> Push to ECR
              |
              v
        Deploy Staging
              |
              v
             ECS
```

I preferred a small pipeline that is easy to understand and troubleshoot over adding several deployment stages that were not necessary for the staging environment.

Production deployment, manual approval, vulnerability scanning and notifications are identified as the next steps rather than being added without validating the underlying deployment flow first.

---

# Things I Would Add for Production

The current implementation is intentionally focused on the assignment's staging environment.

For a production implementation, I would add:

* Separate production AWS account/environment
* Manual approval before production deployment
* Container vulnerability scanning
* Dependency scanning
* CloudWatch alarms and alerting
* Slack/email notifications
* ALB access logs
* Structured application logs
* RDS Multi-AZ where required
* Automated rollback verification
* More restrictive IAM policies
* Formal Terraform remote-state access controls
* CI checks for Terraform formatting, validation and security scanning

These are improvements based on operational requirements rather than simply adding more services to the architecture.