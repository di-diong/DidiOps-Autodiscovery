#!/bin/bash
set -eux -o pipefail
export DEBIAN_FRONTEND=noninteractive

DB_PASSWORD="${db_password}"
# NOTE: verify this is a real SonarQube distribution version. A wrong value makes
# the download below 404 and the bootstrap aborts before SonarQube is installed.
SONAR_VERSION="26.8.0.126808"

apt-get update -y
apt-get install -y wget unzip openssl openjdk-21-jdk postgresql

# ---------------------------------------------------------------------------
# PostgreSQL - wait until the cluster actually accepts connections before use
# ---------------------------------------------------------------------------
systemctl enable --now postgresql
for i in $(seq 1 30); do
  if sudo -u postgres pg_isready -q; then break; fi
  sleep 2
done

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='sonar'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='sonarqube'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -d sonarqube -c "GRANT ALL ON SCHEMA public TO sonar;"

# ---------------------------------------------------------------------------
# Kernel settings SonarQube's embedded Elasticsearch requires
# ---------------------------------------------------------------------------
cat > /etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl --system || true

# ---------------------------------------------------------------------------
# Install SonarQube
# ---------------------------------------------------------------------------
useradd -r -M -d /opt/sonarqube -s /bin/bash sonarqube || true
cd /opt
wget -q "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip" -O sonarqube.zip
unzip -q sonarqube.zip
rm -f sonarqube.zip
mv "sonarqube-$SONAR_VERSION" sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube

cat >> /opt/sonarqube/conf/sonar.properties <<EOF
sonar.jdbc.username=sonar
sonar.jdbc.password=$DB_PASSWORD
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

cat > /etc/systemd/system/sonarqube.service <<'EOF'
[Unit]
Description=SonarQube
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sonarqube

# Install the New Relic infrastructure agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
NEW_RELIC_API_KEY="${nr_key}" \
  NEW_RELIC_ACCOUNT_ID="${nr_acc_id}" \
  NEW_RELIC_REGION="EU" \
  /usr/local/bin/newrelic install -y || true

# The ALB terminates TLS with the ACM cert and forwards straight to 9000/HTTP,
# so no local reverse proxy is needed.

# Give the first ALB health checks something to hit
for i in $(seq 1 60); do
  if curl -sf -o /dev/null http://localhost:9000/api/system/status; then
    echo "sonarqube web is up after $i attempts"
    break
  fi
  sleep 15
done