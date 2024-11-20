#!/bin/bash

kexec -l /boot/vmlinuz-$1 --initrd=/boot/initrd.img-$1 --append="root=UUID=c9600977-5580-47a2-872b-155e747507ca ro quiet splash amd_iommu=off numa=on vt.handoff=7"
kexec -e
