#!/bin/bash

source logging.sh

function usage () {
    div
    log "Welcome to the MMC.AI reset wizard."
    log "The purpose of this script is to reinstall the MMC.AI stack if it enters a bad state."
    div
    log "Usage: $0 -f /path/to/mmcai-ghcr-secret.yaml"
}

usage

NAMESPACE="mmcai-system"

confirm_selection=false
confirm_mysql_database=false

while getopts "f:" opt; do
  case $opt in
    f)
        MMCAI_GHCR_SECRET="$OPTARG"
        ;;
    \?)
        div
        log_bad "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
    :)
        div
        log_bad "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
  esac
done

if [ -z "$MMCAI_GHCR_SECRET" ]; then
    log_bad "Please provide a path to mmcai-ghcr-secret.yaml."
    usage
    exit 1
fi

div
read -p "Are you sure you want to reset all MMC.AI components? This will delete your current configurations. [Y/n]:" confirm_selection
case $confirm_selection in
    [Yy]* ) confirm_selection=true;;
    * ) confirm_selection=false;;
esac

if ! $confirm_selection; then
    div
    log "Exiting..."
    exit 1
fi

# Uninstall helm charts

helm uninstall mmcai-cluster -n $NAMESPACE --timeout 1m0s --ignore-not-found
if [ $? -ne 0 ]; then
    div
    log_bad "MMC.AI cluster helm chart uninstallation failed."
fi

helm uninstall mmcai-manager -n $NAMESPACE --timeout 1m0s --ignore-not-found
if [ $? -ne 0 ]; then
    div
    log_bad "MMC.AI manager helm chart uninstallation failed."
fi

# Then, remove namespaces

div
log "Removing MMC.AI namespaces..."
kubectl delete ns $NAMESPACE mmcloud-operator-system --ignore-not-found

# Remove the gpu-operator.
# Uninstalling the helm chart may fail -- just keep chugging

div
log "Removing NVIDIA GPU Operator..."
kubectl delete crd nvidiadrivers.nvidia.com --ignore-not-found
kubectl delete crd clusterpolicies.nvidia.com --ignore-not-found
helm uninstall -n gpu-operator nvidia-gpu-operator --ignore-not-found
kubectl delete namespace gpu-operator --ignore-not-found
# NFD
kubectl delete crd nodefeatures.nfd.k8s-sigs.io --ignore-not-found
kubectl delete crd nodefeaturerules.nfd.k8s-sigs.io --ignore-not-found

# Remove the gpu-operator and monitoring namespaces

div
log "Removing dependency namespaces..."
kubectl delete ns monitoring gpu-operator

div
log_good "Removed all MMC.AI installation components. Reinstalling stack..."

div
log "Applying $MMCAI_GHCR_SECRET..."
kubectl apply -f $MMCAI_GHCR_SECRET

div
read -p "MySQL database node hostname: " mysql_node_hostname
read -sp "MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""

# MMCAI_GHCR_SECRET should have created the mmcai-system and mmcloud-operator-system namespaces
# Therefore create monitoring by hand.
kubectl create namespace monitoring

kubectl -n $NAMESPACE create secret generic mmai-mysql-secret \
    --from-literal=mysql-root-password=$MYSQL_ROOT_PASSWORD \
    --from-literal=mysql-password=$MYSQL_ROOT_PASSWORD \
    --from-literal=mysql-replication-password=$MYSQL_ROOT_PASSWORD

## Reinstall the GPU operator

wget -O gpu-operator-values.yaml https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/gpu-operator-values.yaml
wget -O nvidia-gpu-operator-setup.sh https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/nvidia-gpu-operator-setup.sh
chmod +x nvidia-gpu-operator-setup.sh
./nvidia-gpu-operator-setup.sh

## Reinstall the mysql directory

wget -O mysql-pre-setup.sh https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/mysql-pre-setup.sh
chmod +x mysql-pre-setup.sh
./mysql-pre-setup.sh

## Reinstall the charts

helm install -n $NAMESPACE mmcai-cluster oci://ghcr.io/memverge/charts/mmcai-cluster \
    --set billing.database.nodeHostname=$mysql_node_hostname

helm install -n $NAMESPACE mmcai-manager oci://ghcr.io/memverge/charts/mmcai-manager
