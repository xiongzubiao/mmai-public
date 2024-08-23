#!/bin/bash

source logging.sh

div
log "Welcome to the MMC.AI Kubeflow installer!"
log "First, setting sysctl variables across all hosts..."
div

cat > sysctl-playbook.yaml <<EOF
---
- name: Configure sysctl settings across all hosts
  hosts: all
  become: yes
  tasks:
    - name: Ensure sysctl configuration file exists
      ansible.builtin.file:
        path: /etc/sysctl.conf
        state: touch

    - name: Set fs.inotify.max_queued_events
      ansible.builtin.lineinfile:
        path: /etc/sysctl.conf
        regexp: '^fs.inotify.max_queued_events'
        line: 'fs.inotify.max_queued_events = 32384'
        create: yes

    - name: Set fs.inotify.max_user_instances
      ansible.builtin.lineinfile:
        path: /etc/sysctl.conf
        regexp: '^fs.inotify.max_user_instances'
        line: 'fs.inotify.max_user_instances = 4096'
        create: yes

    - name: Set fs.inotify.max_user_watches
      ansible.builtin.lineinfile:
        path: /etc/sysctl.conf
        regexp: '^fs.inotify.max_user_watches'
        line: 'fs.inotify.max_user_watches = 2008100'
        create: yes

    - name: Set net.core.somaxconn
      ansible.builtin.lineinfile:
        path: /etc/sysctl.conf
        regexp: '^net.core.somaxconn'
        line: 'net.core.somaxconn = 8192'
        create: yes

    - name: Apply sysctl changes
      ansible.builtin.sysctl:
        name: "{{ item.key }}"
        value: "{{ item.value }}"
        state: present
        reload: yes
      loop:
        - { key: 'fs.inotify.max_queued_events', value: '32384' }
        - { key: 'fs.inotify.max_user_instances', value: '4096' }
        - { key: 'fs.inotify.max_user_watches', value: '2008100' }
        - { key: 'net.core.somaxconn', value: '8192' }
EOF

ansible-playbook sysctl-playbook.yaml

div
log "Second, installing kubeflow..."
div

## Use newer kubeflow
sed -i 's/v1.7.0/v1.8.0/g' ./scripts/k8s/deploy_kubeflow.sh

## Set istio gateway to newer version
sed -i 's:istio-1-16:istio-1-17:g' ./scripts/k8s/deploy_kubeflow.sh

## Patch deploy_kubeflow with a git clone that checks for success
# cp ./git-clone.sh ./scripts/k8s/git-clone.sh
# cp ./logging.sh ./scripts/k8s/logging.sh
# sed -i '/^source /i\source git-clone.sh' ./scripts/k8s/deploy_kubeflow.sh
# sed -i 's:git clone:git_clone:g' ./scripts/k8s/deploy_kubeflow.sh

./scripts/k8s/deploy_kubeflow.sh