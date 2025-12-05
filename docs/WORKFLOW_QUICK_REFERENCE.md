# GitHub Actions Workflows - Quick Reference

## Workflow Files
- **Infrastructure:** `.github/workflows/infrastructure.yml`
- **Application:** `.github/workflows/application.yml`

---

## Triggering Workflows

### Automatic Triggers

#### Infrastructure Workflow
```bash
# Triggers on push to main affecting:
git add infra/terraform/
git add infra/ansible/
git commit -m "Update infrastructure"
git push origin main
```

#### Application Workflow
```bash
# Triggers on push to main affecting:
git add auth-api/ frontend/ todos-api/ users-api/ log-message-processor/
git add docker-compose.yml
git commit -m "Update application"
git push origin main
```

### Manual Triggers

#### Via GitHub UI
1. Go to `Actions` tab
2. Select workflow (Infrastructure/Application Deployment)
3. Click `Run workflow`
4. Select branch (main)
5. Click green `Run workflow` button

#### Via GitHub CLI
```bash
# Install gh CLI: https://cli.github.com/

# Trigger infrastructure workflow
gh workflow run infrastructure.yml

# Trigger application workflow
gh workflow run application.yml

# Trigger drift detection
gh workflow run infrastructure.yml -f job=drift-detection
```

---

## Monitoring Workflows

### Check Workflow Status
```bash
# List recent workflow runs
gh run list

# View specific run
gh run view <run-id>

# Watch run in real-time
gh run watch <run-id>

# View logs
gh run view <run-id> --log
```

### GitHub UI
1. Navigate to `Actions` tab
2. Click on workflow run
3. Click on job to see logs
4. Download logs with "Download log archive"

---

## Common Scenarios

### Scenario 1: Deploy Infrastructure Changes
```bash
# 1. Make changes to Terraform
vim infra/terraform/main.tf

# 2. Commit and push
git add infra/terraform/
git commit -m "Add new security group rule"
git push origin main

# 3. Workflow runs automatically:
#    - terraform-plan: Generates plan
#    - Manual approval required (production environment)
#    - terraform-apply: Applies changes after approval
```

### Scenario 2: Deploy Application Updates
```bash
# 1. Make changes to application code
vim frontend/src/components/App.vue

# 2. Commit and push
git add frontend/
git commit -m "Update frontend UI"
git push origin main

# 3. Workflow runs automatically:
#    - check-infrastructure: Verifies server exists
#    - deploy-application: Pulls code and restarts containers
#    - Verifies deployment with health checks
```

### Scenario 3: Check for Infrastructure Drift
```bash
# Manual drift detection
gh workflow run infrastructure.yml

# Or schedule in infrastructure.yml:
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
```

### Scenario 4: Rollback Application
```bash
# If deployment fails, automatic rollback runs
# Manual rollback:
ssh ubuntu@<instance-ip>
cd /opt/app
git reset --hard HEAD~1
sudo docker-compose down
sudo docker-compose up -d
```

---

## Workflow Outputs

### Infrastructure Workflow Outputs
- Instance ID
- Instance public/private IP
- VPC ID
- Subnet ID
- Security Group ID
- Ansible inventory file location

### Application Workflow Outputs
- Instance IP
- Container count
- Health check results

---

## Debugging Failed Workflows

### Terraform Plan Failed
```bash
# Check terraform syntax locally
cd infra/terraform
terraform init
terraform validate
terraform plan

# View workflow logs
gh run view <run-id> --log
```

### Terraform Apply Failed
```bash
# Check state lock
aws dynamodb describe-table --table-name terraform-state-lock

# View state
cd infra/terraform
terraform state list

# If locked, force unlock (CAREFUL!)
terraform force-unlock <lock-id>
```

### Ansible Deployment Failed
```bash
# Test Ansible connectivity
cd infra/ansible
ansible -i inventory.ini all -m ping

# Run playbook manually with verbose mode
ansible-playbook -i inventory.ini playbook.yml -vvv

# Check SSH access
ssh -i ~/.ssh/devops-stage-6-key.pem ubuntu@<instance-ip>
```

### Application Deployment Failed
```bash
# SSH to server and check logs
ssh ubuntu@<instance-ip>
cd /opt/app
sudo docker-compose logs

# Check container status
sudo docker-compose ps

# Restart manually
sudo docker-compose restart
```

---

## Useful Commands

### Local Testing
```bash
# Run local validation tests
./test-workflows.sh

# Test infrastructure workflow with act
act workflow_dispatch -W .github/workflows/infrastructure.yml -j terraform-plan -n

# Test application workflow with act
act workflow_dispatch -W .github/workflows/application.yml -j check-infrastructure -n
```

### Check Infrastructure Status
```bash
# Get instance IP from Terraform
cd infra/terraform
terraform output instance_public_ip

# Check if instance is running
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id)

# Test application
curl -H "Host: localhost" http://$(terraform output -raw instance_public_ip)/
```

### Check Application Status
```bash
# SSH to server
ssh ubuntu@$(cd infra/terraform && terraform output -raw instance_public_ip)

# Check containers
sudo docker-compose ps

# Check logs
sudo docker-compose logs -f

# Check Traefik
curl -s http://localhost:8080/api/overview
```

---

## Environment Variables

### Required Secrets (GitHub)
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `SSH_PRIVATE_KEY`: EC2 SSH private key

### Optional Secrets
- `NOTIFICATION_EMAIL`: Email for drift notifications
- `APPROVERS`: GitHub usernames for manual approvals

---

## Workflow Customization

### Change Terraform Version
```yaml
# In .github/workflows/infrastructure.yml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.6.0  # Change this
```

### Change AWS Region
```yaml
# In .github/workflows/*.yml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: us-east-1  # Change this
```

### Add Slack Notifications
```yaml
# Add to workflow file
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Deployment failed: ${{ github.sha }}"
      }
```

---

## Best Practices

1. **Always test locally first**
   ```bash
   ./test-workflows.sh
   ```

2. **Use feature branches for major changes**
   ```bash
   git checkout -b feature/new-service
   # Make changes
   git push origin feature/new-service
   # Create PR (triggers workflow on PR)
   ```

3. **Review Terraform plan before applying**
   - Check workflow logs for plan output
   - Approve only after review

4. **Monitor application after deployment**
   ```bash
   # Watch logs for 2 minutes
   ssh ubuntu@<ip> "cd /opt/app && sudo docker-compose logs -f --tail=100"
   ```

5. **Keep secrets secure**
   - Never commit `.secrets` file
   - Rotate credentials regularly
   - Use GitHub OIDC for better security

---

## Quick Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| Workflow not triggering | Check branch name, file paths in `on` section |
| Terraform state locked | `terraform force-unlock <id>` |
| SSH connection timeout | Check security group, instance status |
| Container won't start | Check logs: `docker-compose logs <service>` |
| Health check fails | Wait longer, check port mappings |
| Secrets not found | Verify secrets configured in GitHub |

---

## Support

For detailed information, see:
- `WORKFLOW_TEST_REPORT.md` - Comprehensive testing report
- `.github/workflows/infrastructure.yml` - Infrastructure workflow
- `.github/workflows/application.yml` - Application workflow
- `test-workflows.sh` - Local testing script

For issues, check workflow logs in GitHub Actions tab.
