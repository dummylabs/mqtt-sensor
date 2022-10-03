#!/bin/bash
# -c <component> -n <sensor_name> -t <state_topic> -s <state> -d <device_class> -u <unit_of_measurement>
# -k do not publish discovery topic
# -v verbose output

MQTT_CONF_TOPIC="homeassistant"
MQTT_STATE_TOPIC="mqtt-sensor"
MQTT_CMD="`cat ${XDG_CONF_HOME:-$HOME/.config}/mqtt_conf/mqtt.conf`"

if [ -z "$MQTT_CMD" ]; then
  echo "Error: MQTT configuration file not found."
  exit 3
fi

while getopts kvd:n:s:c:t:l:u: option; do
 case "${option}" in
 n) NAME=${OPTARG};;
 t) STATE_TOPIC=${OPTARG};;
 c) COMPONENT=${OPTARG};;
 s) STATE=${OPTARG};;
 d) DEVICE_CLASS=",\"device_class\":\"${OPTARG}\"";;
 u) UNIT_OF_MEASUREMENT=",\"unit_of_measurement\":\"${OPTARG}\"";;
 k) NODISCOVERY=1;;
 v) VERBOSE=1;;
 \?) exit 2;;
 esac
done

if [ -z "$NAME" ]; then
    echo "Error: sensor name should be provided (-n)".
    exit 5
fi 

if [ -z "$STATE" ]; then
    echo "Error: sensor state should be provided (-s)".
    exit 5
fi

if [ -z ${STATE_TOPIC} ]; then STATE_TOPIC="$MQTT_STATE_TOPIC/$NAME/state"; fi

JSON_CONF="{\"name\":\"$NAME\",\"state_topic\":\"$STATE_TOPIC\"$DEVICE_CLASS$UNIT_OF_MEASUREMENT}";

if [ -z ${COMPONENT} ]; then COMPONENT="sensor"; fi

CONFIG_TOPIC="$MQTT_CONF_TOPIC/$COMPONENT/$NAME/config"

if [ -z "$NODISCOVERY" ]; then
    if [ "$VERBOSE" ]; then
       echo "Create discovery topic: TRUE"
       echo "Config topic: $CONFIG_TOPIC"
       echo "JSON data: $JSON_CONF"
       echo "State topic: $STATE_TOPIC"
       echo "State: $STATE"
       echo "Device class: $DEVICE_CLASS"
       echo "Publish discovery topic command:"
       echo $MQTT_CMD -t "$CONFIG_TOPIC" -m \"$JSON_CONF\" -r
    fi
    result=$( { $MQTT_CMD -t "$CONFIG_TOPIC" -m "$JSON_CONF" -r; } 2>&1)
    if [ ! $? -eq 0 ]; then
        echo "Error publishing config topic: $result"
        exit 4
    fi
fi

if [ "$VERBOSE" ]; then
    echo "Publish state topic command:"
    echo $MQTT_CMD -t "$STATE_TOPIC" -m "$STATE" -r
fi

result=$( { $MQTT_CMD -t "$STATE_TOPIC" -m "$STATE" -r; } 2>&1)

if [ ! $? -eq 0 ]; then
   echo "Error publishing state topic: $result"
   exit 4
fi
