#!/bin/bash

# Automatically determine the node name where the script is being run
NODE_NAME=$(hostname)

# Check if the specified path exists directly on this node, and create it if it doesn't
if [ ! -d "/mnt/disks/mmai-mysql-billing" ]; then
    echo "The directory /mnt/disks/mmai-mysql-billing does not exist on this node ($NODE_NAME). Creating it now."
    sudo mkdir -p /mnt/disks/mmai-mysql-billing
    if [ $? -ne 0 ]; then
        echo "Failed to create the directory /mnt/disks/mmai-mysql-billing. Please check permissions."
        exit 1
    fi
    echo "Directory /mnt/disks/mmai-mysql-billing created successfully."
else
    echo "Directory exists on $NODE_NAME."
fi
