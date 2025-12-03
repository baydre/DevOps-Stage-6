# Multi-stage build for Vue.js frontend
# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy only package.json (not package-lock.json)
COPY package.json ./

# Remove node-sass and add sass (Dart Sass) to package.json, then install all dependencies
RUN npm pkg delete devDependencies.node-sass && \
    npm pkg set devDependencies.sass="~1.32.0" && \
    npm pkg set devDependencies.sass-loader="^7.3.1" && \
    npm install --legacy-peer-deps

# Copy all source files
COPY . .

# Build the application
RUN npm run build

# Stage 2: Production stage
FROM nginx:stable-alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]