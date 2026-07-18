variable "app_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8000
}

variable "app_elb_hostname" {
  description = "ELB hostname created by the Kubernetes LoadBalancer service (copy from kubectl get svc)"
  type        = string
}

variable "app_hostname" {
  description = "Full hostname for the application"
  type        = string
  default     = "pacemoney.kloudways.com"
}

variable "app_name" {
  description = "Infrastructure slug used in resource names, namespaces, and labels"
  type        = string
  default     = "pacemoney"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "Kops cluster name (gossip mode requires .k8s.local suffix)"
  type        = string
  default     = "pacemoney.k8s.local"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance in gigabytes"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_password" {
  description = "Master password for the RDS instance (supply via TF_VAR_db_password)"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "pacemoney_admin"
}

variable "display_name" {
  description = "Human-readable application name for user-facing content"
  type        = string
  default     = "Pace Money"
}

variable "domain_name" {
  description = "Root domain name for DNS and certificate resources"
  type        = string
  default     = "kloudways.com"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}
