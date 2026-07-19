# Runbook

## Daily startup

### 1. Apply Terraform

```bash
cd terraform
export TF_VAR_db_password="<saved password>"
terraform apply
```

Wait for RDS to finish provisioning (approximately 5 minutes). The `rds_endpoint` output confirms it is ready.

### 2. Configure Jenkins with Ansible

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml site.yml
```

This installs Docker, Jenkins, Trivy, kops, Helm, kubectl, and sonar-scanner on the Jenkins EC2 instance.

### 3. Recreate the kops cluster

```bash
kops create -f terraform/kops/cluster.yaml
kops create -f terraform/kops/master.yaml
kops create -f terraform/kops/nodes.yaml

kops update cluster pacemoney.k8s.local \
  --state s3://pacemoney-kops-state \
  --yes

# Wait approximately 10 minutes for nodes to be ready
kops validate cluster pacemoney.k8s.local \
  --state s3://pacemoney-kops-state \
  --wait 15m
```

### 4. Reconfigure Jenkins

Open `http://jenkins.kloudways.com:8080` and complete the following:

- Install plugins: AnsiColor, Pipeline, Git, Credentials Binding, Workspace Cleanup
- Add credential `sonar-token` (Secret text, the SonarCloud token)
- Add credential `db-url` (Secret text, the full PostgreSQL connection string)
- Create a Pipeline job pointing at `https://github.com/kloudways/pacemoney-app.git`, branch `main`, Jenkinsfile from SCM

### 5. Deploy the application

Trigger the Jenkins pipeline. On first run after a fresh kops cluster, the Helm deploy creates a new LoadBalancer Service and kops provisions an ELB. This takes 2-3 minutes.

### 6. Update the app ELB hostname

After the pipeline's Helm Deploy stage succeeds:

```bash
kops export kubecfg pacemoney.k8s.local \
  --state s3://pacemoney-kops-state --admin

kubectl get svc -n pacemoney
# Copy the EXTERNAL-IP value
```

Add it to `terraform/terraform.tfvars`:

```hcl
app_elb_hostname = "<EXTERNAL-IP from above>"
```

Then apply:

```bash
terraform apply -target=aws_route53_record.app
```

## Daily teardown

```bash
# Step 1: delete the kops cluster (must be done before terraform destroy)
kops delete cluster \
  --name pacemoney.k8s.local \
  --state s3://pacemoney-kops-state \
  --yes

# Wait for cluster deletion to complete (2-3 minutes)

# Step 2: remove kops state bucket from Terraform state
# (bucket is intentionally kept for reuse tomorrow)
cd terraform
terraform state rm aws_s3_bucket.kops_state

# Step 3: destroy all remaining infrastructure
terraform destroy
```

### AWS console verification

After destroy, confirm the following are gone:

- EC2: no running instances, no unattached volumes, no EIPs allocated, no load balancers, no auto scaling groups, no launch templates
- VPC: only the default VPC remains
- RDS: no instances, no subnet groups
- ECR: repository is deleted
- Route 53: `jenkins.kloudways.com` and `pacemoney.kloudways.com` records are gone

The following intentionally remain:

- S3: `kloudways-pacemoney-tfstate` (Terraform backend) and `pacemoney-kops-state` (kops state, reused on next startup)
- Route 53: hosted zone `kloudways.com`

## Rotating the RDS password

Generate a new password and apply:

```bash
export TF_VAR_db_password="$(openssl rand -base64 24)"
echo $TF_VAR_db_password   # save securely
terraform apply -target=aws_db_instance.main
```

Then update the `db-url` Jenkins credential with the new password.

## Troubleshooting

### Pods in CrashLoopBackOff after Helm deploy

```bash
kubectl get pods -n pacemoney
kubectl describe pod -n pacemoney <pod-name>
kubectl logs -n pacemoney <pod-name> --previous
```

Check:

1. Does the Secret exist? `kubectl get secret -n pacemoney pacemoney-pacemoney-db`
2. Is the DATABASE_URL value correct? `kubectl get secret pacemoney-pacemoney-db -n pacemoney -o jsonpath='{.data.DATABASE_URL}' | base64 -d`
3. Can the pod reach RDS? Exit code 137 with empty logs means the process hung before uvicorn started, which indicates a network timeout on the database connection.
4. Is the RDS security group allowing traffic from the node? The RDS security group should allow port 5432 from 10.1.0.0/16.

### Helm deploy times out with `context deadline exceeded`

The pods are not becoming ready within 5 minutes. See pod troubleshooting above. Common causes:

- Wrong database password in the `db-url` Jenkins credential
- RDS not reachable from the node (security group issue)
- `create_all` hanging before uvicorn starts (if running an old image without the lifespan fix)

### Jenkins build fails at SonarQube

- Confirm the `sonar-token` credential exists in Jenkins and is not expired
- Confirm Automatic Analysis is disabled in the SonarCloud project: `Administration -> Analysis Method -> CI-based analysis`
- Confirm `sonar-project.properties` contains `sonar.organization=kloudways`

### Trivy fails with HIGH or CRITICAL CVEs

All HIGH/CRITICAL CVEs in the base image should be suppressed by `--ignore-unfixed`. If new fixable CVEs appear, update the base image in the Dockerfile:

```dockerfile
FROM python:3.12-slim
```

Pull the latest digest and rebuild.

### kops delete cluster hangs on security groups or volumes

kops retries automatically. Security groups and volumes cannot be deleted until the EC2 instances using them have fully terminated. Wait 3-5 minutes for the retry loop to complete. Do not interrupt the process.

## Cost hygiene

- Always run `kops delete cluster` before `terraform destroy`. kops resources are not tracked by Terraform and will continue billing if left running.
- The NAT gateway and RDS instance are the two highest-cost items. Confirm both are destroyed in the AWS console after teardown.
- ECR image storage is cheap but unbounded without a lifecycle policy. The current policy retains a maximum of 30 images.
