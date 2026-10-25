#!/usr/bin/env bash
# Phase 0 read-only audit. Executes NONE of the repo's code (only grep/find/curl on Maven Central/trivy).
# Usage: bash scripts/phase0-audit.sh <app-repo-dir> <config-repo-dir>
# Output: <app-repo-dir>/docs/phase0-findings.txt
set -uo pipefail

APP="${1:-.}"
CFG="${2:-../spring-petclinic-microservices-config}"
OUT="$APP/docs/phase0-findings.txt"
mkdir -p "$APP/docs"

{
echo "== Date (UTC): $(date -u +%F)"
echo "== App commit:    $(git -C "$APP" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "== Config commit: $(git -C "$CFG" rev-parse HEAD 2>/dev/null || echo 'config repo not found')"

echo; echo "== Boot parent / Java / Spring Cloud (root pom)"
grep -m1 -A3 "<parent>" "$APP/pom.xml" | grep -E "artifactId|version"
grep -E "<java.version>|<spring-cloud.version>" "$APP/pom.xml"

echo; echo "== Latest Boot 4.0.x on Maven Central (last 3)"
curl -fsS https://repo.maven.apache.org/maven2/org/springframework/boot/spring-boot-starter-parent/maven-metadata.xml \
  | grep -oE "<version>4\.0\.[0-9]+</version>" | tail -3 || echo "lookup failed"

echo; echo "== Latest Spring Cloud 2025.1.x on Maven Central (last 3)"
curl -fsS https://repo.maven.apache.org/maven2/org/springframework/cloud/spring-cloud-dependencies/maven-metadata.xml \
  | grep -oE "<version>2025\.1\.[0-9]+</version>" | tail -3 || echo "lookup failed"

echo; echo "== Maven wrapper distribution URL (must be Apache / Maven Central)"
grep -i "distributionUrl" "$APP/.mvn/wrapper/maven-wrapper.properties" || echo "not found"

echo; echo "== Extra Maven <repository> entries (expect none)"
grep -rn "<repository>" --include=pom.xml "$APP" || echo "none"

echo; echo "== Maven plugins referenced (count)"
grep -rhoE "<artifactId>[a-zA-Z0-9.-]*plugin</artifactId>" --include=pom.xml "$APP" | sort | uniq -c

echo; echo "== Shell scripts present"
find "$APP" -name "*.sh" -not -path "*/.git/*"
echo "-- risky patterns in shell scripts (review each match by hand)"
grep -rnE "curl|wget|sudo|eval |base64|/dev/tcp|chmod \+s" --include=*.sh "$APP" || echo "no matches"

echo; echo "== Images referenced in docker-compose.yml"
grep -n "image:" "$APP/docker-compose.yml" || echo "none found"

echo; echo "== Test files per module"
for d in "$APP"/spring-petclinic-*/; do
  printf "%-45s %s\n" "$(basename "$d")" "$(find "$d" -path '*src/test*' -name '*.java' | wc -l)"
done

echo; echo "== Modules MISSING spring-boot-starter-actuator in their pom"
grep -L "spring-boot-starter-actuator" "$APP"/spring-petclinic-*/pom.xml || true

echo; echo "== Config Server: where does it read config from?"
grep -n -B1 -A4 "git:" "$APP/spring-petclinic-config-server/src/main/resources/application.yml" || echo "not found"

echo; echo "== Ports in config repo (VERIFY against pipeline generator)"
grep -nE "port:" "$CFG"/*.yml 2>/dev/null | head -40 || echo "config repo not found"

echo; echo "== Actuator exposure in config repo"
grep -n -A4 "management:" "$CFG"/*.yml 2>/dev/null | head -40 || echo "config repo not found"

echo; echo "== Existing CI workflows (to disable in the fork)"
ls "$APP/.github/workflows" 2>/dev/null || echo "none"

echo; echo "== Trivy (vuln, secret, misconfig; HIGH and CRITICAL)"
trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --format table "$APP" 2>&1 | tail -120
} | tee "$OUT"

echo
echo "Findings saved to $OUT - read it fully before running any build."
