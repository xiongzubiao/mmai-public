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
git clone git@github.com:kubeflow/manifests.git kubeflow --branch v1.8.1

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

  if grep -q "^${key}=" "$config"; then
    log "Warning: ${key} already exists. Updating value to ${value}."
    sed -i "s|^${key}=.*|${key}=${value}|" "$config"
  else
    log "${key}=${value}" >> "$config"
    log "Appended ${key}=${value} to ${config}."
  fi
}

# Iterate over the sysctl variables and update or append them
for key in "${!sysctl_vars[@]}"; {
  update_sysctl_conf "$key" "${sysctl_vars[$key]}" "$SYSCTL"
}

# Apply the new settings
sysctl --system

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
log_good "Installing Kubeflow..."
div

while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 20; done

div

# div
# log_good "Installing cert-manager..."
# div

# kustomize build common/cert-manager/cert-manager/base | kubectl apply -f -
# kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
# kustomize build common/cert-manager/kubeflow-issuer/base | kubectl apply -f -

# div
# log_good "Installing Istio..."
# div

# kustomize build common/istio-1-17/istio-crds/base | kubectl apply -f -
# kustomize build common/istio-1-17/istio-namespace/base | kubectl apply -f -
# kustomize build common/istio-1-17/istio-install/base | kubectl apply -f -

# div
# log_good "Installing AuthService..."
# div

# kustomize build common/oidc-client/oidc-authservice/base | kubectl apply -f -

# div
# log_good "Installing Dex..."
# div

# kustomize build common/dex/overlays/istio | kubectl apply -f -

# div
# log_good "Installing Knative..."
# div

# kustomize build common/knative/knative-serving/overlays/gateways | kubectl apply -f -
# kustomize build common/knative/knative-eventing/base | kubectl apply -f -
# kustomize build common/istio-1-17/cluster-local-gateway/base | kubectl apply -f -

# div
# log_good "Installing Kubeflow Namespace..."
# div

# kustomize build common/kubeflow-namespace/base | kubectl apply -f -

# div
# log_good "Installing Kubeflow Roles..."
# div

# kustomize build common/kubeflow-roles/base | kubectl apply -f -

# div
# log_good "Installing Kubeflow Istio Resources..."
# div

# kustomize build common/istio-1-17/kubeflow-istio-resources/base | kubectl apply -f -

# div
# log_good "Installing Kubeflow Pipelines..."
# div

# kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -

# div
# log_good "Installing Kserve..."
# div

# kustomize build contrib/kserve/kserve | kubectl apply -f -
# kustomize build contrib/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -

# div
# log_good "Installing Katib..."
# div

# kustomize build apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -

# div
# log_good "Installing Central Dashboard..."
# div

# kustomize build apps/centraldashboard/upstream/overlays/kserve | kubectl apply -f -

# div
# log_good "Installing Admission Webhook..."
# div

# kustomize build apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -

# div
# log_good "Installing Notebooks..."
# div

# kustomize build apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
# kustomize build apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -

# div
# log_good "Installing PVC Viewer Controller..."
# div

# kustomize build apps/pvcviewer-controller/upstream/default | kubectl apply -f -

# div
# log_good "Installing Profiles + KFAM..."
# div

# kustomize build apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -

# div
# log_good "Installing Volumes Web App..."
# div

# kustomize build apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -

# div
# log_good "Installing Tensorboard..."
# div

# kustomize build apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
# kustomize build apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -

# div
# log_good "Installing Training Operator..."
# div

# kustomize build apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -

# div
# log_good "Installing User Namespace..."
# div

# kustomize build common/user-namespace/base | kubectl apply -f -

# div