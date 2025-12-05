# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-vpc-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-public-subnet-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "${var.project}-public-rt-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create Security Group
resource "aws_security_group" "web" {
  name        = "${var.project}-sg-${var.environment}"
  description = "Allow HTTP, HTTPS, and SSH traffic"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.enable_http ? [1] : []
    content {
      from_port   = var.http_port
      to_port     = var.http_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP traffic"
    }
  }

  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      from_port   = var.https_port
      to_port     = var.https_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS traffic"
    }
  }

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = var.ssh_port
      to_port     = var.ssh_port
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
      description = "Allow SSH traffic from specific IP"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project}-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create EC2 instance
resource "aws_instance" "web" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  tags = {
    Name        = "${var.project}-instance-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }

  # User data for initial setup
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-pip
              EOF
}

# Wait for EC2 instance to be SSH-ready and Python installed before running Ansible
resource "null_resource" "wait_for_instance" {
  depends_on = [aws_instance.web]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      echo "Waiting for instance ${aws_instance.web.public_ip} to be SSH-ready..."
      for i in $(seq 1 30); do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.web.public_ip} "python3 --version" 2>/dev/null; then
          echo "Instance is ready with Python 3!"
          exit 0
        fi
        echo "Attempt $i/30: Instance not ready yet, waiting 10 seconds..."
        sleep 10
      done
      echo "Instance did not become ready in time"
      exit 1
    EOT
  }
}

# Trigger Ansible after infrastructure is provisioned and instance is ready
resource "null_resource" "run_ansible" {
  # Ensure Ansible runs only after the server is ready and inventory is written
  depends_on = [
    null_resource.wait_for_instance,
    local_file.ansible_inventory
  ]

  # Execute the Ansible playbook on the local machine
  provisioner "local-exec" {
    command = "cd ${path.module}/../ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml --ssh-common-args='-o IdentitiesOnly=yes'"
  }

  # Re-run if the instance or inventory changes
  triggers = {
    instance_id  = aws_instance.web.id
    inventory    = local_file.ansible_inventory.content
  }
}