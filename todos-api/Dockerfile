FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install dependencies first (leverage layer caching)
COPY package*.json ./

# Use npm ci for deterministic installs when package-lock.json is present
RUN npm ci --only=production && npm cache clean --force

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy application source and set ownership to the non-root user
COPY --chown=appuser:appgroup . .

# Ensure node_modules are owned by the app user (if present)
RUN chown -R appuser:appgroup /usr/src/app/node_modules || true

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Start the application
CMD ["node", "server.js"]