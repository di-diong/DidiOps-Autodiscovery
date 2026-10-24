#!/bin/bash
set -e
set -x

# ==============================
# Variables
# ==============================

AWSCLI_PATH="/usr/local/bin/aws"

ANSIBLE_DIR="/home/ec2-user/ansible"

INVENTORY_FILE="$ANSIBLE_DIR/prod_hosts"

IPS_FILE="$ANSIBLE_DIR/prod.lists"

DEPLOYMENT_FILE="$ANSIBLE_DIR/deployment.yml"

ASG_NAME="prod-asg"

WAIT_TIME=20


# ==============================
# Ensure Ansible directory exists
# ==============================

mkdir -p "$ANSIBLE_DIR"


# ==============================
# Find running production instances
# ==============================

find_ips() {

    echo "Finding production EC2 instances..."

    "$AWSCLI_PATH" ec2 describe-instances \
        --filters \
        "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" \
        "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].PrivateIpAddress' \
        --output text | tr '\t' '\n' | sed '/^$/d' > "$IPS_FILE"

    echo "Production IP addresses:"
    cat "$IPS_FILE"
}


# ==============================
# Update Ansible inventory
# ==============================

update_inventory() {

    echo "Updating production inventory..."

    echo "[webservers]" > "$INVENTORY_FILE"

    for instance in $(cat "$IPS_FILE"); do

        ssh-keyscan -H "$instance" \
            >> /home/ec2-user/.ssh/known_hosts 2>/dev/null

        echo "$instance ansible_user=ubuntu" \
            >> "$INVENTORY_FILE"

    done

    echo "Production inventory updated successfully."

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

    echo "Testing connection to production servers..."

    ansible all \
        -i "$INVENTORY_FILE" \
        -m ping
}


# ==============================
# Run Ansible deployment
# ==============================

run_deployment() {

    echo "Starting production deployment..."

    ansible-playbook \
        -i "$INVENTORY_FILE" \
        "$DEPLOYMENT_FILE"

    echo "Production deployment completed successfully."
}


# ==============================
# Main
# ==============================

main() {

    echo "======================================"
    echo "Starting Production Auto-Discovery"
    echo "======================================"

    find_ips

    update_inventory

    wait_for_instances

    test_connection

    run_deployment

    echo "======================================"
    echo "Production deployment completed"
    echo "======================================"
}

main