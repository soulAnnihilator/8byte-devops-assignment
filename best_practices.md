## CI/CD

I kept CI and deployment as separate workflows.

The CI workflow runs for pull requests and pushes to `master`.

For a pull request:

```text
PR
 |
 +-- tests
 |
 +-- dependency scan
 |
 +-- Docker build
 |
 +-- image scan
```

For a merge to `master`, the same checks run and the image is pushed to ECR.

The Docker image is tagged with the Git commit SHA instead of using `latest`.

For example:

```text
8byte-assignment-staging:<commit-sha>
```

This makes it possible to identify which commit produced the image running in ECS.

The workflow also uses GitHub OIDC to assume the AWS deployment role. I did not put an AWS access key and secret key into GitHub.

If the CI workflow fails, it sends an email using Amazon SES with the repository, branch, commit and workflow run information.

## Security checks in CI

I added two Trivy checks.

The first scans the application files for dependency vulnerabilities.

The second scans the Docker image after it is built.

Only HIGH and CRITICAL vulnerabilities are used to fail the workflow, and unfixed findings are ignored.

This is not meant to replace a full security process, but it gives the pipeline a basic security check before an image reaches ECR.

## What is not implemented yet

The main pieces I would add before using this as a production deployment are:

* Manual approval before production deployment
* Deployment rollback checks
* CloudWatch alarms
* Separate AWS accounts for production and non-production
* More restrictive IAM policies

The production Terraform configuration is already present in the repository, but I have not provisioned it.

The current working deployment is staging.
