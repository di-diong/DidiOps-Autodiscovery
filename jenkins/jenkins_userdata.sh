#!/bin/bash
# Log everything this script does to a file we can inspect after boot:
#   sudo cat /var/log/jenkins-userdata.log
# (also mirrored to the console log visible via `aws ec2 get-console-output`).
exec > >(tee /var/log/jenkins-userdata.log | logger -t jenkins-userdata -s 2>/dev/console) 2>&1
set -x

# RHEL major version (10 on the current AMI). Used to pin third-party repo URLs
# that otherwise expand $releasever to "10.2" and 404.
. /etc/os-release
RHEL_MAJOR="$${VERSION_ID%%.*}"

sudo yum update -y

# install dependencies - git, python3-pip, unzip
# NOTE: RHEL 10 has no "pip" or "maven" packages. pip ships as python3-pip;
# Maven is installed from the Apache tarball below.

sudo yum install -y git unzip tar gzip python3-pip

sudo alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 || sudo ln -svf /usr/bin/pip3 /usr/bin/pip

# Maven (binary distribution -> /opt/maven, on PATH for all users)
MAVEN_VERSION=3.9.9
curl -fsSL "https://archive.apache.org/dist/maven/maven-3/$${MAVEN_VERSION}/binaries/apache-maven-$${MAVEN_VERSION}-bin.tar.gz" \
  | sudo tar -xz -C /opt
sudo ln -svfn "/opt/apache-maven-$${MAVEN_VERSION}" /opt/maven
echo 'export PATH=/opt/maven/bin:$PATH' | sudo tee /etc/profile.d/maven.sh
sudo ln -svf /opt/maven/bin/mvn /usr/bin/mvn

# Install SSM Agent (FIXED - removed region issue)
sudo yum install -y https://s3.eu-west-3.amazonaws.com/amazon-ssm-eu-west-3/latest/linux_amd64/amazon-ssm-agent.rpm
# Install Session Manager Plugin (FIXED)
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
 

# get jenkins repo

sudo curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo

#import jenkins key

sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

sudo yum upgrade -y

# install  java first and then jenkins

sudo yum install java-21-openjdk -y

sudo yum install jenkins -y

#enable systemd integration on jenkins

sudo sed -i 's/^User=jenkins/User=root/' /usr/lib/systemd/system/jenkins.service

sudo systemctl daemon-reload

sudo systemctl start jenkins

sudo systemctl enable jenkins

sudo systemctl start jenkins

sudo usermod -aG jenkins ec2-user

# Install trivy for container scanning.
# The old yum repo path (releases/$releasever) 404s on RHEL 10, so use the
# vendor install script, which resolves the right release asset directly.

curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sudo sh -s -- -b /usr/local/bin

sudo ln -svf /usr/local/bin/trivy /usr/bin/trivy

# install docker
# This box is RHEL, so use Docker's RHEL repo (the CentOS repo's $releasever
# path 404s on RHEL) and pass --allowerasing: the RHEL AMI ships runc/podman/
# buildah, which conflict with containerd.io and make a plain install exit
# non-zero (which is why docker never landed here before).

# Drop the repo file in directly. RHEL 10 ships dnf5, whose `config-manager`
# syntax differs from dnf4, so avoid it entirely.
sudo curl -fsSL https://download.docker.com/linux/rhel/docker-ce.repo \
  -o /etc/yum.repos.d/docker-ce.repo
# download.docker.com only publishes for major versions (7/8/9/10); pin the repo
# so $releasever isn't expanded to "10.2".
sudo sed -i "s/\$releasever/$${RHEL_MAJOR}/g" /etc/yum.repos.d/docker-ce.repo

sudo yum install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# RHEL 10 is nftables-native: the iptables-nft compat shim can't load xt_addrtype,
# so Docker's default iptables path for the bridge NAT rules fails and dockerd
# aborts with "Error initializing network controller ... RULE_APPEND failed".
# Docker >= 28 ships a native nftables firewall backend; select it explicitly.
sudo mkdir -p /etc/docker
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "firewall-backend": "nftables"
}
EOF

# The nftables backend does not enable IPv4 forwarding itself (the legacy
# iptables path used to), so dockerd bails with "IPv4 forwarding is disabled".
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-docker-forward.conf
sudo sysctl -w net.ipv4.ip_forward=1

sudo systemctl enable --now docker

# add jenkins and ec2-user to docker group

sudo usermod -aG docker ec2-user

sudo usermod -aG docker jenkins

sudo chmod 666 /var/run/docker.sock

# jenkins was started earlier in this script, before the docker group existed,
# so restart it to pick up group membership / socket access.

sudo systemctl restart jenkins

# Installing awscli

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

sudo ./aws/install

sudo ln -svf /usr/local/bin/aws /usr/bin/aws

#  install newrelic agent

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash || true
sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y

sudo hostnamectl set-hostname jenkins
 