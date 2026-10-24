#!/bin/bash
set -eux -o pipefail

# 1. Install AWS SSM Agent (Red Hat)
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable --now amazon-ssm-agent

# 2. Java. The Nexus tar.gz bundles its own JVM since 3.78, so this is only a
#    fallback; Nexus 3.96 requires Java 21 if it uses a system JVM.
sudo dnf install -y java-21-openjdk tar || true

# 3. Add swap as a safety net against JVM memory spikes
if [ ! -f /swapfile ]; then
  sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 4. Download and unpack Nexus.
#    Sonatype retired "latest-unix.tar.gz" and now ships version-pinned,
#    arch-named archives. Bump NEXUS_VERSION when a newer release is out
#    (https://help.sonatype.com/en/download.html).
NEXUS_VERSION="3.96.0-09"
cd /opt
downloaded=0
for url in \
  "https://download.sonatype.com/nexus/3/nexus-$${NEXUS_VERSION}-linux-x86_64.tar.gz" \
  "https://download.sonatype.com/nexus/3/nexus-$${NEXUS_VERSION}-unix.tar.gz" \
  "https://download.sonatype.com/nexus/3/latest-unix.tar.gz" ; do
  if sudo curl -fSL --retry 3 --retry-delay 5 -o nexus.tar.gz "$url"; then
    echo "downloaded nexus from $url"
    downloaded=1
    break
  fi
done
if [ "$downloaded" -ne 1 ]; then
  echo "ERROR: could not download Nexus from any known URL" >&2
  exit 1
fi
sudo tar -xf nexus.tar.gz
sudo rm -f nexus.tar.gz
# tar creates /opt/nexus-<version>/ and /opt/sonatype-work/
nexus_dir="$(find /opt -maxdepth 1 -type d -name 'nexus-3*' | head -1)"
sudo rm -rf /opt/nexus
sudo mv "$nexus_dir" /opt/nexus

# 5. Create a dedicated nexus user and hand it the install + data dirs
sudo useradd -r -M -d /opt/nexus -s /bin/false nexus || true
sudo mkdir -p /opt/sonatype-work
sudo chown -R nexus:nexus /opt/nexus /opt/sonatype-work

# 6. Run Nexus as the 'nexus' user (JVM left at the bundle default; t3.large / 8 GiB)
echo 'run_as_user="nexus"' | sudo tee /opt/nexus/bin/nexus.rc

# 7. Create the Nexus systemd service
sudo tee /etc/systemd/system/nexus.service > /dev/null <<'SERVICE'
[Unit]
Description=Sonatype Nexus Repository Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=nexus
Group=nexus
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
Restart=on-failure
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SERVICE

# 8. Enable and start Nexus
sudo systemctl daemon-reload
sudo systemctl enable --now nexus

sudo hostnamectl set-hostname nexus-server

# 9. Install the New Relic infrastructure agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | sudo bash
sudo NEW_RELIC_API_KEY="${nr_key}" \
  NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
  NEW_RELIC_REGION="EU" \
  /usr/local/bin/newrelic install -y || true

# 10. Wait for the web endpoint so the first ALB health checks have something to hit
for i in $(seq 1 60); do
  if curl -sf -o /dev/null http://localhost:8081/; then
    echo "nexus is up after $i attempts"
    break
  fi
  sleep 15
done