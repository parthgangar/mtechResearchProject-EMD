#!/bin/bash

# Create an array with all CPU numbers
all_cpus=($(seq 0 95))

# Read the file with CPU numbers to keep online
# keep_online=[]
readarray -t keep_online < "$1"

# Loop over all CPUs
for cpu in "${all_cpus[@]}"; do
  # If the CPU number is not in the keep_online array, make it offline
  if [[ ! " ${keep_online[@]} " =~ " ${cpu} " ]]; then
    echo "Making CPU $cpu offline"
    echo 0 | sudo tee -a "/sys/devices/system/cpu/cpu${cpu}/online"
  fi
done
