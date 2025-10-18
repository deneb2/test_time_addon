#!/usr/bin/with-contenv bashio

MQTT_TOPIC="home/time_logger"

# Load user credentials from options using bashio
MQTT_HOST=$(bashio::config 'mqtt_host')
MQTT_USER=$(bashio::config 'mqtt_user')
MQTT_PASS=$(bashio::config 'mqtt_pass')

# Optional: You can set default values if the configuration is not available
: "${MQTT_HOST:="localhost"}"
: "${MQTT_USER:="default_user"}"
: "${MQTT_PASS:="default_password"}"

while true; do
  TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "$TIMESTAMP"
  echo "host: $MQTT_HOST, user: $MQTT_USER, password: $MQTT_PASS, topic: $MQTT_TOPIC"
  
  # Publish the timestamp to the MQTT topic
  mosquitto_pub -h "$MQTT_HOST" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$MQTT_TOPIC" -m "$TIMESTAMP"
  sleep 20
done
