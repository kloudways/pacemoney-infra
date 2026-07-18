output "jenkins_instance_id" {
  description = "EC2 instance ID of the Jenkins server"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins server (use for browser access and Ansible inventory)"
  value       = aws_eip.jenkins.public_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing and pulling application images"
  value       = aws_ecr_repository.main.repository_url
}

output "kops_master_instance_profile_arn" {
  description = "ARN of the IAM instance profile for Kops master nodes"
  value       = aws_iam_instance_profile.kops_master.arn
}

output "kops_node_instance_profile_arn" {
  description = "ARN of the IAM instance profile for Kops worker nodes"
  value       = aws_iam_instance_profile.kops_node.arn
}

output "kops_state_bucket" {
  description = "Name of the S3 bucket used as the Kops state store"
  value       = aws_s3_bucket.kops_state.bucket
}

output "private_subnet_ids" {
  description = "IDs of the private subnets where Kops nodes run"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets for the ALB and NAT Gateway"
  value       = aws_subnet.public[*].id
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance"
  value       = aws_db_instance.main.endpoint
}

output "sg_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "sg_app_node_id" {
  description = "ID of the app node security group to attach to Kops node instance groups"
  value       = aws_security_group.app_node.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
