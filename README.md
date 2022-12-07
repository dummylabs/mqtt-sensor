# mqtt-sensor
A simple bash script to create a mqtt sensor in Home Assistant using mqtt discovery, no manual sensor configuration is required. Below is an example of multiple-entity-row custom card showing some data from an example backup script (see examples folder):

<img width="492" alt="image" src="https://user-images.githubusercontent.com/4209521/198874418-6d5d0365-4d68-4822-827d-dc39c70fe64a.png">

# How to use (simple mode)

1. Create an entity named `sensor.foo` with the state "bar" in Home Assistant
```sh
sh ./mqtt_sensor.sh -n foo -s bar
```

2. Create two sensors which contain the result of last backup operation
```sh
cmd_output=$( { rsync -rltgoP /mnt/tank/share backup@192.168.1.68:/i-data/sysvol/backup; } 2>&1)

if [ $? -eq 0 ]; then
    status=OK
    backup_message=OK
else
    status=FAIL
    backup_message=$cmd_output
fi
sh ./mqtt_sensor.sh -n last_backup_result -s $status
sh ./mqtt_sensor.sh -n last_backup_message -s $backup_message
```
This command will create two entities named `sensor.last_backup_result` and `sensor.last_backup_message` in Home Assistant. 

3. Create a timestamp sensor which contains the last backup date:
```sh
# use your timezone here
ts=$(date +"%Y-%m-%dT%T+03:00")
# specify device_class="timestamp" with -d option
sh ./mqtt_sensor.sh -n last_backup_date -s $ts -d timestamp

```

# How does it work

The discovery mechanism requires two MQTT topics to exist in your MQTT broker for each sensor:
1. `config_topic` - this is a configuration of your sensor: the name, unit of measurement, where to get state (state_topic) and so on. `config_topic` location and payload should obey the conventions imposed by MQTT discovery feature. The payload of this topic is JSON object.
2. `state_topic` - MQTT topic where HA should get the state of the sensor. This can be arbitrary path and content, by default all state topics created by mqtt-sensor are published under `mqtt-sensor/{sensor_name}` topic. This can be alrered with `-t` parameter.  

The mqtt-sensor creates and publish both config_topic and state_topic every on each run using either command line parameters (simple mode), or json file (JSON mode). By default config_topic is updated every time the sensor state is updated. When `-k` option is set, only sensor state is published. In theory, this can sligtly improve performance, but you'll unlikely notice the difference. Note that config_topic should exist for every sensor in order to work propely in HA.

# Installation and set up

1. Make sure [MQTT discovery](https://www.home-assistant.io/docs/mqtt/discovery/) in Home Assistant is enabled.
2. Download the script to a convinient place: `wget https://raw.githubusercontent.com/dummylabs/mqtt-sensor/main/mqtt_sensor.sh` or just clone the repo: `git clone https://github.com/dummylabs/mqtt-sensor`.
3. Make it executable: `chmod +x mqtt_sensor.sh`
4. Install `mosquitto_pub` client:
   `sudo apt-get install mosquitto-clients`
4. Create configuration folder in the home directory of a user which will run this script:
   `mkdir -p ~/.config/mqtt_conf`
5. Find out the location of `mosquitto_pub` client:
```sh
   which mosquitto_pub
   /usr/bin/mosquitto_pub
```
6. Create the configuration file with the command to run `mosquitto_pub` client. mqtt-sensor will look for it in `~/.config/mqtt_conf` folder.
   It should have the ip address of mqtt server and user credentials (if required by your MQTT broker):
   `echo "/usr/bin/mosquitto_pub -h 192.168.1.15 -u my_user -P my_password" > ~/.config/mqtt_conf/mqtt.conf `


# Supported options
`-c <component_name>` : OPTIONAL component name, e.g. `binary_sensor`. Default value is `sensor` <br>
`-n <sensor_name>` : MANDATORY sensor name in home assistant, e.g. `last_backup_status` <br>
`-t <state_topic>` : OPTIONAL mqtt topic to keep sensor state. Created automatically if not specified as `mqtt-sensor/<sensor_name>/state` <br>
`-s <state>` : MANDATORY sensor state <br>
`-d <device_class>` : OPTIONAL a sensor's [device_class](https://developers.home-assistant.io/docs/core/entity/sensor/#available-device-classes), e.g. `timestamp`, `temperature` or `motion` <br>
`-u <unit_of_measurement>` : OPTIONAL unit of measurement for the sensor, e.g. `seconds` <br>
`-i <unique_id>` : OPTIONAL unique_id of the sensor. Created automatically if not specified as `mqtt-sensor-<sensor_name>` <br>
`-a <state_class>` : OPTIONAL [state_class](https://developers.home-assistant.io/docs/core/entity/sensor/#available-state-classes) of the sensor. This requires `unit_of_measurement` to be specified as well.
`-j <json_file>`: OPTIONAL use custom JSON file for config topic. See "Advanced use cases (JSON mode)" for details. 
`-k` : Do not publish config_topic. See "How does it work" section for details. <br>
`-v` : Verbose output for testing purposes <br>

# Advanced use cases (JSON mode)
It is always recommended to use simple mode whenever it is possible. But in some rare cases one can use a custom JSON file for the `config_topic`. This can be helpful if you want to add a MQTT sensor attribute which has no matching command-line option (e.g. `native_unit_of_measurement`). The JSON mode is activated by the `-j` switch followed by a JSON file.

```sh
sh mqtt_sensor.sh -s 12 -j ./config_topic.json
```

There are 3 mandatory fields in your yaml file: `name`, `state_topic` and `unique_id`. Technically `unique_id` is not required by Home Assistant, but it makes entity control much more convenient in the UI. Then simple mode is used, both `state_topic` and `unique_id` are created automatically, but you have to specify them in the JSON mode.

```json
{
  "name": "your_sensor_name_in_HA",
  "state_topic": "mqtt-sensor/test_measurement4/state",
  "unique_id": "mqtt-sensor-test_measurement4"
}
```   

Please note:
1. In order to use JSON mode you should install `jq` utility. It will also provide fancy colorful output of JSON payload in verbose mode (-v). 
2. The bare minimum validation of the JSON file is performed using `jq` and some rules, but it's still easy to shoot yourself in the foot. If sensor is not created in Home Assistant, compare your JSON with one created automatically in the simple mode (use `-v` option to show verbose output). 
3. JSON mode force script to ignore all other command line parameters except state (`-s`) and component (`-c`).


# FAQ
1. Q: How do I remove an existing sensor?<br>
   A: Use a MQTT client (e.g., MQTT Explorer) to remove sensor's discovery topic, usually it is under `homeassistant/sensor` topic named after the sensor name, but if you use different device class (e.g., switch) it is under `homeassistant/switch`. Then remove sensor value, the topic is located under `mqtt-sensor` topic.
2. Q: Discovery topic is not updated in Home Assistant. I've tried to add unit of measurement to an existing sensor, but it was not updated in HA <br>
   A: Usually topic update runs smoothly. Try to remove discovery topic in a MQTT client and then run `mqtt_sensor.sh` again.
3. Q: I've got "Permission denied" message<br>
   A: Set up execute permissions for `mqtt_sensor.sh` according to the installation guide.
4. Q: What does "parse error:" error message mean?<br>
   A: Provided json file is mailformed, check it for formatting errors.