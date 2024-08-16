#!/bin/bash

source logging.sh

div
log "Welcome to the MMC.AI Kubeflow installer!"
div

./scripts/k8s/deploy_kubeflow.sh -w