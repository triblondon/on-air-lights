#!/bin/sh

args=("$@") # capture them here so we can use them if --sync's not passed
async=true

source ./config.sh

while [ $# -gt 0 ]
do
    case "$1" in
        --sync)
            async=false
            ;;
        # other options
    esac
    shift
done

for pid in $(pgrep -f on-air-monitor.sh); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : on-air-monitor.sh : Process is already running with PID $pid"
        exit 1
    else
      echo "Running with PID $pid"
    fi
done

# if --sync isn't passed, rerun the script as a background task
if [ "$async" = true ]; then
  echo "Starting on air monitor in the background"
  nohup "${BASH_SOURCE[0]}" --sync "${args[@]}" 0<&- &> /dev/null &
  exit 1
fi

# Old impl: measuring how much CPU Zoom is using
#regex_vcproc="/zoom.us$"
#regex_cpu="^ *([0-9\.]+) "
#cpu_threshold=10
#while true; do
#  vcproc=$(ps -Ao pcpu,comm -r | grep "$regex_vcproc")
#  if [[ $vcproc =~ $regex_cpu ]]; then
#    echo "${BASH_REMATCH[1]}"
#  fi
#  sleep 5
#done


echo "Monitoring camera events for $mqtt_topic"
log stream --predicate 'sender contains "appleh13camerad" and (composedMessage contains "PowerOnCamera" or composedMessage contains "PowerOffCamera")' | grep --line-buffered "ISP_Power" | while read -r line; do
  if [[ $line == *"PowerOn"* ]]; then
    echo "Video start"
    SECONDS=0
    #curl -so /dev/null "http://192.168.1.82/win&T=1" # WLED API
    #curl -so /dev/null -XPOST "http://192.168.1.83/switch/relay/turn_on" # ESPHome HTTP API
    mosquitto_pub -h $mqtt_server -p $mqtt_port -u $mqtt_user -P $mqtt_password -t home-auto/$mqtt_topic/on -m ''
    curl -s "http://homeassistant.local:8123/api/states/$ha_entity" -H "Authorization: Bearer $ha_token" -H "Content-Type: application/json" -d '{"state": "on", "attributes":{"editable":true,"icon":"mdi:video","friendly_name":"Andrew Laptop camera"}}'
  else
    echo "Video off after $SECONDS sec"
    #curl -so /dev/null "http://192.168.1.82/win&T=0"
    #curl -so /dev/null -XPOST "http://192.168.1.83/switch/relay/turn_off"
    mosquitto_pub -h $mqtt_server -p $mqtt_port -u $mqtt_user -P $mqtt_password -t home-auto/$mqtt_topic/off -m ''
    curl -s "http://homeassistant.local:8123/api/states/$ha_entity" -H "Authorization: Bearer $ha_token" -H "Content-Type: application/json" -d '{"state": "off", "attributes":{"editable":true,"icon":"mdi:video","friendly_name":"Andrew Laptop camera"}}'
  fi
done
