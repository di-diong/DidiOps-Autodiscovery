#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive

NEXUS_REGISTRY="${nexus_ip}:8085"
DOCKER_IMAGE="$${NEXUS_REGISTRY}/petclinicapps:latest"

# update system packages
apt-get update -y

# install docker
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$${VERSION_CODENAME}") stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# allow the insecure (plain HTTP) Nexus registry
cat > /etc/docker/daemon.json <<EOF
{ "insecure-registries": ["$${NEXUS_REGISTRY}"] }
EOF
systemctl restart docker

# log in to Nexus (anonymous pull is not enabled) and pull/run the app
echo "admin123" | docker login --username admin --password-stdin "$${NEXUS_REGISTRY}"
docker pull "$${DOCKER_IMAGE}"
docker rm -f pet-adoption || true
set +x
docker run -d --restart always --name pet-adoption -p 8080:8080 \
  -e NEW_RELIC_LICENSE_KEY="${nr_license_key}" \
  -e NEW_RELIC_APP_NAME="pet-adoption-prod" \
  "$${DOCKER_IMAGE}"
set -x

# install the New Relic infrastructure agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
NEW_RELIC_API_KEY="${nr_key}" \
  NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
  NEW_RELIC_REGION="EU" \
  /usr/local/bin/newrelic install -y || true

hostnamectl set-hostname prod-docker-host