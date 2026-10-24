#!/bin/bash
set -e
set -x

# ==============================
# Variables
# ==============================

AWSCLI_PATH="/usr/local/bin/aws"

ANSIBLE_DIR="/home/ec2-user/ansible"

INVENTORY_FILE="$ANSIBLE_DIR/stage_hosts"

IPS_FILE="$ANSIBLE_DIR/stage.lists"

DEPLOYMENT_FILE="$ANSIBLE_DIR/deployment.yml"

ASG_NAME="stage-asg"

WAIT_TIME=20


# ==============================
# Ensure Ansible directory exists
# ==============================

mkdir -p "$ANSIBLE_DIR"


# ==============================
# Find running staging instances
# ==============================

find_ips() {

    echo "Finding staging EC2 instances..."

    "$AWSCLI_PATH" ec2 describe-instances \
        --filters \
        "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
        "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].PrivateIpAddress' \
        --output text | tr '\t' '\n' | sed '/^$/d' > "$IPS_FILE"

    echo "Staging IP addresses:"
    cat "$IPS_FILE"
}


# ==============================
# Update Ansible inventory
# ==============================

update_inventory() {

    echo "Updating staging inventory..."

    echo "[webservers]" > "$INVENTORY_FILE"

    for instance in $(cat "$IPS_FILE"); do

        ssh-keyscan -H "$instance" \
            >> /home/ec2-user/.ssh/known_hosts 2>/dev/null

        echo "$instance ansible_user=ubuntu" \
            >> "$INVENTORY_FILE"

    done

    echo "Staging inventory updated successfully."

    cat "$INVENTORY_FILE"
}


# ==============================
# Wait for instances to be ready
# ==============================

wait_for_instances() {

    echo "Waiting $WAIT_TIME seconds..."

    sleep "$WAIT_TIME"
}


# ==============================
# Test Ansible connection
# ==============================

test_connection() {

    echo "Testing connection to staging servers..."

    ansible all \
        -i "$INVENTORY_FILE" \
        -m ping
}


# ==============================
# Run Ansible deployment
# ==============================

run_deployment() {

    echo "Starting staging deployment..."

    ansible-playbook \
        -i "$INVENTORY_FILE" \
        "$DEPLOYMENT_FILE"

    echo "Staging deployment completed successfully."
}


# ==============================
# Main
# ==============================

main() {

    echo "======================================"
    echo "Starting Staging Auto-Discovery"
    echo "======================================"

    find_ips

    update_inventory

    wait_for_instances

    test_connection

    run_deployment

    echo "======================================"
    echo "Staging deployment completed"
    echo "======================================"
}

main