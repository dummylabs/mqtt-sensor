#!/bin/bash
# (c) 2022 dummylabs
# https://github.com/dummylabs/mqtt-sensor

VERSION="1.0"
V="-----\nmqtt-sensor v$VERSION\nhttps://github.com/dummylabs/mqtt-sensor\n"
MQTT_CONF_TOPIC="homeassistant"
MQTT_STATE_TOPIC="mqtt-sensor"
MQTT_CMD="`cat ${XDG_CONF_HOME:-$HOME/.config}/mqtt_conf/mqtt.conf`"

error () {
  echo "Error: $1.\n${V}"
}

if [ -z "$MQTT_CMD" ]; then
  error "MQTT configuration file not found."
  exit 3
fi

# https://github.com/dummylabs/mqtt-sensor#supported-options
while getopts kvd:n:s:c:t:l:u:i:a:j: option; do
 case "${option}" in
 n) NAME=${OPTARG};;
 t) STATE_TOPIC=${OPTARG};;
 c) COMPONENT=${OPTARG};;
 s) STATE=${OPTARG}; STATE_SET=1;;
 d) DEVICE_CLASS=",\"device_class\":\"${OPTARG}\"";;
 u) UNIT_OF_MEASUREMENT=",\"unit_of_measurement\":\"${OPTARG}\"";;
 i) UNIQUE_ID=",\"unique_id\":\"${OPTARG}\"";;
 a) STATE_CLASS=",\"state_class\":\"${OPTARG}\"";;
 j) JSON_FILE="${OPTARG}";;
 k) NODISCOVERY=1;;
 v) VERBOSE=1;;
 \?) exit 2;;
 esac
done

# check if jq is installed
if command -v jq &> /dev/null 
    then JQ_INSTALLED=1 
fi


# parameters from json file take precedence over command-line args (except state and component)
if [ "$JSON_FILE" ]; then
    if [ -z ${JQ_INSTALLED} ] ; then error "You have to install jq to load json file (-j)"; exit 6; fi
    if [ ! -f $JSON_FILE ]; then error "file $JSON_FILE not found!" && exit 7; fi
    JSON_CONF=$( { cat "$JSON_FILE"; } )
    NAME=$( { echo "$JSON_CONF" | jq -r '.name' ;} )
    STATE_TOPIC=$( { echo "$JSON_CONF" | jq -r '.state_topic' ;} )
    UNIQUE_ID=$( { echo "$JSON_CONF" | jq -r '.unique_id' ;} )
    if [ "$NAME" = "null" ] || [ "$STATE_TOPIC" = "null" ] || [ "$UNIQUE_ID" = "null" ] ; then
      error "one of the keys is missing in yaml file: name, state_topic, unique_id"
      exit 5
    fi 
    # state class will not work without unit_of_measurement
    STATE_CLASS=$( { echo "$JSON_CONF" | jq -r '.state_class' ;} )
    if [ ${STATE_CLASS} != "null" ]; then
        UNIT_OF_MEASUREMENT=$( { echo "$JSON_CONF" | jq -r '.unit_of_measurement' ;} )
        if [ ${UNIT_OF_MEASUREMENT} = "null" ]; then
            error "state_class requires unit_of_measurement to be defined in yaml file."
            exit 6
        fi
    fi
fi
    
# name was not specified in command line params
if [ -z "$NAME" ] ; then
    error "sensor name should be provided (-n)"
    exit 5
fi 

#STATE can be set empty
if [ -z "$STATE_SET" ]; then
    error "sensor state should be provided (-s)".
    exit 5
fi

# set default values for undefied options (only when no yaml file provided)
if [ -z ${STATE_TOPIC} ] ; then STATE_TOPIC="$MQTT_STATE_TOPIC/$NAME/state"; fi
if [ -z ${UNIQUE_ID} ]; then UNIQUE_ID=",\"unique_id\":\"${MQTT_STATE_TOPIC}-${NAME}\""; fi
if [ -z ${COMPONENT} ]; then COMPONENT="sensor"; fi

# the same check as above for json file, but for command line params
if [ -z ${UNIT_OF_MEASUREMENT} ] && [ ${STATE_CLASS} ]; then
    error "STATE_CLASS requires UNIT_OF_MEASUREMENT (-u) to be defined."
    exit 6
fi

# configuration topic for autodiscovery
CONFIG_TOPIC="$MQTT_CONF_TOPIC/$COMPONENT/$NAME/config"
# json content for configuration topic

# config_topic payload can be either loaded from a json file or built up using command-line parameters
# Note that $NAME, $STATE and $COMPONENT cannot be loaded from json file and thus have to be 
# specified as command-line parameters. $COMPONENT will be set to 'sensor' automatically if not set 
if [ -z "$JSON_FILE" ]; then
    JSON_CONF="{\"name\":\"$NAME\",\"state_topic\":\"$STATE_TOPIC\"$UNIQUE_ID$DEVICE_CLASS$UNIT_OF_MEASUREMENT$STATE_CLASS}";
else
    if [ ! -f $JSON_FILE ]; then error "file $JSON_FILE not found!" && exit 7; fi
    JSON_CONF=$( { cat "$JSON_FILE"; } )
fi

# only update config_topic when NODISCOVERY was not set
if [ -z "$NODISCOVERY" ]; then
    if [ "$VERBOSE" ]; then
       echo ">>> SENSOR STATE: $STATE"
       echo ">>> CONFIG_TOPIC: $CONFIG_TOPIC"
       echo ">>> CONFIG_TOPIC_JSON: " 
       if [ -z ${JQ_INSTALLED} ] ; then
           echo $JSON_CONF
         else
           echo $JSON_CONF | jq
       fi
       echo "<<<\n"
       echo ">>> CONFIG_TOPIC CMD:"
       echo $MQTT_CMD -t "$CONFIG_TOPIC" -m \"$JSON_CONF\" -r
       echo "<<<\n"
    fi

    result=$( { $MQTT_CMD -t "$CONFIG_TOPIC" -m "$JSON_CONF" -r; } 2>&1)
    if [ ! $? -eq 0 ]; then
        error "publishing config topic: $result"
        exit 4
    fi
fi

if [ "$VERBOSE" ]; then
    echo ">>> STATE_TOPIC CMD:"
    echo $MQTT_CMD -t "$STATE_TOPIC" -m "$STATE" -r
    echo "<<<\n\n${V}"
fi

# update state topic
result=$( { $MQTT_CMD -t "$STATE_TOPIC" -m "$STATE" -r; } 2>&1)

if [ ! $? -eq 0 ]; then
   error "publishing state topic: $result"
   exit 4
fi
