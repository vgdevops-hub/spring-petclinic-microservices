#!/bin/bash
# Jenkins controller bootstrap (cloud-init). Progress log: /var/log/jenkins-bootstrap.log
set -euxo pipefail
exec > >(tee -a /var/log/jenkins-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update
# Java first: Jenkins fails to start if Java is installed after it. JDK 21 builds the Java 17 target of this project.
apt-get install -y ca-certificates curl gnupg unzip git fontconfig openjdk-21-jdk docker.io docker-buildx

# ---- Jenkins LTS: official signed apt repository (2026 signing key) ----
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

# ---- Trivy: official signed apt repository ----
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y jenkins trivy

# ---- AWS CLI v2 ----
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# ---- kubectl (latest patch of the chosen minor), verified against its published checksum ----
KVER="$(curl -fsSL https://dl.k8s.io/release/stable-${kubectl_minor}.txt)"
curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
curl -fsSL -o /tmp/kubectl.sha256 "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl.sha256"
echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum --check
chmod 0755 /usr/local/bin/kubectl

# ---- Let Jenkins run Docker builds; give Trivy a persistent cache (used by the Jenkinsfile) ----
usermod -aG docker jenkins
install -d -o jenkins -g jenkins /var/lib/jenkins/.cache/trivy
systemctl enable docker
systemctl restart jenkins

# ---- Record what was installed ----
{
  java -version 2>&1 | head -1
  docker --version
  trivy --version | head -1
  aws --version
  kubectl version --client
  dpkg -s jenkins | grep '^Version'
} | tee /var/log/jenkins-bootstrap-versions.log
touch /var/lib/jenkins-bootstrap.done
