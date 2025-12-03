# Multi-stage build for Java Spring Boot Users API

# Build stage: use Maven with JDK 11
FROM maven:3.8-openjdk-11 AS builder

WORKDIR /app

# Copy pom first to leverage dependency caching
COPY pom.xml ./

# Download dependencies offline (speeds repeated builds)
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src ./src
RUN mvn package -DskipTests -B

# Runtime stage: use Eclipse Temurin (recommended OpenJDK distribution)
FROM eclipse-temurin:11-jre

WORKDIR /app

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy the packaged JAR from the builder
COPY --from=builder /app/target/*.jar app.jar

# Ensure non-root ownership
RUN chown appuser:appuser app.jar

# Switch to non-root user
USER appuser

# Use the same port as configured in docker-compose for users-api
EXPOSE 8083

# JVM options
ENV JAVA_OPTS="-Xmx512m -Xms256m"

ENTRYPOINT ["java", "-jar", "app.jar"]