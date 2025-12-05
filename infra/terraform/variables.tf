variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "us-west-2"  # Changed to match AWS CLI configuration
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for EC2 instances"
  type        = string
  default     = "devops-stage-6-key"  # Update this to your actual AWS key pair name
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
  default     = "ami-00c1d63aff2d420ad" # Amazon Linux 2 in us-west-2 (latest)
}

variable "environment" {
  description = "Environment name for tagging resources"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name for tagging resources"
  type        = string
  default     = "devops-stage-6"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_http" {
  description = "Enable HTTP traffic"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS traffic"
  type        = bool
  default     = true
}

variable "enable_ssh" {
  description = "Enable SSH traffic"
  type        = bool
  default     = true
}

variable "http_port" {
  description = "HTTP port"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS port"
  type        = number
  default     = 443
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "my_ip" {
  description = "Your IP address for SSH access (use 0.0.0.0/0 for open access)"
  type        = string
  default     = "102.91.98.221/32"  # Restricted to your current IP for security
}