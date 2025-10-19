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

while true; do
  TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "$TIMESTAMP"
  echo "host: $MQTT_HOST, port: $MQTT_PORT, user: $MQTT_USER, password: $MQTT_PASS, topic: $MQTT_TOPIC"
  
  # Publish the timestamp to the MQTT topic
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "$MQTT_TOPIC" -m "$TIMESTAMP"
  sleep 10
done
