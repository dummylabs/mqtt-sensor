#!/bin/bash
# example script to backup klipper configuration to a remote server using rsync
# the status, error message and duration of the last backup are shown as MQTT sensors in Home Assistant

NOW=$(date +"%Y-%d-%m")
HOME=/home/klipper
MQTT_CMD="/bin/sh /home/klipper/backup_scripts/mqtt_sensor.sh"
start_time=`date +%s`

# create two sensors in Home Assistant for backup status and error message
${MQTT_CMD} -n klipper_backup_status -s RUNNING
${MQTT_CMD} -n klipper_backup_message -s ""

result=$( { sudo service moonraker stop; } 2>&1 )
# if previous command failed, update sensor status end error message in Home Assistant
if [ $? -ne 0 ]; then
    ${MQTT_CMD} -n klipper_backup_status -s FAIL
    ${MQTT_CMD} -n klipper_backup_message -s "${result}"
    exit 1; 
fi

result=$( { rsync -a $HOME/klipper_config $HOME/.moonraker_database $HOME/gcode_files  backup2@truenas.home:/mnt/raid10/backup/klipper/$NOW; } 2>&1)

if [ $? -ne 0 ]; then
    ${MQTT_CMD} -n klipper_backup_status -s FAIL
    ${MQTT_CMD} -n klipper_backup_message -s "${result}"
    exit 1;
fi

result=$( { sudo service moonraker start; } 2>&1 )
if [ $? -ne 0 ]; then
    ${MQTT_CMD} -n klipper_backup_status -s FAIL
    ${MQTT_CMD} -n klipper_backup_message -s "${result}"
    exit 1;

fi

end_time=`date +%s`
duration=$((end_time-start_time))

${MQTT_CMD} -n klipper_backup_status -s SUCCESS
${MQTT_CMD} -n klipper_backup_duration -s "$duration" -u "seconds"
${MQTT_CMD} -n klipper_backup_message -s ""
