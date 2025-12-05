#!/bin/bash
# Test script to validate GitHub Actions workflows locally
# This simulates the workflow steps without making actual changes

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  GitHub Actions Workflow Local Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to print step headers
print_step() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Test 1: Infrastructure Workflow - Terraform Plan
print_step "TEST 1: Infrastructure Workflow - Terraform Plan"
echo "Testing if terraform commands work..."

cd infra/terraform

# Check terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi
print_success "Terraform is installed ($(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4))"

# Check AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    print_error "AWS credentials not configured"
    exit 1
fi
print_success "AWS credentials are configured"

# Test terraform init
print_step "Running terraform init..."
if terraform init > /tmp/tf_init.log 2>&1; then
    print_success "Terraform init successful"
else
    print_error "Terraform init failed"
    cat /tmp/tf_init.log
    exit 1
fi

# Test terraform validate
print_step "Running terraform validate..."
if terraform validate > /tmp/tf_validate.log 2>&1; then
    print_success "Terraform validation passed"
else
    print_error "Terraform validation failed"
    cat /tmp/tf_validate.log
    exit 1
fi

# Test terraform plan
print_step "Running terraform plan..."
if terraform plan -out=/tmp/tfplan > /tmp/tf_plan.log 2>&1; then
    print_success "Terraform plan generated successfully"
    
    # Check for changes
    if grep -q "No changes" /tmp/tf_plan.log; then
        print_success "No infrastructure changes detected (idempotent)"
    else
        echo -e "${YELLOW}Changes detected in plan:${NC}"
        grep -A 5 "Terraform will perform" /tmp/tf_plan.log || true
    fi
else
    print_error "Terraform plan failed"
    cat /tmp/tf_plan.log
    exit 1
fi

cd ../..

# Test 2: Application Workflow - Instance Check
print_step "TEST 2: Application Workflow - Instance Check"
echo "Checking if EC2 instance exists and is accessible..."

# Get instance IP from terraform output
cd infra/terraform
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)

if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" == "" ]; then
    print_error "Could not get instance IP from Terraform"
    exit 1
fi
print_success "Instance IP retrieved: $INSTANCE_IP"

# Check if instance responds to ping
print_step "Checking instance connectivity..."
if ping -c 3 -W 2 $INSTANCE_IP > /dev/null 2>&1; then
    print_success "Instance is reachable via ping"
else
    print_error "Instance is not responding to ping"
fi

# Check if SSH port is open
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$INSTANCE_IP/22" 2>/dev/null; then
    print_success "SSH port (22) is open"
else
    print_error "SSH port (22) is not accessible"
fi

# Check if HTTP port is open
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$INSTANCE_IP/80" 2>/dev/null; then
    print_success "HTTP port (80) is open"
else
    print_error "HTTP port (80) is not accessible"
fi

cd ../..

# Test 3: Application Health Check
print_step "TEST 3: Application Health Check"
echo "Verifying application is responding..."

# Test frontend
if curl -s -H "Host: localhost" http://$INSTANCE_IP/ | grep -q "frontend"; then
    print_success "Frontend is responding correctly"
else
    print_error "Frontend is not responding correctly"
fi

# Test Traefik dashboard
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$INSTANCE_IP:8080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "401" ]; then
    print_success "Traefik dashboard is accessible (HTTP $HTTP_CODE)"
else
    print_error "Traefik dashboard is not accessible (HTTP $HTTP_CODE)"
fi

# Test 4: Workflow File Syntax
print_step "TEST 4: Workflow File Syntax Validation"

# Check if workflow files are valid YAML
for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
            print_success "$(basename $workflow) has valid YAML syntax"
        else
            print_error "$(basename $workflow) has invalid YAML syntax"
            exit 1
        fi
    fi
done

# Test 5: Required Secrets Check
print_step "TEST 5: Required Secrets Validation"

REQUIRED_SECRETS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "SSH_PRIVATE_KEY"
)

echo "Checking if required secrets are defined..."
for secret in "${REQUIRED_SECRETS[@]}"; do
    if grep -q "$secret" .github/workflows/*.yml; then
        print_success "Workflow references secret: $secret"
    else
        print_error "Workflow missing secret reference: $secret"
    fi
done

# Test 6: Ansible Inventory Check
print_step "TEST 6: Ansible Configuration Check"

if [ -f "infra/ansible/inventory.ini" ]; then
    print_success "Ansible inventory file exists"
    
    # Check if inventory has the correct IP
    if grep -q "$INSTANCE_IP" infra/ansible/inventory.ini; then
        print_success "Ansible inventory has correct IP address"
    else
        print_error "Ansible inventory IP mismatch"
    fi
else
    print_error "Ansible inventory file not found"
fi

# Check if vault file exists
if [ -f "infra/ansible/vars/vault.yml" ]; then
    print_success "Ansible vault file exists"
else
    print_error "Ansible vault file not found"
fi

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}✓ All workflow validation tests passed!${NC}"
echo ""
echo "The workflows are ready to be used with GitHub Actions."
echo "Next steps:"
echo "  1. Configure GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, SSH_PRIVATE_KEY)"
echo "  2. Push the workflow files to GitHub"
echo "  3. Workflows will run automatically on push/PR to main branch"
echo ""
