# mqtt-sensor
A simple bash script to create a mqtt sensor in Home Assistant using mqtt discovery. No additional sensor configuration in Home Assistant is required.

<img width="489" alt="image" src="https://user-images.githubusercontent.com/4209521/193655097-ebb4f36e-ab3a-4354-86c0-f418c1c28eb2.png">

# How to install

1. Make sure [MQTT discovery](https://www.home-assistant.io/docs/mqtt/discovery/) in Home Assistant is enabled.
2. Clone this repository to a convinient place `git clone https://github.com/dummylabs/mqtt-sensor`
3. Install mosquitto_pub and mosquitto_sub clients:
   `sudo apt-get install mosquitto-clients`
4. Create a folder in the home directory of a user which will run this script
   `mkdir -p ~/.config/mqtt_conf`
5. Create the configuration file with the path to mosquitto_pub utility, ip address of mqtt server and user credentials:
   `echo "/usr/bin/mosquitto_pub -h 192.168.1.15 -u my_user -P my_password" > ~/.config/mqtt_conf/mqtt.conf `


# Usage examples:

1. Create a text sensor which contains the result of last backup operation
```sh
result=$( { rsync -rltgoP /mnt/tank/share backup@192.168.1.68:/i-data/sysvol/backup; } 2>&1)

if [ $? -eq 0 ]; then
    status=OK
    backup_message=OK
else
    status=FAIL
    backup_message=$result
fi
sh ./mqtt_sensor.sh -n "last_backup_result" -s "$status"`
```
 This command will create a sensor named `last_backup_result` in Home Assistant. 

2. Create a timestamp sensor which contains the last backup date:
```sh
# use your timezone here
ts=$(date +"%Y-%m-%dT%T+03:00")
# specify device_class="timestamp" with -d option
sh ./mqtt_sensor.sh -n "last_backup_date" -s "$ts" -d "timestamp"

```

# Supported options

-c <component>: OPTIONAL component name, e.g. binary_sensor. Default value is "sensor" 
-n <sensor_name> : MANDATORY sensor name in home assistant, e.g. last_backup_status
-t <state_topic> : OPTIONAL mqtt topic to keep sensor state. Created automatically if not specified as `mqtt-sensor/$sensor_name/state`
-s <state> : MANDATORY sensor state
-d <device_class> : OPTIONAL a Home Assistant device class, e.g. timestamp, temperature or motion
-u <unit_of_measurement> : OPTIONAL unit of measurement for the sensor, e.g. seconds
-k : Do not publish discovery topic. By default every time the sensor updates, mqtt discovery topic is also updated. This can be altered with -k option. If specified, only sensor state will be published 
-v : Verbose output for testing purposes


# FAQ
1. Q: Discovery topic is not updated in Home Assistant. I've tried to add unit of measurement to existing sensor, but it was not updated in HA
   A: Try to remove discovery topic in a MQTT client (MQTT Explorer is a good choice) and run command again 
