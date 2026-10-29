# Phase 0 notes: local validation and version audit

Completed: 25 October 2026

## Baseline
- App repo baseline commit: `<fill: git rev-parse baseline>`
- Config repo baseline commit: `<fill: git rev-parse HEAD in the config repo>`
- Spring Boot: 4.0.1 upgraded to 4.0.9. Spring Cloud: 2025.1.0 upgraded to `<fill: version you set>`. Java 17.

## Services and ports
| Module | Port | Tests (files) |
|---|---|---|
| config-server | 8888 | 1 |
| discovery-server | 8761 | 1 |
| api-gateway | 8080 | 6 |
| customers-service | 8081 | 1 |
| visits-service | 8082 | 1 |
| vets-service | 8083 | 1 |
| genai-service | 8084 | 0 (not deployed, needs an OpenAI key) |
| admin-server | 9090 | 0 |

## Changes made
- Root `pom.xml`: Spring Boot parent and Spring Cloud version bump (the project's own `<version>` left at 4.0.1).
- `spring-petclinic-config-server/pom.xml`: added `spring-boot-starter-actuator` (needed for `/actuator/health` probes and the pipeline smoke test).
- `docker/Dockerfile`: JRE-only runtime, numeric non-root user (UID 10001), heap sized from the container limit.
- `scripts/phase0-audit.sh`: read-only audit script.

## Results
- Trivy before the bump (root POM): 432 findings (89 CRITICAL, 343 HIGH), no secrets.
- Trivy after the bump: no fixable CRITICAL findings. All 8 modules pass the CRITICAL gate (`--ignore-unfixed --exit-code 1`).
- Local stack (Docker Compose) verified: Eureka lists the services, the gateway serves the app, containers run as UID 10001.

## Idle memory (docker stats, compose limit 512 MiB)
customers 359, visits 350, api-gateway 329, vets 316, discovery 266, admin 241, config-server 222 MiB. Seven Spring services total about 2.0 GiB.
Starting Kubernetes values: request 384 Mi; limit 768 Mi (gateway, customers, visits, vets) or 512 Mi (config, discovery, admin); small CPU request, no hard CPU limit.
Node plan: 2 x t3.large Spot.

## Issues hit and fixes
- Trivy 429 from Maven Central: wait 30 minutes, run the Maven build to populate `~/.m2`, rescan.
- Image build exit code 125: `docker-buildx` was not installed (upstream passes `--load`).
- `lstat /target: no such file`: wrong generic Dockerfile. This repo builds with the module's `target/` as context and uses the `ARTIFACT_NAME` build arg.
- `WorkdirRelativePath` warnings: harmless.
- Windows SSH config errors: fixed the config lines, or used temporary security-group rules (removed afterwards).

## Decisions
- Base project: official `spring-petclinic` microservices (Java, Maven, JUnit). Conversion to e-commerce services is an optional last phase.
- Keep Boot 4.0.x for now. Free support for 4.0 ends 31 Dec 2026, so evaluate 4.1 later as a separate change.
- Config Server still reads the upstream config repo. In Phase 5, point it at our fork and pin a commit or tag.
