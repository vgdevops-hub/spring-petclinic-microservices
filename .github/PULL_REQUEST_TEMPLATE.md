## What and why
<!-- One or two sentences: what changed and the reason -->

## Area touched
- [ ] Application service(s): customers / vets / visits / api-gateway / config / discovery / admin
- [ ] Docker or Jenkins pipeline
- [ ] Terraform (infra/)
- [ ] Kubernetes manifests (k8s/)
- [ ] Docs only

## Checklist
- [ ] Builds and tests pass locally (`./mvnw -B -ntp clean package`)
- [ ] No secrets, keys, tokens, .pem or .tfvars files in the diff
- [ ] Trivy CRITICAL gate still passes (or a dated .trivyignore entry explains why)
- [ ] Docs updated if behaviour changed
- [ ] Rollback is possible (no destructive change without a plan)

