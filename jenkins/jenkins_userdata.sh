#!/bin/bash

sudo yum update -y

# install dependencies-wget,pip,git,maven

sudo yum install wget git pip maven -y

# Install SSM Agent (FIXED - removed region issue)
sudo yum install -y https://s3.eu-west-3.amazonaws.com/amazon-ssm-eu-west-3/latest/linux_amd64/amazon-ssm-agent.rpm
# Install Session Manager Plugin (FIXED)
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
 

# get jenkins repo

sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

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

# Install trivy for container scanning

RELEASE_VERSION=$(grep -Po '(?<=VERSION_ID=")[0-9]' /etc/os-release)

cat << EOT | sudo tee -a /etc/yum.repos.d/trivy.repo

[trivy]

name=Trivy repository

baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$RELEASE_VERSION/\$basearch/

gpgcheck=0

enabled=1

EOT

sudo yum -y update

sudo yum -y install trivy

# install docker

sudo yum install -y yum-utils

sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install docker-ce -y

sudo service docker start

sudo systemctl start docker

sudo systemctl enable docker

# add jenkins and ec2-user to docker group

sudo usermod -aG docker ec2-user

sudo usermod -aG docker jenkins

sudo chmod 777 /var/run/docker.sock

# Installing awscli

sudo yum install unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

sudo ./aws/install

sudo ln -svf /usr/local/bin/aws /usr/bin/aws

#  install newrelic agent

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY= NEW_RELIC_ACCOUNT_ID= NEW_RELIC_REGION=EU /usr/local/bin/newrelic install

sudo hostnamectl set-hostname jenkins
 