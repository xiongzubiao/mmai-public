#!/bin/bash

## Ansible playbook for directory creation

PLAYBOOK=mysql-playbook.yaml

cat > $PLAYBOOK <<EOF
---
- name: Create directory on all nodes
  hosts: all
  become: yes
  tasks:
    - name: Ensure directory exists
      file:
        path: /mnt/disks/mmai-mysql-billing
        state: directory
        mode: '0655'
EOF

## Run ansible

ansible-playbook -i config/inventory $PLAYBOOK

rm -rf $PLAYBOOK
