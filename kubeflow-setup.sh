#!/bin/bash

source logging.sh

div
log "Welcome to the MMC.AI Kubeflow installer!"
div

# Variables to be added/updated
declare -A sysctl_vars
sysctl_vars=(
  ["fs.inotify.max_queued_events"]="16384"
  ["fs.inotify.max_user_instances"]="1024"
  ["fs.inotify.max_user_watches"]="1004050"
)

SYSCTL="/etc/sysctl.conf"

# Function to update or append a sysctl variable
update_sysctl_conf() {
  local key="$1"
  local value="$2"
  local config="$3"

  if sudo grep -q "^${key}=" "$config"; then
    log "Warning: ${key} already exists. Updating value to ${value}."
    sudo sed -i "s|^${key}=.*|${key}=${value}|" "$config"
  else
    echo "${key}=${value}" | sudo tee -a "$config"
    log "Appended ${key}=${value} to ${config}."
  fi
}

# Iterate over the sysctl variables and update or append them
for key in "${!sysctl_vars[@]}"; {
  update_sysctl_conf "$key" "${sysctl_vars[$key]}" "$SYSCTL"
}

# Apply the new settings
sudo sysctl --system

# Verify the new settings
log "Verifying sysctl settings:"
for key in "${!sysctl_vars[@]}"; do
  current_value=$(sysctl -n "$key")
  expected_value="${sysctl_vars[$key]}"

  if [ "$current_value" == "$expected_value" ]; then
    log "Success: ${key} is set to ${expected_value}."
  else
    log "Error: ${key} is set to ${current_value} but expected ${expected_value}."
  fi
done

div
log "Installing kubeflow..."
div

## Use newer kubeflow
sed -i 's/v1.7.0/v1.8.0/g' ./scripts/k8s/deploy_kubeflow.sh

## Set istio gateway to newer version
sed -i 's:istio-1-16:istio-1-17:g' ./scripts/k8s/deploy_kubeflow.sh


./scripts/k8s/deploy_kubeflow.sh