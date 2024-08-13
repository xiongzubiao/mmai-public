#!/bin/bash

source logging.sh

## welcome message

div
log "Welcome to the MMC.AI DeepOps setup helper!"
div

## pull yq binary -- will need it to modify config settings later

YQ_BIN=yq_linux_amd64

function yq_install() {
  local yq_version=v4.44.1
  wget https://github.com/mikefarah/yq/releases/download/${yq_version}/${YQ_BIN}.tar.gz -O - | tar xz

  # Test installation
  log "yq version:"
  ./${YQ_BIN} --version
}

function yq_uninstall() {
  rm -rf ./yq*
  rm -rf ./install-man*
}

function yq_set() {
  ./${YQ_BIN} -i "$1" $2

  local var=$(echo "$1" | sed 's/=.*//')
  local yq_get=$(./${YQ_BIN} "$var" $2)

  log "yq set $1 in $2 -> $yq_get"
}

## Check that the parent directory is deepops

if [ "$(basename "$PWD")" != "deepops" ]; then
  log_bad "User is not currently in the deepops directory; please run this script from within '/deepops/'."
  exit 1
fi

## modify relevant config values

yq_install

yq_set '.nvidia_driver_branch = "550"' roles/galaxy/nvidia.nvidia_driver/defaults/main.yml

yq_set '.container_manager = "crio"' config/group_vars/k8s-cluster.yml

yq_uninstall

div
log_good "Attempting Kubernetes setup..."
div
ansible-playbook -l k8s-cluster playbooks/k8s-cluster.yml

div
log_good "Kubernetes setup was successful!"
div
log_good "Attempting NFS client provisioner setup..."
div
ansible-playbook playbooks/k8s-cluster/nfs-client-provisioner.yml
