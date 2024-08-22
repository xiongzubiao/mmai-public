#!/bin/bash

source logging.sh

div
log "Performing kubeflow teardown."
log "First, installing kustomize..."
div

wget -O install_kustomize.sh "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
chmod +x install_kustomize.sh
./install_kustomize.sh

sudo chmod 755 kustomize

sudo cp kustomize /usr/local/bin

rm -rf kustomize
rm -rf install_kustomize.sh

cd config/kubeflow-install/manifests

attempts=4

div
log "Will attempt to delete all kubeflow resources $attempts times."
div

while [ $attempts -gt 0 ]; do
    div
    log "Deleting all kubeflow resources. Attempts left: $((attempts))"
    div
    kustomize build example | kubectl delete -f -
    sleep 15
    # Decrease the counter
    attempts=$((attempts - 1))
done

div
log "Check if there are any remaining kubeflow pods or namespaces."
log "If not, remove this directory via 'cd ..; rm -rf manifests'"
div
