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

# Processed calls tracking (to avoid duplicates)
PROCESSED_CALLS="/tmp/processed_calls"
touch "$PROCESSED_CALLS"

# Create Gammu configuration file
GAMMU_CONFIG="/tmp/gammurc"
cat > "$GAMMU_CONFIG" << EOF
[gammu]
device = $SERIAL_PORT
connection = at
EOF

bashio::log.info "Gammu config created at $GAMMU_CONFIG for device $SERIAL_PORT"

# Function to send next SMS from queue
send_queued_sms() {
    if [ -s "$SMS_QUEUE" ]; then
        local sms_data=$(head -n 1 "$SMS_QUEUE")
        local number=$(echo "$sms_data" | jq -r '.number // empty' 2>/dev/null)
        local message=$(echo "$sms_data" | jq -r '.message // empty' 2>/dev/null)
        
        if [ -n "$number" ] && [ -n "$message" ]; then
            bashio::log.info "Sending SMS to $number"
            
            # Send SMS using gammu with config file
            local result
            result=$(echo "$message" | gammu -c "$GAMMU_CONFIG" sendsms TEXT "$number" 2>&1)
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

# Function to check for missed calls using Gammu
check_missed_calls() {
    local call_log
    call_log=$(gammu -c "$GAMMU_CONFIG" getcalllog 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        bashio::log.debug "Could not read call log (modem may not support it): $call_log"
        return 1
    fi
    
    # Parse call log for missed calls
    echo "$call_log" | grep -i "Missed" | while IFS= read -r line; do
        # Example format: Call 1, Missed, Number "+393755403326", Date/time: 21.10.2025 15:02:00
        if [[ "$line" =~ [Nn]umber[[:space:]]*[\"\']*([+0-9]+) ]]; then
            local caller_number="${BASH_REMATCH[1]}"
            # Remove quotes if present
            caller_number=$(echo "$caller_number" | tr -d '"' | tr -d "'")
            
            # Create unique identifier for this call (number + current hour to handle multiple calls)
            local call_id="${caller_number}_$(date +%Y%m%d_%H)"
            
            # Check if we've already processed this call
            if ! grep -qF "$call_id" "$PROCESSED_CALLS" 2>/dev/null; then
                local message="Missed call from: $caller_number"
                bashio::log.info "$message"
                
                # Publish to MQTT
                mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
                    -t "$MQTT_TOPIC" -m "$message"
                
                # Mark as processed
                echo "$call_id" >> "$PROCESSED_CALLS"
                
                # Keep processed calls file manageable (last 100 entries)
                tail -100 "$PROCESSED_CALLS" > "$PROCESSED_CALLS.tmp" 2>/dev/null
                mv "$PROCESSED_CALLS.tmp" "$PROCESSED_CALLS" 2>/dev/null
            fi
        fi
    done
}

# Function to check for received SMS using Gammu (placeholder for future implementation)
check_received_sms() {
    # Future implementation:
    # local sms_list
    # sms_list=$(gammu -c "$GAMMU_CONFIG" getallsms 2>&1)
    # 
    # Parse SMS, publish to MQTT, delete from SIM
    # gammu -c "$GAMMU_CONFIG" deletesms 1 <location>
    
    return 0
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

# Main loop - Gammu-based polling pattern
bashio::log.info "Starting main monitoring loop (Gammu-based)"
while true; do
    # Wait for serial port to be available
    while [ ! -c "$SERIAL_PORT" ]; do
        bashio::log.info "Serial port $SERIAL_PORT not found. Retrying in 5 seconds..."
        sleep 5
    done

    # Priority 1: Check if we have SMS to send
    if send_queued_sms; then
        # SMS sent, shorter wait before next cycle
        bashio::log.info "SMS sent, waiting before next cycle"
        sleep 1
        continue
    fi

    # Priority 2: Check for missed calls using Gammu
    bashio::log.debug "Checking for missed calls"
    check_missed_calls

    # Priority 3: Check for received SMS (future implementation)
    # check_received_sms

    # Wait before next cycle
    sleep 10
done
