variable "aws_region" {
  description = "AWS region for provisioning resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for tags and naming"
  type        = string
  default     = "python-ec2-deployment"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the Public Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance size for the Python application"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing AWS EC2 Key Pair (only used if auto_generate_key_pair is false)"
  type        = string
  default     = "my-ec2-key"
}

variable "auto_generate_key_pair" {
  description = "Automatically generate an RSA SSH key pair in AWS and save .pem locally (Prevents InvalidKeyPair.NotFound error)"
  type        = bool
  default     = true
}


variable "create_iam_user" {
  description = "Whether to create IAM user and access keys for GitHub Actions SSM deployment"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Set to false to avoid AWS charges for NAT Gateway ($32/month). The pipeline uses offline wheels."
  type        = bool
  default     = false
}


