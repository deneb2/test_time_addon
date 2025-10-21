#!/usr/bin/with-contenv bashio

# Load user credentials from options using bashio
MQTT_HOST=$(bashio::config 'mqtt_host')
MQTT_PORT=$(bashio::config 'mqtt_port')
MQTT_USER=$(bashio::config 'mqtt_user')
MQTT_PASS=$(bashio::config 'mqtt_pass')
MQTT_TOPIC=$(bashio::config 'mqtt_topic')
SERIAL_PORT=$(bashio::config 'serial_port')

# Optional: Set default values if the configuration is not available
: "${MQTT_HOST:="localhost"}"
: "${MQTT_PORT:="1883"}"
: "${MQTT_USER:="default_user"}"
: "${MQTT_PASS:="default_password"}"
: "${MQTT_TOPIC:="home/time_logger"}"
: "${SERIAL_PORT:="/dev/ttyUSB2"}"


# Set the modem to text mode - THIS MAY BE USEFUL FOR SMS, BUT NOT WORKING SO FAR
# echo -e "AT+CMGF=1\r" > "$SERIAL_PORT"
# sleep 1

while true; do
  # Wait for the serial port to become available
  while [ ! -c "$SERIAL_PORT" ]; do
      bashio::log.info "Serial port $SERIAL_PORT not found. Retrying in 5 seconds..."
      sleep 5
  done

  bashio::log.info "Listening for modem events on $SERIAL_PORT"

  # Start the socat monitor. If it exits, the outer while loop will restart it.
  socat "$SERIAL_PORT,raw,echo=0" - | while IFS= read -r line; do
    bashio::log.info "Received: $line"

    # Check for the MISSED_CALL message
    if [[ "$line" =~ MISSED_CALL:.*([+][0-9]+) ]]; then
      CALLER_NUMBER="${BASH_REMATCH[1]}"
      MESSAGE="Missed call from: $CALLER_NUMBER"

      bashio::log.info "$MESSAGE"
      mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$MQTT_TOPIC" -m "$MESSAGE"

      # Check for the +CMTI message to read SMS -
      # NOT WORKING YET
    # elif [[ "$line" =~ \+CMTI:.* ]]; then
    #   INDEX=$(echo "$line" | grep -o '[0-9]\+$')
    #   echo -e "AT+CMGR=$INDEX\r" > "$SERIAL_PORT"
    #   sleep 1
    #   response=$(cat "$SERIAL_PORT")
    #   bashio::log.info "SMS Content: $response"

    #   mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$MQTT_TOPIC" -m "SMS Content: $response"

    else
      bashio::log.info "Other message: $line"
    fi
  done

  bashio::log.warning "Restarting in 10 seconds..."
  sleep 10
done
