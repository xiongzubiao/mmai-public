#!/bin/bash

curl -LfsSo logging.sh https://raw.githubusercontent.com/MemVerge/mmc.ai-setup/main/logging.sh

source logging.sh

YQ_BIN=yq_linux_amd64
DOCKER_HUB_AUTH=""

function jq_install() {
  wget -O jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
  chmod +x jq
  sudo cp jq /usr/local/bin/
}

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

function add_unqualified_registry() {
  cat << EOF > submodules/kubespray/roles/container-engine/cri-o/templates/unqualified.conf.j2
{%- set _unqualified_registries = ['docker.io'] -%}
{% for _registry in crio_registries if _registry.unqualified -%}
{% if _registry.prefix is defined -%}
{{ _unqualified_registries.append(_registry.prefix) }}
{% else %}
{{ _unqualified_registries.append(_registry.location) }}
{%- endif %}
{%- endfor %}

unqualified-search-registries = {{ _unqualified_registries | string }}
EOF
}

function cat_docker_hub_credentials() {
  if [ -z $DOCKER_HUB_AUTH ]; then
    return 1
  fi

  log "Inserting the following block:"

  cat << EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$DOCKER_HUB_AUTH"
    }
  }
}
EOF

  log "Into ./submodules/kubespray/roles/container-engine/cri-o/templates/config.json.j2"

  cat << EOF > submodules/kubespray/roles/container-engine/cri-o/templates/config.json.j2
{% if crio_registry_auth is defined and crio_registry_auth|length %}
{
{% for reg in crio_registry_auth %}
  "auths": {
    "{{ reg.registry }}": {
      "auth": "{{ (reg.username + ':' + reg.password) | string | b64encode }}"
    }
{% if not loop.last %}
  },
{% else %}
  }
{% endif %}
{% endfor %}
}
{% else %}
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$DOCKER_HUB_AUTH"
    }
  }
}
{% endif %}
EOF
}

function get_docker_hub_credentials() {
  log_good "Log into https://hub.docker.com/ and generate a \"Public Repo Read-Only\" token under Account Settings > Personal Access Token."
  div
  log_good "Please provide a Docker Hub username:"
  read docker_username
  log_good "Please provide a Docker Hub Personal Access Token:"
  read -s docker_token

  DOCKER_HUB_AUTH=$(echo -n '$docker_username:$docker_token' | base64)
}

function prompt_docker_hub_credentials() {
  ## Ask the user for docker hub login credentials;
  ## use these to construct a dockerconfigjson that can be fed to deepops
  if [ -z $PULLS_REMAINING ]; then
    return 1
  fi

  if [ $PULLS_REMAINING -lt "100" ]; then
    log_bad "You have $PULLS_REMAINING Docker Hub container image pulls remaining."
    log_bad "This is less than the default limit of 100 pulls for anonymous users."
  else
    log "You have at least 100 Docker Hub container image pulls remaining."
    log "This meets the default limit for anonymous users."
  fi

  log "Kubernetes setup may fail partway if there are not sufficient image pull requests available."
  log "Do you want to provide Docker Hub login credentials, so that you can increase your image pull limit to 200 or more? [y/N]"
  read -p "" docker_response

  case $docker_response in
    [Yy]* )
      div
      get_docker_hub_credentials
      return 0
      ;;
    * )
      log "Continuing without Docker Hub credentials..."
      return 0
      ;;
  esac
}

function get_docker_hub_stats() {
  TOKEN="$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)"
  PULLS_REMAINING="$(curl -s --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | grep -E -o "ratelimit-remaining: [0-9]+" | awk '{print $2}')"
}

div

log "Welcome to the MMC.AI Kubernetes setup helper!"

div

jq_install

div

cat_unqualified_registry

div

get_docker_hub_stats

prompt_docker_hub_credentials

cat_docker_hub_credentials

## modify relevant config values

yq_install

yq_set '.nvidia_driver_branch = "550"' roles/galaxy/nvidia.nvidia_driver/defaults/main.yml

yq_set '.container_manager = "crio"' config/group_vars/k8s-cluster.yml

yq_uninstall

## Set up ansible logs

rm -rf logs

mkdir logs

ANSIBLE_CFG=./ansible.cfg

if [[ "$(grep log_path $ANSIBLE_CFG)" -ne 0 ]]; then
  LOG_PATH=logs/k8s_deploy.log
  log "No log_path found in deepops/ansible.cfg, will set path to ./$LOG_PATH"

  # Create the logfile if it doesn't already exist
  touch $LOG_PATH
  echo "log_path = $(pwd)/$LOG_PATH" >> $ANSIBLE_CFG
  echo "display_args_to_stdout = True" >> $ANSIBLE_CFG
fi

div
log_good "Attempting Kubernetes setup..."
div
ansible-playbook -l k8s-cluster playbooks/k8s-cluster.yml
