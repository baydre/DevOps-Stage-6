# Deployment Guide

## Environment Variables (.env)

### ⚠️ Important Security Notes

1. **`.env` is NOT in git** - It contains sensitive secrets (JWT_SECRET, etc.)
2. **`.env.sample` is tracked** - Safe template with placeholder values
3. **Server `.env` is managed separately** - Must be deployed manually

### Initial Server Setup

When deploying to a new server, you must manually create the `.env` file:

```bash
# Copy your local .env to the server
scp -i ~/.ssh/devops-stage-6-key.pem .env ubuntu@<server-ip>:/tmp/app.env

# Move it to the application directory
ssh -i ~/.ssh/devops-stage-6-key.pem ubuntu@<server-ip>
sudo mv /tmp/app.env /opt/app/.env
sudo chown root:root /opt/app/.env
sudo chmod 644 /opt/app/.env
```

### Automated Deployments

The GitHub Actions workflow (`.github/workflows/application.yml`) automatically:
1. Backs up `.env` before pulling code
2. Pulls latest code from GitHub
3. Restores `.env` after pulling

This ensures the server's `.env` is never overwritten during deployments.

### Updating Environment Variables

To update `.env` on the server:

**Option 1: Manual Update (Recommended)**
```bash
# Edit directly on server
ssh -i ~/.ssh/devops-stage-6-key.pem ubuntu@<server-ip>
sudo nano /opt/app/.env
sudo docker-compose -f /opt/app/docker-compose.yml restart
```

**Option 2: Deploy from Local**
```bash
# Copy updated .env from local machine
scp -i ~/.ssh/devops-stage-6-key.pem .env ubuntu@<server-ip>:/tmp/new.env
ssh -i ~/.ssh/devops-stage-6-key.pem ubuntu@<server-ip>
sudo mv /tmp/new.env /opt/app/.env
sudo docker-compose -f /opt/app/docker-compose.yml restart
```

### Required Environment Variables

See `.env.sample` for the complete list. Key variables:

- `JWT_SECRET` - Must be identical across auth-api, todos-api, and users-api
- `PORT` - Frontend port
- `AUTH_API_PORT` - Auth service port
- `SERVER_PORT` - Users service port
- `REDIS_HOST` - Redis hostname for message queue
- Service addresses for inter-service communication

### Generating Secure Secrets

Generate a new JWT_SECRET:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Troubleshooting

**Problem**: Containers fail to start after deployment
- **Solution**: Check that `/opt/app/.env` exists and has correct values

**Problem**: JWT authentication fails
- **Solution**: Ensure all services have the same `JWT_SECRET`

**Problem**: Services can't communicate
- **Solution**: Verify service addresses match container names in docker-compose.yml

### Current Deployment

- **Server**: 44.247.35.162
- **Domain**: todoforge.mooo.com
- **Location**: /opt/app/
- **Status**: .env is properly configured with production secrets
