#!/bin/bash

PLAYBOOK=mysql-playbook.yaml

cat > $PLAYBOOK <<EOF
---
- name: Remove directory on all nodes
  hosts: all
  become: yes
  tasks:
    - name: Ensure directory is removed
      file:
        path: /mnt/disks/mmai-mysql-billing
        state: absent
EOF

## Run ansible

ansible-playbook -i config/inventory $PLAYBOOK

rm -rf $PLAYBOOK