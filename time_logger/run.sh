#!/usr/bin/with-contenv bashio

# Load user credentials from options using bashio
MQTT_HOST=$(bashio::config 'mqtt_host')
MQTT_PORT=$(bashio::config 'mqtt_port')
MQTT_USER=$(bashio::config 'mqtt_user')
MQTT_PASS=$(bashio::config 'mqtt_pass')
MQTT_TOPIC=$(bashio::config 'mqtt_topic')

# Optional: Set default values if the configuration is not available
: "${MQTT_HOST:="localhost"}"
: "${MQTT_PORT:="1883"}"
: "${MQTT_USER:="default_user"}"
: "${MQTT_PASS:="default_password"}"
: "${MQTT_TOPIC:="home/time_logger"}"

# Wait for NetworkManager to detect and configure the device
bashio::log.info "Waiting for NetworkManager to detect the modem..."
sleep 30

bashio::log.info "Listening for network device changes from NetworkManager."

# Monitor D-Bus for NetworkManager device signals
# Use nmcli to verify device status
while true; do
  # Find the modem device using nmcli
  MODEM_DBUS_PATH=$(nmcli -t -f DEVICE,TYPE,DBUS_PATH device | grep -E 'modem' | awk -F: '{print $3}')

  if [ -z "$MODEM_DBUS_PATH" ]; then
      bashio::log.info "No modem found via NetworkManager."
      MESSAGE="No modem detected."
  else
      bashio::log.info "Modem detected at D-Bus path: $MODEM_DBUS_PATH"
      MESSAGE="Modem detected and being managed by NetworkManager at $MODEM_DBUS_PATH"
  fi

  echo "host: $MQTT_HOST, port: $MQTT_PORT, user: $MQTT_USER, password: $MQTT_PASS, topic: $MQTT_TOPIC, message: $MESSAGE"

  # Publish the timestamp to the MQTT topic
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$MQTT_TOPIC" -m "$MESSAGE"
  sleep 10
done
