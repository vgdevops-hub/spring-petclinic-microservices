FROM eclipse-temurin:17-jre AS builder
WORKDIR application
ARG ARTIFACT_NAME
COPY ${ARTIFACT_NAME}.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM eclipse-temurin:17-jre
WORKDIR application
ARG EXPOSED_PORT
EXPOSE ${EXPOSED_PORT}
ENV SPRING_PROFILES_ACTIVE=docker
# CHANGED: size the heap from the container memory limit
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"

# CHANGED: numeric non-root user (K8s runAsNonRoot needs a numeric UID)
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home app

COPY --from=builder --chown=app:app application/dependencies/ ./
# fix for https://stackoverflow.com/questions/51115856/docker-failed-to-export-image-failed-to-create-image-failed-to-get-layer
# (only last copy caused issue)
# this seems to be triggered by using btrfs:
# https://github.com/moby/moby/issues/36573
RUN true
COPY --from=builder --chown=app:app application/spring-boot-loader/ ./
RUN true
COPY --from=builder --chown=app:app application/snapshot-dependencies/ ./
RUN true
COPY --from=builder --chown=app:app application/application/ ./

USER 10001:10001

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
