## Build stage
FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /workspace

# Leverage Docker layer caching by copying wrappers + pom first
COPY pom.xml ./
COPY .mvn .mvn
COPY mvnw ./
RUN chmod +x mvnw

# Build the application
COPY src src
RUN ./mvnw -B -DskipTests package

## Runtime stage
FROM eclipse-temurin:21-jre

WORKDIR /app

# Spring Boot default port
EXPOSE 8080

# Copy the built jar (adjust if you change artifact/version)
COPY --from=build /workspace/target/SmartHire_Backend-0.0.1-SNAPSHOT.jar /app/app.jar

ENV JAVA_OPTS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
