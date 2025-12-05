# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [web]
    ${aws_instance.web.public_ip} ansible_user=${length(regexall("ubuntu", var.ami_id)) > 0 || var.ami_id == "ami-05134c8ef96964280" ? "ubuntu" : "ec2-user"}
    
    [web:vars]
    ansible_ssh_private_key_file=~/.ssh/${var.ssh_key_name}.pem
    ansible_python_interpreter=/usr/bin/python3
    EOT
  filename = "${path.module}/../ansible/inventory.ini"
}