#!/bin/bash

source logging.sh

div
log "Welcome to the MMC.AI Kubeflow installer!"
div

if [ -d ./kubeflow/ ]; then
  log "Found kubeflow repository, reinstalling from scratch..."
  rm -rf kubeflow
fi

log "Cloning Kubeflow..."
git clone https://github.com/kubeflow/manifests.git kubeflow --branch v1.8.1

cd kubeflow

div
## grep for fs.inotify.* variables in /etc/sysctl.conf
## append if not present; else print a warning and overwrite

## IIRC this is necessary because one of kubeflow's services
## opens file descriptors like crazy, and tends to run up
## against the system limit

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
log_good "Installing Kustomize..."
div

wget -O install_kustomize.sh "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
chmod +x install_kustomize.sh
./install_kustomize.sh

sudo chmod 755 kustomize

sudo cp kustomize /usr/local/bin

rm -rf kustomize
rm -rf install_kustomize.sh

div
log_good "Installing Kubeflow..."
div

while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 20; done

div
