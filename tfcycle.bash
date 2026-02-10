#!/bin/bash

# Handy script companion for terraform
# Author: Antoine Drochon

set -e -o pipefail
# Extra debug if needed
# set -x

LOG_FILE=$(mktemp ${TMPDIR:-/tmp/}tfcycle.log.XXXXXX)
TF_VERSION=$(terraform -version -json | jq -r '.terraform_version')
TF_TFVARS="${2:-$TF_TFVARS}"
TF_DESTROY_TIMEOUT=${TF_DESTROY_TIMEOUT:-600}

# Check for required commands
for cmd in jq terraform; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed or not in PATH" >&2
        exit 2
    fi
done

echo -e "Current directory: \033[1;33m$(pwd)\033[0m"
if [ -n "$TF_TFVARS" ]; then
    echo -e "Using variable file: \033[1;33m$TF_TFVARS\033[0m"
fi

function tf_destroy() {
    echo -e "\033[1;31mDestroying Terraform-managed infrastructure...\033[0m"
    if [ -n "$TF_TFVARS" ]; then
        timeout $TF_DESTROY_TIMEOUT terraform destroy -var-file="$TF_TFVARS" -auto-approve | tee -a "$LOG_FILE"
    else
        timeout $TF_DESTROY_TIMEOUT terraform destroy -auto-approve | tee -a "$LOG_FILE"
    fi
}

function tf_apply() {
    echo -e "\033[1;32mBuilding Terraform-managed infrastructure...\033[0m"
    if [ -n "$TF_TFVARS" ]; then
        terraform apply -var-file="$TF_TFVARS" -auto-approve | tee -a "$LOG_FILE"
    else
        terraform apply -auto-approve | tee -a "$LOG_FILE"
    fi
}

function tf_output() {
    echo "Terraform outputs:"
    echo "------------------"
    terraform output -json | jq
    echo "------------------"
}

case "$1" in
  "a"|"apply")
    tf_apply
    tf_output
    ;;
  "da"|"destroy-apply")
    tf_destroy
    tf_apply
    tf_output
    ;;
  "o")
    tf_output
    ;;
  "d"|"destroy")
    tf_destroy
    ;;
  *)
    echo "Terraform Cycle 1.0 (Terraform version $TF_VERSION)"
    echo "Antoine Drochon <androcho@akamai.com>"
    echo ""
    echo "Usage: $0 {apply (a)|destroy-apply (da)|output (o)|destroy (d)}"
    exit 1
esac

echo "🏁 Operation completed at $(date) in $SECONDS seconds."
echo "Log file: $LOG_FILE"