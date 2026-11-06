#!/usr/bin/env bash
# Generates jenkins/<service>/Jenkinsfile (one pipeline per service) from jenkins/Jenkinsfile.template.
# Run from anywhere:  bash scripts/gen-jenkinsfiles.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# service:port
# Ports verified in Phase 0 against the config repo and the config-server pom (8888).
# genai-service is intentionally left out: it needs an OpenAI/Azure API key. Add it later with a managed secret.
SERVICES=(
  "config-server:8888"
  "discovery-server:8761"
  "api-gateway:8080"
  "customers-service:8081"
  "visits-service:8082"
  "vets-service:8083"
  "admin-server:9090"
)

for entry in "${SERVICES[@]}"; do
  svc="${entry%%:*}"
  port="${entry##*:}"
  [ -d "spring-petclinic-${svc}" ] || { echo "ERROR: module spring-petclinic-${svc} not found" >&2; exit 1; }
  mkdir -p "jenkins/${svc}"
  sed -e "s/__SERVICE__/${svc}/g" -e "s/__PORT__/${port}/g" \
      jenkins/Jenkinsfile.template > "jenkins/${svc}/Jenkinsfile"
  echo "generated jenkins/${svc}/Jenkinsfile (port ${port})"
done
