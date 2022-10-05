#!/bin/bash
# Example script to report free space for a disk partition
# Credits: https://stackoverflow.com/questions/8110530/check-free-disk-space-for-current-partition-in-bash
FREE=`df -k --output=avail /var/log | tail -n1`   # df -k not df -h
/bin/sh /home/klipper/backup_scripts/mqtt_sensor.sh -n "log_free_space" -s "$FREE" -u "bytes"
