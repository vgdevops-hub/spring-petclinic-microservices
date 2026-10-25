# Copy to <service>/Dockerfile. Build context = the service directory (Jenkins runs: docker build ... <service>).
# The JAR is produced by "mvn clean package" in the pipeline, so the image contains only a JRE + the JAR.
FROM eclipse-temurin:21-jre-alpine

# Run as a non-root user (also enforce runAsNonRoot in the Kubernetes securityContext later)
RUN addgroup -S app && adduser -S app -G app

WORKDIR /app
COPY target/*.jar /app/app.jar
USER app

# Size the heap from the container memory limit instead of hard-coding -Xmx
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"

# Informational only; set to the service's real port (order=8070, product=8050, ...)
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
