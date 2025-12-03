# Multi-stage build for Go Auth API
# Stage 1: Build stage
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Install CA certificates so we can copy them into the final image
RUN apk add --no-cache ca-certificates && update-ca-certificates

# Copy source code
COPY *.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o auth-api .

# Stage 2: Production stage
# Use a minimal image. Copy the compiled static binary and CA certs from builder.
FROM scratch

# Copy CA certificates from the builder (so HTTPS / TLS works)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Set working directory
WORKDIR /

# Copy the binary from builder stage
COPY --from=builder /app/auth-api /auth-api

# Expose port 8080 (default port for Echo)
EXPOSE 8080

# Run the application
CMD ["./auth-api"]