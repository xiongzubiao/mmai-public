#!/bin/bash

source logging.sh

## uninstall gpu-operator

div
log_good "Removing existing NVIDIA GPU Operator..."
div

kubectl get namespace gpu-operator &>/dev/null || kubectl create namespace gpu-operator

helm uninstall nvidia-gpu-operator -n gpu-operator

if [[ "$?" -eq 0 ]]; then
  div
  log "Helm uninstallation of gpu-operator failed. See setup guide for more details."
fi

## Wait until no pods in the gpu-operator namespace

while true; do
  # Get the output of kubectl get pods
  output=$(kubectl get pods -n gpu-operator 2>&1)

  # Check if the output contains "No resources"
  if [[ $output == *"No resources"* ]]; then
    div
    log "No resources found in the gpu-operator namespace. Exiting loop."
    break
  else
    div
    log "Pods found in the gpu-operator namespace:"
    log $output
    log "Waiting 5s for termination..."
  fi

  # Wait for a short interval before checking again
  sleep 5
done

div
log_good "Upgrading helm installation..."
div

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

div
log_good "Installing NVIDIA GPU Operator..."
div

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia &&
helm repo update &&
helm install -n gpu-operator --wait nvidia-gpu-operator nvidia/gpu-operator --version 'v24.3.0' -f gpu-operator-values.yaml
