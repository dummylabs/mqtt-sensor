# mqtt-sensor
A simple bash script to create a mqtt sensor in Home Assistant using mqtt discovery, no manual sensor configuration is required. Below is an example of multiple-entity-row custom card showing some data from an example backup script (see examples folder):

<img width="492" alt="image" src="https://user-images.githubusercontent.com/4209521/198874418-6d5d0365-4d68-4822-827d-dc39c70fe64a.png">

# Installation

1. Make sure [MQTT discovery](https://www.home-assistant.io/docs/mqtt/discovery/) in Home Assistant is enabled.
2. Download the script to a convinient place: `wget https://raw.githubusercontent.com/dummylabs/mqtt-sensor/main/mqtt_sensor.sh` or just clone the repo: `git clone https://github.com/dummylabs/mqtt-sensor`.
3. Make it executable: `chmod +x mqtt_sensor.sh`
4. Install `mosquitto_pub` client:
   `sudo apt-get install mosquitto-clients`
4. Create configuration folder in the home directory of a user which will run this script:
   `mkdir -p ~/.config/mqtt_conf`
5. Create the configuration file with the path to mosquitto_pub utility, ip address of mqtt server and user credentials:
   `echo "/usr/bin/mosquitto_pub -h 192.168.1.15 -u my_user -P my_password" > ~/.config/mqtt_conf/mqtt.conf `


# How to use

1. Create a sensor named "foo" with the state "bar"
```sh
   sh ./mqtt_sensor.sh -n "foo" -s "bar"
```

2. Create two sensors which contain the result of last backup operation
```sh
result=$( { rsync -rltgoP /mnt/tank/share backup@192.168.1.68:/i-data/sysvol/backup; } 2>&1)

if [ $? -eq 0 ]; then
    status=OK
    backup_message=OK
else
    status=FAIL
    backup_message=$result
fi
sh ./mqtt_sensor.sh -n "last_backup_result" -s "$status"
sh ./mqtt_sensor.sh -n "last_backup_message" -s "$backup_message"
```
 This command will create two sensors named `last_backup_result` and `las_backup_message` in Home Assistant. 

3. Create a timestamp sensor which contains the last backup date:
```sh
# use your timezone here
ts=$(date +"%Y-%m-%dT%T+03:00")
# specify device_class="timestamp" with -d option
sh ./mqtt_sensor.sh -n "last_backup_date" -s "$ts" -d "timestamp"

```

# Supported options

`-c <component_name>` : OPTIONAL component name, e.g. `binary_sensor`. Default value is `sensor` <br>
`-n <sensor_name>` : MANDATORY sensor name in home assistant, e.g. `last_backup_status` <br>
`-t <state_topic>` : OPTIONAL mqtt topic to keep sensor state. Created automatically if not specified as `mqtt-sensor/<sensor_name>/state` <br>
`-s <state>` : MANDATORY sensor state <br>
`-d <device_class>` : OPTIONAL a sensor's [device class](https://developers.home-assistant.io/docs/core/entity/sensor/#available-device-classes), e.g. `timestamp`, `temperature` or `motion` <br>
`-u <unit_of_measurement>` : OPTIONAL unit of measurement for the sensor, e.g. `seconds` <br>
`-i <unique_id>` : OPTIONAL unique_id of the sensor. Created automatically if not specified as `mqtt-sensor-<sensor_name>` <br>
`-k` : Do not publish discovery topic. Discovery topic has to be published once when HA should discover a new sensor. By default this topic is updated every time the sensor state is updated. When `-k` option is set, only sensor state is published. <br>
`-v` : Verbose output for testing purposes <br>


# FAQ
1. Q: How do I remove an existing sensor?<br>
   A: Use a MQTT client (e.g., MQTT Explorer) to remove sensor's discovery topic, usually it is under `homeassistant/sensor` topic named after the sensor name, but if you use different device class (e.g., switch) it is under `homeassistant/switch`. Then remove sensor value, the topic is located under `mqtt-sensor` topic.
2. Q: Discovery topic is not updated in Home Assistant. I've tried to add unit of measurement to an existing sensor, but it was not updated in HA <br>
   A: Usually topic update runs smoothly. Try to remove discovery topic in a MQTT client and then run `mqtt_sensor.sh` again 
3. Q: I've got "Permission denied" message<br>
   A: Set up execute permissions for `mqtt_sensor.sh` according to the installation guide.
