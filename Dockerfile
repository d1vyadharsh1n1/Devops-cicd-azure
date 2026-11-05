# Build once, ship the same artifact: the JAR is produced + tested by Maven in the pipeline
# (`mvn verify`) and copied in here. For local use run `mvn -B verify` first.
# Best practice: pin the base image by digest (eclipse-temurin:17-jre-alpine@sha256:...) in production.
FROM eclipse-temurin:25-jre-alpine

ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="webapp" \
      org.opencontainers.image.revision="${GIT_SHA}"

# Non-root user with a fixed numeric UID (required by the Kubernetes 'restricted' policy)
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app

WORKDIR /app
COPY --chown=10001:10001 target/app.jar app.jar

USER 10001:10001
EXPOSE 8080
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
