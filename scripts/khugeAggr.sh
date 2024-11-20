#!/bin/bash

echo "always" | sudo tee -a /sys/kernel/mm/transparent_hugepage/enabled
echo "THP enabled"
echo 40960 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
   echo "Page to scan value"
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
    echo 1 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
    echo "Scan sleep millisecs value is "
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs

