# Auto-Discovery Pet Adoption Application

This repository contains Terraform configuration for provisioning AWS infrastructure for a Pet Adoption application. The project uses reusable Terraform modules to create networking, CI/CD infrastructure, staging and production environments, supporting DevOps tools, and application deployment resources.

## Project Overview

The main infrastructure stack provisions an AWS environment for the Pet Adoption application. It uses Terraform for infrastructure provisioning, Jenkins for CI/CD automation, and Ansible and Docker for application deployment.

The infrastructure includes:

- A dedicated VPC with public and private subnets across multiple Availability Zones.
- Internet Gateway and NAT Gateway for internet access and private subnet egress.
- Application Load Balancers for staging and production traffic.
- Auto Scaling Groups to manage application instances.
- Docker containers running the Pet Adoption application.
- An Ansible control node for configuration management and deployment.
- Jenkins for CI/CD pipeline automation.
- SonarQube for source-code analysis and quality gates.
- Nexus for storing application build artifacts.
- HashiCorp Vault for secrets management.
- Amazon RDS MySQL for application data storage.
- Amazon Route 53 for DNS management.
- AWS Certificate Manager (ACM) for HTTPS certificates.
- Amazon S3 and DynamoDB for Terraform remote state storage and locking.
- New Relic for monitoring and Slack for pipeline notifications.

The project also includes an Auto-Discovery mechanism that identifies running EC2 instances in configured Auto Scaling Groups and automatically updates the Ansible inventory when instance IP addresses change.

## Architecture

At a high level, the project separates public-facing services from application workloads:

- Public subnets host configured internet-facing resources, including load balancers and supporting access infrastructure.
- Private subnets host application instances and database resources where configured.
- Application Load Balancers distribute incoming traffic to the staging and production environments.
- Auto Scaling Groups manage application instances and support instance replacement and scaling.
- An Auto-Discovery script queries AWS for current running instances and updates the Ansible inventory.
- Ansible uses the updated inventory to target the current application instances during deployment.
- Jenkins coordinates the CI/CD pipeline and integrates with the GitHub repositories.
- SonarQube analyses application source code, OWASP Dependency-Check scans dependencies, Trivy scans Docker images, and Checkov scans Terraform configurations.
- Nexus stores application build artifacts for subsequent deployment.
- Vault manages configured secrets, including database credentials.
- Amazon RDS MySQL provides database services.
- Amazon Route 53 and ACM support DNS and HTTPS for configured endpoints.
- New Relic and Slack provide monitoring and pipeline notifications where configured.

## Repository Structure

The project uses separate GitHub repositories for infrastructure and application code. The exact directory structure depends on the repository.

```text
.
|-- main.tf                  # Root Terraform configuration
|-- provider.tf              # AWS provider and Terraform backend configuration
|-- variables.tf             # Input variable definitions
|-- outputs.tf               # Terraform outputs
|-- create-s3-bucket.sh      # Create remote state
|-- delete-s3-bucket,sh      # Delete remote state
|-- ansible/                 # Ansible inventory, playbooks, and configuration
|-- modules/                 # Reusable Terraform modules
|   |-- vpc/                 # VPC, subnet, gateway, and routing resources
|   |-- jenkins/             # Jenkins infrastructure/vault infrastucture
|   |-- database/            # Provides the application database.
|   |-- nexus/               # Nexus infrastructure
|   |-- ansible/             # Ansible inventory, playbooks, and configuration
|   |-- sonarqube/           # SonarQube infrastructure
|   |-- stage/               # Staging environment resources
|   `-- prod/                # Production environment resources
`-- README.md                # Project documentation
```


## Terraform State

The Terraform configuration uses an S3 remote backend for state storage and DynamoDB for state locking where configured.

- **S3 bucket:** Stores the Terraform state file.
- **DynamoDB table:** Prevents concurrent Terraform operations from modifying the same state.
- **State separation:** Separate state keys can be used for different infrastructure stacks or environments.
- **State protection:** S3 versioning and encryption help protect stored state.

Use the actual bucket name, lock-table name, state keys, AWS profile, and region defined in your Terraform backend configuration. Do not commit credentials or sensitive state data to GitHub.

## Prerequisites

Before applying this project, make sure you have:

- Terraform installed at a compatible version.
- AWS CLI installed and configured with the correct AWS profile.
- Access to the AWS region configured in Terraform.
- The required S3 backend bucket and DynamoDB lock table created, if using a remote backend.
- Required AWS permissions for EC2, VPC, IAM, S3, DynamoDB, Auto Scaling, Elastic Load Balancing, RDS, Route 53, ACM, and other services used by the configuration.
- Access to the infrastructure and application GitHub repositories.
- Jenkins configured with the required plugins, credentials, and webhook integrations.
- Ansible and Docker configured for the deployment workflow.
- Maven and a compatible Java version for building the application.
- Valid Route 53 hosted zone and ACM certificate configuration for HTTPS endpoints.
- Required integrations configured for SonarQube, Nexus, Vault, New Relic, and Slack.

