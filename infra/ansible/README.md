# Ansible Roles for Application Deployment

This directory contains Ansible roles for setting up dependencies and deploying a multi-container application with Docker, Docker Compose, and Traefik.

## Prerequisites

Before running the Ansible playbook, ensure you have the following:

1. **Ansible installed** on your control machine:
   ```bash
   pip install ansible
   ```

2. **SSH access** to the target server with key-based authentication.

3. **Terraform-provisioned infrastructure** (optional but recommended):
   - Run `terraform apply` in the `../terraform` directory first
   - This will generate an inventory file at `../terraform/ansible_inventory.ini`

4. **Vault-encrypted secrets** (optional but recommended):
   - Create a `vars/vault.yml` file for sensitive data
   - Encrypt it with `ansible-vault encrypt vars/vault.yml`

## Roles

### Dependencies Role (`roles/dependencies`)

This role installs and configures all necessary system dependencies:

- Docker and Docker Compose
- Git
- Required packages for Traefik
- Other necessary system packages

#### Key Features:
- Idempotent installation of Docker and Docker Compose
- Configuration of Docker daemon with proper logging
- User setup for Docker access
- System package management

### Deploy Role (`roles/deploy`)

This role handles the deployment of the application:

- Cloning the application repository
- Pulling latest changes
- Starting services with Docker Compose
- Setting up Traefik and SSL with Let's Encrypt
- Idempotent deployment (no restart unless files changed)

#### Key Features:
- Git-based deployment with version control
- Docker Compose service management
- Traefik reverse proxy configuration
- SSL certificate management with Let's Encrypt
- Environment variable management

## Usage

### 1. Using with Terraform-generated Inventory (Recommended)

After provisioning your infrastructure with Terraform:

```bash
# Run the playbook using the Terraform-generated inventory
ansible-playbook -i ../terraform/ansible_inventory.ini playbook.yml
```

### 2. Using with Static Inventory

For testing or manual setup:

```bash
# Run the playbook using the example inventory
ansible-playbook -i inventory playbook.yml
```

### 3. Using with Vault-encrypted Secrets

If you have encrypted secrets:

```bash
# Run the playbook with vault password
ansible-playbook -i inventory playbook.yml --ask-vault-pass
```

Or, if you have a vault password file:

```bash
# Run the playbook with vault password file
ansible-playbook -i inventory playbook.yml --vault-password-file ~/.vault_pass.txt
```

## Configuration

### Variables

The main variables that can be customized are in the `playbook.yml` file:

- `app_domain`: The domain name for your application
- `ssl_email`: Email for Let's Encrypt certificate notifications
- `vault_db_password`: Database password (should be in vault)
- `vault_jwt_secret`: JWT secret for authentication (should be in vault)
- `vault_rabbitmq_password`: RabbitMQ password (should be in vault)

### Secrets Management

For production use, it's recommended to use Ansible Vault for sensitive data:

1. Create a `vars/vault.yml` file with your secrets:

```yaml
vault_db_password: "your_secure_db_password"
vault_jwt_secret: "your_secure_jwt_secret"
vault_rabbitmq_password: "your_secure_rabbitmq_password"
```

2. Encrypt the file:

```bash
ansible-vault encrypt vars/vault.yml
```

3. Update the `vars_files` section in `playbook.yml` to use this file.

## Troubleshooting

### Common Issues

1. **Docker permission errors**:
   - Ensure the user is in the docker group
   - You may need to log out and log back in for group changes to take effect

2. **SSL certificate issues**:
   - Ensure the domain name is correctly configured and pointing to your server
   - Check that ports 80 and 443 are open and accessible
   - Verify your DNS settings

3. **Git repository issues**:
   - Ensure the repository URL is correct and accessible
   - Check that the branch exists
   - Verify SSH keys if using a private repository

4. **Docker Compose issues**:
   - Check that all environment variables are set correctly
   - Verify that the Docker images are available
   - Check the Docker Compose logs with `docker-compose logs`

### Debugging

To enable debug mode, set `debug_mode: true` in the `playbook.yml` file. This will provide more detailed output during the playbook run.

### Testing the Deployment

1. Check if all containers are running:
   ```bash
   docker ps
   ```

2. Check the application logs:
   ```bash
   docker-compose logs -f
   ```

3. Check Traefik dashboard:
   - Access at `https://{{ traefik_dashboard_host }}`
   - Verify that all services are properly routed

## Idempotency

The Ansible roles are designed to be fully idempotent. Running the playbook multiple times will:

- Only make changes if necessary
- Not restart services unless configuration files have changed
- Preserve the current state if no changes are needed

This makes the playbook safe to run in production environments.

## Security Considerations

1. Use strong passwords and secrets
2. Store secrets in Ansible Vault
3. Limit access to the inventory files
4. Use SSH key-based authentication
5. Regularly update Docker images and dependencies
6. Monitor logs and security advisories

## Contributing

When making changes to these roles:

1. Test changes in a non-production environment first
2. Ensure idempotency is maintained
3. Update documentation as needed
4. Follow Ansible best practices