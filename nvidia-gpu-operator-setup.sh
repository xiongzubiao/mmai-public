#!/bin/bash

source logging.sh

## uninstall gpu-operator

div
log_good "Removing existing NVIDIA GPU Operator..."
div

kubectl get namespace gpu-operator &>/dev/null || kubectl create namespace gpu-operator

helm uninstall nvidia-gpu-operator -n gpu-operator

## Wait until no pods in the gpu-operator namespace

while true; do
  # Get the output of kubectl get pods
  output=$(kubectl get pods -n gpu-operator 2>/dev/null)

  # Check if the output contains "No resources"
  if [[ $output == *"No resources"* ]]; then
    div
    log "No resources found in the gpu-operator namespace. Exiting loop."
    break
  else
    div
    log "Pods found in the gpu-operator namespace. Waiting..."
  fi

  # Wait for a short interval before checking again
  sleep 5
done

div
log_good "Installing NVIDIA GPU Operator..."
div

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia &&
helm repo update &&
helm install -n gpu-operator --wait nvidia-gpu-operator nvidia/gpu-operator --version 'v24.3.0' -f gpu-operator-values.yaml
