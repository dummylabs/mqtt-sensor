#!/bin/bash
# example script to backup klipper (https://klipper3d.org) configuration to a remote server using rsync command
# the status, error message and duration of the last backup are exposed as MQTT sensors to Home Assistant

# location of mqtt_sensor script, make sure it has execute permission
MQTT_CMD="/usr/local/bin/mqtt_sensor.sh"
# all sensor IDs will have this prefix
SENSOR_PREFIX=klipper
BACKUP_CMD="rsync -rltgoP /mnt/tank/share backup@192.168.1.68:/i-data/sysvol/backup;"

start_time=`date +%s`

# create/update sensor for the backup process status
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_status -s RUNNING
# create/update sensor for last backup error message
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_message -s ""

# keep output of the backup command
cmd_output=$( ${BACKUP_CMD} 2>&1 )
status=$?
duration=$((`date +%s`-start_time))
ts=$(date +"%Y-%m-%dT%T+03:00")
# create/update sensor for backup process duration
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_duration -s "$duration" -u "seconds"


if [ $status -ne 0 ]; then # backup process failed
    ${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_status -s FAIL
    ${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_message -s "${cmd_output}"
    exit 1;
fi

# backup process completed successfully
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_status -s SUCCESS
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_message -s ""
# create/update timestamp sensor for the last successfull backup
${MQTT_CMD} -n ${SENSOR_PREFIX}_backup_last_success -s "$ts" -d "timestamp"
