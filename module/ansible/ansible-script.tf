locals {
  # Included so the userdata content changes (and, with
  # user_data_replace_on_change, the instance gets recreated) whenever the
  # scripts/playbook uploaded to S3 in main.tf change.
  ansible_scripts_hash = join(",", [
    filemd5("${path.module}/scripts/prod-bashscript.sh"),
    filemd5("${path.module}/scripts/stage-bashscript.sh"),
    filemd5("${path.module}/scripts/deployment.yml"),
  ])

  ansible_userdata = <<-EOF
#!/bin/bash
set -e

# ansible-scripts-hash: ${local.ansible_scripts_hash}

# -------------------------------
# 1. Update system & install dependencies
# -------------------------------

sudo dnf update -y
sudo dnf install -y wget unzip curl git jq


# -------------------------------
# 2. Install AWS CLI v2
# -------------------------------

cd /tmp

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o "awscliv2.zip"

unzip -q awscliv2.zip

sudo ./aws/install

sudo ln -svf /usr/local/bin/aws /usr/bin/aws

rm -rf /tmp/awscliv2.zip /tmp/aws


# -------------------------------
# 3. Install Ansible
# -------------------------------

sudo dnf install -y ansible-core

# deployment.yml (run from cron below) uses community.docker.docker_container/
# docker_login for an idempotent app deploy - install the collection here so
# it's available on every boot, not just when Jenkinsfile3 installs it ad hoc
# on its own separate /opt/docker/*.yml run.
sudo -u ec2-user ansible-galaxy collection install community.docker


# -------------------------------
# 4. Configure SSH for Ansible
# -------------------------------

sudo mkdir -p /etc/ansible

sudo tee /etc/ansible/id_rsa > /dev/null <<EOF2
${var.private_key}
EOF2

sudo chmod 400 /etc/ansible/id_rsa
sudo chown ec2-user:ec2-user /etc/ansible/id_rsa


# Configure SSH for ec2-user
sudo mkdir -p /home/ec2-user/.ssh

sudo tee /home/ec2-user/.ssh/config > /dev/null <<EOF2
Host *
  StrictHostKeyChecking no
EOF2

sudo chmod 600 /home/ec2-user/.ssh/config
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/config


# -------------------------------
# 5. Configure Ansible
# -------------------------------

sudo tee /etc/ansible/ansible.cfg > /dev/null <<EOF2
[defaults]
inventory = /etc/ansible/hosts
remote_user = ec2-user
private_key_file = /etc/ansible/id_rsa
host_key_checking = False
EOF2

sudo chmod 644 /etc/ansible/ansible.cfg


# -------------------------------
# 6. Pull Ansible scripts from S3
# -------------------------------

sudo mkdir -p /home/ec2-user/ansible

sudo aws s3 cp \
  s3://${var.bucket_name}/ansible-script/prod-bashscript.sh \
  /home/ec2-user/ansible/prod-bashscript.sh

sudo aws s3 cp \
  s3://${var.bucket_name}/ansible-script/stage-bashscript.sh \
  /home/ec2-user/ansible/stage-bashscript.sh

sudo aws s3 cp \
  s3://${var.bucket_name}/ansible-script/deployment.yml \
  /home/ec2-user/ansible/deployment.yml


# Set permissions
sudo chmod 755 /home/ec2-user/ansible/*.sh
sudo chown -R ec2-user:ec2-user /home/ec2-user/ansible


# -------------------------------
# 7. Create Ansible variable file
# -------------------------------

sudo tee /home/ec2-user/ansible/ansible_vars_file.yml > /dev/null <<EOF2
NEXUS_IP: "${var.nexus_ip}:8085"
NEW_RELIC_LICENSE_KEY: "${var.nr_license_key}"
NEW_RELIC_APP_NAME: pet-adoption
EOF2

sudo chown ec2-user:ec2-user \
  /home/ec2-user/ansible/ansible_vars_file.yml

# 600, not 644: this file now carries the New Relic ingest license key.
sudo chmod 600 \
  /home/ec2-user/ansible/ansible_vars_file.yml


# -------------------------------
# 8. Configure cron jobs for scripts
# -------------------------------

sudo crontab -u ec2-user -l > /tmp/mycron 2>/dev/null || true

echo "* * * * * /bin/bash /home/ec2-user/ansible/prod-bashscript.sh" >> /tmp/mycron
echo "* * * * * /bin/bash /home/ec2-user/ansible/stage-bashscript.sh" >> /tmp/mycron

sudo crontab -u ec2-user /tmp/mycron

rm -f /tmp/mycron


# -------------------------------
# 9. Install New Relic
# -------------------------------

curl -Ls \
  https://download.newrelic.com/install/newrelic-cli/scripts/install.sh \
  | bash


# -------------------------------
# 10. Install New Relic Infrastructure Agent
# -------------------------------

sudo NEW_RELIC_API_KEY="${var.nr_key}" \
NEW_RELIC_ACCOUNT_ID="${var.nr_acc_id}" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y


# -------------------------------
# 11. Enable and start New Relic
# -------------------------------

sudo systemctl enable newrelic-infra
sudo systemctl restart newrelic-infra


# -------------------------------
# 12. Set hostname
# -------------------------------

sudo hostnamectl set-hostname ansible-server


# -------------------------------
# Setup complete
# -------------------------------

echo "Ansible server setup completed successfully."

EOF
}