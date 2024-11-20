#!/bin/bash

# Create an array with all CPU numbers
all_cpus=($(seq 0 95))

# Loop over all CPUs
for cpu in "${all_cpus[@]}"; do
  # If the CPU number is not in the keep_online array, make it offline
  echo 1 | sudo tee -a "/sys/devices/system/cpu/cpu${cpu}/online"
done
