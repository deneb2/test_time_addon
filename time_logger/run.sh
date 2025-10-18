#!/usr/bin/env bash

MQTT_BROKER="localhost"  # Change if the broker is on a different host
MQTT_TOPIC="home/time_logger"

while true; do
  TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "$TIMESTAMP"
  # Publish the timestamp to the MQTT topic
  mosquitto_pub -h "$MQTT_BROKER" -t "$MQTT_TOPIC" -m "$TIMESTAMP"
  sleep 10
done