## Usage

Initialize and validate the Terraform configuration from the appropriate infrastructure directory:

```bash
terraform init
terraform fmt -check
terraform validate
```

Review the planned infrastructure changes:

```bash
terraform plan
```

Apply the infrastructure after reviewing the plan:

```bash
terraform apply
```

Run these commands from the correct Terraform working directory and use the required variables, workspace, AWS profile, and region.

For application delivery, trigger the configured Jenkins pipeline through a GitHub webhook or manually from Jenkins. Review the pipeline results before promoting the application from staging to production.

## Auto-Discovery Workflow

The Auto-Discovery mechanism keeps the Ansible inventory updated as EC2 instances change.

The workflow is as follows:

1. A scheduled cron job runs the discovery script.
2. The script queries AWS for running instances in the configured Auto Scaling Groups.
3. It retrieves the current instance IP addresses.
4. It updates the relevant Ansible inventory file.
5. Ansible uses the refreshed inventory when a deployment or configuration playbook runs.

This reduces manual inventory maintenance and helps deployment automation target the current instances.

**Note:** Auto-Discovery refreshes the inventory; it does not automatically deploy the application unless a separate deployment process is triggered.

## Jenkins Pipeline

The Jenkins pipeline automates the application delivery workflow. Depending on the configured Jenkinsfile, the stages include:

- Checkout application source code from GitHub.
- Run SonarQube source-code analysis and quality-gate checks.
- Build the Java application using Maven.
- Scan third-party dependencies using OWASP Dependency-Check.
- Publish the build artifact to Nexus.
- Use Ansible to retrieve the artifact and coordinate Docker image creation.
- Scan the Docker image using Trivy.
- Deploy the application to the selected staging or production environment.
- Run Checkov scans in the infrastructure pipeline to identify Terraform configuration issues.
- Send Slack notifications for pipeline success or failure where configured.

The infrastructure pipeline uses Terraform to initialize, validate, plan, and apply infrastructure changes according to the configured approval process.

## Security

Security controls are applied across the infrastructure and CI/CD workflow:

- Private GitHub repositories and token-based authentication control source-code access.
- Checkov scans Terraform configurations for potential security misconfigurations.
- OWASP Dependency-Check identifies known vulnerabilities in third-party libraries.
- Trivy scans Docker images for known vulnerabilities.
- Security groups restrict network access according to the configured service requirements.
- Private subnets limit direct public exposure of application and database resources where configured.
- AWS Systems Manager supports managed access to eligible instances.
- Vault manages configured secrets, including database credentials.
- ACM certificates support HTTPS on configured endpoints.
- S3 versioning, encryption, and public-access blocking help protect Terraform state where enabled.

Security scanning helps identify potential issues, but findings must be reviewed and resolved according to the project's deployment policy.

## Monitoring and Notifications

New Relic is used where configured to monitor infrastructure and application performance. Slack notifications provide updates on Jenkins pipeline results.

For troubleshooting, review Jenkins console output, Auto Scaling Group activity, load-balancer target health, EC2 instance status, Ansible logs, Docker container logs, application logs, and New Relic telemetry.

## Cost Management

Cost-management practices include:

- Using appropriately sized EC2 instances and database resources.
- Configuring Auto Scaling Group capacity based on workload requirements.
- Reviewing AWS billing and Cost Explorer.
- Setting budgets and billing alerts.
- Removing unused resources and temporary environments.
- Preserving shared resources required for Terraform state management.

Actual costs depend on the resources deployed, the AWS region, and usage.

## Cleanup

Before destroying infrastructure:

1. Confirm the AWS account, region, workspace, and Terraform backend.
2. Review the resources that will be removed.
3. Back up required application data and artifacts.
4. Identify shared resources that must remain, including state-storage resources.
5. Review the Terraform destroy plan or cleanup script.
6. Verify the resources removed from AWS.

**Warning:** Destroying infrastructure can cause application downtime and permanent data loss. Do not delete the S3 state bucket or DynamoDB lock table until you have confirmed that they are no longer needed and that the Terraform state is safely backed up.

## Notes

- Review `terraform fmt -check`, `terraform validate`, and `terraform plan` before applying infrastructure changes.
- Keep credentials, private keys, tokens, and other sensitive information out of source control.
- Confirm that the Auto-Discovery script uses the correct AWS region, Auto Scaling Group identifiers, and Ansible inventory path.
- Inventory refresh and application deployment are separate operations unless explicitly connected in the automation.
- Verify the actual Terraform modules, Jenkins stages, and security settings before relying on them in production.
