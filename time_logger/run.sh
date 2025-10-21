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

# SMS queue file
SMS_QUEUE="/tmp/sms_queue"
touch "$SMS_QUEUE"

# Function to send next SMS from queue
send_queued_sms() {
    if [ -s "$SMS_QUEUE" ]; then
        local sms_data=$(head -n 1 "$SMS_QUEUE")
        local number=$(echo "$sms_data" | jq -r '.number // empty' 2>/dev/null)
        local message=$(echo "$sms_data" | jq -r '.message // empty' 2>/dev/null)
        
        if [ -n "$number" ] && [ -n "$message" ]; then
            bashio::log.info "Sending SMS to $number"
            
            # Send SMS using gammu with command-line parameters
            local result
            result=$(echo "$message" | gammu --device "$SERIAL_PORT" --connection at sendsms TEXT "$number" 2>&1)
            local exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                bashio::log.info "SMS sent successfully to $number"
                mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
                    -t "${MQTT_TOPIC}/sms_status" \
                    -m "{\"number\":\"$number\",\"status\":\"sent\",\"timestamp\":\"$(date -Iseconds)\"}"
            else
                bashio::log.error "Failed to send SMS to $number: $result"
                mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
                    -t "${MQTT_TOPIC}/sms_status" \
                    -m "{\"number\":\"$number\",\"status\":\"failed\",\"error\":\"$result\",\"timestamp\":\"$(date -Iseconds)\"}"
            fi
            
            # Remove from queue
            sed -i '1d' "$SMS_QUEUE"
            return 0
        else
            # Invalid entry, remove it
            bashio::log.warning "Invalid SMS entry in queue, removing"
            sed -i '1d' "$SMS_QUEUE"
            return 1
        fi
    fi
    return 1
}

# Start MQTT listener that queues SMS commands
bashio::log.info "Starting MQTT SMS command listener on topic: ${MQTT_TOPIC}/send_sms"
mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "${MQTT_TOPIC}/send_sms" | while read -r payload; do
    
    bashio::log.info "Received SMS command: $payload"
    
    # Validate JSON format
    if echo "$payload" | jq -e '.number and .message' > /dev/null 2>&1; then
        echo "$payload" >> "$SMS_QUEUE"
        bashio::log.info "SMS queued for sending"
    else
        bashio::log.error "Invalid SMS format. Expected: {\"number\":\"+1234567890\",\"message\":\"text\"}"
    fi
done &

MQTT_SUB_PID=$!
bashio::log.info "MQTT listener started (PID: $MQTT_SUB_PID)"

# Main loop - simple polling pattern
while true; do
    # Wait for serial port to be available
    while [ ! -c "$SERIAL_PORT" ]; do
        bashio::log.info "Serial port $SERIAL_PORT not found. Retrying in 5 seconds..."
        sleep 5
    done

    # Priority 1: Check if we have SMS to send
    if send_queued_sms; then
        # SMS sent, give modem time to process before next cycle
        bashio::log.info "SMS sent, waiting before next cycle"
        sleep 5
        continue
    fi

    # Priority 2: Check modem for events (socat will read and exit)
    bashio::log.info "Checking modem for events on $SERIAL_PORT"
    socat "$SERIAL_PORT,raw,echo=0" - | while IFS= read -r line; do
        bashio::log.info "Received: $line"

        # Check for MISSED_CALL message
        if [[ "$line" =~ MISSED_CALL:.*([+][0-9]+) ]]; then
            CALLER_NUMBER="${BASH_REMATCH[1]}"
            MESSAGE="Missed call from: $CALLER_NUMBER"
            bashio::log.info "$MESSAGE"
            mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
                -t "$MQTT_TOPIC" -m "$MESSAGE"

        # Check for +CMTI message to read SMS - NOT WORKING YET
        # elif [[ "$line" =~ \+CMTI:.* ]]; then
        #   INDEX=$(echo "$line" | grep -o '[0-9]\+$')
        #   echo -e "AT+CMGR=$INDEX\r" > "$SERIAL_PORT"
        #   sleep 1
        #   response=$(cat "$SERIAL_PORT")
        #   bashio::log.info "SMS Content: $response"
        #   mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
        #       -t "$MQTT_TOPIC" -m "SMS Content: $response"

        elif [ -n "$line" ]; then
            bashio::log.info "Other message: $line"
        fi
    done

    # Wait before next cycle
    sleep 10
done
