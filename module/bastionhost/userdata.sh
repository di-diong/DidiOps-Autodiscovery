#!/bin/bash
set -ex

# Update system packages
sudo apt-get update -y

# SSM Agent ships with Ubuntu AMIs via snap; make sure it is enabled and running
sudo snap install amazon-ssm-agent --classic || true
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service || true

# Install the AWS CLI v2
sudo apt-get install -y unzip curl
cd /tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf /tmp/awscliv2.zip /tmp/aws

# Default region for the AWS CLI on the bastion
sudo tee /etc/profile.d/aws-region.sh > /dev/null <<EOF2
export AWS_DEFAULT_REGION=${region}
EOF2

# Create the private key file used to jump to private instances
sudo mkdir -p /home/ubuntu/.ssh
sudo tee /home/ubuntu/.ssh/private_key.pem > /dev/null <<EOF2
${private_key}
EOF2
sudo chmod 400 /home/ubuntu/.ssh/private_key.pem
sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/private_key.pem

# Install the New Relic infrastructure agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | sudo bash
sudo NEW_RELIC_API_KEY="${nr_key}" \
  NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
  NEW_RELIC_REGION="EU" \
  /usr/local/bin/newrelic install -y || true

sudo hostnamectl set-hostname bastion-host