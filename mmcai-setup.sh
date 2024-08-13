#!/bin/bash

## Following Scott's instructions here https://memverge.atlassian.net/wiki/x/B4Dkr

source logging.sh

## welcome message

div
log "Welcome to MMC.AI setup!"
div

## uninstall gpu-operator

div
log_good "Removing existing nvidia-gpu-operator..."
div

helm uninstall nvidia-gpu-operator -n gpu-operator --cascade "foreground"

## Create a secret for pulling MemVerge docker images

div
log_good "Please provide credentials for pulling images from ghcr.io/memverge:"
div

DOCKER_CONFIG="$HOME/.docker/config.json"
IMAGE_REGISTRY="ghcr.io/memverge"
NAMESPACE="mmcai-system"

mkdir -p $(dirname $DOCKER_CONFIG)
read -p "username: " registry_username
read -sp "password or token: " registry_password
echo ""
registry_auth=$(echo -n "$registry_username:$registry_password" | base64)
if [[ ! -f $DOCKER_CONFIG ]]; then
  cat >$DOCKER_CONFIG <<EOF
{
  "auths": {
  }
}
EOF
fi
jq "if .\"auths\".\"$IMAGE_REGISTRY\"? then .\"auths\".\"$IMAGE_REGISTRY\".\"auth\"=\"$registry_auth\" else .\"auths\" += { \"$IMAGE_REGISTRY\": { \"auth\": \"$registry_auth\" } } end" \
    "$DOCKER_CONFIG" > "$DOCKER_CONFIG.tmp" && mv "$DOCKER_CONFIG.tmp" "$DOCKER_CONFIG"

div
log_good "Please provide information for billing database:"
div

read -p "MySQL database node hostname: " mysql_node_hostname
read -sp "MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""


div
log_good "Creating namespaces if needed..."
div

## Create namespaces

kubectl get namespace $NAMESPACE &>/dev/null || kubectl create namespace $NAMESPACE
kubectl get namespace mmcloud-operator-system &>/dev/null || kubectl create namespace mmcloud-operator-system
kubectl get namespace monitoring &>/dev/null || kubectl create namespace monitoring

div
log_good "Creating secrets if needed..."
div

## Create MySQL secret

kubectl -n $NAMESPACE get secret mysql-secret &>/dev/null || \
kubectl -n $NAMESPACE create secret generic mysql-secret --from-literal=mysql-root-password=$MYSQL_ROOT_PASSWORD --from-literal=mysql-password=$MYSQL_ROOT_PASSWORD # TODO: Determine which passwords are needed for what

## Create image pull secrets

kubectl -n $NAMESPACE get secret memverge-dockerconfig &>/dev/null || \
kubectl -n $NAMESPACE create secret generic memverge-dockerconfig --from-file=.dockerconfigjson=$DOCKER_CONFIG --type=kubernetes.io/dockerconfigjson

kubectl -n mmcloud-operator-system get secret memverge-dockerconfig &>/dev/null || \
kubectl -n mmcloud-operator-system create secret generic memverge-dockerconfig --from-file=.dockerconfigjson=$DOCKER_CONFIG --type=kubernetes.io/dockerconfigjson

div
log_good "Beginning installation..."
div

## install mmc.ai system
helm install -n $NAMESPACE mmcai-system charts/mmcai-system \
    --set billing.database.nodeHostname=$mysql_node_hostname \
