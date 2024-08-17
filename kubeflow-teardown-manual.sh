#!/bin/bash

git clone https://github.com/kubeflow/manifests.git kubeflow --branch v1.8.1
cd kubeflow

div
log_good "Uninstalling Kubeflow..."
div

while ! kustomize build example | kubectl delete -f -; do echo "Retrying to delete resources"; sleep 20; done