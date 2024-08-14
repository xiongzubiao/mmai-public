#!/bin/bash

source logging.sh

## uninstall gpu-operator

div
log_good "Removing existing NVIDIA GPU Operator..."
div

kubectl get namespace gpu-operator &>/dev/null || kubectl create namespace gpu-operator

helm uninstall nvidia-gpu-operator -n gpu-operator --cascade "foreground" --ignore-not-found

div
log_good "Installing NVIDIA GPU Operator..."
div

helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update
helm install -n gpu-operator --wait nvidia-gpu-operator nvidia/gpu-operator --version 'v24.3.0' -f gpu-operator-values.yaml
